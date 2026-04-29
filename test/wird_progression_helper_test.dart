import 'package:flutter_test/flutter_test.dart';
import 'package:noor_al_imaan/features/wird/domain/wird_progression_helper.dart';

void main() {
  // ── logicalCurrentDay ────────────────────────────────────────────────────

  group('logicalCurrentDay', () {
    test('empty completed → day 1', () {
      expect(WirdProgressionHelper.logicalCurrentDay({}, 30), 1);
    });

    test('days 1-3 done → day 4', () {
      expect(WirdProgressionHelper.logicalCurrentDay({1, 2, 3}, 30), 4);
    });

    test('all days done → targetDays + 1 (completion sentinel)', () {
      final completed = {for (int i = 1; i <= 30; i++) i};
      expect(WirdProgressionHelper.logicalCurrentDay(completed, 30), 31);
    });

    test('gap: 1,2 done, 3 missing, 4,5 done → day 3', () {
      expect(WirdProgressionHelper.logicalCurrentDay({1, 2, 4, 5}, 30), 3);
    });

    test('day 1 missing, rest done → day 1', () {
      final completed = {for (int i = 2; i <= 30; i++) i};
      expect(WirdProgressionHelper.logicalCurrentDay(completed, 30), 1);
    });

    test('only future day pre-completed: {6}, target=30 → day 1', () {
      expect(WirdProgressionHelper.logicalCurrentDay({6}, 30), 1);
    });

    test('zero targetDays → 1 (guard)', () {
      expect(WirdProgressionHelper.logicalCurrentDay({}, 0), 1);
    });

    test('targetDays negative → 1 (guard)', () {
      expect(WirdProgressionHelper.logicalCurrentDay({}, -5), 1);
    });
  });

  // ── computeQadaa ─────────────────────────────────────────────────────────

  group('computeQadaa', () {
    test('marker=1, nothing → empty qadaa', () {
      expect(WirdProgressionHelper.computeQadaa({}, 1), isEmpty);
    });

    test('all days before marker complete → no qadaa', () {
      // marker=6, days 1-5 complete
      expect(WirdProgressionHelper.computeQadaa({1, 2, 3, 4, 5}, 6), isEmpty);
    });

    test('day 3 missing, marker=7 → qadaa=[3]', () {
      expect(
        WirdProgressionHelper.computeQadaa({1, 2, 4, 5, 6}, 7),
        [3],
      );
    });

    test('multiple missing → all returned in order', () {
      // marker=8, days 3 and 5 missing
      expect(
        WirdProgressionHelper.computeQadaa({1, 2, 4, 6, 7}, 8),
        [3, 5],
      );
    });

    test('marker=1 with completed days → still empty (no days before marker)', () {
      expect(WirdProgressionHelper.computeQadaa({1, 2}, 1), isEmpty);
    });

    test('undo past day: remove day 3 from {1..7}, marker=8 → qadaa=[3]', () {
      final completed = {1, 2, 4, 5, 6, 7}; // day 3 removed
      expect(WirdProgressionHelper.computeQadaa(completed, 8), [3]);
    });
  });

  // ── computeSkippedOnComplete ──────────────────────────────────────────────

  group('computeSkippedOnComplete', () {
    test('no pre-completions → no skip', () {
      // days 1-4 complete, completing day 5 normally
      final old = {1, 2, 3, 4};
      final newC = {1, 2, 3, 4, 5};
      expect(
        WirdProgressionHelper.computeSkippedOnComplete(
          justCompletedDay: 5,
          oldCompleted: old,
          newCompleted: newC,
          targetDays: 30,
          progressionMarker: 5, // normal flow: marker == logical
        ),
        isEmpty,
      );
    });

    test('day 6 pre-completed → completing day 5 skips day 6', () {
      final old = {1, 2, 3, 4, 6}; // logicalCurrent = 5
      final newC = {1, 2, 3, 4, 5, 6};
      final skipped = WirdProgressionHelper.computeSkippedOnComplete(
        justCompletedDay: 5,
        oldCompleted: old,
        newCompleted: newC,
        targetDays: 30,
        progressionMarker: 5, // frontier at 5; day 6 is pre-completed future
      );
      expect(skipped, [6]);
    });

    test('days 6 and 7 pre-completed → both skipped when day 5 done', () {
      final old = {1, 2, 3, 4, 6, 7};
      final newC = {1, 2, 3, 4, 5, 6, 7};
      final skipped = WirdProgressionHelper.computeSkippedOnComplete(
        justCompletedDay: 5,
        oldCompleted: old,
        newCompleted: newC,
        targetDays: 30,
        progressionMarker: 5, // frontier at 5; days 6,7 are pre-completed
      );
      expect(skipped, [6, 7]);
    });

    test('completing a non-current day (future pre-completion) → no skip', () {
      // logicalCurrent = 5, but user marks day 10
      final old = {1, 2, 3, 4};
      final newC = {1, 2, 3, 4, 10};
      expect(
        WirdProgressionHelper.computeSkippedOnComplete(
          justCompletedDay: 10,
          oldCompleted: old,
          newCompleted: newC,
          targetDays: 30,
          progressionMarker: 5,
        ),
        isEmpty,
      );
    });

    test('completing a past day (not logical current) → no skip', () {
      // marker would be at 8, user marks day 3 from qadaa
      final old = {1, 2, 4, 5, 6, 7}; // day 3 is qadaa
      final newC = {1, 2, 3, 4, 5, 6, 7};
      expect(
        WirdProgressionHelper.computeSkippedOnComplete(
          justCompletedDay: 3,
          oldCompleted: old,
          newCompleted: newC,
          targetDays: 30,
          progressionMarker: 8, // days 4-7 below marker → not true skips
        ),
        isEmpty,
      );
    });

    test('completing last day with no pre-completed days after → no skip', () {
      final completed = {for (int i = 1; i <= 29; i++) i};
      final newC = {...completed, 30};
      expect(
        WirdProgressionHelper.computeSkippedOnComplete(
          justCompletedDay: 30,
          oldCompleted: completed,
          newCompleted: newC,
          targetDays: 30,
          progressionMarker: 30,
        ),
        isEmpty,
      );
    });

    test('all days already done except last → completing last, no skip', () {
      final old = {for (int i = 1; i <= 29; i++) i};
      final newC = {...old, 30};
      expect(
        WirdProgressionHelper.computeSkippedOnComplete(
          justCompletedDay: 30,
          oldCompleted: old,
          newCompleted: newC,
          targetDays: 30,
          progressionMarker: 30,
        ),
        isEmpty,
      );
    });

    test('clear all → logicalCurrentDay = 1 from empty set', () {
      expect(WirdProgressionHelper.logicalCurrentDay({}, 30), 1);
    });
  });
}
