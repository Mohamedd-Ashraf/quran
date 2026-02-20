import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/di/injection_container_firebase.dart' as di;
import 'core/services/adhan_notification_service.dart';
import 'core/services/app_update_service_firebase.dart';
import 'core/widgets/app_update_dialog_premium.dart';
import 'core/theme/app_theme.dart';
import 'core/settings/app_settings_cubit.dart';
import 'core/audio/ayah_audio_cubit.dart';
import 'core/widgets/onboarding_gate.dart';
import 'features/quran/presentation/bloc/surah/surah_bloc.dart';
import 'features/quran/presentation/bloc/ayah/ayah_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize dependency injection
  await di.init();

  // Initialize update service
  final updateService = di.sl<AppUpdateServiceFirebase>();
  await updateService.initialize();

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
    print('🔍 _checkForUpdates called - languageCode: $languageCode');
    
    try {
      final updateService = di.sl<AppUpdateServiceFirebase>();
      print('✅ Update service retrieved');
      
      // Force check for testing (remove shouldCheckForUpdate check temporarily)
      // final shouldCheck = await updateService.shouldCheckForUpdate();
      // print('⏰ Should check: $shouldCheck');
      // if (!shouldCheck) return;

      // Check for updates
      print('🔄 Calling checkForUpdate...');
      final updateInfo = await updateService.checkForUpdate();
      print('📦 Update info received: ${updateInfo != null ? "YES" : "NO"}');
      
      if (updateInfo != null) {
        print('   - Current: ${updateInfo.currentVersion}');
        print('   - Latest: ${updateInfo.latestVersion}');
        print('   - Has update: ${updateInfo.hasUpdate}');
        print('   - Mandatory: ${updateInfo.isMandatory}');
        print('   - Download URL: ${updateInfo.downloadUrl}');
      }
      
      // Show dialog if update is available
      if (updateInfo != null && context.mounted) {
        print('🎉 Showing update dialog NOW!');
        // Delay slightly to ensure UI is ready
        await Future.delayed(const Duration(milliseconds: 500));
        if (context.mounted) {
          showPremiumUpdateDialog(
            context: context,
            updateInfo: updateInfo,
            updateService: updateService,
            languageCode: languageCode,
          );
          print('✅ Dialog shown successfully');
        } else {
          print('❌ Context not mounted after delay');
        }
      } else {
        print('⚠️ No update to show');
        print('   - updateInfo null: ${updateInfo == null}');
        print('   - context mounted: ${context.mounted}');
      }
    } catch (e, stack) {
      print('❌ Error in _checkForUpdates: $e');
      print('Stack trace: $stack');
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
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  print('📲 App loaded, checking for updates...');
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
