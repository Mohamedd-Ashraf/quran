import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/quran/data/datasources/ibn_kathir_remote_data_source.dart';
import '../../features/quran/data/datasources/quran_local_tafsir_data_source.dart';
import '../../features/quran/domain/usecases/get_surah.dart';
import '../../features/quran/presentation/bloc/tafsir/tafsir_download_cubit.dart';
import '../constants/api_constants.dart';
import 'tafsir_download_state_service.dart';

/// Starts one automatic background download for Al-Muyassar on first app launch
/// after installing/updating to 1.0.11, then avoids re-triggering every launch.
class TafsirAutoDownloadService {
  static const String _targetVersion = '1.0.11';
  static const String _kMuyassarAutoTriggeredV1011 =
      'tafsir_muyassar_auto_triggered_1_0_11';

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
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version.trim();
      final alreadyTriggered =
          _prefs.getBool(_kMuyassarAutoTriggeredV1011) ?? false;

      if (alreadyTriggered) {
        return;
      }

      if (currentVersion != _targetVersion) {
        return;
      }

      final cubit = TafsirDownloadCubit(
        _getSurah,
        _ibnKathirDataSource,
        _localTafsir,
        _stateService,
      );

      try {
        if (!alreadyTriggered) {
          await _prefs.setBool(_kMuyassarAutoTriggeredV1011, true);
        }

        await cubit.startFull(ApiConstants.tafsirMuyassar);
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