import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/navigation/notification_router.dart';
import '../data/wird_service.dart';
import '../../../core/services/settings_service.dart';

/// Manages all local notifications for the daily Wird feature.
///
/// Notification strategy:
/// • ID 5000 — main daily reminder at user-set time (repeating daily).
/// • IDs 5001–5005 — follow-up reminders every 4 hours if wird not complete.
///   Follow-ups are one-time notifications for TODAY only.
///   They are cancelled when the user marks their wird complete.
///   When the app re-opens the next day, follow-ups are re-evaluated & re-scheduled.
class WirdNotificationService {
  static const String _channelId = 'wird_daily_reminder_v4';
  // Old channels to delete on first run so the user gets correct sound settings.
  static const List<String> _oldChannelIds = [
    'wird_daily_reminder_v1',
    'wird_daily_reminder_v2',
    'wird_daily_reminder_v3',
  ];
  static const String _channelName = 'الورد اليومي';
  static const String _channelDescription =
      'تذكير يومي بقراءة الورد اليومي من القرآن الكريم';

  // Green Islamic color
  static const int _primaryColorInt = 0xFF0D5E3A;

  static const int _idMainReminder = 5000;
  static const List<int> _followUpIds = [5001, 5002, 5003, 5004, 5005];
  static const List<int> _allIds = [5000, 5001, 5002, 5003, 5004, 5005];

  final FlutterLocalNotificationsPlugin _plugin;
  final WirdService _wirdService;
  final SettingsService _settingsService;

  WirdNotificationService(
    this._plugin,
    this._wirdService,
    this._settingsService,
  );

  // ── Initialisation ────────────────────────────────────────────────────────

  Future<void> init() async {
    // Timezone is already initialised globally by AdhanNotificationService.
    await _createChannel();
  }

  Future<void> _createChannel() async {
    if (kIsWeb) return;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;

    // Delete old channels to clear any stale sound / importance settings.
    for (final old in _oldChannelIds) {
      try {
        await android.deleteNotificationChannel(old);
      } catch (_) {}
    }

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
        playSound: true, // uses device default notification sound
        enableVibration: true,
      ),
    );
    debugPrint('📿 [Wird] Notification channel created: $_channelId');
  }

  // ── Permissions ───────────────────────────────────────────────────────────

  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();

    bool ok = true;
    if (android != null) {
      try {
        ok = (await android.requestNotificationsPermission()) ?? true;
      } catch (_) {
        // Ignore "permissionRequestInProgress" if adhan service is requesting
        // at the same time; the shared notification permission will still be
        // granted via the other request.
      }
      try {
        await android.requestExactAlarmsPermission();
      } catch (_) {}
    }
    if (ios != null) {
      ok =
          (await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          )) ??
          true;
    }
    return ok;
  }

  // ── Main scheduling entry-point ───────────────────────────────────────────

  /// Call this after plan creation or reminder time update.
  /// Cancels all existing wird notifications and re-schedules them.
  Future<void> scheduleForPlan() async {
    if (!_wirdService.notificationsEnabled) {
      await cancelAll();
      return;
    }

    final plan = _wirdService.getPlan();
    if (plan == null) {
      await cancelAll();
      return;
    }

    final reminderTime = _wirdService.getReminderTime();
    if (reminderTime == null) {
      debugPrint('📿 [Wird] No reminder time set — skipping schedule');
      return;
    }

    final hour = reminderTime['hour']!;
    final minute = reminderTime['minute']!;

    final todayIndex = plan.logicalCurrentDay;
    final isTodayComplete = plan.isDayComplete(todayIndex);

    await cancelAll();
    await _scheduleMainReminder(hour, minute, skipToday: isTodayComplete);

    // Schedule follow-ups only if interval is not 0 ("Never").
    if (_wirdService.followUpIntervalHours > 0) {
      if (!plan.isDayComplete(todayIndex)) {
        // Today's wird not done — schedule follow-ups for today.
        await _scheduleFollowUps(hour, minute, forNextDay: false);
      } else {
        // Today is done — pre-schedule follow-ups for the next plan day so
        // the user gets reminded tomorrow without needing to open the app.
        final nextDay = todayIndex + 1;
        if (nextDay <= plan.targetDays && !plan.isDayComplete(nextDay)) {
          await _scheduleFollowUps(hour, minute, forNextDay: true);
        }
      }
    }

    debugPrint('📿 [Wird] Scheduled daily reminder at $hour:$minute');
  }

  /// Re-evaluate follow-ups for today (call on app foreground).
  Future<void> refreshFollowUps() async {
    if (!_wirdService.notificationsEnabled) return;
    if (_wirdService.followUpIntervalHours == 0) {
      await cancelFollowUps();
      return;
    }
    final plan = _wirdService.getPlan();
    if (plan == null) return;
    final reminderTime = _wirdService.getReminderTime();
    if (reminderTime == null) return;

    // Cancel any stale follow-ups.
    await cancelFollowUps();

    final todayIndex = plan.logicalCurrentDay;
    if (!plan.isDayComplete(todayIndex)) {
      // Today not done — schedule follow-ups for today.
      await _scheduleFollowUps(
        reminderTime['hour']!,
        reminderTime['minute']!,
        forNextDay: false,
      );
    } else {
      // Today done — push main reminder + follow-ups to tomorrow.
      await refreshMainReminder();
      final nextDay = todayIndex + 1;
      if (nextDay <= plan.targetDays && !plan.isDayComplete(nextDay)) {
        await _scheduleFollowUps(
          reminderTime['hour']!,
          reminderTime['minute']!,
          forNextDay: true,
        );
      }
    }
  }

  /// Cancels today's main reminder and re-schedules it for tomorrow if
  /// the plan still has upcoming days. Call when wird is marked complete.
  Future<void> refreshMainReminder() async {
    if (!_wirdService.notificationsEnabled) return;
    final plan = _wirdService.getPlan();
    if (plan == null) return;
    final reminderTime = _wirdService.getReminderTime();
    if (reminderTime == null) return;

    final todayIndex = plan.logicalCurrentDay;
    if (!plan.isDayComplete(todayIndex)) return;

    await _plugin.cancel(_idMainReminder);
    debugPrint('📿 [Wird] Cancelled main reminder (today complete)');

    final nextDay = todayIndex + 1;
    if (nextDay <= plan.targetDays && !plan.isDayComplete(nextDay)) {
      await _scheduleMainReminder(
        reminderTime['hour']!,
        reminderTime['minute']!,
        skipToday: true,
      );
    }
  }

  // ── Internal scheduling ───────────────────────────────────────────────────

  // Motivational bodies for the main daily reminder — rotated each day.
  static const _mainReminderBodiesAr = [
    'لا تنس قراءة وردك اليومي من القرآن الكريم',
    'اجعل القرآن أنيس يومك ونور دربك 🌟',
    'وِردك اليوم خطوة نحو ختمة مباركة 📖',
    'اقرأ وارتقِ.. فإن منزلتك عند آخر آية تقرأها 🌙',
    'القرآن ربيع القلوب، فلا تحرم قلبك منه 🤲',
    'من قرأ حرفاً من كتاب الله فله حسنة والحسنة بعشر أمثالها 🌟',
    'خير ما تبدأ به يومك هو كلام الله ☀️',
    'لا يأتي القرآن شفيعاً لمن هجره — أقبِل عليه اليوم 💚',
    'خصّص دقائق لوردك وسترى أثرها في يومك كله 🕌',
    'إن هذا القرآن يهدي للتي هي أقوم 🌿',
  ];

  static const _mainReminderBodiesEn = [
    'Don\'t forget to read your daily Quran portion',
    'Make the Quran the companion of your day 🌟',
    'Today\'s portion is a step toward a blessed khatmah 📖',
    'Read and ascend — your rank is at the last verse you read 🌙',
    'The Quran is the spring of hearts — don\'t deprive yours 🤲',
    'Every letter of the Quran earns you a good deed multiplied tenfold 🌟',
    'The best way to start your day is with the words of Allah ☀️',
    'The Quran will not intercede for those who abandoned it — turn to it today 💚',
    'Dedicate a few minutes to your wird and see its blessing all day 🕌',
    'Indeed this Quran guides to the straightest path 🌿',
  ];

  // Follow-up bodies — rotated across IDs.
  static const _followUpBodiesAr = [
    'لم تسجّل وردك بعد — لا تؤخر القراءة',
    'يومك لم يكتمل بدون وردك 📖',
    'لا تجعل اليوم يمضي بلا قراءة 🌙',
    'تذكّر: القرآن ينتظرك، رُدّ عليه السلام ☀️',
    'غداً ستتمنى لو قرأت اليوم — ابدأ الآن 💪',
  ];

  static const _followUpBodiesEn = [
    'You haven\'t logged your wird yet — don\'t delay',
    'Your day isn\'t complete without your recitation 📖',
    'Don\'t let the day pass without reading 🌙',
    'Remember: the Quran awaits you ☀️',
    'Tomorrow you\'ll wish you read today — start now 💪',
  ];

  static const _followUpUrgentBodiesAr = [
    'اغتنم ما تبقى من الوقت وأكمل وردك اليومي 🌙',
    'الوقت يضيق — بادر بقراءة وردك قبل نهاية اليوم ⏰',
    'لم يتبقَّ سوى القليل، أكمل وردك الآن 🤲',
  ];

  static const _followUpUrgentBodiesEn = [
    'Time is running out — finish your daily wird 🌙',
    'Only a little time left — complete your recitation now ⏰',
    'Don\'t miss today\'s portion, there\'s still time 🤲',
  ];

  /// Pick a message from a list using a rotating counter stored in SharedPrefs.
  String _pickRotating(
    List<String> arList,
    List<String> enList,
    String counterKey,
  ) {
    final isArabic = _wirdService.getAppLanguage() == 'ar';
    final list = isArabic ? arList : enList;
    final counter = _wirdService.getCounter(counterKey);
    final msg = list[counter % list.length];
    _wirdService.incrementCounter(counterKey);
    return msg;
  }

  Future<void> _scheduleMainReminder(
    int hour,
    int minute, {
    required bool skipToday,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (skipToday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    final body = _pickRotating(
      _mainReminderBodiesAr,
      _mainReminderBodiesEn,
      'wird_main_msg_counter',
    );
    final notifMode = _settingsService.getWirdNotificationMode();

    final isArabic = _wirdService.getAppLanguage() == 'ar';
    await _zonedScheduleSafe(
      id: _idMainReminder,
      title: isArabic
          ? '📖 حان وقت الورد اليومي'
          : '📖 Time for Your Daily Wird',
      body: notifMode == 'sound_only' ? '' : body,
      payload: NotificationRoute.wird,
      scheduledDate: scheduled,
      details: _buildDetails(isFollowUp: false, isArabic: isArabic),
      // NOT using matchDateTimeComponents - we reschedule daily on app foreground
      // to properly check if user already completed their wird
    );
  }

  /// Schedules follow-up notifications.
  ///
  /// [forNextDay] = false → follow-ups start after today's reminder time.
  /// [forNextDay] = true  → follow-ups start after tomorrow's reminder time
  ///                        (pre-schedule for the next plan day so reminders
  ///                         arrive even if the user never reopens the app).
  Future<void> _scheduleFollowUps(
    int hour,
    int minute, {
    required bool forNextDay,
  }) async {
    final now = tz.TZDateTime.now(tz.local);

    // Base = the reminder time of the target day (today or tomorrow).
    var baseDay = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (forNextDay) {
      baseDay = baseDay.add(const Duration(days: 1));
    } else {
      // If today's base is already in the past (user set reminder earlier),
      // it still makes sense to schedule follow-ups from that past anchor.
    }

    // Follow-up boundary: must fire before the day AFTER the target day's reminder.
    final boundaryTime = baseDay.add(const Duration(days: 1));

    final intervalHours = _wirdService.followUpIntervalHours;
    final maxSlots = _followUpIds.length; // 5
    final offsets = List.generate(maxSlots, (i) => (i + 1) * intervalHours);

    int scheduledCount = 0;
    for (var i = 0; i < offsets.length; i++) {
      final followUpTime = baseDay.add(Duration(hours: offsets[i]));

      // Must be in the future and before the boundary.
      if (followUpTime.isBefore(now) || !followUpTime.isBefore(boundaryTime)) {
        continue;
      }

      final hoursToNext = boundaryTime.difference(followUpTime).inHours;
      final body = hoursToNext <= 2
          ? _pickRotating(
              _followUpUrgentBodiesAr,
              _followUpUrgentBodiesEn,
              'wird_urgent_msg_counter',
            )
          : _pickRotating(
              _followUpBodiesAr,
              _followUpBodiesEn,
              'wird_followup_msg_counter',
            );
      final wirdNotifMode = _settingsService.getWirdNotificationMode();

      final isArabic = _wirdService.getAppLanguage() == 'ar';
      await _zonedScheduleSafe(
        id: _followUpIds[i],
        title: isArabic ? '🌙 تذكير: الورد اليومي' : '🌙 Reminder: Daily Wird',
        body: wirdNotifMode == 'sound_only' ? '' : body,
        payload: NotificationRoute.wird,
        scheduledDate: followUpTime,
        details: _buildDetails(isFollowUp: true, isArabic: isArabic),
      );
      scheduledCount++;
    }

    debugPrint(
      '📿 [Wird] Scheduled $scheduledCount follow-up(s) '
      '(${forNextDay ? "next day" : "today"}, every $intervalHours h)',
    );
  }

  // ── Test notification ───────────────────────────────────────────────────────

  /// Send an immediate test notification so the user can verify sound/appearance.
  Future<void> sendTestNotification() async {
    if (kIsWeb) return;
    final isArabic = _wirdService.getAppLanguage() == 'ar';
    final body = _pickRotating(
      _mainReminderBodiesAr,
      _mainReminderBodiesEn,
      'wird_test_msg_counter',
    );
    await _plugin.show(
      5999,
      isArabic ? '📖 حان وقت الورد اليومي' : '📖 Time for Your Daily Wird',
      body,
      _buildDetails(isFollowUp: false, isArabic: isArabic),
      payload: NotificationRoute.wird,
    );
    debugPrint('📿 [Wird] Test notification sent');
  }

  // ── Cancellation helpers ──────────────────────────────────────────────────

  /// Cancel ONLY today's follow-up reminders (when wird is marked complete).
  Future<void> cancelFollowUps() async {
    for (final id in _followUpIds) {
      await _plugin.cancel(id);
    }
    debugPrint('📿 [Wird] Follow-up notifications cancelled');
  }

  /// Cancel ALL wird notifications (on plan reset / app cleanup).
  Future<void> cancelAll() async {
    for (final id in _allIds) {
      await _plugin.cancel(id);
    }
    debugPrint('📿 [Wird] All wird notifications cancelled');
  }

  // ── Notification style ────────────────────────────────────────────────────

  NotificationDetails _buildDetails({
    required bool isFollowUp,
    bool? isArabic,
  }) {
    final ar = isArabic ?? (_wirdService.getAppLanguage() == 'ar');
    final notifMode = _settingsService.getWirdNotificationMode();
    final shouldPlaySound = notifMode != 'text_only';
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        playSound: shouldPlaySound,
        enableVibration: true,
        category: AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.public,
        icon: '@drawable/ic_notification',
        color: const Color(_primaryColorInt),
        ticker: isFollowUp
            ? (ar ? 'تذكير بالورد اليومي' : 'Daily Wird Reminder')
            : (ar ? 'حان وقت الورد اليومي' : 'Time for Your Daily Wird'),
        ongoing: false,
        autoCancel: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: shouldPlaySound,
        presentBadge: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
  }

  /// Tries to schedule with [alarmClock] mode (exact) and silently falls back
  /// to [inexact] if the SCHEDULE_EXACT_ALARM permission is not granted.
  Future<void> _zonedScheduleSafe({
    required int id,
    required String title,
    required String body,
    required String payload,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails details,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        details,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        matchDateTimeComponents: matchDateTimeComponents,
      );
    } on PlatformException catch (e) {
      if (e.code == 'exact_alarms_not_permitted') {
        // Exact alarms not granted — fall back to inexact (slightly less
        // precise but never crashes).
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          details,
          payload: payload,
          androidScheduleMode: AndroidScheduleMode.inexact,
          matchDateTimeComponents: matchDateTimeComponents,
        );
        debugPrint(
          '📿 [Wird] Exact alarm not permitted, used inexact for id=$id',
        );
      } else {
        rethrow;
      }
    }
  }
}
