import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/constants/api_constants.dart';
import '../../../../../core/di/injection_container.dart' as di;
import '../../../../../core/error/exceptions.dart';
import '../../../../../core/services/settings_service.dart';
import '../../../../../features/quran/data/datasources/ibn_kathir_remote_data_source.dart';
import '../../../../../features/quran/data/datasources/quran_local_tafsir_data_source.dart';
import '../../../../../features/quran/domain/usecases/get_ayah.dart';
import '../../../../wird/data/quran_boundaries.dart';
import 'tafsir_state.dart';

class TafsirOfflineDownloadSummary {
  final int totalAyahs;
  final int downloadedAyahs;
  final int failedAyahs;

  const TafsirOfflineDownloadSummary({
    required this.totalAyahs,
    required this.downloadedAyahs,
    required this.failedAyahs,
  });
}

class TafsirCubit extends Cubit<TafsirState> {
  final GetAyah _getAyah;
  final IbnKathirRemoteDataSource _ibnKathirDataSource;
  final QuranLocalTafsirDataSource _localTafsir;

  // Reference stored so we can re-fetch when edition changes.
  late int _surahNumber;
  late int _ayahNumber;
  int _requestToken = 0;

  TafsirCubit(this._getAyah, this._ibnKathirDataSource, this._localTafsir)
      : super(
          TafsirState.initial(ApiConstants.tafsirMuyassar),
        );

  /// Must be called once after the cubit is provided.
  Future<void> init({
    required int surahNumber,
    required int ayahNumber,
    String? initialEdition,
  }) async {
    _surahNumber = surahNumber;
    _ayahNumber = ayahNumber;
    await _fetch(initialEdition ?? ApiConstants.tafsirMuyassar);
  }

  /// Switch to a different tafsir edition and re-fetch.
  Future<void> selectEdition(String edition) async {
    if (edition == state.selectedEdition && state.status == TafsirStatus.loaded) {
      return; // already showing this edition
    }
    await _fetch(edition);
  }

  Future<void> retry() async => _fetch(state.selectedEdition);

  Future<void> _fetch(String edition) async {
    final token = ++_requestToken;

    if (isClosed) return;
    emit(state.copyWith(
      status: TafsirStatus.loading,
      selectedEdition: edition,
      tafsirText: '',
      errorMessage: '',
      isOfflineContent: false,
    ));

    // Cache-first: if this ayah was downloaded before, render instantly offline.
    try {
      final cached = await _localTafsir.getCachedAyahTafsir(
        edition: edition,
        surahNumber: _surahNumber,
        ayahNumber: _ayahNumber,
      );

      if (isClosed || token != _requestToken) return;
      emit(state.copyWith(
        status: TafsirStatus.loaded,
        tafsirText: cached,
        isOfflineContent: true,
      ));
      return;
    } on CacheException {
      // Cache miss -> fall back to remote.
    }

    try {
      final text = await _fetchFromRemote(
        edition: edition,
        surahNumber: _surahNumber,
        ayahNumber: _ayahNumber,
      );
      await _localTafsir.cacheAyahTafsir(
        edition: edition,
        surahNumber: _surahNumber,
        ayahNumber: _ayahNumber,
        text: text,
      );

      if (isClosed || token != _requestToken) return;
      emit(state.copyWith(
        status: TafsirStatus.loaded,
        tafsirText: text,
        isOfflineContent: false,
      ));
    } on ServerException {
      if (isClosed || token != _requestToken) return;
      emit(state.copyWith(
        status: TafsirStatus.error,
        errorMessage: di.sl<SettingsService>().getAppLanguage() == 'ar'
            ? 'تعذّر تحميل التفسير. يمكنك تنزيله مسبقًا للاستخدام بدون إنترنت.'
            : 'Failed to load Tafsir. You can download it for offline use.',
      ));
    } catch (e) {
      if (isClosed || token != _requestToken) return;
      emit(state.copyWith(
        status: TafsirStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<String> _fetchFromRemote({
    required String edition,
    required int surahNumber,
    required int ayahNumber,
  }) async {
    if (edition == ApiConstants.tafsirIbnKathir) {
      return _ibnKathirDataSource.getTafsir(surahNumber, ayahNumber);
    }

    final reference = '$surahNumber:$ayahNumber';
    final result = await _getAyah(
      GetAyahParams(reference: reference, edition: edition),
    );

    return result.fold(
      (failure) => throw ServerException(),
      (ayah) => ayah.text,
    );
  }

  Future<int> getCachedAyahCountForEdition(String edition) {
    return _localTafsir.getCachedAyahCountForEdition(edition);
  }

  Future<TafsirOfflineDownloadSummary> downloadSurahsForOffline({
    required String edition,
    required List<int> surahs,
  }) async {
    final normalizedSurahs = surahs.toSet().toList()..sort();
    final validSurahs = normalizedSurahs.where((s) => s >= 1 && s <= 114).toList();
    int totalAyahs = 0;
    for (final s in validSurahs) {
      totalAyahs += kSurahAyahCounts[s - 1];
    }

    if (totalAyahs == 0) {
      return const TafsirOfflineDownloadSummary(
        totalAyahs: 0,
        downloadedAyahs: 0,
        failedAyahs: 0,
      );
    }

    emit(state.copyWith(
      isDownloadingOffline: true,
      downloadDone: 0,
      downloadTotal: totalAyahs,
      downloadStatusText: 'جاري تجهيز التحميل...',
    ));

    int done = 0;
    int failed = 0;

    for (final surah in validSurahs) {
      final ayahCount = kSurahAyahCounts[surah - 1];
      for (int ayah = 1; ayah <= ayahCount; ayah++) {
        try {
          final text = await _fetchFromRemote(
            edition: edition,
            surahNumber: surah,
            ayahNumber: ayah,
          );
          await _localTafsir.cacheAyahTafsir(
            edition: edition,
            surahNumber: surah,
            ayahNumber: ayah,
            text: text,
          );
        } catch (_) {
          failed++;
        }

        done++;
        emit(state.copyWith(
          isDownloadingOffline: true,
          downloadDone: done,
          downloadTotal: totalAyahs,
          downloadStatusText: 'جاري تحميل تفسير $edition ($done/$totalAyahs)',
        ));
      }
    }

    emit(state.copyWith(
      isDownloadingOffline: false,
      downloadDone: done,
      downloadTotal: totalAyahs,
      downloadStatusText: failed == 0
          ? 'اكتمل التنزيل بنجاح'
          : 'اكتمل التنزيل مع $failed أخطاء',
    ));

    return TafsirOfflineDownloadSummary(
      totalAyahs: totalAyahs,
      downloadedAyahs: done - failed,
      failedAyahs: failed,
    );
  }

  Future<TafsirOfflineDownloadSummary> downloadJuzForOffline({
    required String edition,
    required List<int> juzList,
  }) async {
    final surahs = <int>{};
    for (final juz in juzList) {
      if (juz < 1 || juz > 30) continue;
      final start = kJuzStarts[juz - 1];
      final end = juz == 30 ? kQuranEnd : prevPosition(kJuzStarts[juz]);
      for (int s = start.surah; s <= end.surah; s++) {
        surahs.add(s);
      }
    }
    return downloadSurahsForOffline(edition: edition, surahs: surahs.toList());
  }

  Future<TafsirOfflineDownloadSummary> downloadFullQuranForOffline({
    required String edition,
  }) {
    final surahs = List<int>.generate(114, (index) => index + 1);
    return downloadSurahsForOffline(edition: edition, surahs: surahs);
  }
}
