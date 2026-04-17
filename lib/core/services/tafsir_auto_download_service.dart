import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/quran/data/datasources/ibn_kathir_remote_data_source.dart';
import '../../features/quran/data/datasources/quran_local_tafsir_data_source.dart';
import '../../features/quran/domain/usecases/get_surah.dart';
import '../../features/quran/presentation/bloc/tafsir/tafsir_download_cubit.dart';
import '../constants/api_constants.dart';
import 'tafsir_download_state_service.dart';

/// Automatically downloads Al-Muyassar tafsir in the background on Wi-Fi
/// the first time the app runs without the tafsir already cached.
///
/// Policy compliance:
///   • Wi-Fi only — skips silently on mobile data (user can download manually
///     from the offline-tafsir screen).
///   • Silent on Wi-Fi — downloading tafsir content on Wi-Fi without a prompt
///     is acceptable under Google Play policies.
///   • Flag is written AFTER a successful download (not before), so a failure
///     (e.g. offline at first launch) will be retried on the next app start.
class TafsirAutoDownloadService {
  static const String _kMuyassarFullyDownloaded =
      'tafsir_muyassar_fully_downloaded_v2';

  final SharedPreferences _prefs;
  final TafsirDownloadStateService _stateService;
  final GetSurah _getSurah;
  final IbnKathirRemoteDataSource _ibnKathirDataSource;
  final QuranLocalTafsirDataSource _localTafsir;

  bool _isRunning = false;

  TafsirAutoDownloadService(
    this._prefs,
    this._stateService,
    this._getSurah,
    this._ibnKathirDataSource,
    this._localTafsir,
  );

  Future<void> triggerIfEligible() async {
    if (_isRunning) return;
    _isRunning = true;
    try {
      // Skip if already fully downloaded in a previous session.
      if (_prefs.getBool(_kMuyassarFullyDownloaded) == true) return;

      // Skip if already fully cached in the local DB (covers manual downloads).
      final stats = await _localTafsir.getEditionStats(ApiConstants.tafsirMuyassar);
      if (stats.ayahCount >= 6236) {
        await _prefs.setBool(_kMuyassarFullyDownloaded, true);
        return;
      }

      // Wi-Fi only — never consume mobile data without user consent.
      final connectivity = await Connectivity().checkConnectivity();
      final isWifi = connectivity.any((r) =>
          r == ConnectivityResult.wifi || r == ConnectivityResult.ethernet);
      if (!isWifi) {
        debugPrint('TafsirAutoDownloadService: skipping – not on Wi-Fi');
        return;
      }

      debugPrint('TafsirAutoDownloadService: starting background download of Al-Muyassar');

      final cubit = TafsirDownloadCubit(
        _getSurah,
        _ibnKathirDataSource,
        _localTafsir,
        _stateService,
      );

      try {
        await cubit.startFull(ApiConstants.tafsirMuyassar);
        // Verify the download actually completed before setting the flag.
        final after = await _localTafsir.getEditionStats(ApiConstants.tafsirMuyassar);
        if (after.ayahCount >= 6236) {
          await _prefs.setBool(_kMuyassarFullyDownloaded, true);
          debugPrint('TafsirAutoDownloadService: Al-Muyassar download complete');
        } else {
          debugPrint(
            'TafsirAutoDownloadService: incomplete – ${after.ayahCount}/6236 ayahs cached',
          );
        }
      } finally {
        await cubit.close();
      }
    } catch (e, stack) {
      debugPrint('TafsirAutoDownloadService error: $e\n$stack');
    } finally {
      _isRunning = false;
    }
  }
}
