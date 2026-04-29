import 'package:equatable/equatable.dart';
import '../../data/wird_service.dart';

abstract class WirdState extends Equatable {
  const WirdState();

  @override
  List<Object?> get props => [];
}

/// Initial state before the service is queried.
class WirdInitial extends WirdState {
  const WirdInitial();
}

/// No active plan exists – show setup UI.
class WirdNoPlan extends WirdState {
  final bool notificationsEnabled;
  final int followUpIntervalHours;
  const WirdNoPlan({
    this.notificationsEnabled = true,
    this.followUpIntervalHours = 4,
  });

  @override
  List<Object?> get props => [notificationsEnabled, followUpIntervalHours];
}

/// An active plan is loaded and ready to display.
class WirdPlanLoaded extends WirdState {
  final WirdPlan plan;

  /// Current reminder time (null if not set yet).
  final int? reminderHour;
  final int? reminderMinute;

  /// Whether wird notifications are enabled.
  final bool notificationsEnabled;

  /// Hours between follow-up reminders.
  final int followUpIntervalHours;

  /// Last reading bookmark: surah number (1–114). Null if not set.
  final int? lastReadSurah;

  /// Last reading bookmark: ayah number. Null if not set.
  final int? lastReadAyah;

  /// Last mushaf page (1–604) where the user stopped reading.
  /// Takes priority over lastReadSurah/lastReadAyah when navigating in QCF mode.
  final int? lastReadPage;

  /// Makeup bookmark: which missed plan-day the user was last working on.
  final int? makeupBookmarkDay;

  /// Makeup bookmark: surah position.
  final int? makeupBookmarkSurah;

  /// Makeup bookmark: ayah position.
  final int? makeupBookmarkAyah;

  /// Persisted focused day for manual forward flow in daily card.
  final int? focusedDay;

  /// True only when the user explicitly set a daily bookmark via the dialog.
  final bool manualDailyBookmark;

  /// True only when the user explicitly set a makeup bookmark via the dialog.
  final bool manualMakeupBookmark;

  /// Transient list of days auto-skipped during the most recent completion.
  /// Non-empty only immediately after a skip event; cleared on the next load.
  final List<int> skipEventDays;

  const WirdPlanLoaded(
    this.plan, {
    this.reminderHour,
    this.reminderMinute,
    this.notificationsEnabled = true,
    this.followUpIntervalHours = 4,
    this.lastReadSurah,
    this.lastReadAyah,
    this.lastReadPage,
    this.makeupBookmarkDay,
    this.makeupBookmarkSurah,
    this.makeupBookmarkAyah,
    this.focusedDay,
    this.manualDailyBookmark = false,
    this.manualMakeupBookmark = false,
    this.skipEventDays = const [],
  });

  bool get hasReminder => reminderHour != null && reminderMinute != null;

  /// True when the user has a saved reading bookmark (page or surah+ayah)
  /// AND explicitly set it manually via the dialog.
  bool get hasLastRead =>
      manualDailyBookmark &&
      (lastReadPage != null || (lastReadSurah != null && lastReadAyah != null));

  /// True when the user has a saved makeup reading bookmark
  /// AND explicitly set it manually via the dialog.
  bool get hasMakeupBookmark =>
      manualMakeupBookmark &&
      makeupBookmarkDay != null &&
      makeupBookmarkSurah != null &&
      makeupBookmarkAyah != null;

  @override
  List<Object?> get props => [
    plan.type,
    plan.startDate,
    plan.targetDays,
    plan.planMode,
    plan.pagesPerDay,
    plan.completedDays,
    plan.progressionMarker,
    plan.skippedDays,
    plan.skipNoteAnchorDay,
    reminderHour,
    reminderMinute,
    notificationsEnabled,
    followUpIntervalHours,
    lastReadSurah,
    lastReadAyah,
    lastReadPage,
    makeupBookmarkDay,
    makeupBookmarkSurah,
    makeupBookmarkAyah,
    focusedDay,
    manualDailyBookmark,
    manualMakeupBookmark,
    skipEventDays,
  ];
}
