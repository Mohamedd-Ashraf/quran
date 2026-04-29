/// Pure progression helpers — no Flutter or SharedPreferences dependencies.
///
/// Single source of truth for all wird sequence logic. Every function is
/// a stateless pure computation over [completedDays] and [targetDays].
class WirdProgressionHelper {
  WirdProgressionHelper._();

  // ── Core: logical current day ─────────────────────────────────────────────

  /// Returns the first day not present in [completed], starting from 1.
  ///
  /// Returns [targetDays] + 1 when every day is complete (completion sentinel).
  /// Never returns a value < 1 or > targetDays + 1.
  static int logicalCurrentDay(Set<int> completed, int targetDays) {
    if (targetDays <= 0) return 1;
    int day = 1;
    while (day <= targetDays && completed.contains(day)) {
      day++;
    }
    return day; // == targetDays + 1 when all done
  }

  // ── Qadaa (missed days) ───────────────────────────────────────────────────

  /// Days in [1 .. progressionMarker − 1] that are NOT in [completed].
  ///
  /// [progressionMarker] is the logical high-water mark: the furthest logical
  /// day the user has actively progressed to. Days before the marker that
  /// are uncompleted are true qadaa days.
  static List<int> computeQadaa(Set<int> completed, int progressionMarker) {
    return [
      for (int d = 1; d < progressionMarker; d++)
        if (!completed.contains(d)) d,
    ];
  }

  // ── Skip detection ────────────────────────────────────────────────────────

  /// Returns the list of days that were automatically bypassed when
  /// [justCompletedDay] was marked complete.
  ///
  /// A day is a "true skip" only when:
  ///  1. The user completed the logical current day (not qadaa or future).
  ///  2. The bypassed day is at or beyond [progressionMarker] — meaning it was
  ///     a pre-completed future day, not a day already processed by normal flow.
  ///
  /// Passing [progressionMarker] prevents false positives when a qadaa day is
  /// completed and the sequence jumps over days that were previously done in
  /// order (all below the marker).
  static List<int> computeSkippedOnComplete({
    required int justCompletedDay,
    required Set<int> oldCompleted,
    required Set<int> newCompleted,
    required int targetDays,
    required int progressionMarker,
  }) {
    final oldLogical = logicalCurrentDay(oldCompleted, targetDays);

    // Only trigger skip logic when the user completes the current logical day.
    if (justCompletedDay != oldLogical) return const [];

    final newLogical = logicalCurrentDay(newCompleted, targetDays);

    // Collect every day between old and new logical positions that is
    // already in newCompleted AND at/beyond the frontier (progressionMarker).
    // Days below the marker were processed in normal order, not pre-completed.
    final skipped = <int>[];
    for (int d = oldLogical + 1; d < newLogical; d++) {
      if (newCompleted.contains(d) && d >= progressionMarker) {
        skipped.add(d);
      }
    }
    return skipped;
  }
}
