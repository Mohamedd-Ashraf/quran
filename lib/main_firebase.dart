import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'firebase_options.dart';
import 'core/di/injection_container_firebase.dart' as di;
import 'core/services/adhan_notification_service.dart';
import 'core/services/quran_cache_warmup_service.dart';
import 'core/services/app_update_service_firebase.dart';
import 'features/wird/services/wird_notification_service.dart';
import 'core/widgets/app_update_dialog_premium.dart';
import 'core/theme/app_theme.dart';
import 'core/settings/app_settings_cubit.dart';
import 'core/audio/ayah_audio_cubit.dart';
import 'core/audio/download_manager_cubit.dart';
import 'core/widgets/onboarding_gate.dart';
import 'features/quran/presentation/bloc/surah/surah_bloc.dart';
import 'features/quran/presentation/bloc/ayah/ayah_bloc.dart';
import 'features/wird/presentation/cubit/wird_cubit.dart';
import 'features/adhkar/presentation/cubit/adhkar_progress_cubit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Ensure Firestore is initialized (fixes gray screen in release if tree-shaken)
  try {
    FirebaseFirestore.instance.settings;
  } catch (e) {
    debugPrint('Firestore init error: $e');
  }
  
  // Initialize dependency injection
  await di.init();

  // Start background Quran cache warm-up so all surahs are available offline
  // and open instantly on subsequent visits.  Runs fully in background.
  di.sl<QuranCacheWarmupService>().startInBackground();

  // Initialize update service (Remote Config defaults + first fetch)
  final updateService = di.sl<AppUpdateServiceFirebase>();
  await updateService.initialize();

  // Notifications are used for prayer reminders (adhan). Initialize early.
  final adhanService = di.sl<AdhanNotificationService>();
  await adhanService.init();

  // Prime adhan scheduling immediately from cached coordinates or Egypt fallback.
  // Permissions are requested from the first-frame callback (with a delay)
  // so they never appear before the UI is visible.
  // The first foreground frame will retry with a real location permission prompt.
  unawaited(adhanService.ensureScheduleFresh());

  // If the selected adhan sound is online, cache it silently so it plays at
  // prayer time even when there is no internet connection.
  unawaited(adhanService.ensureSelectedSoundCached());

  // Initialize wird (daily recitation) reminder notifications.
  final wirdNotifService = di.sl<WirdNotificationService>();
  await wirdNotifService.init();
  // scheduleForPlan() re-registers BOTH the main daily reminder AND follow-ups
  // on every app start (covers device reboots that clear scheduled alarms).
  unawaited(wirdNotifService.scheduleForPlan());

  // Enable background audio playback (foreground service + lock-screen controls).
  // Must be called before runApp so AyahAudioCubit's AudioPlayer can connect
  // to the MediaBrowserServiceCompat when the widget tree is built.
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.example.quraan.channel.audio',
    androidNotificationChannelName: 'تلاوة القرآن الكريم',
    androidNotificationOngoing: true,
    androidStopForegroundOnPause: true,
    notificationColor: const Color(0xFF1B5E20), // Islamic dark green
    androidNotificationIcon: 'drawable/ic_notification',
  );

  runApp(const MyApp());
}

/// Global lifecycle observer that keeps wird notifications alive regardless
/// of which screen is currently open.
class _GlobalWirdLifecycleObserver extends StatefulWidget {
  final Widget child;
  const _GlobalWirdLifecycleObserver({required this.child});

  @override
  State<_GlobalWirdLifecycleObserver> createState() =>
      _GlobalWirdLifecycleObserverState();
}

class _GlobalWirdLifecycleObserverState
    extends State<_GlobalWirdLifecycleObserver> with WidgetsBindingObserver {
  bool _requestedInitialAdhanSchedule = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _requestedInitialAdhanSchedule) return;
      _requestedInitialAdhanSchedule = true;
      // Schedule adhan immediately from cached coordinates or Egypt fallback.
      // Permissions are requested from MainNavigator (after any What's New
      // screen is dismissed) so dialogs never interrupt the intro flow.
      unawaited(di.sl<AdhanNotificationService>().ensureScheduleFresh());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh the adhan schedule before the programmed window runs out.
      unawaited(di.sl<AdhanNotificationService>().ensureScheduleFresh());
      // Re-schedule wird notifications every time the app comes to foreground.
      // This ensures follow-up reminders are refreshed even when the user is
      // not on the Wird screen.
      unawaited(di.sl<WirdNotificationService>().scheduleForPlan());
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  /// Check for app updates in the background
  Future<void> _checkForUpdates(BuildContext context, String languageCode) async {
    try {
      final updateService = di.sl<AppUpdateServiceFirebase>();
      final updateInfo = await updateService.checkForUpdate();

      if (updateInfo != null && context.mounted) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (context.mounted) {
          showPremiumUpdateDialog(
            context: context,
            updateInfo: updateInfo,
            updateService: updateService,
            languageCode: languageCode,
          );
        }
      }
    } catch (e, stack) {
      debugPrint('Error in _checkForUpdates: $e\n$stack');
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
            cubit.checkForResumableSession();
            return cubit;
          },
        ),
        BlocProvider(
          create: (_) => di.sl<WirdCubit>()..load(),
        ),
        BlocProvider(
          create: (_) => di.sl<AdhkarProgressCubit>()..load(),
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
            home: _GlobalWirdLifecycleObserver(
              child: Builder(
                builder: (context) {
                  // Check for updates after the app loads
                  WidgetsBinding.instance.addPostFrameCallback((_) async {
                    _checkForUpdates(context, settings.appLanguageCode);
                  });
                  return const OnboardingGate();
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
