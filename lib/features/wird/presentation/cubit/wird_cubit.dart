import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/wird_service.dart';
import '../../data/quran_boundaries.dart';
import '../../domain/wird_progression_helper.dart';
import '../../services/wird_notification_service.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../core/constants/surah_names.dart';
import 'wird_state.dart';

class WirdCubit extends Cubit<WirdState> {
  final WirdService _wirdService;
  final WirdNotificationService _notifService;
  final SettingsService _settingsService;

  WirdCubit(this._wirdService, this._notifService, this._settingsService)
    : super(const WirdInitial());

  // ── Test notification ─────────────────────────────────────────────────

  Future<void> testNotification() => _notifService.sendTestNotification();

  // ── Load ────────────────────────────────────────────────────────────

  /// Load (or reload) the plan from SharedPreferences.
  void load() => _loadWithSkipDays(const []);

  /// Emit a fresh [WirdPlanLoaded] state, optionally with skip-event data.
  void _loadWithSkipDays(List<int> skipEventDays) {
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
          focusedDay: _wirdService.focusedDay,
          manualDailyBookmark: _wirdService.manualDailyBookmark,
          manualMakeupBookmark: _wirdService.manualMakeupBookmark,
          skipEventDays: skipEventDays,
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

  // Cached bookmark values so undo (un-completing a day) can restore them.
  int? _lastClearedBookmarkSurah;
  int? _lastClearedBookmarkAyah;
  int? _lastClearedBookmarkPage;
  bool _lastClearedManualDailyFlag = false;
  int? _lastClearedMakeupDay;
  int? _lastClearedMakeupSurah;
  int? _lastClearedMakeupAyah;
  bool _lastClearedManualMakeupFlag = false;

  /// Toggle the completion state of a specific day (1-indexed).
  Future<void> toggleDayComplete(int day) async {
    final currentState = state;
    if (currentState is! WirdPlanLoaded) return;

    final plan = currentState.plan;
    final wasComplete = plan.isDayComplete(day);

    if (wasComplete) {
      // ── MARK INCOMPLETE ────────────────────────────────────────────────
      final isSkippedDay = plan.skippedDays.contains(day);

      if (isSkippedDay) {
        // Skip-undo: remove day from completed + skippedDays, regress marker.
        await _applySkipUndo(plan, day);
      } else {
        // Regular undo: remove from completed, marker stays (day becomes qadaa
        // if it was before the progression marker).
        await _wirdService.markDayIncomplete(day);

        // Restore daily bookmark if it was cached when this day was completed.
        final logicalCurrent = plan.logicalCurrentDay;
        if (day == logicalCurrent) {
          await _restoreDailyBookmark();
          await _notifService.refreshFollowUps();
        }
        // Restore makeup bookmark if applicable.
        if (day == _lastClearedMakeupDay) {
          await _restoreMakeupBookmark(day);
        }
      }
      load();
    } else {
      // ── MARK COMPLETE ────────────────────────────────────────────────
      final oldCompletedSet = plan.completedDays.toSet();
      final newCompletedSet = {...oldCompletedSet, day};

      // Detect which future pre-completed days will be skipped.
      final skipped = WirdProgressionHelper.computeSkippedOnComplete(
        justCompletedDay: day,
        oldCompleted: oldCompletedSet,
        newCompleted: newCompletedSet,
        targetDays: plan.targetDays,
        progressionMarker: plan.progressionMarker,
      );

      // Persist the day.
      await _wirdService.markDayComplete(day);

      // Advance progression marker when completing the logical current day.
      final newLogical = WirdProgressionHelper.logicalCurrentDay(
        newCompletedSet,
        plan.targetDays,
      );
      if (newLogical > plan.progressionMarker) {
        await _wirdService.setProgressionMarker(newLogical);
      }

      // Persist skip metadata if any days were auto-skipped.
      if (skipped.isNotEmpty) {
        final allSkipped = [...plan.skippedDays, ...skipped];
        await _wirdService.setSkippedDays(allSkipped);
        await _wirdService.setSkipNoteAnchorDay(newLogical);
      }

      // Cache bookmark before clearing (so undo can restore it).
      final logicalCurrent = plan.logicalCurrentDay; // BEFORE the new set
      if (day == logicalCurrent) {
        await _notifService.refreshFollowUps();
        await _notifService.refreshMainReminder();
        _lastClearedBookmarkSurah = _wirdService.lastReadSurah;
        _lastClearedBookmarkAyah = _wirdService.lastReadAyah;
        _lastClearedBookmarkPage = _wirdService.lastReadPage;
        _lastClearedManualDailyFlag = _wirdService.manualDailyBookmark;
        await _wirdService.clearLastRead();
      }

      // Cache makeup bookmark if applicable.
      if (_wirdService.makeupBookmarkDay == day) {
        _lastClearedMakeupDay = day;
        _lastClearedMakeupSurah = _wirdService.makeupBookmarkSurah;
        _lastClearedMakeupAyah = _wirdService.makeupBookmarkAyah;
        _lastClearedManualMakeupFlag = _wirdService.manualMakeupBookmark;
        await _wirdService.clearMakeupBookmark();
      }

      _loadWithSkipDays(skipped);
    }
  }

  /// Undo a skipped day from the skip-note banner.
  /// Removes the day from completedDays, regresses the progression marker,
  /// and clears the skip note. The skipped day becomes the new logical current.
  Future<void> undoSkippedDay(int day) async {
    final currentState = state;
    if (currentState is! WirdPlanLoaded) return;
    if (!currentState.plan.skippedDays.contains(day)) return;
    await _applySkipUndo(currentState.plan, day);
    load();
  }

  /// Dismiss the skip-note banner without undoing the skip.
  Future<void> dismissSkipNote() async {
    await _wirdService.clearSkipNote();
    load();
  }

  // ── Internal skip-undo ─────────────────────────────────────────────────

  /// Remove [day] (a skipped day) from completedDays, remove ALL currently
  /// stored skipped days from completedDays, regress the progression marker to
  /// [day] (the first skipped day), and clear the skip note.
  Future<void> _applySkipUndo(WirdPlan plan, int day) async {
    // Remove all skipped days from completedDays so the user re-reads them
    // in natural sequence. The [day] arg is the first skipped day.
    final allSkipped = plan.skippedDays.toSet();
    for (final skippedDay in allSkipped) {
      await _wirdService.markDayIncomplete(skippedDay);
    }
    // Regress marker to the first skipped day (the earliest one).
    final firstSkipped = ([...allSkipped]..sort()).first;
    await _wirdService.setProgressionMarker(firstSkipped);
    await _wirdService.clearSkipNote();
  }

  // ── Internal bookmark restore ───────────────────────────────────────────

  Future<void> _restoreDailyBookmark() async {
    if (_lastClearedBookmarkPage != null) {
      await _wirdService.saveLastReadPage(_lastClearedBookmarkPage!);
    }
    if (_lastClearedBookmarkSurah != null && _lastClearedBookmarkAyah != null) {
      await _wirdService.saveLastRead(
        _lastClearedBookmarkSurah!,
        _lastClearedBookmarkAyah!,
      );
    }
    if (_lastClearedManualDailyFlag) {
      await _wirdService.markDailyBookmarkManual();
    }
    _lastClearedBookmarkSurah = null;
    _lastClearedBookmarkAyah = null;
    _lastClearedBookmarkPage = null;
    _lastClearedManualDailyFlag = false;
  }

  Future<void> _restoreMakeupBookmark(int day) async {
    if (_lastClearedMakeupSurah != null && _lastClearedMakeupAyah != null) {
      await _wirdService.saveMakeupBookmark(
        day,
        _lastClearedMakeupSurah!,
        _lastClearedMakeupAyah!,
      );
    }
    if (_lastClearedManualMakeupFlag) {
      await _wirdService.markMakeupBookmarkManual();
    }
    _lastClearedMakeupDay = null;
    _lastClearedMakeupSurah = null;
    _lastClearedMakeupAyah = null;
    _lastClearedManualMakeupFlag = false;
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
      await _syncProgressionMarker();
      await _notifService.refreshFollowUps();
      await _notifService.refreshMainReminder();
      load();
    }
  }

  /// Syncs the progression marker to match the current logicalCurrentDay.
  /// Call after bulk completions (autoCompleteByPage, setStartingPoint).
  Future<void> _syncProgressionMarker() async {
    final plan = _wirdService.getPlan();
    if (plan == null) return;
    final logical = WirdProgressionHelper.logicalCurrentDay(
      plan.completedDays.toSet(),
      plan.targetDays,
    );
    if (logical > _wirdService.storedProgressionMarker) {
      await _wirdService.setProgressionMarker(logical);
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
  /// Also syncs to the home-screen "Continue Reading" tracker.
  Future<void> saveLastRead(int surah, int ayah) async {
    await _wirdService.saveLastRead(surah, ayah);
    // Sync to home-screen tracker with surah names.
    final nameAr = surah >= 1 && surah <= 114
        ? SurahNames.surahs[surah - 1]['arabic'] ?? ''
        : '';
    final nameEn = surah >= 1 && surah <= 114
        ? SurahNames.surahs[surah - 1]['english'] ?? ''
        : '';
    await _settingsService.updateLastReadProgress(
      surahNumber: surah,
      surahNameAr: nameAr.isNotEmpty ? nameAr : null,
      surahNameEn: nameEn.isNotEmpty ? nameEn : null,
      ayah: ayah,
    );
    load();
  }

  /// Saves the current mushaf page number (fires on every page swipe).
  /// Also syncs to the home-screen "Continue Reading" tracker with surah info.
  Future<void> saveLastReadPage(int page) async {
    await _wirdService.saveLastReadPage(page);
    // Derive the surah that starts on this page so the home tracker shows
    // the correct surah name alongside the page number.
    final safeP = page.clamp(1, 604);
    final pos = pageStartPosition(safeP);
    final surah = pos.surah;
    final nameAr = surah >= 1 && surah <= 114
        ? SurahNames.surahs[surah - 1]['arabic'] ?? ''
        : '';
    final nameEn = surah >= 1 && surah <= 114
        ? SurahNames.surahs[surah - 1]['english'] ?? ''
        : '';
    await _settingsService.updateLastReadProgress(
      surahNumber: surah,
      surahNameAr: nameAr.isNotEmpty ? nameAr : null,
      surahNameEn: nameEn.isNotEmpty ? nameEn : null,
      page: page,
    );
    load();
  }

  /// Clears the reading bookmark (also called automatically when day is marked complete).
  /// Does NOT clear the home-screen tracker — overall progress is preserved.
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

  /// Saves a daily bookmark explicitly set by the user via the dialog.
  /// Also sets the manual flag so the bookmark is visible in the UI.
  Future<void> saveManualDailyBookmark(int page) async {
    await _wirdService.saveLastReadPage(page);
    await _wirdService.markDailyBookmarkManual();
    // Keep home tracker in sync.
    final safeP = page.clamp(1, 604);
    final pos = pageStartPosition(safeP);
    final surah = pos.surah;
    final nameAr = surah >= 1 && surah <= 114
        ? SurahNames.surahs[surah - 1]['arabic'] ?? ''
        : '';
    final nameEn = surah >= 1 && surah <= 114
        ? SurahNames.surahs[surah - 1]['english'] ?? ''
        : '';
    await _settingsService.updateLastReadProgress(
      surahNumber: surah,
      surahNameAr: nameAr.isNotEmpty ? nameAr : null,
      surahNameEn: nameEn.isNotEmpty ? nameEn : null,
      page: page,
    );
    load();
  }

  /// Saves a makeup bookmark explicitly set by the user via the dialog.
  /// Also sets the manual flag so the bookmark is visible in the UI.
  Future<void> saveManualMakeupBookmark(int day, int surah, int ayah) async {
    await _wirdService.saveMakeupBookmark(day, surah, ayah);
    await _wirdService.markMakeupBookmarkManual();
    load();
  }

  // ── Focused daily day (manual forward mode) ───────────────────────────────

  Future<void> setFocusedDay(int day) async {
    final currentState = state;
    if (currentState is! WirdPlanLoaded) return;
    if (day < 1 || day > currentState.plan.targetDays) return;
    await _wirdService.setFocusedDay(day);
    load();
  }

  Future<void> clearFocusedDay() async {
    await _wirdService.clearFocusedDay();
    load();
  }

  /// Clears the makeup bookmark.
  Future<void> clearMakeupBookmark() async {
    await _wirdService.clearMakeupBookmark();
    load();
  }

  // ── Set wird starting point ───────────────────────────────────────────────

  /// Sets the wird starting point by marking all days before the given page
  /// as complete. This helps users who lost their progress during app updates.
  /// For page-based plans, marks days whose end page ≤ [page].
  /// For day-based plans, marks all days whose reading range ends before [surah]:[ayah].
  Future<void> setStartingPoint({int? page, int? surah, int? ayah}) async {
    final currentState = state;
    if (currentState is! WirdPlanLoaded) return;
    final plan = currentState.plan;

    if (page != null && plan.isPagesBased && plan.pagesPerDay != null) {
      // Page-based: mark all days whose end page ≤ given page
      for (int d = 1; d <= plan.targetDays; d++) {
        if (plan.isDayComplete(d)) continue;
        final dayRange = getPageRangeForDay(d, plan.pagesPerDay!);
        if (dayRange.endPage <= page) {
          await _wirdService.markDayComplete(d);
        } else {
          break;
        }
      }
      await _wirdService.saveLastReadPage(page);
    } else if (surah != null && ayah != null) {
      // Day-based: mark all days whose reading range ends before the given position
      final targetLinear = posToLinear(QuranPosition(surah, ayah));
      for (int d = 1; d <= plan.targetDays; d++) {
        if (plan.isDayComplete(d)) continue;
        final dayRange = getReadingRangeForDay(d, plan.targetDays);
        final dayEndLinear = posToLinear(dayRange.end);
        if (dayEndLinear < targetLinear) {
          await _wirdService.markDayComplete(d);
        } else {
          break;
        }
      }
      await _wirdService.saveLastRead(surah, ayah);
    } else if (page != null) {
      // Day-based plan but user picked a page
      final pageRange = getReadingRangeForPages(page, page);
      final targetLinear = posToLinear(pageRange.start);
      for (int d = 1; d <= plan.targetDays; d++) {
        if (plan.isDayComplete(d)) continue;
        final dayRange = getReadingRangeForDay(d, plan.targetDays);
        final dayEndLinear = posToLinear(dayRange.end);
        if (dayEndLinear < targetLinear) {
          await _wirdService.markDayComplete(d);
        } else {
          break;
        }
      }
      await _wirdService.saveLastReadPage(page);
    }

    await _notifService.refreshFollowUps();
    await _notifService.refreshMainReminder();
    await _syncProgressionMarker();
    load();
  }
}
