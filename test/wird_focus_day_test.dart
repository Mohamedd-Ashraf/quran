import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_al_imaan/core/services/settings_service.dart';
import 'package:noor_al_imaan/features/wird/data/wird_service.dart';
import 'package:noor_al_imaan/features/wird/presentation/cubit/wird_cubit.dart';
import 'package:noor_al_imaan/features/wird/presentation/cubit/wird_state.dart';
import 'package:noor_al_imaan/features/wird/services/wird_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WirdService focused day persistence', () {
    test('set/get/clear focused day works', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = WirdService(prefs);

      expect(service.focusedDay, isNull);

      await service.setFocusedDay(5);
      expect(service.focusedDay, 5);

      await service.clearFocusedDay();
      expect(service.focusedDay, isNull);
    });

    test('initPlan clears stale focused day', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = WirdService(prefs);

      await service.setFocusedDay(8);
      expect(service.focusedDay, 8);

      await service.initPlan(
        type: WirdType.regular,
        startDate: DateTime(2026, 1, 1),
        targetDays: 10,
      );

      expect(service.focusedDay, isNull);
    });

    test('clearPlan clears focused day', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = WirdService(prefs);

      await service.initPlan(
        type: WirdType.regular,
        startDate: DateTime(2026, 1, 1),
        targetDays: 10,
      );
      await service.setFocusedDay(7);
      expect(service.focusedDay, 7);

      await service.clearPlan();

      expect(service.focusedDay, isNull);
    });
  });

  group('WirdCubit focused day behavior', () {
    Future<WirdCubit> createCubit() async {
      final prefs = await SharedPreferences.getInstance();
      final wirdService = WirdService(prefs);
      final settingsService = SettingsService(prefs);
      final notificationService = WirdNotificationService(
        FlutterLocalNotificationsPlugin(),
        wirdService,
        settingsService,
      );

      return WirdCubit(wirdService, notificationService, settingsService);
    }

    test('load exposes focused day from storage', () async {
      SharedPreferences.setMockInitialValues({});
      final cubit = await createCubit();

      await cubit.setupPlan(
        type: WirdType.regular,
        targetDays: 10,
        startDate: DateTime.now(),
      );
      await cubit.setFocusedDay(6);
      cubit.load();

      final state = cubit.state;
      expect(state, isA<WirdPlanLoaded>());
      expect((state as WirdPlanLoaded).focusedDay, 6);

      await cubit.close();
    });

    test('setFocusedDay rejects out-of-range values', () async {
      SharedPreferences.setMockInitialValues({});
      final cubit = await createCubit();

      await cubit.setupPlan(
        type: WirdType.regular,
        targetDays: 10,
        startDate: DateTime.now(),
      );

      await cubit.setFocusedDay(4);
      await cubit.setFocusedDay(0);
      expect((cubit.state as WirdPlanLoaded).focusedDay, 4);

      await cubit.setFocusedDay(99);
      expect((cubit.state as WirdPlanLoaded).focusedDay, 4);

      await cubit.close();
    });

    test('setFocusedDay rejects day at or before activeDailyDay', () async {
      SharedPreferences.setMockInitialValues({});
      final cubit = await createCubit();

      // startDate = today so activeDailyDay starts at 1.
      await cubit.setupPlan(
        type: WirdType.regular,
        targetDays: 10,
        startDate: DateTime.now(),
      );

      await cubit.setFocusedDay(1); // 1 <= activeDailyDay(1) → rejected
      expect((cubit.state as WirdPlanLoaded).focusedDay, isNull);

      await cubit.toggleDayComplete(1);
      expect((cubit.state as WirdPlanLoaded).plan.logicalCurrentDay, 2);

      await cubit.setFocusedDay(2); // 2 <= activeDailyDay(2) → rejected
      expect((cubit.state as WirdPlanLoaded).focusedDay, isNull);

      await cubit.setFocusedDay(3); // 3 > activeDailyDay(2) → accepted
      expect((cubit.state as WirdPlanLoaded).focusedDay, 3);

      await cubit.close();
    });

    test('clearFocusedDay removes focused day from state', () async {
      SharedPreferences.setMockInitialValues({});
      final cubit = await createCubit();

      await cubit.setupPlan(
        type: WirdType.regular,
        targetDays: 10,
        startDate: DateTime.now(),
      );

      await cubit.setFocusedDay(5);
      expect((cubit.state as WirdPlanLoaded).focusedDay, 5);

      await cubit.clearFocusedDay();
      expect((cubit.state as WirdPlanLoaded).focusedDay, isNull);

      await cubit.close();
    });

    test('completed focused day stays focused until explicit change', () async {
      SharedPreferences.setMockInitialValues({});
      final cubit = await createCubit();

      await cubit.setupPlan(
        type: WirdType.regular,
        targetDays: 10,
        startDate: DateTime.now(),
      );

      await cubit.setFocusedDay(5);
      expect((cubit.state as WirdPlanLoaded).focusedDay, 5);

      await cubit.toggleDayComplete(5);
      expect((cubit.state as WirdPlanLoaded).focusedDay, 5);

      await cubit.close();
    });

    test('focused day stays after toggling another earlier day', () async {
      SharedPreferences.setMockInitialValues({});
      final cubit = await createCubit();

      await cubit.setupPlan(
        type: WirdType.regular,
        targetDays: 10,
        startDate: DateTime.now(),
      );

      await cubit.setFocusedDay(6);
      expect((cubit.state as WirdPlanLoaded).focusedDay, 6);

      await cubit.toggleDayComplete(2);
      expect((cubit.state as WirdPlanLoaded).focusedDay, 6);

      await cubit.toggleDayComplete(2);
      expect((cubit.state as WirdPlanLoaded).focusedDay, 6);

      await cubit.close();
    });

    test('focused day beyond targetDays is rejected', () async {
      SharedPreferences.setMockInitialValues({});
      final cubit = await createCubit();

      await cubit.setupPlan(
        type: WirdType.regular,
        targetDays: 10,
        startDate: DateTime.now(),
      );

      await cubit.setFocusedDay(3);
      expect((cubit.state as WirdPlanLoaded).focusedDay, 3);

      await cubit.setFocusedDay(11);
      expect((cubit.state as WirdPlanLoaded).focusedDay, 3);

      await cubit.close();
    });

    test('toggleDayComplete on focused day preserves focus', () async {
      SharedPreferences.setMockInitialValues({});
      final cubit = await createCubit();

      await cubit.setupPlan(
        type: WirdType.regular,
        targetDays: 10,
        startDate: DateTime.now(),
      );

      await cubit.setFocusedDay(7);
      await cubit.toggleDayComplete(7);
      expect((cubit.state as WirdPlanLoaded).focusedDay, 7);
      expect((cubit.state as WirdPlanLoaded).plan.isDayComplete(7), isTrue);

      await cubit.toggleDayComplete(7);
      expect((cubit.state as WirdPlanLoaded).focusedDay, 7);
      expect((cubit.state as WirdPlanLoaded).plan.isDayComplete(7), isFalse);

      await cubit.close();
    });

    test('focused day clears when active day reaches focused day', () async {
      SharedPreferences.setMockInitialValues({});
      final cubit = await createCubit();

      // startDate = today so activeDailyDay starts at 1.
      await cubit.setupPlan(
        type: WirdType.regular,
        targetDays: 10,
        startDate: DateTime.now(),
      );

      await cubit.setFocusedDay(3); // focus day 3 (activeDailyDay=1 → accepted)
      expect((cubit.state as WirdPlanLoaded).focusedDay, 3);

      await cubit.toggleDayComplete(1); // active: 1→2; focus=3>2 → keep
      expect((cubit.state as WirdPlanLoaded).focusedDay, 3);

      await cubit.toggleDayComplete(2); // active: 2→3; focus=3<=3 → CLEAR
      final state = cubit.state as WirdPlanLoaded;
      expect(state.plan.logicalCurrentDay, 3);
      expect(state.focusedDay, isNull);

      await cubit.close();
    });

    test('completing a qadaa day does NOT clear upcoming focus', () async {
      SharedPreferences.setMockInitialValues({});
      final cubit = await createCubit();

      // startDate = today; complete day 1, then focus day 5.
      await cubit.setupPlan(
        type: WirdType.regular,
        targetDays: 10,
        startDate: DateTime.now(),
      );
      await cubit.toggleDayComplete(1); // active=2
      await cubit.setFocusedDay(5); // accepted (5>2)
      expect((cubit.state as WirdPlanLoaded).focusedDay, 5);

      // Mark day 2 complete via grid (qadaa, since 2 is now the active day).
      // Active moves 2→3. Focus=5>3 → must NOT clear.
      await cubit.toggleDayComplete(2);
      expect((cubit.state as WirdPlanLoaded).focusedDay, 5); // still 5

      await cubit.close();
    });
  });

  // ── effectiveFrontier: calendar-driven qadaa ────────────────────────────

  group('WirdPlan.effectiveFrontier', () {
    test('startDate today: effectiveFrontier == progressionMarker', () {
      final plan = WirdPlan(
        type: WirdType.regular,
        startDate: DateTime.now(),
        targetDays: 30,
        completedDays: const [1, 2],
        storedProgressionMarker: 3,
      );
      // currentDay == 1 (today), progressionMarker == 3 → frontier == 3
      expect(plan.effectiveFrontier, plan.progressionMarker);
    });

    test('5 days elapsed with only 2 completed: frontier == currentDay', () {
      final startDate = DateTime.now().subtract(const Duration(days: 4));
      final plan = WirdPlan(
        type: WirdType.regular,
        startDate: startDate,
        targetDays: 30,
        completedDays: const [1, 2],
        storedProgressionMarker: 3,
      );
      // currentDay == 5, progressionMarker == 3 → effectiveFrontier == 5
      expect(plan.currentDay, 5);
      expect(plan.progressionMarker, 3);
      expect(plan.effectiveFrontier, 5);
    });

    test('days 3-4 are qadaa when calendar day is 5 and only 1,2 completed', () {
      final startDate = DateTime.now().subtract(const Duration(days: 4));
      final plan = WirdPlan(
        type: WirdType.regular,
        startDate: startDate,
        targetDays: 30,
        completedDays: const [1, 2],
        storedProgressionMarker: 3,
      );
      final frontier = plan.effectiveFrontier;
      final qadaa = [
        for (int d = 1; d < frontier; d++) if (!plan.isDayComplete(d)) d,
      ];
      expect(qadaa, [3, 4]);
    });

    test('activeDailyDay = effectiveFrontier when frontier day not complete', () {
      final startDate = DateTime.now().subtract(const Duration(days: 4));
      final plan = WirdPlan(
        type: WirdType.regular,
        startDate: startDate,
        targetDays: 30,
        completedDays: const [1, 2],
        storedProgressionMarker: 3,
      );
      // currentDay=5, effectiveFrontier=5, day 5 not complete → activeDailyDay=5
      expect(plan.activeDailyDay, 5);
    });

    test('activeDailyDay skips completed frontier day', () {
      final startDate = DateTime.now().subtract(const Duration(days: 4));
      final plan = WirdPlan(
        type: WirdType.regular,
        startDate: startDate,
        targetDays: 30,
        // days 1,2,5 done; frontier=5 done → activeDailyDay=6
        completedDays: const [1, 2, 5],
        storedProgressionMarker: 3,
      );
      expect(plan.effectiveFrontier, 5);
      expect(plan.activeDailyDay, 6); // 5 is done, next is 6
    });

    test('activeDailyDay in screen context: qadaa days NOT shown as today', () {
      // Simulates screenshot scenario: logicalCurrentDay=6 (missed), but
      // activeDailyDay=33 (calendar frontier). The main card should show 33.
      final startDate = DateTime.now().subtract(const Duration(days: 32));
      final plan = WirdPlan(
        type: WirdType.regular,
        startDate: startDate,
        targetDays: 61,
        // Days 7-12 done, 25-30 done (like screenshot). Day 6 missed.
        completedDays: const [1, 2, 3, 4, 5, 7, 8, 9, 10, 11, 12, 25, 26, 28, 29, 30],
        storedProgressionMarker: 13,
      );
      expect(plan.logicalCurrentDay, 6); // first missing = 6
      expect(plan.currentDay, 33); // calendar day
      expect(plan.effectiveFrontier, 33);
      expect(plan.activeDailyDay, 33); // NOT 6!
    });
  });

  // ── focusedDay date-expiry ────────────────────────────────────────────────

  group('WirdService.focusedDay date-expiry', () {
    test('focusedDay returns day when set today', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = WirdService(prefs);

      await service.setFocusedDay(7);
      expect(service.focusedDay, 7);
    });

    test('focusedDay returns null when set-date is a past date', () async {
      // Simulate a stale pref from a prior day.
      SharedPreferences.setMockInitialValues({
        'wird_focused_day': 7,
        'wird_focused_day_set_date': '20260101', // a fixed past date
      });
      final prefs = await SharedPreferences.getInstance();
      final service = WirdService(prefs);

      // Today != 20260101, so focusedDay should be null (expired).
      expect(service.focusedDay, isNull);
    });

    test('clearFocusedDay also removes set-date', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = WirdService(prefs);

      await service.setFocusedDay(5);
      expect(service.focusedDay, 5);

      await service.clearFocusedDay();
      expect(prefs.containsKey('wird_focused_day'), isFalse);
      expect(prefs.containsKey('wird_focused_day_set_date'), isFalse);
    });
  });
}
