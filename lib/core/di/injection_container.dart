import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../features/quran/data/datasources/quran_remote_data_source.dart';
import '../../features/quran/data/datasources/quran_local_data_source.dart';
import '../../features/quran/data/datasources/quran_bundled_data_source.dart';
import '../../features/quran/data/repositories/quran_repository_impl.dart';
import '../../features/quran/domain/repositories/quran_repository.dart';
import '../../features/quran/domain/usecases/get_all_surahs.dart';
import '../../features/quran/domain/usecases/get_surah.dart';
import '../../features/quran/domain/usecases/get_ayah.dart';
import '../../features/quran/domain/usecases/get_juz.dart';
import '../../features/quran/presentation/bloc/surah/surah_bloc.dart';
import '../../features/quran/presentation/bloc/ayah/ayah_bloc.dart';
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
import '../audio/download_manager_cubit.dart';

final sl = GetIt.instance;

Future<void> init() async {
  //! Features - Quran
  // Bloc
  sl.registerFactory(
    () => SurahBloc(
      getAllSurahs: sl(),
      getSurah: sl(),
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

  // Use cases
  sl.registerLazySingleton(() => GetAllSurahs(sl()));
  sl.registerLazySingleton(() => GetSurah(sl()));
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

  //! Core
  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(sl()));

  //! Services
  sl.registerLazySingleton(() => SettingsService(sl()));
  sl.registerLazySingleton(() => const LocationService());
  sl.registerLazySingleton(() => FlutterLocalNotificationsPlugin());
  sl.registerLazySingleton(() => PrayerTimesCacheService(sl()));
  sl.registerLazySingleton(() => AdhanNotificationService(sl(), sl(), sl(), sl()));
  sl.registerLazySingleton(() => BookmarkService(sl()));
  sl.registerLazySingleton(() => OfflineAudioService(sl(), sl()));
  sl.registerLazySingleton(() => AyahAudioService(sl(), sl(), sl()));
  sl.registerLazySingleton(() => AudioEditionService(sl(), sl(), sl()));
  sl.registerLazySingleton(() => AppUpdateService(sl(), sl()));
  sl.registerLazySingleton(() => AudioDownloadStateService(sl()));
  sl.registerLazySingleton(
    () => AudioDownloadNotificationService(sl()),
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
