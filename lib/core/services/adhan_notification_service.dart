import 'dart:async';
import 'dart:convert';

import 'package:adhan/adhan.dart';
import 'package:flutter/foundation.dart';
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

  // Using v2 channel ID to force recreation with adhan.mp3 sound
  static const String _channelId = 'adhan_prayer_times_v2';
  
  // Old channel IDs to clean up
  static const List<String> _oldChannelIds = [
    'adhan_prayer_times',
    'adhan_prayer_times_custom',
  ];

  // Android: expects a file at android/app/src/main/res/raw/adhan.(mp3|wav|ogg)
  static const AndroidNotificationSound _adhanSound =
      RawResourceAndroidNotificationSound('adhan');

  // iOS: expects a bundled sound file (e.g. Runner -> adhan.caf)
  static const String _iosAdhanSoundName = 'adhan.caf';

  static const int _daysToScheduleAhead = 30;

  final FlutterLocalNotificationsPlugin _plugin;
  final SettingsService _settings;
  final LocationService _location;
  final PrayerTimesCacheService _cache;

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

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(initSettings);

    await recreateAndroidChannels();
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

    // Create new Adhan channel with adhan.mp3 sound
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        sound: _adhanSound,
        audioAttributesUsage: AudioAttributesUsage.alarm,
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
    await cancelAll();
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
    } catch (_) {
      // Ignore preview persistence failures.
    }
  }

  Future<void> testNow() async {
    await _plugin.show(
      999001,
      'Adhan Test',
      'If you hear the Adhan, reminders are working.',
      _notificationDetails(),
    );
  }

  Future<void> scheduleTestIn(Duration delay) async {
    final when = tz.TZDateTime.now(tz.local).add(delay);

    await _plugin.zonedSchedule(
      999002,
      'Adhan Test (Scheduled)',
      'This should play Adhan even if the app is closed.',
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
        playSound: true,
        enableVibration: true,
        sound: _adhanSound,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        fullScreenIntent: true, // Show full screen for alarm-like behavior
        audioAttributesUsage: AudioAttributesUsage.alarm,
        ongoing: false,
        autoCancel: true,
        timeoutAfter: 60000, // Auto-dismiss after 1 minute
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
