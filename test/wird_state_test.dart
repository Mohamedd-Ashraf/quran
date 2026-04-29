import 'package:flutter_test/flutter_test.dart';
import 'package:noor_al_imaan/features/wird/data/wird_service.dart';
import 'package:noor_al_imaan/features/wird/presentation/cubit/wird_state.dart';

void main() {
  group('WirdPlanLoaded equality', () {
    test('changes when progression metadata changes', () {
      final basePlan = WirdPlan(
        type: WirdType.regular,
        startDate: DateTime(2026, 1, 1),
        targetDays: 30,
        completedDays: const [1, 2],
        storedProgressionMarker: 3,
      );
      final planWithSkipMeta = WirdPlan(
        type: WirdType.regular,
        startDate: DateTime(2026, 1, 1),
        targetDays: 30,
        completedDays: const [1, 2],
        storedProgressionMarker: 5,
        skippedDays: const [3, 4],
        skipNoteAnchorDay: 5,
      );

      expect(
        WirdPlanLoaded(basePlan),
        isNot(equals(WirdPlanLoaded(planWithSkipMeta))),
      );
    });

    test('changes when plan mode metadata changes', () {
      final daysPlan = WirdPlan(
        type: WirdType.regular,
        startDate: DateTime(2026, 1, 1),
        targetDays: 30,
        completedDays: const [1, 2],
        storedProgressionMarker: 3,
      );
      final pagesPlan = WirdPlan(
        type: WirdType.regular,
        startDate: DateTime(2026, 1, 1),
        targetDays: 30,
        planMode: WirdPlanMode.pages,
        pagesPerDay: 20,
        completedDays: const [1, 2],
        storedProgressionMarker: 3,
      );

      expect(
        WirdPlanLoaded(daysPlan),
        isNot(equals(WirdPlanLoaded(pagesPlan))),
      );
    });
  });
}