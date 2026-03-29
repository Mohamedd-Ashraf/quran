import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/services/settings_service.dart';
import '../data/quiz_repository.dart';

/// Manages daily quiz reminder notifications.
///
/// Notification IDs:
/// • ID 6000 — daily quiz reminder (repeating daily).
class QuizNotificationService {
  static const String _channelId = 'quiz_daily_reminder_v1';
  static const String _channelName = 'المسابقة اليومية';
  static const String _channelDescription =
      'تذكير يومي للمشاركة في المسابقة الدينية اليومية';

  static const int _primaryColorInt = 0xFF0D5E3A;
  static const int _idDailyReminder = 6000;

  final FlutterLocalNotificationsPlugin _plugin;
  final QuizRepository _repository;

  QuizNotificationService(this._plugin, this._repository);

  // ── Initialisation ────────────────────────────────────────────────────────

  Future<void> init() async {
    await _createChannel();
  }

  Future<void> _createChannel() async {
    if (kIsWeb) return;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );
    debugPrint('[Quiz] Notification channel created: $_channelId');
  }

  // ── Schedule ──────────────────────────────────────────────────────────────

  /// Schedules a daily reminder. Rotates through 7 motivational messages.
  Future<void> scheduleDailyReminder() async {
    if (!SettingsService.enableQuizFeature) {
      await cancelAll();
      return;
    }
    if (!_repository.notificationsEnabled) return;

    await cancelAll();

    final hour = _repository.reminderHour;
    final minute = _repository.reminderMinute;
    final isArabic = _repository.getAppLanguage().startsWith('ar');

    final messages = isArabic
        ? [
            'سؤال اليوم جاهز! هل تقدر تجاوب صح؟',
            'حافظ على سلسلة إجاباتك الصحيحة!',
            'تحدَّ نفسك بسؤال ديني جديد اليوم',
            'لا تنسَ سؤال المسابقة اليومية!',
            'اختبر معلوماتك الدينية الآن!',
            'سؤال جديد في انتظارك، جاوب قبل ما الوقت يخلص!',
            'حافظ على ترتيبك في لوحة المتصدرين!',
          ]
        : [
            "Today's question is ready! Can you answer it?",
            'Keep your correct answer streak going!',
            'Challenge yourself with a new religious question',
            "Don't forget the daily quiz!",
            'Test your Islamic knowledge now!',
            'A new question awaits — answer before time runs out!',
            'Maintain your leaderboard position!',
          ];

    final msgIndex = _repository.totalAnswered % messages.length;
    final title = isArabic ? 'المسابقة اليومية' : 'Daily Quiz';
    final body = messages[msgIndex];

    try {
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      // If the scheduled time has already passed today, push to tomorrow
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      await _plugin.zonedSchedule(
        _idDailyReminder,
        title,
        body,
        scheduledDate,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            color: const Color(_primaryColorInt),
            icon: 'ic_notification',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      debugPrint(
        '[Quiz] Daily reminder scheduled at '
        '$hour:${minute.toString().padLeft(2, '0')}',
      );
    } catch (e, st) {
      debugPrint('[Quiz] Failed to schedule notification: $e\n$st');
    }
  }

  // ── Cancel ────────────────────────────────────────────────────────────────

  Future<void> cancelAll() async {
    await _plugin.cancel(_idDailyReminder);
    debugPrint('[Quiz] Notification cancelled');
  }
}
