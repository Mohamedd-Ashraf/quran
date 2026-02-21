import 'dart:async';
import 'dart:convert';

import 'package:adhan/adhan.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

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
  
  // Old channel IDs to clean up
  static const List<String> _oldChannelIds = [
    'adhan_prayer_times',
    'adhan_prayer_times_custom',
    'adhan_prayer_times_v2',
  ];

  // iOS: expects a bundled sound file (e.g. Runner -> adhan.caf)
  static const String _iosAdhanSoundName = 'adhan.caf';

  static const int _daysToScheduleAhead = 30;

  final FlutterLocalNotificationsPlugin _plugin;
  final SettingsService _settings;
  final LocationService _location;
  final PrayerTimesCacheService _cache;

  final List<Timer> _inAppTimers = [];
  // _isAdhanPlaying removed — AdhanPlayerService manages its own concurrency.
  DateTime? _lastAdhanStartedAt;
  String? _lastInAppScheduleSignature;
  DateTime? _lastInAppScheduleAt;

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

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(initSettings);

    await recreateAndroidChannels();
    await _initAdhanPlayer();
  }

  Future<void> _initAdhanPlayer() async {
    // Android playback is handled natively via MethodChannel.
  }

  Future<void> _playFullAdhanAudio() async {
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
        // Use the foreground service so audio plays even when the app is in the background.
        final ok = await _androidAdhanPlayerChannel.invokeMethod<bool>(
          'startAdhanService',
          {'soundName': soundId},
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
    try {
      final soundId = _settings.getSelectedAdhanSound();
      final alarms = preview.map((item) {
        final timeStr = item['time'] as String?;
        if (timeStr == null) return null;
        final dt = DateTime.tryParse(timeStr);
        if (dt == null) return null;
        return <String, dynamic>{
          'id': item['id'] as int,
          'timeMs': dt.millisecondsSinceEpoch,
        };
      }).whereType<Map<String, dynamic>>().toList();

      await _androidAdhanPlayerChannel.invokeMethod('scheduleAdhanAlarms', {
        'alarms': alarms,
        'soundName': soundId,
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
      final raw = _settings.getAdhanSchedulePreview();
      if (raw == null || raw.isEmpty) return;
      final list = jsonDecode(raw) as List;
      final ids = list
          .whereType<Map>()
          .map((e) => e['id'])
          .whereType<int>()
          .toList();
      if (ids.isEmpty) return;
      await _androidAdhanPlayerChannel.invokeMethod('cancelAdhanAlarms', {'ids': ids});
      debugPrint('🔔 [Adhan] AlarmManager: cancelled ${ids.length} alarm(s)');
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

  void _scheduleInAppAdhanFromPreview(List<Map<String, dynamic>> preview) {
    final normalizedTimes = <String>[];
    for (final item in preview) {
      final timeIso = item['time'] as String?;
      if (timeIso != null && timeIso.isNotEmpty) {
        normalizedTimes.add(timeIso);
      }
    }
    normalizedTimes.sort();
    final signature = normalizedTimes.join('|');
    final lastSignature = _lastInAppScheduleSignature;
    final lastAt = _lastInAppScheduleAt;
    if (lastSignature == signature && lastAt != null && DateTime.now().difference(lastAt) < const Duration(minutes: 2)) {
      debugPrint('🔔 [Adhan] In-app timer schedule unchanged, skipping reschedule');
      return;
    }

    _lastInAppScheduleSignature = signature;
    _lastInAppScheduleAt = DateTime.now();
    _clearInAppTimers();

    final now = DateTime.now();
    final end = now.add(const Duration(hours: 48));

    for (final item in preview) {
      final timeIso = item['time'] as String?;
      if (timeIso == null || timeIso.isEmpty) continue;
      final dt = DateTime.tryParse(timeIso);
      if (dt == null) continue;
      if (!dt.isAfter(now) || dt.isAfter(end)) continue;

      final delay = dt.difference(now);
      _inAppTimers.add(
        Timer(delay, () async {
          await _playFullAdhanAudio();
        }),
      );
    }

    debugPrint('🔔 [Adhan] Scheduled ${_inAppTimers.length} in-app adhan timer(s)');
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
    await cancelAll();
    await _cancelAllNativeAlarms();
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

  Future<void> ensureScheduled() async {
    final enabled = _settings.getAdhanNotificationsEnabled();
    if (!enabled) return;

    final coords = await _ensureCoordinatesForScheduling();
    if (coords == null) return;

    // Update prayer times cache if invalid or stale
    if (!_cache.isCacheValid()) {
      await _cache.cachePrayerTimes(coords.latitude, coords.longitude);
    }

    // Schedule multiple days ahead so reminders still fire when the app is closed.
    final now = tz.TZDateTime.now(tz.local);
    final today = DateTime(now.year, now.month, now.day);

    await cancelAll();
    final preview = <Map<String, dynamic>>[];
    for (var i = 0; i < _daysToScheduleAhead; i++) {
      final items = await _scheduleForDate(coords, today.add(Duration(days: i)));
      for (final it in items) {
        preview.add(it);
      }
    }

    await _settings.setLastAdhanScheduleDateIso(today.toIso8601String());

    // Persist a snapshot of what we scheduled (for UI display).
    // Note: this does not guarantee OS delivery, but reflects our intended schedule.
    try {
      preview.sort((a, b) {
        final ta = DateTime.tryParse(a['time'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        final tb = DateTime.tryParse(b['time'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        return ta.compareTo(tb);
      });
      await _settings.setAdhanSchedulePreview(jsonEncode(preview));
      _scheduleInAppAdhanFromPreview(preview);
      await _scheduleNativeAlarms(preview);
    } catch (_) {
      // Ignore preview/schedule failures.
    }
  }

  Future<void> testNow() async {
    await _playFullAdhanAudio();
    await _plugin.show(
      999001,
      'Adhan Test',
      'If you hear the Adhan, reminders are working.',
      _notificationDetails(),
    );
  }

  Future<void> scheduleTestIn(Duration delay) async {
    final when = tz.TZDateTime.now(tz.local).add(delay);
    final whenLocal = DateTime.now().add(delay);

    // In-app timer (fires if app stays open)
    Timer(delay, () async {
      await _playFullAdhanAudio();
    });

    // Native AlarmManager alarm (fires even when app is killed)
    await _scheduleNativeAlarms([
      {
        'id': 999002,
        'time': whenLocal.toIso8601String(),
        'prayer': 'test',
        'label': 'Test',
      }
    ]);

    // Silent OS notification as a companion reminder
    await _plugin.zonedSchedule(
      999002,
      'اختبار الأذان',
      'إذا سمعت الأذان، فالتطبيق يعمل بشكل صحيح ✓',
      when,
      _notificationDetails(),
      androidScheduleMode: await _androidScheduleMode(),
    );
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  Future<Coordinates?> _ensureCoordinatesForScheduling() async {
    final cached = _settings.getLastKnownCoordinates();
    if (cached != null) return cached;

    final cachedFromTimes = _cache.getCachedLocation();
    if (cachedFromTimes != null) {
      return Coordinates(cachedFromTimes.latitude, cachedFromTimes.longitude);
    }

    // Try getting a fresh location once.
    final permission = await _location.ensurePermission();
    if (permission != LocationPermissionState.granted) {
      return null;
    }

    try {
      final pos = await _location.getPosition(timeout: const Duration(seconds: 12));
      await _settings.setLastKnownCoordinates(pos.latitude, pos.longitude);
      return Coordinates(pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _scheduleForDate(Coordinates coordinates, DateTime date) async {
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

    final includeFajr = _settings.getAdhanIncludeFajr();

    final items = <_PrayerNotifItem>[
      _PrayerNotifItem(Prayer.fajr, 'Fajr', prayerTimesMap['fajr']!, enabled: includeFajr),
      _PrayerNotifItem(Prayer.dhuhr, 'Dhuhr', prayerTimesMap['dhuhr']!),
      _PrayerNotifItem(Prayer.asr, 'Asr', prayerTimesMap['asr']!),
      _PrayerNotifItem(Prayer.maghrib, 'Maghrib', prayerTimesMap['maghrib']!),
      _PrayerNotifItem(Prayer.isha, 'Isha', prayerTimesMap['isha']!),
    ];

    final scheduled = <Map<String, dynamic>>[];
    for (final item in items) {
      if (!item.enabled) continue;

      final localTime = tz.TZDateTime.from(item.time.toLocal(), tz.local);
      // Don't schedule notifications in the past.
      if (localTime.isBefore(tz.TZDateTime.now(tz.local))) continue;

      final id = _notificationId(date, item.prayer);
      await _plugin.zonedSchedule(
        id,
        'Prayer Time',
        '${item.label} time',
        localTime,
        _notificationDetails(),
        androidScheduleMode: await _androidScheduleMode(),
      );

      scheduled.add({
        'id': id,
        'prayer': item.prayer.name,
        'label': item.label,
        'time': item.time.toLocal().toIso8601String(),
      });
    }

    return scheduled;
  }

  NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.max,
        playSound: false, // SILENT
        enableVibration: true,
        // sound: _adhanSound, // REMOVED
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        fullScreenIntent: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        ongoing: false,
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

  Future<AndroidScheduleMode> _androidScheduleMode() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }

    try {
      final canExact = await android.canScheduleExactNotifications();
      return (canExact ?? false)
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;
    } catch (_) {
      return AndroidScheduleMode.inexactAllowWhileIdle;
    }
  }

  int _notificationId(DateTime day, Prayer prayer) {
    // Deterministic per day+prayer; stable and under int32 range.
    final ymd = day.year * 10000 + day.month * 100 + day.day;
    return (ymd * 10) + prayer.index;
  }
}

class _PrayerNotifItem {
  final Prayer prayer;
  final String label;
  final DateTime time;
  final bool enabled;

  _PrayerNotifItem(this.prayer, this.label, this.time, {this.enabled = true});
}
