import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../features/quran/data/datasources/quran_remote_data_source.dart';
import '../../features/quran/data/datasources/quran_local_data_source.dart';
import '../../features/quran/data/datasources/quran_bundled_data_source.dart';
import '../../features/quran/data/datasources/ibn_kathir_remote_data_source.dart';
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
import '../audio/ayah_audio_cubit.dart';
import '../network/network_info.dart';
import '../services/settings_service.dart';
import '../services/bookmark_service.dart';
import '../services/offline_audio_service.dart';
import '../services/ayah_audio_service.dart';
import '../services/audio_edition_service.dart';
import '../services/audio_download_state_service.dart';
import '../services/audio_download_notification_service.dart';
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

final sl = GetIt.instance;

Future<void> init() async {
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
    () => TafsirCubit(sl(), sl()),
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
  sl.registerLazySingleton(() => WirdNotificationService(sl(), sl()));
  sl.registerFactory(() => WirdCubit(sl(), sl()));
  sl.registerLazySingleton(() => AdhkarProgressService(sl()));
  sl.registerFactory(() => AdhkarProgressCubit(sl()));
  sl.registerLazySingleton(() => AudioDownloadStateService(sl()));
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

  //! External
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);
  sl.registerLazySingleton(() => http.Client());
  sl.registerLazySingleton(() => InternetConnectionChecker());
}
