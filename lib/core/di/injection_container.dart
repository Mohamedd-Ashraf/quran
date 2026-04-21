import 'dart:io';

import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/auth/data/auth_service.dart';
import '../../features/auth/data/cloud_sync_service.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';

import '../../features/quran/data/datasources/quran_remote_data_source.dart';
import '../../features/quran/data/datasources/quran_local_data_source.dart';
import '../../features/quran/data/datasources/quran_bundled_data_source.dart';
import '../../features/quran/data/datasources/ibn_kathir_remote_data_source.dart';
import '../../features/quran/data/datasources/quran_local_tafsir_data_source.dart';
import '../../features/quran/data/repositories/quran_repository_impl.dart';
import '../../features/quran/domain/repositories/quran_repository.dart';
import '../../features/quran/domain/usecases/get_all_surahs.dart';
import '../../features/quran/domain/usecases/get_surah.dart';
import '../../features/quran/domain/usecases/get_ayah.dart';
import '../../features/quran/domain/usecases/get_juz.dart';
import '../../features/quran/presentation/bloc/surah/surah_bloc.dart';
import '../services/quran_cache_warmup_service.dart';
import '../../features/quran/presentation/bloc/ayah/ayah_bloc.dart';
import '../../features/quran/presentation/bloc/tafsir/tafsir_cubit.dart';
import '../../features/quran/presentation/bloc/tafsir/tafsir_download_cubit.dart';
import '../audio/ayah_audio_cubit.dart';
import '../network/network_info.dart';
import '../services/settings_service.dart';
import '../services/bookmark_service.dart';
import '../services/offline_audio_service.dart';
import '../services/ayah_audio_service.dart';
import '../services/audio_edition_service.dart';
import '../services/audio_download_state_service.dart';
import '../services/audio_download_notification_service.dart';
import '../services/tafsir_download_state_service.dart';
import '../services/location_service.dart';
import '../services/adhan_notification_service.dart';
import '../services/prayer_times_cache_service.dart';
import '../services/app_update_service.dart';
import '../services/whats_new_service.dart';
import '../services/feedback_service.dart';
import '../audio/download_manager_cubit.dart';
import '../../features/wird/data/wird_service.dart';
import '../../features/wird/services/wird_notification_service.dart';
import '../../features/wird/presentation/cubit/wird_cubit.dart';
import '../../features/adhkar/data/adhkar_progress_service.dart';
import '../../features/adhkar/presentation/cubit/adhkar_progress_cubit.dart';
import '../../features/quiz/data/quiz_repository.dart';
import '../../features/quiz/services/quiz_notification_service.dart';
import '../../features/quiz/presentation/cubit/quiz_cubit.dart';
import '../../features/quiz/presentation/cubit/leaderboard_cubit.dart';

final sl = GetIt.instance;

Future<void> _pruneOversizedLegacySharedPrefs() async {
  if (defaultTargetPlatform != TargetPlatform.android) return;

  try {
    final supportDir = await getApplicationSupportDirectory();
    final appRootDir = supportDir.parent;
    final prefsFile = File(
      '${appRootDir.path}/shared_prefs/FlutterSharedPreferences.xml',
    );

    if (!await prefsFile.exists()) return;

    final sizeBytes = await prefsFile.length();
    const int maxSafeBytes = 8 * 1024 * 1024; // 8 MB
    if (sizeBytes <= maxSafeBytes) return;

    final backupFile = File('${prefsFile.path}.oversized.bak');
    try {
      if (await backupFile.exists()) {
        await backupFile.delete();
      }
      await prefsFile.copy(backupFile.path);
    } catch (_) {
      // Best effort backup only.
    }

    await prefsFile.delete();
    debugPrint(
      'Deleted oversized legacy SharedPreferences file '
      '(${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB) to avoid OOM.',
    );
  } catch (e, st) {
    debugPrint('SharedPreferences prune skipped: $e\n$st');
  }
}

Future<void> init() async {
  await _pruneOversizedLegacySharedPrefs();

  //! Features - Quran
  // Bloc
  sl.registerFactory(
    () => SurahBloc(
      getAllSurahs: sl(),
      getSurah: sl(),
      getInstantSurah: sl(),
    ),
  );

  sl.registerFactory(
    () => AyahBloc(
      getAyah: sl(),
    ),
  );

  sl.registerFactory(
    () => AyahAudioCubit(sl(), sl()),
  );

  sl.registerFactory(
    () => TafsirCubit(sl(), sl(), sl()),
  );

  sl.registerFactory(
    () => TafsirDownloadCubit(sl(), sl(), sl(), sl()),
  );

  // Use cases
  sl.registerLazySingleton(() => GetAllSurahs(sl()));
  sl.registerLazySingleton(() => GetSurah(sl()));
  sl.registerLazySingleton(() => GetInstantSurah(sl()));
  sl.registerLazySingleton(() => GetAyah(sl()));
  sl.registerLazySingleton(() => GetJuz(sl()));

  // Repository
  sl.registerLazySingleton<QuranRepository>(
    () => QuranRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
      bundledDataSource: sl(),
      networkInfo: sl(),
    ),
  );

  // Data sources
  sl.registerLazySingleton<QuranRemoteDataSource>(
    () => QuranRemoteDataSourceImpl(client: sl()),
  );

  sl.registerLazySingleton<QuranLocalDataSource>(
    () => QuranLocalDataSourceImpl(prefs: sl()),
  );

  sl.registerLazySingleton<QuranBundledDataSource>(
    () => QuranBundledDataSourceImpl(),
  );

  sl.registerLazySingleton(
    () => IbnKathirRemoteDataSource(client: sl()),
  );

  sl.registerLazySingleton<QuranLocalTafsirDataSource>(
    () => QuranLocalTafsirDataSourceImpl(),
  );

  //! Core
  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(sl()));

  //! Services
  sl.registerLazySingleton(() => SettingsService(sl()));
  sl.registerLazySingleton(
    () => QuranCacheWarmupService(
      repository: sl(),
      localDataSource: sl(),
      settingsService: sl(),
      networkInfo: sl(),
    ),
  );
  sl.registerLazySingleton(() => const LocationService());
  sl.registerLazySingleton(() => FlutterLocalNotificationsPlugin());
  sl.registerLazySingleton(() => PrayerTimesCacheService(sl()));
  sl.registerLazySingleton(() => AdhanNotificationService(sl(), sl(), sl(), sl()));
  sl.registerLazySingleton(() => BookmarkService(sl()));
  sl.registerLazySingleton(() => OfflineAudioService(sl(), sl()));
  sl.registerLazySingleton(() => AyahAudioService(sl(), sl(), sl()));
  sl.registerLazySingleton(() => AudioEditionService(sl(), sl(), sl()));
  sl.registerLazySingleton(() => AppUpdateService(sl(), sl()));
  sl.registerLazySingleton(() => WhatsNewService(sl()));
  sl.registerLazySingleton(() => FeedbackService(sl()));
  sl.registerLazySingleton(() => WirdService(sl()));
  sl.registerLazySingleton(() => WirdNotificationService(sl(), sl(), sl()));
  sl.registerFactory(() => WirdCubit(sl(), sl(), sl()));
  sl.registerLazySingleton(() => AdhkarProgressService(sl()));
  sl.registerFactory(() => AdhkarProgressCubit(sl()));
  sl.registerLazySingleton(() => AudioDownloadStateService(sl()));
  sl.registerLazySingleton(() => TafsirDownloadStateService(sl()));
  sl.registerLazySingleton(
    () => AudioDownloadNotificationService(sl(), sl()),
  );
  sl.registerFactory(
    () => DownloadManagerCubit(
      audioService: sl(),
      stateService: sl(),
      notifService: sl(),
      editionService: sl(),
    ),
  );

  //! Features - Quiz
  sl.registerLazySingleton(
    () => QuizRepository(FirebaseFirestore.instance, FirebaseAuth.instance, sl()),
  );
  sl.registerLazySingleton(() => QuizNotificationService(sl(), sl()));
  sl.registerFactory(() => QuizCubit(sl(), sl()));
  sl.registerFactory(() => LeaderboardCubit(sl()));

  //! Auth
  sl.registerLazySingleton(() => AuthService());
  sl.registerLazySingleton(
    () => CloudSyncService(
      FirebaseFirestore.instance,
      sl(),
      sl(),
      sl(),
    ),
  );
  sl.registerFactory(() => AuthCubit(sl(), sl()));

  //! External
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);
  sl.registerLazySingleton(() => http.Client());
  sl.registerLazySingleton(() => InternetConnectionChecker());
}
