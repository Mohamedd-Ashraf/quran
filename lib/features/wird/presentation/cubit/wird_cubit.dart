import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/wird_service.dart';
import '../../data/quran_boundaries.dart';
import '../../services/wird_notification_service.dart';
import 'wird_state.dart';

class WirdCubit extends Cubit<WirdState> {
  final WirdService _wirdService;
  final WirdNotificationService _notifService;

  WirdCubit(this._wirdService, this._notifService) : super(const WirdInitial());

  // ── Test notification ─────────────────────────────────────────────────

  Future<void> testNotification() => _notifService.sendTestNotification();

  // ── Load ────────────────────────────────────────────────────────────

  /// Load (or reload) the plan from SharedPreferences.
  void load() {
    final plan = _wirdService.getPlan();
    final notifEnabled = _wirdService.notificationsEnabled;
    final followUpInterval = _wirdService.followUpIntervalHours;
    if (plan == null) {
      emit(
        WirdNoPlan(
          notificationsEnabled: notifEnabled,
          followUpIntervalHours: followUpInterval,
        ),
      );
    } else {
      final rt = _wirdService.getReminderTime();
      emit(
        WirdPlanLoaded(
          plan,
          reminderHour: rt?['hour'],
          reminderMinute: rt?['minute'],
          notificationsEnabled: notifEnabled,
          followUpIntervalHours: followUpInterval,
          lastReadSurah: _wirdService.lastReadSurah,
          lastReadAyah: _wirdService.lastReadAyah,
          lastReadPage: _wirdService.lastReadPage,
          makeupBookmarkDay: _wirdService.makeupBookmarkDay,
          makeupBookmarkSurah: _wirdService.makeupBookmarkSurah,
          makeupBookmarkAyah: _wirdService.makeupBookmarkAyah,
        ),
      );
    }
  }

  // ── Plan setup ──────────────────────────────────────────────────

  /// Create a new wird plan (generic, also used by regular plans).
  Future<void> setupPlan({
    required WirdType type,
    required int targetDays,
    required DateTime startDate,
    WirdPlanMode planMode = WirdPlanMode.days,
    int? pagesPerDay,
    List<int> completedDays = const [],
    int? reminderHour,
    int? reminderMinute,
  }) async {
    await _wirdService.initPlan(
      type: type,
      targetDays: targetDays,
      startDate: startDate,
      planMode: planMode,
      pagesPerDay: pagesPerDay,
      completedDays: completedDays,
      reminderHour: reminderHour,
      reminderMinute: reminderMinute,
    );
    load();
    if (reminderHour != null && reminderMinute != null) {
      await _notifService.scheduleForPlan();
    }
  }

  // ── Day completion ─────────────────────────────────────────────

  /// Toggle the completion state of a specific day (1-indexed).
  Future<void> toggleDayComplete(int day) async {
    final currentState = state;
    if (currentState is! WirdPlanLoaded) return;

    final wasComplete = currentState.plan.isDayComplete(day);
    if (wasComplete) {
      await _wirdService.markDayIncomplete(day);
      // If un-completing today, re-schedule follow-ups.
      final todayDay = currentState.plan.currentDay;
      if (day == todayDay) {
        await _notifService.refreshFollowUps();
      }
    } else {
      await _wirdService.markDayComplete(day);
      // Always re-evaluate notifications after completion:
      // • cancels today's stale follow-ups
      // • pre-schedules tomorrow's follow-ups so the user keeps getting
      //   reminded for the new day even without reopening the app.
      final todayDay = currentState.plan.currentDay;
      if (day == todayDay) {
        await _notifService.refreshFollowUps();
        await _wirdService.clearLastRead();
      }
      // If completing a makeup day, clear its bookmark.
      if (_wirdService.makeupBookmarkDay == day) {
        await _wirdService.clearMakeupBookmark();
      }
    }
    load();
  }

  // ── Auto-complete days by page (for page-based plans) ──────────────────

  /// For page-based plans: marks all days from [fromDay] onwards as complete
  /// if the saved [page] covers their full page range.
  Future<void> autoCompleteByPage(int fromDay, int page) async {
    final currentState = state;
    if (currentState is! WirdPlanLoaded) return;
    final plan = currentState.plan;
    if (!plan.isPagesBased || plan.pagesPerDay == null) return;

    bool anyMarked = false;
    for (int d = fromDay; d <= plan.targetDays; d++) {
      if (plan.isDayComplete(d)) continue;
      final dayRange = getPageRangeForDay(d, plan.pagesPerDay!);
      if (page >= dayRange.endPage) {
        await _wirdService.markDayComplete(d);
        anyMarked = true;
      } else {
        break;
      }
    }
    if (anyMarked) {
      await _notifService.refreshFollowUps();
      load();
    }
  }

  // ── Reminder time ───────────────────────────────────────────────

  Future<void> updateReminderTime(int hour, int minute) async {
    await _wirdService.setReminderTime(hour, minute);
    load();
    await _notifService.scheduleForPlan();
  }

  // ── App lifecycle ─────────────────────────────────────────────

  /// Call when app returns to foreground to refresh wird notifications.
  /// Uses scheduleForPlan() so both the main daily reminder AND follow-ups
  /// are re-registered (handles device reboots that clear scheduled alarms).
  Future<void> refreshNotificationsIfNeeded() async {
    await _notifService.scheduleForPlan();
  }

  // ── Plan deletion ─────────────────────────────────────────────

  Future<void> deletePlan() async {
    await _notifService.cancelAll();
    await _wirdService.clearPlan();
    emit(WirdNoPlan(notificationsEnabled: _wirdService.notificationsEnabled));
  }

  // ── Follow-up interval ─────────────────────────────────────────────────────

  Future<void> setFollowUpIntervalHours(int hours) async {
    await _wirdService.setFollowUpIntervalHours(hours);
    if (_wirdService.notificationsEnabled && _wirdService.hasReminder) {
      await _notifService.scheduleForPlan();
    }
    load();
  }

  // ── Notifications toggle ──────────────────────────────────────────────────

  Future<void> setNotificationsEnabled(bool enabled) async {
    await _wirdService.setNotificationsEnabled(enabled);
    if (!enabled) {
      await _notifService.cancelAll();
    } else {
      // Re-schedule if a plan with a reminder time already exists.
      if (_wirdService.hasReminder) {
        await _notifService.scheduleForPlan();
      }
    }
    load();
  }
  // ── Reading bookmark (last-read position) ─────────────────────────────────

  /// Saves the user's current reading position (surah+ayah, on surah navigation).
  Future<void> saveLastRead(int surah, int ayah) async {
    await _wirdService.saveLastRead(surah, ayah);
    load();
  }

  /// Saves the current mushaf page number (fires on every page swipe).
  Future<void> saveLastReadPage(int page) async {
    await _wirdService.saveLastReadPage(page);
    load();
  }

  /// Clears the reading bookmark (also called automatically when day is marked complete).
  Future<void> clearLastRead() async {
    await _wirdService.clearLastRead();
    load();
  }

  // ── Makeup bookmark ───────────────────────────────────────────────────────

  /// Saves where the user stopped inside a makeup-wird session.
  Future<void> saveMakeupBookmark(int day, int surah, int ayah) async {
    await _wirdService.saveMakeupBookmark(day, surah, ayah);
    load();
  }

  /// Clears the makeup bookmark.
  Future<void> clearMakeupBookmark() async {
    await _wirdService.clearMakeupBookmark();
    load();
  }
}
