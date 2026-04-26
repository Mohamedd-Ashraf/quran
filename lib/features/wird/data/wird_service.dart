import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

enum WirdType { ramadan, regular }

enum WirdPlanMode { days, pages }

/// Represents an active wird (daily recitation) plan.
class WirdPlan {
  final WirdType type;
  final DateTime startDate;
  final int targetDays;
  final WirdPlanMode planMode;
  final int? pagesPerDay;
  final List<int> completedDays; // 1-indexed day numbers
  late final Set<int> _completedSet = completedDays.toSet();

  WirdPlan({
    required this.type,
    required this.startDate,
    required this.targetDays,
    this.planMode = WirdPlanMode.days,
    this.pagesPerDay,
    required this.completedDays,
  });

  /// Current day index (1-indexed), clamped within [1, targetDays].
  int get currentDay {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final startOnly = DateTime(startDate.year, startDate.month, startDate.day);
    final diff = todayOnly.difference(startOnly).inDays + 1;
    return diff.clamp(1, targetDays);
  }

  bool get isComplete => completedDays.length >= targetDays;

  double get progressPercent => targetDays == 0
      ? 0.0
      : (completedDays.length / targetDays).clamp(0.0, 1.0);

  bool isDayComplete(int day) => _completedSet.contains(day);

  bool get isPagesBased =>
      planMode == WirdPlanMode.pages && pagesPerDay != null;

  /// Consecutive completed days ending at (or just before) today.
  /// If today is not yet complete, the streak counts backwards from yesterday
  /// so users don't lose their streak display during the day.
  int get currentStreak {
    final today = currentDay;
    // Start from today if complete, otherwise from yesterday
    int startFrom = _completedSet.contains(today) ? today : today - 1;
    int streak = 0;
    for (int d = startFrom; d >= 1; d--) {
      if (_completedSet.contains(d)) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  /// Best (longest) consecutive streak ever in this plan.
  int get bestStreak {
    if (completedDays.isEmpty) return 0;
    final sorted = [...completedDays]..sort();
    int best = 0;
    int run = 0;
    int? prev;
    for (final d in sorted) {
      if (prev == null || d == prev + 1) {
        run++;
      } else {
        run = 1;
      }
      if (run > best) best = run;
      prev = d;
    }
    return best;
  }

  WirdPlan copyWith({List<int>? completedDays}) => WirdPlan(
    type: type,
    startDate: startDate,
    targetDays: targetDays,
    planMode: planMode,
    pagesPerDay: pagesPerDay,
    completedDays: completedDays ?? this.completedDays,
  );
}

/// Service for persisting and managing the daily wird plan.
class WirdService {
  static const String _keyType = 'wird_type';
  static const String _keyStartDate = 'wird_start_date';
  static const String _keyTargetDays = 'wird_target_days';
  static const String _keyPlanMode = 'wird_plan_mode';
  static const String _keyPagesPerDay = 'wird_pages_per_day';
  static const String _keyCompletedDays = 'wird_completed_days';
  static const String _keyReminderHour = 'wird_reminder_hour';
  static const String _keyReminderMinute = 'wird_reminder_minute';
  static const String _keyNotificationsEnabled = 'wird_notifications_enabled';
  static const String _keyFollowUpIntervalHours =
      'wird_followup_interval_hours';
  static const String _keyLastReadSurah = 'wird_last_read_surah';
  static const String _keyLastReadAyah = 'wird_last_read_ayah';
  static const String _keyLastReadPage = 'wird_last_read_page';
  // Makeup wird bookmark
  static const String _keyMakeupDay = 'wird_makeup_day';
  static const String _keyMakeupSurah = 'wird_makeup_surah';
  static const String _keyMakeupAyah = 'wird_makeup_ayah';
  static const String _keyFocusedDay = 'wird_focused_day';

  final SharedPreferences _prefs;

  /// Called whenever the wird plan or progress is mutated so cloud sync can trigger.
  void Function()? onDataChanged;

  WirdService(this._prefs);

  bool get hasPlan => _prefs.getString(_keyType) != null;

  /// Loads the current plan from SharedPreferences.
  /// Returns null if no plan has been set up.
  WirdPlan? getPlan() {
    final typeStr = _prefs.getString(_keyType);
    if (typeStr == null) return null;

    final type = typeStr == 'ramadan' ? WirdType.ramadan : WirdType.regular;

    final startDateStr = _prefs.getString(_keyStartDate);
    if (startDateStr == null) return null;

    DateTime startDate;
    try {
      startDate = DateTime.parse(startDateStr);
    } catch (_) {
      return null;
    }

    final targetDays = _prefs.getInt(_keyTargetDays) ?? 30;
    final planModeStr = _prefs.getString(_keyPlanMode) ?? 'days';
    final planMode = planModeStr == 'pages'
        ? WirdPlanMode.pages
        : WirdPlanMode.days;
    final pagesPerDay = _prefs.getInt(_keyPagesPerDay);

    List<int> completedDays = [];
    final completedJson = _prefs.getString(_keyCompletedDays);
    if (completedJson != null) {
      try {
        completedDays = (jsonDecode(completedJson) as List)
            .cast<int>()
            .toList();
      } catch (_) {}
    }

    return WirdPlan(
      type: type,
      startDate: startDate,
      targetDays: targetDays,
      planMode: planMode,
      pagesPerDay: pagesPerDay,
      completedDays: completedDays,
    );
  }

  /// Creates a new wird plan, overwriting any existing one.
  Future<void> initPlan({
    required WirdType type,
    required DateTime startDate,
    required int targetDays,
    WirdPlanMode planMode = WirdPlanMode.days,
    int? pagesPerDay,
    List<int> completedDays = const [],
    int? reminderHour,
    int? reminderMinute,
  }) async {
    final dateOnly = DateTime(startDate.year, startDate.month, startDate.day);
    await _prefs.setString(
      _keyType,
      type == WirdType.ramadan ? 'ramadan' : 'regular',
    );
    await _prefs.setString(_keyStartDate, dateOnly.toIso8601String());
    await _prefs.setInt(_keyTargetDays, targetDays);
    await _prefs.setString(
      _keyPlanMode,
      planMode == WirdPlanMode.pages ? 'pages' : 'days',
    );
    if (pagesPerDay != null) {
      await _prefs.setInt(_keyPagesPerDay, pagesPerDay);
    } else {
      await _prefs.remove(_keyPagesPerDay);
    }
    await _prefs.setString(
      _keyCompletedDays,
      jsonEncode(completedDays.toList()),
    );
    await _prefs.remove(_keyFocusedDay);
    if (reminderHour != null) {
      await _prefs.setInt(_keyReminderHour, reminderHour);
    }
    if (reminderMinute != null) {
      await _prefs.setInt(_keyReminderMinute, reminderMinute);
    }
    onDataChanged?.call();
  }

  /// Marks a day as complete.
  Future<void> markDayComplete(int day) async {
    final plan = getPlan();
    if (plan == null) return;
    final completed = List<int>.from(plan.completedDays);
    if (!completed.contains(day)) {
      completed.add(day);
      await _prefs.setString(_keyCompletedDays, jsonEncode(completed));
      onDataChanged?.call();
    }
  }

  /// Removes the complete mark from a day.
  Future<void> markDayIncomplete(int day) async {
    final plan = getPlan();
    if (plan == null) return;
    final completed = List<int>.from(plan.completedDays)..remove(day);
    await _prefs.setString(_keyCompletedDays, jsonEncode(completed));
    onDataChanged?.call();
  }

  /// Deletes the current plan entirely.
  Future<void> clearPlan() async {
    await _prefs.remove(_keyType);
    await _prefs.remove(_keyStartDate);
    await _prefs.remove(_keyTargetDays);
    await _prefs.remove(_keyPlanMode);
    await _prefs.remove(_keyPagesPerDay);
    await _prefs.remove(_keyCompletedDays);
    await _prefs.remove(_keyLastReadSurah);
    await _prefs.remove(_keyLastReadAyah);
    await _prefs.remove(_keyLastReadPage);
    await _prefs.remove(_keyMakeupDay);
    await _prefs.remove(_keyMakeupSurah);
    await _prefs.remove(_keyMakeupAyah);
    await _prefs.remove(_keyFocusedDay);
    onDataChanged?.call();
    // Intentionally keep reminder time — user may want to re-use it.
  }

  // ── Reminder time ──────────────────────────────────────────────────────────

  /// Returns the stored reminder time as {'hour': H, 'minute': M}, or null.
  Map<String, int>? getReminderTime() {
    final hour = _prefs.getInt(_keyReminderHour);
    final minute = _prefs.getInt(_keyReminderMinute);
    if (hour == null || minute == null) return null;
    return {'hour': hour, 'minute': minute};
  }

  Future<void> setReminderTime(int hour, int minute) async {
    await _prefs.setInt(_keyReminderHour, hour);
    await _prefs.setInt(_keyReminderMinute, minute);
    onDataChanged?.call();
  }

  Future<void> clearReminderTime() async {
    await _prefs.remove(_keyReminderHour);
    await _prefs.remove(_keyReminderMinute);
    onDataChanged?.call();
  }

  bool get hasReminder =>
      _prefs.containsKey(_keyReminderHour) &&
      _prefs.containsKey(_keyReminderMinute);

  // ── Notifications enabled ─────────────────────────────────────────────────

  bool get notificationsEnabled =>
      _prefs.getBool(_keyNotificationsEnabled) ?? true;

  Future<void> setNotificationsEnabled(bool enabled) async {
    await _prefs.setBool(_keyNotificationsEnabled, enabled);
    onDataChanged?.call();
  }

  // ── Follow-up interval ────────────────────────────────────────────────────

  /// Hours between follow-up reminders (when wird not yet marked complete).
  /// Default: 2 hours. Allowed values: 1, 2, 3, 4, 6, 8.
  int get followUpIntervalHours =>
      _prefs.getInt(_keyFollowUpIntervalHours) ?? 2;

  Future<void> setFollowUpIntervalHours(int hours) async {
    await _prefs.setInt(_keyFollowUpIntervalHours, hours);
    onDataChanged?.call();
  }

  // ── Last-read position (daily progress bookmark) ───────────────────────────

  /// Surah number (1–114) where the user last stopped reading today.
  /// Returns null if no bookmark has been saved for the current day.
  int? get lastReadSurah => _prefs.getInt(_keyLastReadSurah);

  /// Ayah number where the user last stopped reading today.
  int? get lastReadAyah => _prefs.getInt(_keyLastReadAyah);

  /// Mushaf page number (1–604) where the user last stopped reading.
  /// This is the primary resume point in QCF mushaf mode.
  int? get lastReadPage => _prefs.getInt(_keyLastReadPage);

  /// Saves a reading bookmark (surah + ayah, typically on surah navigation).
  Future<void> saveLastRead(int surah, int ayah) async {
    await _prefs.setInt(_keyLastReadSurah, surah);
    await _prefs.setInt(_keyLastReadAyah, ayah);
    onDataChanged?.call();
  }

  /// Saves the current mushaf page number wherever the user is reading.
  Future<void> saveLastReadPage(int page) async {
    await _prefs.setInt(_keyLastReadPage, page);
    onDataChanged?.call();
  }

  /// Clears the current reading bookmark (call when day is marked complete).
  Future<void> clearLastRead() async {
    await _prefs.remove(_keyLastReadSurah);
    await _prefs.remove(_keyLastReadAyah);
    await _prefs.remove(_keyLastReadPage);
    onDataChanged?.call();
  }

  // ── Makeup wird bookmark ──────────────────────────────────────────────────

  /// The plan-day number saved as the makeup bookmark (which missed day the
  /// user was working on). Null if no makeup bookmark exists.
  int? get makeupBookmarkDay => _prefs.getInt(_keyMakeupDay);

  /// Surah number of the saved makeup position.
  int? get makeupBookmarkSurah => _prefs.getInt(_keyMakeupSurah);

  /// Ayah number of the saved makeup position.
  int? get makeupBookmarkAyah => _prefs.getInt(_keyMakeupAyah);

  /// Saves the user's makeup reading position.
  Future<void> saveMakeupBookmark(int day, int surah, int ayah) async {
    await _prefs.setInt(_keyMakeupDay, day);
    await _prefs.setInt(_keyMakeupSurah, surah);
    await _prefs.setInt(_keyMakeupAyah, ayah);
    onDataChanged?.call();
  }

  /// Clears the makeup bookmark (call when the makeup day is marked complete).
  Future<void> clearMakeupBookmark() async {
    await _prefs.remove(_keyMakeupDay);
    await _prefs.remove(_keyMakeupSurah);
    await _prefs.remove(_keyMakeupAyah);
    onDataChanged?.call();
  }

  // ── Focused daily day (manual forward mode) ──────────────────────────────

  /// Persisted day currently shown in daily card when user advances manually.
  /// Null means normal behavior (use calendar day).
  int? get focusedDay => _prefs.getInt(_keyFocusedDay);

  Future<void> setFocusedDay(int day) async {
    await _prefs.setInt(_keyFocusedDay, day);
    onDataChanged?.call();
  }

  Future<void> clearFocusedDay() async {
    await _prefs.remove(_keyFocusedDay);
    onDataChanged?.call();
  }

  // ── Juz distribution helpers ─────────────────────────────────────────────

  /// Returns the list of juz numbers (1-30) assigned to [day] in a plan
  /// with [targetDays] total days.
  ///
  /// * targetDays == 30 (Ramadan): 1 juz per day.
  /// * targetDays < 30: multiple juz per day.
  /// * targetDays > 30: multiple days share one juz.
  static List<int> getJuzForDay(int day, int targetDays) {
    if (targetDays <= 0 || day <= 0) return [];

    if (targetDays <= 30) {
      final startJuz = ((day - 1) * 30 ~/ targetDays) + 1;
      final endJuz = (day * 30 ~/ targetDays).clamp(1, 30);
      final count = (endJuz - startJuz + 1).clamp(1, 30);
      return List.generate(count, (i) => startJuz + i);
    } else {
      // Multiple days per juz (e.g. 60 or 90-day khatm)
      final juzNum = (((day - 1) * 30) / targetDays).floor() + 1;
      return [juzNum.clamp(1, 30)];
    }
  }

  /// Human-readable description of today's reading for a given juz/day setup.
  static String getDayDescription(
    int day,
    int targetDays, {
    required bool isArabic,
  }) {
    final juzList = getJuzForDay(day, targetDays);
    if (juzList.isEmpty) return '';

    if (targetDays <= 30) {
      // One or more full juz per day
      if (juzList.length == 1) {
        return isArabic
            ? 'الجزء ${_arabicOrdinal(juzList.first)}'
            : 'Juz ${juzList.first}';
      } else {
        return isArabic
            ? 'الجزء ${_arabicOrdinal(juzList.first)} إلى ${_arabicOrdinal(juzList.last)}'
            : 'Juz ${juzList.first} – ${juzList.last}';
      }
    } else {
      // Partial juz per day — show "half" or "third"
      final daysPerJuz = targetDays ~/ 30;
      final portion = 1.0 / daysPerJuz;
      String portionAr, portionEn;
      if (portion >= 0.5) {
        portionAr = 'نصف';
        portionEn = 'half of';
      } else if (portion >= 0.33) {
        portionAr = 'ثلث';
        portionEn = 'a third of';
      } else {
        portionAr = 'ربع';
        portionEn = 'a quarter of';
      }
      return isArabic
          ? '$portionAr الجزء ${_arabicOrdinal(juzList.first)}'
          : '$portionEn Juz ${juzList.first}';
    }
  }

  // ── Arabic helpers ────────────────────────────────────────────────────────

  static String _arabicOrdinal(int n) {
    const names = [
      '',
      'الأول',
      'الثاني',
      'الثالث',
      'الرابع',
      'الخامس',
      'السادس',
      'السابع',
      'الثامن',
      'التاسع',
      'العاشر',
      'الحادي عشر',
      'الثاني عشر',
      'الثالث عشر',
      'الرابع عشر',
      'الخامس عشر',
      'السادس عشر',
      'السابع عشر',
      'الثامن عشر',
      'التاسع عشر',
      'العشرون',
      'الحادي والعشرون',
      'الثاني والعشرون',
      'الثالث والعشرون',
      'الرابع والعشرون',
      'الخامس والعشرون',
      'السادس والعشرون',
      'السابع والعشرون',
      'الثامن والعشرون',
      'التاسع والعشرون',
      'الثلاثون',
    ];
    if (n < 1 || n > 30) return n.toString();
    return names[n];
  }

  /// Convert integer to Arabic-Indic numeral string (٠١٢...).
  static String toArabicNumerals(int n) {
    const digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return n.toString().split('').map((c) => digits[int.parse(c)]).join();
  }

  // ── Rotating-message helpers (used by WirdNotificationService) ─────────

  /// Returns the current app language code ('ar' or 'en').
  String getAppLanguage() => _prefs.getString('app_language') ?? 'ar';

  /// Reads a named counter from SharedPreferences (default 0).
  int getCounter(String key) => _prefs.getInt(key) ?? 0;

  /// Increments a named counter and persists it.
  void incrementCounter(String key) {
    _prefs.setInt(key, getCounter(key) + 1);
  }
}
