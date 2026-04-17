import 'dart:io';

import 'package:flutter/services.dart';

/// Manages a persistent Android foreground notification that always shows
/// the current prayer, next prayer, and remaining time.
///
/// Implementation notes:
/// - The actual work is done by [PrayerTimesService.kt] — a pure native
///   Android foreground service.  All data is read from SharedPreferences
///   inside the native service, so no Dart isolate is involved.
/// - The notification is user-enabled from settings and includes a stop action
///   so users can disable it directly from the notification shade.
/// - The notification icon uses Splash_dark_transparent.png from Flutter
///   assets (same as AdhanAlarmReceiver).
/// - Operations are forwarded to native via the existing `quraan/adhan_player`
///   MethodChannel.
/// - No-op on iOS.
class PrayerForegroundService {
  PrayerForegroundService._();

  static const MethodChannel _channel = MethodChannel('quraan/adhan_player');

  /// Starts the native PrayerTimesService foreground service (Android only).
  static Future<void> start() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('startPrayerTimesService');
    } catch (_) {
      // Service may already be running — safe to ignore.
    }
  }

  /// Stops the native PrayerTimesService (Android only).
  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('stopPrayerTimesService');
    } catch (_) {}
  }
}
