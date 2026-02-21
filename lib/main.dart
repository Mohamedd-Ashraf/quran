import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/di/injection_container.dart' as di;
import 'core/services/adhan_notification_service.dart';
import 'core/services/app_update_service.dart';
import 'core/widgets/app_update_dialog.dart';
import 'core/theme/app_theme.dart';
import 'core/settings/app_settings_cubit.dart';
import 'core/audio/ayah_audio_cubit.dart';
import 'core/audio/download_manager_cubit.dart';
import 'core/widgets/onboarding_gate.dart';
import 'features/quran/presentation/bloc/surah/surah_bloc.dart';
import 'features/quran/presentation/bloc/ayah/ayah_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await di.init();

  // Notifications are used for prayer reminders (adhan). Initialize early.
  final adhanService = di.sl<AdhanNotificationService>();
  await adhanService.init();

  // Best-effort: ask for notification + exact alarm permission up-front.
  // Scheduling will no-op if permissions are denied.
  unawaited(adhanService.requestPermissions());

  // Schedule upcoming prayer reminders (uses cached location/times when available).
  unawaited(adhanService.ensureScheduled());

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  /// Check for app updates in the background
  Future<void> _checkForUpdates(BuildContext context, String languageCode) async {
    final updateService = di.sl<AppUpdateService>();
    
    // Only check if enough time has passed since last check
    final shouldCheck = await updateService.shouldCheckForUpdate();
    if (!shouldCheck) return;

    // Check for updates
    final updateInfo = await updateService.checkForUpdate();
    
    // Show dialog if update is available
    if (updateInfo != null && context.mounted) {
      // Delay slightly to ensure UI is ready
      await Future.delayed(const Duration(milliseconds: 500));
      if (context.mounted) {
        AppUpdateDialog.show(
          context: context,
          updateInfo: updateInfo,
          updateService: updateService,
          languageCode: languageCode,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => di.sl<SurahBloc>()),
        BlocProvider(create: (_) => di.sl<AyahBloc>()),
        BlocProvider(create: (_) => di.sl<AyahAudioCubit>()),
        BlocProvider(create: (_) => AppSettingsCubit(di.sl())),
        BlocProvider(
          create: (_) {
            final cubit = di.sl<DownloadManagerCubit>();
            // Check for interrupted download session from previous app run.
            cubit.checkForResumableSession();
            return cubit;
          },
        ),
      ],
      child: BlocBuilder<AppSettingsCubit, AppSettingsState>(
        builder: (context, settings) {
          final locale = Locale(settings.appLanguageCode);
          final isArabicUi = settings.appLanguageCode.toLowerCase().startsWith(
            'ar',
          );
          return MaterialApp(
            title: 'Quran App',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme(isArabicUi: isArabicUi),
            darkTheme: AppTheme.darkTheme(isArabicUi: isArabicUi),
            themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
            locale: locale,
            supportedLocales: const [Locale('en'), Locale('ar')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Builder(
              builder: (context) {
                // Check for updates after the app loads
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _checkForUpdates(context, settings.appLanguageCode);
                });
                return const OnboardingGate();
              },
            ),
          );
        },
      ),
    );
  }
}