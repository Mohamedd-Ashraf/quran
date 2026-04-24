import 'dart:async';
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'firebase_options.dart';
import 'package:qcf_quran_plus/qcf_quran_plus.dart' show QcfFontLoader;
import 'core/services/qcf_font_download_service.dart';
import 'core/services/font_download_manager.dart';
import 'core/di/injection_container_firebase.dart' as di;
import 'core/navigation/notification_router.dart';
import 'core/services/adhan_notification_service.dart';
import 'core/services/quran_cache_warmup_service.dart';
import 'core/services/app_update_service_firebase.dart';
import 'core/services/tafsir_auto_download_service.dart';

import 'features/wird/services/wird_notification_service.dart';
import 'features/quiz/services/quiz_notification_service.dart';
import 'core/widgets/app_update_dialog_premium.dart';
import 'core/theme/app_theme.dart';
import 'core/settings/app_settings_cubit.dart';
import 'core/audio/ayah_audio_cubit.dart';
import 'core/audio/download_manager_cubit.dart';
import 'core/widgets/onboarding_gate.dart';
import 'features/auth/presentation/cubit/auth_cubit.dart';
import 'features/quran/presentation/bloc/surah/surah_bloc.dart';
import 'features/quran/presentation/bloc/ayah/ayah_bloc.dart';
import 'features/wird/presentation/cubit/wird_cubit.dart';
import 'features/adhkar/presentation/cubit/adhkar_progress_cubit.dart';
import 'features/hadith/presentation/cubit/hadith_cubit.dart';
import 'features/hadith/data/repositories/hadith_repository.dart';

void main() {
  // runZonedGuarded is the most reliable way to catch ALL uncaught async errors,
  // including errors that escape PlatformDispatcher.instance.onError due to the
  // google_fonts 6.3.3 bug where `.then()` without `.catchError()` creates
  // unhandled rejections that bypass the platform error handler.
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Pre-load only the bundled QCF page fonts (9 pages covering key surah openings).
      // Remaining 595 pages are downloaded on demand via QcfFontDownloadService.
      // Matches the smart selection in _BundledPages inside qcf_font_download_service.dart.
      const Set<int> bundledPages = {
        1, 2, 3, 4, // Al-Fatiha + Al-Baqarah opening
        50, // Al-Imran opening
        77, // An-Nisa opening
        106, // Al-Maidah opening
        128, // Al-An'am opening
        151, // Al-A'raf opening
      };
      for (final page in bundledPages) {
        await QcfFontLoader.ensureFontLoaded(page);
      }

      // If any previously-downloaded (non-bundled) fonts are on disk, register
      // them in the Flutter font engine now so they render instantly on first view.
      // This is lightweight – skipped pages have no disk file so nothing happens.
      final fontsComplete = await QcfFontDownloadService.isFullyDownloaded();
      if (fontsComplete) {
        // All fonts on disk — load them all (fast batch since TTFs already cached).
        await QcfFontLoader.setupFontsAtStartup(onProgress: (_) {});
      }

      // Fonts are bundled locally in assets/google_fonts/ – no network needed.
      GoogleFonts.config.allowRuntimeFetching = false;

      // Pre-load all bundled Google Fonts into the engine NOW so that later
      // widget builds never trigger an async loadFontIfNecessary that can race
      // with the QCF font downloads and throw unhandled exceptions.
      // Wrapped in try/catch because this runs before error handlers are installed
      // – if a font variant is missing from the bundle it would otherwise crash.
      try {
        await GoogleFonts.pendingFonts([
          GoogleFonts.cairo(),
          GoogleFonts.amiriQuran(),
          GoogleFonts.arefRuqaa(),
          GoogleFonts.arefRuqaa(fontWeight: FontWeight.bold),
          GoogleFonts.amiri(),
          GoogleFonts.amiri(fontWeight: FontWeight.bold),
          GoogleFonts.notoNaskhArabic(),
          GoogleFonts.notoNaskhArabic(fontWeight: FontWeight.w600),
          GoogleFonts.notoNaskhArabic(fontWeight: FontWeight.bold),
          GoogleFonts.cinzel(),
          GoogleFonts.cinzel(fontWeight: FontWeight.bold),
          GoogleFonts.poppins(),
          GoogleFonts.poppins(fontWeight: FontWeight.w500),
          GoogleFonts.poppins(fontWeight: FontWeight.w600),
          GoogleFonts.poppins(fontWeight: FontWeight.bold),
          // Only Bold is bundled in assets/google_fonts/ — Regular is not available.
          GoogleFonts.notoSerif(fontWeight: FontWeight.bold),
        ]);
      } catch (_) {
        // Some font variants may not be in the bundle – silently ignore.
        // They will fall back to the default font when rendered.
      }

      bool isGoogleFontsError(Object error) {
        final msg = error.toString().toLowerCase();
        return msg.contains('google_fonts') ||
            msg.contains('googlefonts') ||
            msg.contains('failed to load font') ||
            msg.contains('font') ||
            msg.contains('socketexception') ||
            msg.contains('network') ||
            msg.contains('clientexception');
      }

      FlutterError.onError = (details) {
        final ex = details.exception;
        if (isGoogleFontsError(ex)) {
          debugPrint('Ignored non-fatal network/font error: $ex');
          return;
        }
        FlutterError.presentError(details);
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        if (isGoogleFontsError(error)) {
          debugPrint('Ignored async network/font error: $error');
          return true; // Return true to prevent the crash
        }
        // Return true for any unhandled async error in release to prevent app closure,
        // but in debug we let it pass.
        return true; // Prevent all async crashes offline
      };

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

      // Start QCF font download immediately — gives maximum head-start before the
      // user navigates to Quran pages.  Wi-Fi only by default; mobile-data
      // consent is handled inside FontDownloadManager.  Fully background, no UI.
      unawaited(FontDownloadManager.instance.startIfNeeded());

      // Chain: when fonts finish downloading, start tafsir auto-download.
      // Staggering the two heavy operations avoids competing for bandwidth.
      _scheduleTafsirAfterFonts();

      // Initialize update service (Remote Config defaults + first fetch)
      final updateService = di.sl<AppUpdateServiceFirebase>();
      await updateService.initialize();

      // Notifications are used for prayer reminders (adhan). Initialize early.
      final adhanService = di.sl<AdhanNotificationService>();
      await adhanService.init(
        onNotificationTap: (NotificationResponse response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            navigateFromNotification(payload);
          }
        },
      );

      // ── Cold-start: check if the app was launched by tapping a notification ──
      // This covers the case where the app was killed and the user tapped a
      // flutter_local_notifications notification (quiz reminder).
      try {
        final launchDetails = await di
            .sl<FlutterLocalNotificationsPlugin>()
            .getNotificationAppLaunchDetails();
        if (launchDetails != null &&
            launchDetails.didNotificationLaunchApp &&
            launchDetails.notificationResponse?.payload != null) {
          final payload = launchDetails.notificationResponse!.payload!;
          if (payload.isNotEmpty) {
            setPendingNotificationRoute(payload);
            debugPrint(
              '[Notif] Cold-start from notification: payload=$payload',
            );
          }
        }
      } catch (e) {
        debugPrint('[Notif] getNotificationAppLaunchDetails failed: $e');
      }

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

      // Initialize quiz (daily competition) reminder notifications.
      final quizNotifService = di.sl<QuizNotificationService>();
      await quizNotifService.init();
      unawaited(quizNotifService.scheduleDailyReminder());

      // Enable background audio playback (foreground service + lock-screen controls).
      // Must be called before runApp so AyahAudioCubit's AudioPlayer can connect
      // to the MediaBrowserServiceCompat when the widget tree is built.
      await JustAudioBackground.init(
        androidNotificationChannelId: 'com.nooraliman.quran.channel.audio',
        androidNotificationChannelName: 'تلاوة القرآن الكريم',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
        notificationColor: const Color(0xFF1B5E20), // Islamic dark green
        androidNotificationIcon: 'drawable/ic_notification',
      );

      runApp(const MyApp());
    },
    (error, stack) {
      // Catches all unhandled zone errors — including google_fonts async throws
      // that escape PlatformDispatcher.instance.onError in google_fonts <8.0.2.
      debugPrint('[Zone] Ignored unhandled error: $error');
    },
  );
}

/// Waits for QCF font download to finish, then triggers the Muyassar tafsir
/// auto-download.  Uses a one-shot [ChangeNotifier] listener so there is no
/// polling or busy-waiting.  Safe to call before fonts have started.
void _scheduleTafsirAfterFonts() {
  final fm = FontDownloadManager.instance;

  void trigger() {
    unawaited(di.sl<TafsirAutoDownloadService>().triggerIfEligible());
  }

  if (fm.isComplete) {
    trigger();
    return;
  }

  // Fonts are still downloading (or have not started yet on mobile data).
  // Register a one-shot listener that fires as soon as they finish or error.
  late void Function() listener;
  listener = () {
    if (fm.isComplete || fm.hasError) {
      fm.removeListener(listener);
      trigger();
    }
  };
  fm.addListener(listener);
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
    extends State<_GlobalWirdLifecycleObserver>
    with WidgetsBindingObserver {
  bool _requestedInitialAdhanSchedule = false;
  Timer? _midnightTimer;
  DateTime? _lastRescheduleDate;

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
    _scheduleMidnightCheck();
  }

  /// Schedule a timer to refresh notifications at midnight.
  /// This ensures that wenn the date changes while the app is running,
  /// notifications are rescheduled with the correct "completed today" state.
  void _scheduleMidnightCheck() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final durationUntilMidnight = tomorrow.difference(now);

    _midnightTimer = Timer(durationUntilMidnight, () {
      if (!mounted) return;
      // Date changed - reschedule notifications for the new day
      unawaited(di.sl<WirdNotificationService>().scheduleForPlan());
      unawaited(di.sl<QuizNotificationService>().scheduleDailyReminder());
      // Schedule next midnight check
      _scheduleMidnightCheck();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnightTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh the adhan schedule before the programmed window runs out.
      unawaited(di.sl<AdhanNotificationService>().ensureScheduleFresh());

      // Check if date changed while app was in background
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      if (_lastRescheduleDate == null ||
          !_lastRescheduleDate!.isAtSameMomentAs(todayDate)) {
        _lastRescheduleDate = todayDate;
        // Date changed - reschedule notifications for the new day
        unawaited(di.sl<WirdNotificationService>().scheduleForPlan());
        unawaited(di.sl<QuizNotificationService>().scheduleDailyReminder());
        // Reset midnight timer for the new day
        _scheduleMidnightCheck();
      } else {
        // Same day - normal foreground refresh
        unawaited(di.sl<WirdNotificationService>().scheduleForPlan());
        unawaited(di.sl<QuizNotificationService>().scheduleDailyReminder());
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  /// Check for app updates in the background
  Future<void> _checkForUpdates(
    BuildContext context,
    String languageCode,
  ) async {
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
    return RepositoryProvider<HadithRepository>(
      create: (_) => di.sl<HadithRepository>(),
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => di.sl<AuthCubit>()),
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
          BlocProvider(create: (_) => di.sl<WirdCubit>()..load()),
          BlocProvider(create: (_) => di.sl<AdhkarProgressCubit>()..load()),
          BlocProvider(create: (_) => di.sl<HadithCubit>()),
        ],
        child: BlocBuilder<AppSettingsCubit, AppSettingsState>(
          builder: (context, settings) {
            final locale = Locale(settings.appLanguageCode);
            final isArabicUi = settings.appLanguageCode
                .toLowerCase()
                .startsWith('ar');
            return MaterialApp(
              title: 'Quran App',
              debugShowCheckedModeBanner: false,
              navigatorKey: appNavigatorKey,
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
      ),
    );
  }
}
