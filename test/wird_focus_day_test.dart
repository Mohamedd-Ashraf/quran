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
        startDate: DateTime(2026, 1, 1),
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
        startDate: DateTime(2026, 1, 1),
      );

      await cubit.setFocusedDay(4);
      await cubit.setFocusedDay(0);
      expect((cubit.state as WirdPlanLoaded).focusedDay, 4);

      await cubit.setFocusedDay(99);
      expect((cubit.state as WirdPlanLoaded).focusedDay, 4);

      await cubit.close();
    });

    test('clearFocusedDay removes focused day from state', () async {
      SharedPreferences.setMockInitialValues({});
      final cubit = await createCubit();

      await cubit.setupPlan(
        type: WirdType.regular,
        targetDays: 10,
        startDate: DateTime(2026, 1, 1),
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
        startDate: DateTime(2026, 1, 1),
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
        startDate: DateTime(2026, 1, 1),
      );

      await cubit.setFocusedDay(6);
      expect((cubit.state as WirdPlanLoaded).focusedDay, 6);

      await cubit.toggleDayComplete(2);
      expect((cubit.state as WirdPlanLoaded).focusedDay, 6);

      await cubit.toggleDayComplete(2);
      expect((cubit.state as WirdPlanLoaded).focusedDay, 6);

      await cubit.close();
    });
  });
}
