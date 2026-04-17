// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:noor_al_imaan/core/services/settings_service.dart';
import 'package:noor_al_imaan/core/settings/app_settings_cubit.dart';
import 'package:noor_al_imaan/features/islamic/presentation/screens/onboarding_screen.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Onboarding screen renders and Continue calls callback', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final settingsService = SettingsService(prefs);
    final settingsCubit = AppSettingsCubit(settingsService);
    var didContinue = false;

    await tester.pumpWidget(
      BlocProvider.value(
        value: settingsCubit,
        child: MaterialApp(
          home: OnboardingScreen(
            onContinue: () {
              didContinue = true;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Onboarding'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(didContinue, isTrue);

    await settingsCubit.close();
  });
}
