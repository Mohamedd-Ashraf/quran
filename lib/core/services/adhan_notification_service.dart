import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:adhan/adhan.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../constants/adhan_sounds.dart';
import '../constants/prayer_calculation_constants.dart';
import 'location_service.dart';
import 'settings_service.dart';
import 'prayer_times_cache_service.dart';

/// Schedules local notifications at the calculated prayer times.
///
/// Notes:
/// - On Android, notifications + exact alarms require user approval on newer OS versions.
/// - Always uses custom adhan.mp3 sound from res/raw.
class AdhanNotificationService {
  static const String _channelName = 'Prayer Times';
  static const String _channelDescription = 'Prayer time reminders with Adhan sound.';
  static const MethodChannel _androidAdhanPlayerChannel =
      MethodChannel('quraan/adhan_player');

  // V3: Silent channel. We rely on the native MediaPlayer via MethodChannel for audio.
  // This avoids conflicts/ducking/cutting between notification sound and media player.
  static const String _channelId = 'adhan_prayer_times_v3_silent';

  // Reminder channels — one per prayer so users can customise each independently
  // in Android → App info → Notifications, and each prayer has its own voice.
  // v1 channels kept for fajr/asr/isha (sounds unchanged).
  // v2 channels for dhuhr/maghrib (updated to approaching sounds).
  static const String _reminderChannelFajr    = 'prayer_reminder_fajr_v1';
  static const String _reminderChannelDhuhr   = 'prayer_reminder_dhuhr_v2'; // v2: approaching sound
  static const String _reminderChannelAsr     = 'prayer_reminder_asr_v1';
  static const String _reminderChannelMaghrib = 'prayer_reminder_maghrib_v2'; // v2: approaching sound
  static const String _reminderChannelIsha    = 'prayer_reminder_isha_v1';
  static const String _reminderChannelName        = 'Pre-Prayer Reminder';
  static const String _reminderChannelDescription = 'Alert N minutes before each prayer.';
  static const String _iqamaChannelId             = 'iqama_reminder_v2'; // v2: full iqama sound
  static const String _iqamaChannelName           = 'Iqama Reminder';
  static const String _iqamaChannelDescription    = 'Alert N minutes after the prayer call.';
  // Salawat: 5 dedicated channels — one per sound option.
  // Channels are immutable after creation, so each sound needs its own channel.
  static const String _salawatChannelId1    = 'salawat_1_v1';
  static const String _salawatChannelId2    = 'salawat_2_v1';
  static const String _salawatChannelId3    = 'salawat_3_v1';
  static const String _salawatChannelId4    = 'salawat_4_v1';
  static const String _salawatChannelId5    = 'salawat_5_v1';
  static const String _salawatChannelName         = 'Salawat Reminder';
  static const String _salawatChannelDescription  = 'Periodic salawat (blessings on the Prophet \u33ba) reminders.';

  // Old channel IDs to clean up on next launch
  static const List<String> _oldChannelIds = [
    'adhan_prayer_times',
    'adhan_prayer_times_custom',
    'adhan_prayer_times_v2',
    'prayer_reminders_v1',        // merged into 3 separate channels
    'prayer_reminder_v2',          // replaced by 5 prayer-specific channels
    'prayer_reminder_dhuhr_v1',   // replaced by v2 with approaching sound
    'prayer_reminder_maghrib_v1', // replaced by v2 with approaching sound
    'salawat_reminder_v1',        // replaced by 5 dedicated salawat channels
    'iqama_reminder_v1',          // replaced by v2 with full iqama sound
  ];

  // iOS: expects a bundled sound file (e.g. Runner -> adhan.caf)
  static const String _iosAdhanSoundName = 'adhan.caf';

  // Maximum days we'll ever schedule (hard ceiling so we never cross 60 days).
  static const int _maxDaysToSchedule = 60;
  // Minimum days to guarantee reliability even with many reminders enabled.
  static const int _minDaysToSchedule = 30;
  // Cairo, Egypt fallback used only when no location is available yet.
  static final Coordinates _defaultEgyptCoordinates = Coordinates(
    30.0444,
    31.2357,
  );
  static const int _rescheduleWindowDays = 7;

  final FlutterLocalNotificationsPlugin _plugin;
  final SettingsService _settings;
  final LocationService _location;
  final PrayerTimesCacheService _cache;

  final List<Timer> _inAppTimers = [];
  // _isAdhanPlaying removed — AdhanPlayerService manages its own concurrency.
  DateTime? _lastAdhanStartedAt;

  // Mutex: prevents concurrent ensureScheduled() calls from racing and
  // causing alarm accumulation that exceeds Android's 500-alarm limit.
  bool _isScheduling = false;
  bool _schedulePending = false;

  AdhanNotificationService(
    this._plugin,
    this._settings,
    this._location,
    this._cache,
  );

  Future<void> init() async {
    tz.initializeTimeZones();
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    } catch (_) {
      // Fallback: tz.local will still work on many platforms.
    }

    const androidInit = AndroidInitializationSettings('@drawable/ic_notification');
    const iosInit = DarwinInitializationSettings();
    const windowsInit = WindowsInitializationSettings(
      appName: 'Quraan',
      appUserModelId: 'com.example.quraan',
      guid: 'a8d4b6e2-3f1c-4a7d-9e2b-5c0f8a1d3e6b',
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
      windows: windowsInit,
    );

    try {
      await _plugin.initialize(initSettings);
    } catch (e) {
      debugPrint('[Adhan] Notification plugin init failed (non-fatal): $e');
    }

    await recreateAndroidChannels();
    await _initAdhanPlayer();
  }

  Future<void> _initAdhanPlayer() async {
    // Android playback is handled natively via MethodChannel.
  }

  Future<void> _playFullAdhanAudio({String? prayerArabicName}) async {
    try {
      final now = DateTime.now();
      // 35-second cooldown guard prevents double-triggers from overlapping timers.
      final lastStart = _lastAdhanStartedAt;
      if (lastStart != null && now.difference(lastStart) < const Duration(seconds: 35)) {
        debugPrint('🔇 [Adhan] Ignored duplicate trigger within cooldown window');
        return;
      }
      _lastAdhanStartedAt = now;

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final soundId = _settings.getSelectedAdhanSound();
        final sound = AdhanSounds.findById(soundId);
        final ok = await _androidAdhanPlayerChannel.invokeMethod<bool>(
          'startAdhanService',
          {
            'soundName': soundId,
            'shortMode': _settings.getAdhanShortMode(),
            'shortCutoffSeconds': sound.shortDurationSeconds,
            'onlineUrl': sound.isOnline ? sound.url : null,
            'fallbackSoundName': AdhanSounds.offlineFallback.id,
            'useAlarmStream': _settings.getAdhanAudioStream() == 'alarm',
            if (prayerArabicName != null && prayerArabicName.isNotEmpty) ...{
              'notifTitle': 'أذان $prayerArabicName',
              'notifBody': 'اضغط لإيقاف الأذان',
            },
          },
        );
        if (ok == true) {
          debugPrint('🔊 [Adhan] AdhanPlayerService started: $soundId');
          return;
        }
      }

      // Fallback for non-Android / service failure.
      await _plugin.show(
        999003,
        'وقت الصلاة',
        'حان وقت الصلاة',
        _notificationDetails(),
      );
      debugPrint('🔔 [Adhan] Fallback notification shown');
    } catch (e) {
      debugPrint('Adhan playback error: $e');
    }
  }

  // ── Native AlarmManager scheduling ──────────────────────────────

  /// Pushes all future prayer-time alarms to the Android AlarmManager.
  /// These alarms survive the app being killed and fire AdhanPlayerService.
  Future<void> _scheduleNativeAlarms(List<Map<String, dynamic>> preview) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    const arabicPrayerNames = {
      'fajr': 'الفجر',
      'dhuhr': 'الظهر',
      'asr': 'العصر',
      'maghrib': 'المغرب',
      'isha': 'العشاء',
    };
    try {
      final soundId = _settings.getSelectedAdhanSound();
      final sound = AdhanSounds.findById(soundId);
      final alarms = preview.map((item) {
        final timeStr = item['time'] as String?;
        if (timeStr == null) return null;
        final dt = DateTime.tryParse(timeStr);
        if (dt == null) return null;
        final prayer = item['prayer'] as String? ?? '';
        final arabicName = arabicPrayerNames[prayer] ?? (item['label'] as String? ?? '');
        return <String, dynamic>{
          'id': item['id'] as int,
          'timeMs': dt.millisecondsSinceEpoch,
          'arabicName': arabicName,
        };
      }).whereType<Map<String, dynamic>>().toList();

      await _androidAdhanPlayerChannel.invokeMethod('scheduleAdhanAlarms', {
        'alarms': alarms,
        'soundName': soundId,
        'shortMode': _settings.getAdhanShortMode(),
        'shortCutoffSeconds': sound.shortDurationSeconds,
        'onlineUrl': sound.isOnline ? sound.url : null,
        'fallbackSoundName': AdhanSounds.offlineFallback.id,
        'useAlarmStream': _settings.getAdhanAudioStream() == 'alarm',
      });
      debugPrint('🔔 [Adhan] AlarmManager: scheduled ${alarms.length} alarm(s)');
    } catch (e) {
      debugPrint('Native alarm scheduling error: $e');
    }
  }

  /// Cancels all previously scheduled AlarmManager alarms using the stored IDs.
  Future<void> _cancelAllNativeAlarms() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      // Cancel adhan alarms.
      final raw = _settings.getAdhanSchedulePreview();
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List;
        final ids = list
            .whereType<Map>()
            .map((e) => e['id'])
            .whereType<int>()
            .toList();
        if (ids.isNotEmpty) {
          await _androidAdhanPlayerChannel.invokeMethod('cancelAdhanAlarms', {'ids': ids});
          debugPrint('🔔 [Adhan] AlarmManager: cancelled ${ids.length} alarm(s)');
        }
      }
      // Cancel iqama alarms — use saved iqama IDs (different from adhan IDs).
      try {
        final raw2 = _settings.getIqamaAlarmIds();
        if (raw2 != null && raw2.isNotEmpty) {
          final ids2 = (jsonDecode(raw2) as List).whereType<int>().toList();
          if (ids2.isNotEmpty) {
            await _androidAdhanPlayerChannel.invokeMethod('cancelIqamaAlarms', {'ids': ids2});
            debugPrint('🔔 [Iqama] AlarmManager: cancelled ${ids2.length} alarm(s)');
          }
        }
      } catch (_) {}
      // Cancel approaching-reminder alarms.
      try {
        final raw3 = _settings.getApproachingAlarmIds();
        if (raw3 != null && raw3.isNotEmpty) {
          final ids3 = (jsonDecode(raw3) as List).whereType<int>().toList();
          if (ids3.isNotEmpty) {
            await _androidAdhanPlayerChannel.invokeMethod('cancelApproachingAlarms', {'ids': ids3});
            debugPrint('🔔 [Approaching] AlarmManager: cancelled ${ids3.length} alarm(s)');
          }
        }
      } catch (_) {}
      // Cancel salawat alarms.
      try {
        final raw4 = _settings.getSalawatAlarmIds();
        if (raw4 != null && raw4.isNotEmpty) {
          final ids4 = (jsonDecode(raw4) as List).whereType<int>().toList();
          if (ids4.isNotEmpty) {
            await _androidAdhanPlayerChannel.invokeMethod('cancelSalawatAlarms', {'ids': ids4});
            debugPrint('🌙 [Salawat] AlarmManager: cancelled ${ids4.length} alarm(s)');
          }
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('Native alarm cancel error: $e');
    }
  }

  void _clearInAppTimers() {
    for (final t in _inAppTimers) {
      t.cancel();
    }
    _inAppTimers.clear();
  }

  Future<void> recreateAndroidChannels() async {
    if (kIsWeb) return;

    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    // Delete all old channels (best-effort cleanup)
    for (final oldId in _oldChannelIds) {
      try {
        await android.deleteNotificationChannel(oldId);
      } catch (_) {}
    }
    
    // Delete current channel if it exists
    try {
      await android.deleteNotificationChannel(_channelId);
    } catch (_) {}

    // Create new Adhan channel with SILENT settings as we play audio via native MediaPlayer
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.max,
        playSound: false, // Ensure no double audio triggers
        enableVibration: true,
        // sound: _adhanSound, // DO NOT USE
      ),
    );

    // Reminder channel — text notifications with OS default sound.
    // Note: createNotificationChannel() is idempotent. We do NOT delete reminder channels
    // on every launch because Android discards pending notifications when a channel is deleted.
    final reminderChannels = [
      // Five prayer-specific reminder channels.
      // Fajr/Asr/Isha: original voice files (v1 unchanged).
      // Dhuhr/Maghrib: approaching-prayer sounds (v2 — new channels).
      const AndroidNotificationChannel(
        _reminderChannelFajr, _reminderChannelName,
        description: _reminderChannelDescription,
        importance: Importance.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('prayer_reminder_fajr'),
        enableVibration: true,
      ),
      const AndroidNotificationChannel(
        _reminderChannelDhuhr, _reminderChannelName,
        description: _reminderChannelDescription,
        importance: Importance.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('prayer_approaching_dhuhr'),
        enableVibration: true,
      ),
      const AndroidNotificationChannel(
        _reminderChannelAsr, _reminderChannelName,
        description: _reminderChannelDescription,
        importance: Importance.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('prayer_reminder_asr'),
        enableVibration: true,
      ),
      const AndroidNotificationChannel(
        _reminderChannelMaghrib, _reminderChannelName,
        description: _reminderChannelDescription,
        importance: Importance.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('prayer_approaching_maghrib'),
        enableVibration: true,
      ),
      const AndroidNotificationChannel(
        _reminderChannelIsha, _reminderChannelName,
        description: _reminderChannelDescription,
        importance: Importance.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('prayer_reminder_isha'),
        enableVibration: true,
      ),
      const AndroidNotificationChannel(
        _iqamaChannelId, _iqamaChannelName,
        description: _iqamaChannelDescription,
        importance: Importance.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('iqama_sound_full'),
        enableVibration: true,
      ),
      // Five salawat channels — one per sound option (sounds are baked at channel creation).
      const AndroidNotificationChannel(
        _salawatChannelId1, _salawatChannelName,
        description: _salawatChannelDescription,
        importance: Importance.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('salawat_1'),
        enableVibration: false,
      ),
      const AndroidNotificationChannel(
        _salawatChannelId2, _salawatChannelName,
        description: _salawatChannelDescription,
        importance: Importance.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('salawat_2'),
        enableVibration: false,
      ),
      const AndroidNotificationChannel(
        _salawatChannelId3, _salawatChannelName,
        description: _salawatChannelDescription,
        importance: Importance.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('salawat_3'),
        enableVibration: false,
      ),
      const AndroidNotificationChannel(
        _salawatChannelId4, _salawatChannelName,
        description: _salawatChannelDescription,
        importance: Importance.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('salawat_4'),
        enableVibration: false,
      ),
      const AndroidNotificationChannel(
        _salawatChannelId5, _salawatChannelName,
        description: _salawatChannelDescription,
        importance: Importance.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('salawat_5'),
        enableVibration: false,
      ),
    ];
    for (final ch in reminderChannels) {
      await android.createNotificationChannel(ch);
    }
  }

  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;

    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

    var ok = true;

    if (android != null) {
      final notifOk = await android.requestNotificationsPermission();
      ok = ok && (notifOk ?? true);

      // Best-effort: exact alarms permission (Android 12+).
      try {
        await android.requestExactAlarmsPermission();
      } catch (_) {
        // Some Android versions/devices may not support this API; ignore.
      }
    }

    if (ios != null) {
      final notifOk = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      ok = ok && (notifOk ?? true);
    }

    return ok;
  }

  Future<void> disable() async {
    await _settings.setAdhanNotificationsEnabled(false);
    _clearInAppTimers();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _androidAdhanPlayerChannel.invokeMethod<void>('stopAdhan');
      } catch (_) {}
    }
    await cancelAll();               // Cancels ALL pending notifications (adhan, reminders, iqama, salawat)
    await _cancelAllNativeAlarms();   // Cancels AlarmManager alarms
    // Clear the schedule preview so the UI schedule dialog shows empty, not stale data.
    await _settings.setAdhanSchedulePreview('[]');
    // صلاة على النبي ﷺ reminders are independent of adhan.
    // Re-schedule them so they keep working even when adhan is disabled.
    await _scheduleSalawatNotifications();
  }

  /// Stops the currently playing Adhan without disabling future scheduled notifications.
  /// Call this when the user starts Quran audio so the two don't overlap.
  Future<void> stopCurrentAdhan() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _androidAdhanPlayerChannel.invokeMethod<void>('stopAdhan');
      } catch (_) {}
    }
  }

  Future<void> enableAndSchedule() async {
    await _settings.setAdhanNotificationsEnabled(true);
    await ensureScheduled();
  }

  // ── Offline cache for selected online sound ─────────────────────────────────

  /// Returns the local cache directory shared with AdhanPlayerService.kt.
  /// Must match: filesDir/adhan_cache in native code.
  Future<Directory> _adhanCacheDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/adhan_cache');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Returns the expected cache file path for an online sound.
  Future<File> _adhanCacheFile(AdhanSoundInfo sound) async {
    final dir = await _adhanCacheDir();
    return File('${dir.path}/${sound.id}.mp3');
  }

  /// Downloads and caches the given online adhan sound.
  /// Safe to call multiple times — skips if file is already cached.
  Future<void> _downloadAdhanSound(AdhanSoundInfo sound) async {
    if (!sound.isOnline || sound.url == null) return;
    try {
      final file = await _adhanCacheFile(sound);
      if (file.existsSync() && file.lengthSync() > 1024) {
        debugPrint('[AdhanCache] Already cached: ${sound.id}');
        return;
      }
      debugPrint('[AdhanCache] Downloading: ${sound.id} — ${sound.url}');
      final request = http.Request('GET', Uri.parse(sound.url!));
      final response = await request.send();
      if (response.statusCode != 200) {
        debugPrint('[AdhanCache] HTTP ${response.statusCode} for ${sound.id}');
        return;
      }
      final tmpFile = File('${file.path}.tmp');
      final sink = tmpFile.openWrite();
      await for (final chunk in response.stream) {
        sink.add(chunk);
      }
      await sink.close();
      // Atomic rename: only replace the cache file once the download is complete.
      await tmpFile.rename(file.path);
      debugPrint('[AdhanCache] Cached successfully: ${sound.id}');
    } catch (e) {
      debugPrint('[AdhanCache] Download failed for ${sound.id}: $e');
    }
  }

  /// Called once on app startup.
  /// If the user has selected an online adhan sound that is not yet cached,
  /// downloads it silently in the background so it plays offline at prayer time.
  Future<void> ensureSelectedSoundCached() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final soundId = _settings.getSelectedAdhanSound();
    final sound = AdhanSounds.findById(soundId);
    if (!sound.isOnline) return; // bundled sounds need no caching
    await _downloadAdhanSound(sound);
  }

  /// Requests location permission and caches real GPS coordinates if not already saved.
  ///
  /// Call this once after the first frame (bypasses the schedule-freshness check)
  /// so location permission is asked on first launch — not deferred until the
  /// user opens the prayer times screen.  After the first successful GPS read
  /// the coordinates are persisted; subsequent calls are instant no-ops.
  Future<void> requestLocationIfNeeded() async {
    if (kIsWeb) return;
    // Already have real GPS coordinates — nothing to do.
    if (_settings.getLastKnownCoordinates() != null) return;

    final permission = await _location.ensurePermission();
    if (permission != LocationPermissionState.granted) return;

    try {
      final pos = await _location.getPosition(
        timeout: const Duration(seconds: 15),
      );
      await _settings.setLastKnownCoordinates(pos.latitude, pos.longitude);
      // Refresh prayer-times cache with the real location so the schedule
      // (and prayer times screen) reflect accurate times from the first launch.
      await _cache.cachePrayerTimes(pos.latitude, pos.longitude);
      // Trigger a full reschedule now that we have a real position.
      await ensureScheduled();
    } catch (_) {
      // Silent fail — Egypt fallback will be used until the user grants
      // permission or until getPosition succeeds on the next launch.
    }
  }

  Future<void> ensureScheduled({bool requestLocationPermission = true}) async {
    // If a scheduling is already in progress, just flag that another run is
    // needed after it finishes. This prevents concurrent calls from racing
    // (cancel-then-add interleaving) and blowing past the 500-alarm limit.
    if (_isScheduling) {
      _schedulePending = true;
      return;
    }
    _isScheduling = true;
    try {
      await _doEnsureScheduled(
        requestLocationPermission: requestLocationPermission,
      );
      // If settings changed while we were scheduling, run once more.
      while (_schedulePending) {
        _schedulePending = false;
        await _doEnsureScheduled(
          requestLocationPermission: requestLocationPermission,
        );
      }
    } finally {
      _isScheduling = false;
    }
  }

  Future<void> ensureScheduleFresh({bool requestLocationPermission = false}) async {
    if (!_needsScheduleRefresh()) return;
    await ensureScheduled(requestLocationPermission: requestLocationPermission);
  }

  Future<void> _doEnsureScheduled({bool requestLocationPermission = true}) async {
    final enabled = _settings.getAdhanNotificationsEnabled();
    if (!enabled) return;

    final coords = await _ensureCoordinatesForScheduling(
      requestPermission: requestLocationPermission,
    );
    if (coords == null) return;

    // Update prayer times cache if invalid or stale
    if (!_cache.isCacheValid()) {
      await _cache.cachePrayerTimes(coords.latitude, coords.longitude);
    }

    // Schedule multiple days ahead so reminders still fire when the app is closed.
    final now = tz.TZDateTime.now(tz.local);
    final today = DateTime(now.year, now.month, now.day);

    await cancelAll();             // clear flutter_local_notifications alarms (including from older app versions)
    await _cancelAllNativeAlarms(); // cancel existing native AlarmManager alarms before re-registering
    final days = computeDaysAhead();
    final preview              = <Map<String, dynamic>>[];
    final allIqamaAlarms       = <Map<String, dynamic>>[];
    final allApproachingAlarms = <Map<String, dynamic>>[];
    for (var i = 0; i < days; i++) {
      final r = await _scheduleForDate(coords, today.add(Duration(days: i)));
      preview.addAll(r.scheduled);
      allIqamaAlarms.addAll(r.iqama);
      allApproachingAlarms.addAll(r.approaching);
    }

    // Persist a snapshot of what we scheduled (for UI display).
    // Note: this does not guarantee OS delivery, but reflects our intended schedule.
    // IMPORTANT: setLastAdhanScheduleDateIso is stamped INSIDE the try block so
    // that if scheduling fails mid-way, the date is not marked as done and
    // ensureScheduleFresh() will retry on the next resume/launch within the same day.
    try {
      preview.sort((a, b) {
        final ta = DateTime.tryParse(a['time'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        final tb = DateTime.tryParse(b['time'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        return ta.compareTo(tb);
      });
      await _settings.setAdhanSchedulePreview(jsonEncode(preview));
      await _scheduleNativeAlarms(preview);
      // Iqama — schedule all days at once and persist IDs for correct cancellation.
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        try {
          await _androidAdhanPlayerChannel.invokeMethod('scheduleIqamaAlarms', {
            'alarms':  allIqamaAlarms,
            'enabled': _settings.getIqamaEnabled(),
          });
          await _settings.setIqamaAlarmIds(
              jsonEncode(allIqamaAlarms.map((a) => a['id']).toList()));
          debugPrint('🔔 [Iqama] Native: scheduled ${allIqamaAlarms.length} alarm(s)');
        } catch (e) {
          debugPrint('🔔 [Iqama] Native scheduling error: $e');
        }
        // Approaching — schedule all days at once and persist all IDs.
        try {
          final remEnabled = _settings.getPrayerReminderEnabled();
          final remMinutes = _settings.getPrayerReminderMinutes();
          await _androidAdhanPlayerChannel.invokeMethod('scheduleApproachingAlarms', {
            'alarms':  allApproachingAlarms,
            'enabled': remEnabled && remMinutes > 0,
          });
          await _settings.setApproachingAlarmIds(
              jsonEncode(allApproachingAlarms.map((a) => a['id']).toList()));
          debugPrint('🔔 [Approaching] Native: scheduled ${allApproachingAlarms.length} alarm(s)');
        } catch (e) {
          debugPrint('🔔 [Approaching] Native scheduling error: $e');
        }
      }
      await _scheduleSalawatNotifications();
      // Stamp the schedule date only after all alarms have been submitted.
      // Placing this here (instead of before the try block) means a failure
      // anywhere above leaves the date un-stamped, so ensureScheduleFresh()
      // will retry on the next app resume or launch within the same day.
      await _settings.setLastAdhanScheduleDateIso(today.toIso8601String());
    } catch (e) {
      // Log scheduling failures instead of swallowing them silently.
      debugPrint('⚠️ [Adhan] Scheduling failed — will retry next launch: $e');
    }
  }

  bool _needsScheduleRefresh() {
    if (!_settings.getAdhanNotificationsEnabled()) return false;

    final rawPreview = _settings.getAdhanSchedulePreview();
    if (rawPreview == null || rawPreview.trim().isEmpty || rawPreview.trim() == '[]') {
      return true;
    }

    final lastIso = _settings.getLastAdhanScheduleDateIso();
    if (lastIso == null || lastIso.isEmpty) return true;

    final lastScheduledDate = DateTime.tryParse(lastIso);
    if (lastScheduledDate == null) return true;

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // Force a full reschedule once per calendar day.
    // AlarmManager alarms are silently cleared on APK update, wake-lock
    // expiry, or aggressive battery optimisation. The native boot/update
    // receiver attempts recovery, but can race with a cold-start or be
    // skipped entirely.  Rescheduling on first launch of each new day
    // guarantees alarms are always registered, at the cost of a few
    // extra seconds of background work per day — acceptable for a prayer app.
    final lastDateOnly = DateTime(
      lastScheduledDate.year,
      lastScheduledDate.month,
      lastScheduledDate.day,
    );
    if (todayDate.isAfter(lastDateOnly)) return true;

    // Within the same day, only reschedule when the window is running short.
    final scheduledThrough = lastDateOnly.add(Duration(days: computeDaysAhead() - 1));
    final remainingDays = scheduledThrough.difference(todayDate).inDays;
    return remainingDays <= _rescheduleWindowDays;
  }

  /// Dynamically computes the optimal number of days to schedule ahead,
  /// keeping total AlarmManager registrations safely under Android's 500-alarm limit.
  ///
  /// Budget: 500 limit - 30 (salawat if on) - 20 (safety) ÷ (prayers × types)
  /// Clamped to [14 .. 60] days.
  int computeDaysAhead() {
    const int limit   = 500;
    const int buffer  = 20;
    const int salawatCap = 30; // matches _scheduleSalawatNotifications

    final enabledPrayers = [
      _settings.getAdhanIncludeFajr(),
      _settings.getAdhanEnableDhuhr(),
      _settings.getAdhanEnableAsr(),
      _settings.getAdhanEnableMaghrib(),
      _settings.getAdhanEnableIsha(),
    ].where((e) => e).length;

    if (enabledPrayers == 0) return _maxDaysToSchedule;

    // Alarm types per prayer per day
    int typesPerPrayer = 1; // adhan always
    if (_settings.getIqamaEnabled()) {
      typesPerPrayer++;
    }
    if (_settings.getPrayerReminderEnabled() &&
        _settings.getPrayerReminderMinutes() > 0) {
      typesPerPrayer++;
    }

    // Always reserve salawatCap regardless of getSalawatEnabled() to prevent
    // overflow if the setting is read inconsistently mid-cycle (e.g. during a
    // rapid settings change + phone lock). With 500 - 30 - 20 = 450 available,
    // the worst case is 450 prayer alarms + 30 salawat = 480 < 500.
    const salawatBudget = salawatCap;
    final available = limit - salawatBudget - buffer;
    final perDay    = enabledPrayers * typesPerPrayer;

    return (available / perDay).floor().clamp(_minDaysToSchedule, _maxDaysToSchedule);
  }

  Future<void> testNow() async {
    // Uses the same native AdhanPlayerService path as a real prayer alarm.
    // No extra flutter_local_notifications — the foreground service posts its own notification.
    await _playFullAdhanAudio(prayerArabicName: 'الأذان');
  }

  Future<void> scheduleTestIn(Duration delay) async {
    final whenLocal = DateTime.now().add(delay);

    // In-app timer (fires if app stays open) — mirrors real adhan startup path.
    Timer(delay, () async {
      await _playFullAdhanAudio(prayerArabicName: 'الأذان');
    });

    // Native AlarmManager alarm via setAlarmClock() — same path as real prayer alarms.
    // Fires even when the app is killed or the screen is off.
    await _scheduleNativeAlarms([
      {
        'id': 999002,
        'time': whenLocal.toIso8601String(),
        'prayer': 'test',
        'label': 'Test',
      }
    ]);
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  Future<Coordinates?> _ensureCoordinatesForScheduling({
    bool requestPermission = true,
  }) async {
    final cached = _settings.getLastKnownCoordinates();
    if (cached != null) return cached;

    final cachedFromTimes = _cache.getCachedLocation();
    if (cachedFromTimes != null) {
      return Coordinates(cachedFromTimes.latitude, cachedFromTimes.longitude);
    }

    if (requestPermission) {
      final permission = await _location.ensurePermission();
      if (permission == LocationPermissionState.granted) {
        try {
          final pos = await _location.getPosition(
            timeout: const Duration(seconds: 12),
          );
          await _settings.setLastKnownCoordinates(pos.latitude, pos.longitude);
          return Coordinates(pos.latitude, pos.longitude);
        } catch (_) {
          // Fall through to Egypt fallback so first-launch scheduling never stays empty.
        }
      }
    }

    return _defaultEgyptCoordinates;
  }

  Future<({List<Map<String, dynamic>> scheduled, List<Map<String, dynamic>> iqama, List<Map<String, dynamic>> approaching})> _scheduleForDate(Coordinates coordinates, DateTime date) async {
    // Try to use cached prayer times first (offline support)
    final cachedTimes = _cache.getCachedTimesForDate(date);
    
    Map<String, DateTime> prayerTimesMap;
    
    if (cachedTimes != null) {
      // Use cached times (offline mode)
      prayerTimesMap = cachedTimes;
    } else {
      // Fallback: calculate fresh times with user's preferred method
      final calculationMethod = _settings.getPrayerCalculationMethod();
      final asrMethod = _settings.getPrayerAsrMethod();
      final params = PrayerCalculationConstants.getCompleteParameters(
        calculationMethod: calculationMethod,
        asrMethod: asrMethod,
      );
      
      final prayerTimes = PrayerTimes(
        coordinates,
        DateComponents(date.year, date.month, date.day),
        params,
      );

      prayerTimesMap = {
        'fajr': prayerTimes.fajr,
        'dhuhr': prayerTimes.dhuhr,
        'asr': prayerTimes.asr,
        'maghrib': prayerTimes.maghrib,
        'isha': prayerTimes.isha,
      };
    }

    final isArabic = _settings.getAppLanguage() == 'ar';

    const arabicNames = {
      'fajr': 'الفجر',
      'dhuhr': 'الظهر',
      'asr': 'العصر',
      'maghrib': 'المغرب',
      'isha': 'العشاء',
    };

    // Per-prayer enabled flags.
    final items = <_PrayerNotifItem>[
      _PrayerNotifItem(Prayer.fajr,    'Fajr',    prayerTimesMap['fajr']!,    enabled: _settings.getAdhanIncludeFajr()),
      _PrayerNotifItem(Prayer.dhuhr,   'Dhuhr',   prayerTimesMap['dhuhr']!,   enabled: _settings.getAdhanEnableDhuhr()),
      _PrayerNotifItem(Prayer.asr,     'Asr',     prayerTimesMap['asr']!,     enabled: _settings.getAdhanEnableAsr()),
      _PrayerNotifItem(Prayer.maghrib, 'Maghrib', prayerTimesMap['maghrib']!, enabled: _settings.getAdhanEnableMaghrib()),
      _PrayerNotifItem(Prayer.isha,    'Isha',    prayerTimesMap['isha']!,    enabled: _settings.getAdhanEnableIsha()),
    ];

    final reminderEnabled = _settings.getPrayerReminderEnabled();
    final reminderMinutes = _settings.getPrayerReminderMinutes();
    final iqamaEnabled    = _settings.getIqamaEnabled();
    final schedMode       = _androidScheduleMode();
    final now             = tz.TZDateTime.now(tz.local);
    final isAndroid       = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    // Native alarms (Android only) — collected then bulk-scheduled after the loop.
    final iqamaNativeAlarms       = <Map<String, dynamic>>[];
    final approachingNativeAlarms = <Map<String, dynamic>>[];

    final scheduled = <Map<String, dynamic>>[];
    for (final item in items) {
      if (!item.enabled) continue;

      final localTime  = tz.TZDateTime.from(item.time.toLocal(), tz.local);
      final arabicName = arabicNames[item.prayer.name] ?? item.label;

      // ── Iqama reminder ────────────────────────────────────────────────────
      // Evaluated BEFORE the adhan-past check so that the iqama alarm is
      // (re-)scheduled even when the app reschedules between adhan and iqama
      // time.  Without this, _cancelAllNativeAlarms() wipes the previously
      // registered iqama alarm and it is never re-added because the adhan's
      // localTime is already in the past.
      if (iqamaEnabled) {
        final iqamaMinutes = switch (item.prayer) {
          Prayer.fajr    => _settings.getIqamaMinutesFajr(),
          Prayer.dhuhr   => _settings.getIqamaMinutesDhuhr(),
          Prayer.asr     => _settings.getIqamaMinutesAsr(),
          Prayer.maghrib => _settings.getIqamaMinutesMaghrib(),
          Prayer.isha    => _settings.getIqamaMinutesIsha(),
          _              => _settings.getIqamaMinutes(),
        };
        if (iqamaMinutes > 0) {
          final iqamaTime  = localTime.add(Duration(minutes: iqamaMinutes));
          // Only add if the iqama itself is still in the future.
          if (iqamaTime.isAfter(now)) {
            final iqamaId    = _iqamaNotificationId(date, item.prayer);
            final iqamaTitle = isArabic ? 'إقامة: $arabicName' : 'Iqama: ${item.label}';
            final iqamaBody  = isArabic
                ? 'حان وقت الإقامة لصلاة $arabicName'
                : 'Time to stand for ${item.label} prayer';
            if (isAndroid) {
              iqamaNativeAlarms.add({
                'id':     iqamaId,
                'timeMs': iqamaTime.millisecondsSinceEpoch,
                'title':  iqamaTitle,
                'body':   iqamaBody,
              });
            } else {
              await _plugin.zonedSchedule(
                iqamaId, iqamaTitle, iqamaBody,
                iqamaTime,
                _iqamaNotificationDetails(),
                androidScheduleMode: schedMode,
              );
            }
          }
        }
      }

      // ── Don't schedule adhan or pre-prayer reminder in the past ──────────
      if (localTime.isBefore(now)) continue;

      final id = _notificationId(date, item.prayer);

      // ── Only add to schedule (drives native alarms + preview UI) ─────────
      // Audio + foreground notification are handled by AdhanPlayerService.
      // No additional OS notification here — that caused Doze-delayed double-play.
      scheduled.add({
        'id': id,
        'prayer': item.prayer.name,
        'label': item.label,
        'time': item.time.toLocal().toIso8601String(),
      });

      // ── Pre-prayer reminder ──────────────────────────────────────────────
      if (reminderEnabled && reminderMinutes > 0) {
        final reminderTime = localTime.subtract(Duration(minutes: reminderMinutes));
        if (reminderTime.isAfter(now)) {
          final remId    = _reminderNotificationId(date, item.prayer);
          final remTitle = isArabic
              ? 'تنبيه: $arabicName بعد $reminderMinutes دقيقة'
              : '${item.label} in $reminderMinutes min';
          final remBody  = isArabic
              ? 'استعد لصلاة $arabicName'
              : 'Prepare for ${item.label} prayer';
          if (isAndroid) {
            // Android: route through ApproachingAlarmReceiver → AdhanPlayerService
            // so the app volume slider (approaching_volume) actually controls the level.
            approachingNativeAlarms.add({
              'id':     remId,
              'timeMs': reminderTime.millisecondsSinceEpoch,
              'title':  remTitle,
              'body':   remBody,
              'sound':  _reminderSoundFile(item.prayer),
            });
          } else {
            // iOS: flutter_local_notifications handles it
            await _plugin.zonedSchedule(
              remId, remTitle, remBody,
              reminderTime,
              _reminderNotificationDetails(item.prayer),
              androidScheduleMode: schedMode,
            );
          }
        }
      }
    }

    // Iqama and approaching alarms are returned to the caller (_doEnsureScheduled)
    // for bulk scheduling across all days in a single native call — this prevents
    // per-day ID overwrites that caused < all IDs to be saved for cancellation.
    return (scheduled: scheduled, iqama: iqamaNativeAlarms, approaching: approachingNativeAlarms);
  }

  NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.max,
        playSound: false, // SILENT — audio via AdhanPlayerService
        enableVibration: true,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        // fullScreenIntent removed – it caused wake+play on Doze-delayed delivery
        autoCancel: true,
        icon: '@drawable/ic_notification',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: true,
        sound: _iosAdhanSoundName,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
  }

  // Uses AlarmManager.setAlarmClock() — same as native Adhan/Iqama receivers.
  // Reliable delivery in Doze mode with no runtime permission required.
  AndroidScheduleMode _androidScheduleMode() => AndroidScheduleMode.alarmClock;

  int _notificationId(DateTime day, Prayer prayer) {
    // Deterministic per day+prayer; stable and under int32 range.
    final ymd = day.year * 10000 + day.month * 100 + day.day;
    return (ymd * 10) + prayer.index;
  }

  /// ID for pre-prayer reminder — offset 300M to avoid collision with main adhan IDs.
  int _reminderNotificationId(DateTime day, Prayer prayer) {
    final ymd = day.year * 10000 + day.month * 100 + day.day;
    return 300000000 + (ymd % 1000000) * 10 + prayer.index;
  }

  /// ID for iqama reminder — offset 600M.
  int _iqamaNotificationId(DateTime day, Prayer prayer) {
    final ymd = day.year * 10000 + day.month * 100 + day.day;
    return 600000000 + (ymd % 1000000) * 10 + prayer.index;
  }

  /// Returns the reminder channel ID for a given prayer.
  String _reminderChannelId(Prayer prayer) {
    switch (prayer) {
      case Prayer.fajr:    return _reminderChannelFajr;
      case Prayer.dhuhr:   return _reminderChannelDhuhr;
      case Prayer.asr:     return _reminderChannelAsr;
      case Prayer.maghrib: return _reminderChannelMaghrib;
      case Prayer.isha:    return _reminderChannelIsha;
      default:             return _reminderChannelDhuhr;
    }
  }

  /// Returns the raw-resource sound file name for a given prayer's reminder.
  /// Dhuhr and Maghrib use dedicated approaching-prayer sounds.
  String _reminderSoundFile(Prayer prayer) {
    switch (prayer) {
      case Prayer.fajr:    return 'prayer_reminder_fajr';
      case Prayer.dhuhr:   return 'prayer_approaching_dhuhr';   // replaced with approaching sound
      case Prayer.asr:     return 'prayer_reminder_asr';
      case Prayer.maghrib: return 'prayer_approaching_maghrib'; // replaced with approaching sound
      case Prayer.isha:    return 'prayer_reminder_isha';
      default:             return 'prayer_approaching_dhuhr';
    }
  }

  /// Notification details for pre-prayer reminder (prayer-specific Arabic voice).
  NotificationDetails _reminderNotificationDetails(Prayer prayer) {
    final channelId  = _reminderChannelId(prayer);
    final soundFile  = _reminderSoundFile(prayer);
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        _reminderChannelName,
        channelDescription: _reminderChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(soundFile),
        enableVibration: true,
        category: AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.public,
        autoCancel: true,
        icon: '@drawable/ic_notification',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: false,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
  }

  /// Notification details for iqama (stands-for-prayer sound).
  NotificationDetails _iqamaNotificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _iqamaChannelId,
        _iqamaChannelName,
        channelDescription: _iqamaChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('iqama_sound_full'),
        enableVibration: true,
        category: AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.public,
        autoCancel: true,
        icon: '@drawable/ic_notification',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: false,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
  }

  /// Returns the channel ID for the currently selected salawat sound.
  String _salawatChannelId() {
    final soundId = _settings.getSalawatSound();
    switch (soundId) {
      case 'salawat_2': return _salawatChannelId2;
      case 'salawat_3': return _salawatChannelId3;
      case 'salawat_4': return _salawatChannelId4;
      case 'salawat_5': return _salawatChannelId5;
      default:          return _salawatChannelId1; // salawat_1 or any unknown value
    }
  }

  /// Notification details for Salawat reminders.
  /// Uses the channel matching the currently selected salawat sound.
  NotificationDetails _salawatNotificationDetails() {
    final channelId = _salawatChannelId();
    final soundId   = _settings.getSalawatSound();
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        _salawatChannelName,
        channelDescription: _salawatChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(soundId),
        enableVibration: false,
        category: AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.public,
        autoCancel: true,
        icon: '@drawable/ic_notification',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: false,
        interruptionLevel: InterruptionLevel.active,
      ),
    );
  }

  /// Schedules periodic salawat (صلاة على النبي) reminder notifications.
  /// Up to 100 notifications, each [salawatMinutes] apart.
  Future<void> _scheduleSalawatNotifications() async {
    // Always cancel old flutter_local_notifications salawat slots (migration + refresh).
    for (var i = 0; i < 100; i++) {
      await _plugin.cancel(700000000 + i);
    }

    final enabled = _settings.getSalawatEnabled();
    final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    if (isAndroid) {
      // ── Android: native AlarmManager → AdhanPlayerService ─────────────────
      // Cancel any previously scheduled native alarms first.
      try {
        final storedIds = _settings.getSalawatAlarmIds();
        if (storedIds != null && storedIds.isNotEmpty) {
          final ids = (jsonDecode(storedIds) as List).whereType<int>().toList();
          if (ids.isNotEmpty) {
            await _androidAdhanPlayerChannel.invokeMethod('cancelSalawatAlarms', {'ids': ids});
          }
        }
      } catch (_) {}

      if (!enabled) {
        await _settings.setSalawatAlarmIds('[]');
        return;
      }

      final intervalMinutes = _settings.getSalawatMinutes();
      if (intervalMinutes <= 0) return;

      final sleepEnabled = _settings.getSalawatSleepEnabled();
      final sleepStartH  = _settings.getSalawatSleepStartH();
      final sleepEndH    = _settings.getSalawatSleepEndH();

      bool isInSleep(tz.TZDateTime t) {
        if (!sleepEnabled) return false;
        final h = t.hour;
        if (sleepStartH > sleepEndH) return h >= sleepStartH || h < sleepEndH;
        return h >= sleepStartH && h < sleepEndH;
      }

      final isArabic  = _settings.getAppLanguage() == 'ar';
      final soundName = _settings.getSalawatSound();

      final salawatTexts = [
        isArabic ? 'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ' : 'O Allah, send blessings upon Muhammad ﷺ',
        isArabic ? 'صَلَّى اللهُ عَلَيْهِ وَسَلَّمَ' : 'Peace and blessings be upon the Prophet ﷺ',
        isArabic ? 'اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ' : 'O Allah, send peace upon our Prophet Muhammad ﷺ',
      ];

      final now = tz.TZDateTime.now(tz.local);
      final nativeAlarms = <Map<String, dynamic>>[];

      for (var i = 0; i < 30; i++) {
        final triggerTime = now.add(Duration(minutes: intervalMinutes * (i + 1)));
        if (isInSleep(triggerTime)) continue;
        final text = salawatTexts[i % salawatTexts.length];
        nativeAlarms.add({
          'id':     700000000 + i,
          'timeMs': triggerTime.millisecondsSinceEpoch,
          'title':  isArabic ? '🌙 الصلاة على النبي' : '🌙 Salawat Reminder',
          'body':   text,
          'sound':  soundName,
        });
      }

      try {
        await _androidAdhanPlayerChannel.invokeMethod('scheduleSalawatAlarms', {
          'alarms':  nativeAlarms,
          'enabled': enabled,
        });
        await _settings.setSalawatAlarmIds(
            jsonEncode(nativeAlarms.map((a) => a['id']).toList()));
        debugPrint('🌙 [Salawat] Native: scheduled ${nativeAlarms.length} alarm(s) every ${intervalMinutes}m');
      } catch (e) {
        debugPrint('🌙 [Salawat] Native scheduling error: $e');
      }
      return;
    }

    // ── iOS: flutter_local_notifications ────────────────────────────────────
    if (!enabled) return;

    final intervalMinutes = _settings.getSalawatMinutes();
    if (intervalMinutes <= 0) return;

    final sleepEnabled = _settings.getSalawatSleepEnabled();
    final sleepStartH  = _settings.getSalawatSleepStartH();
    final sleepEndH    = _settings.getSalawatSleepEndH();

    bool isInSleep(tz.TZDateTime t) {
      if (!sleepEnabled) return false;
      final h = t.hour;
      if (sleepStartH > sleepEndH) return h >= sleepStartH || h < sleepEndH;
      return h >= sleepStartH && h < sleepEndH;
    }

    final isArabic = _settings.getAppLanguage() == 'ar';
    final schedMode = _androidScheduleMode();

    final salawatTexts = [
      isArabic ? 'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ' : 'O Allah, send blessings upon Muhammad ﷺ',
      isArabic ? 'صَلَّى اللهُ عَلَيْهِ وَسَلَّمَ' : 'Peace and blessings be upon the Prophet ﷺ',
      isArabic ? 'اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ' : 'O Allah, send peace upon our Prophet Muhammad ﷺ',
    ];

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = 0;

    for (var i = 0; i < 30; i++) {
      final triggerTime = now.add(Duration(minutes: intervalMinutes * (i + 1)));
      if (isInSleep(triggerTime)) continue;
      final text = salawatTexts[i % salawatTexts.length];
      try {
        await _plugin.zonedSchedule(
          700000000 + i,
          isArabic ? '🌙 الصلاة على النبي' : '🌙 Salawat Reminder',
          text,
          triggerTime,
          _salawatNotificationDetails(),
          androidScheduleMode: schedMode,
        );
        scheduled++;
      } catch (_) {
        break;
      }
    }

    debugPrint('🌙 [Salawat] Scheduled $scheduled reminder(s) every ${intervalMinutes}m');
  }
}

class _PrayerNotifItem {
  final Prayer prayer;
  final String label;
  final DateTime time;
  final bool enabled;

  _PrayerNotifItem(this.prayer, this.label, this.time, {this.enabled = true});
}
