import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/constants/api_constants.dart';
import '../../../../../core/error/exceptions.dart';
import '../../../../../core/services/tafsir_download_state_service.dart';
import '../../../../../features/quran/data/datasources/ibn_kathir_remote_data_source.dart';
import '../../../../../features/quran/data/datasources/quran_local_tafsir_data_source.dart';
import '../../../../../features/quran/domain/usecases/get_ayah.dart';
import '../../../../../features/quran/domain/usecases/get_surah.dart';
import '../../../../wird/data/quran_boundaries.dart';
import 'tafsir_download_state.dart';

class _FetchedAyah {
  final String ref;
  final int surah;
  final int ayah;
  final String text;

  const _FetchedAyah({
    required this.ref,
    required this.surah,
    required this.ayah,
    required this.text,
  });
}

class TafsirDownloadCubit extends Cubit<TafsirDownloadState> {
  final GetSurah _getSurah;
  final IbnKathirRemoteDataSource _ibnKathirDataSource;
  final QuranLocalTafsirDataSource _localTafsir;
  final TafsirDownloadStateService _stateService;

  bool _cancelRequested = false;
  int _dirtySinceLastPersist = 0;

  TafsirDownloadCubit(
    this._getSurah,
    this._ibnKathirDataSource,
    this._localTafsir,
    this._stateService,
  ) : super(const TafsirDownloadIdle());

  Future<void> clearSessionForEdition(String edition) async {
    if (!_stateService.isActive || _stateService.edition != edition) return;
    await _stateService.clearSession();

    if (!isClosed) {
      if (state is TafsirDownloadResumable &&
          (state as TafsirDownloadResumable).edition == edition) {
        emit(const TafsirDownloadIdle());
      } else if (state is TafsirDownloadFailed &&
          (state as TafsirDownloadFailed).edition == edition) {
        emit(const TafsirDownloadIdle());
      }
    }
  }

  Future<void> checkForResumableSession() async {
    if (!_stateService.isActive) {
      emit(const TafsirDownloadIdle());
      return;
    }

    final pending = _stateService.pendingAyahs;
    if (pending.isEmpty) {
      await _stateService.clearSession();
      emit(const TafsirDownloadIdle());
      return;
    }

    emit(
      TafsirDownloadResumable(
        edition: _stateService.edition,
        scope: _stateService.scope,
        pendingAyahs: pending,
        completedAyahs: _stateService.completedAyahs,
        totalAyahs: _stateService.totalAyahs,
      ),
    );
  }

  Future<void> startAllEditionsFull() async {
    int totalSavedAll = 0;
    for (final e in ApiConstants.tafsirEditions) {
      if (_cancelRequested) break;
      final editionId = e['id']!;

      // Before starting the download, let's verify if all 6236 are fully cached and skipped
      final stats = await _localTafsir.getEditionStats(editionId);
      if (stats.ayahCount >= 6236) {
        totalSavedAll += 6236;
        continue; // Fully downloaded, seamlessly jump to the next
      }

      await startFull(editionId, isPartOfAll: true);
      totalSavedAll += 6236;
    }

    // Once all are checked/downloaded properly, emit the real completed state
    if (!_cancelRequested && !isClosed) {
      emit(TafsirDownloadCompleted(edition: 'all', totalAyahs: totalSavedAll));
    }
  }

  Future<void> startFull(String edition, {bool isPartOfAll = false}) async {
    final refs = <String>[];
    for (int surah = 1; surah <= 114; surah++) {
      final ayahCount = kSurahAyahCounts[surah - 1];
      for (int ayah = 1; ayah <= ayahCount; ayah++) {
        refs.add('$surah:$ayah');
      }
    }
    await _startDownload(
      edition: edition,
      refs: refs,
      scope: 'full',
      isPartOfAll: isPartOfAll,
    );
  }

  Future<void> startSurahs(String edition, List<int> surahs) async {
    final refs = <String>[];
    final valid = surahs.toSet().where((s) => s >= 1 && s <= 114).toList()
      ..sort();
    for (final surah in valid) {
      final ayahCount = kSurahAyahCounts[surah - 1];
      for (int ayah = 1; ayah <= ayahCount; ayah++) {
        refs.add('$surah:$ayah');
      }
    }
    await _startDownload(edition: edition, refs: refs, scope: 'surahs');
  }

  Future<void> startJuz(String edition, List<int> juzList) async {
    final refs = <String>[];
    final validJuz = juzList.toSet().where((j) => j >= 1 && j <= 30).toList()
      ..sort();

    for (final juz in validJuz) {
      final start = kJuzStarts[juz - 1];
      final end = juz == 30 ? kQuranEnd : prevPosition(kJuzStarts[juz]);

      for (int surah = start.surah; surah <= end.surah; surah++) {
        final firstAyah = surah == start.surah ? start.ayah : 1;
        final lastAyah = surah == end.surah
            ? end.ayah
            : kSurahAyahCounts[surah - 1];
        for (int ayah = firstAyah; ayah <= lastAyah; ayah++) {
          refs.add('$surah:$ayah');
        }
      }
    }

    await _startDownload(edition: edition, refs: refs, scope: 'juz');
  }

  Future<void> resume() async {
    if (!_stateService.isActive) return;
    final pending = _stateService.pendingAyahs;
    if (pending.isEmpty) return;

    await _startDownload(
      edition: _stateService.edition,
      refs: pending,
      scope: _stateService.scope,
      existingCompleted: _stateService.completedAyahs,
      existingTotal: _stateService.totalAyahs,
      isResume: true,
    );
  }

  void cancel() {
    _cancelRequested = true;
    emit(const TafsirDownloadCancelling());
  }

  Future<void> dismissResumable() async {
    await _stateService.clearSession();
    emit(const TafsirDownloadIdle());
  }

  Future<void> _startDownload({
    required String edition,
    required List<String> refs,
    required String scope,
    List<String>? existingCompleted,
    int? existingTotal,
    bool isResume = false,
    bool isPartOfAll = false,
  }) async {
    final deduped = refs.toSet().toList();
    if (deduped.isEmpty) {
      emit(const TafsirDownloadIdle());
      return;
    }

    _cancelRequested = false;
    _dirtySinceLastPersist = 0;

    final completed = List<String>.from(existingCompleted ?? const <String>[]);
    final pending = List<String>.from(deduped);
    final total = existingTotal ?? deduped.length;

    // Verify already-cached ayahs and skip re-downloading them.
    final verifiedCached = await _findVerifiedCachedRefs(
      edition: edition,
      refs: pending,
    );
    if (verifiedCached.isNotEmpty) {
      pending.removeWhere(verifiedCached.contains);
      for (final ref in verifiedCached) {
        if (!completed.contains(ref)) {
          completed.add(ref);
        }
      }
      debugPrint(
        '[TafsirDL] verified cached ayahs=${verifiedCached.length} '
        'startCompleted=${completed.length} startPending=${pending.length}',
      );
    }

    if (!isClosed && completed.isNotEmpty) {
      emit(
        TafsirDownloadInProgress(
          edition: edition,
          scope: scope,
          completed: completed.length,
          total: total,
          currentAyahRef: completed.last,
        ),
      );
    }

    await _stateService.saveSession(
      edition: edition,
      pendingAyahs: pending,
      completedAyahs: completed,
      totalAyahs: total,
      scope: scope,
    );

    if (!isClosed) {
      emit(
        TafsirDownloadInProgress(
          edition: edition,
          scope: scope,
          completed: completed.length,
          total: total,
          currentAyahRef: completed.isNotEmpty
              ? completed.last
              : (pending.isNotEmpty ? pending.first : ''),
        ),
      );
    }

    if (pending.isEmpty) {
      await _stateService.clearSession();
      if (!isClosed) {
        emit(TafsirDownloadCompleted(edition: edition, totalAyahs: total));
      }
      return;
    }

    try {
      await _downloadBySurahBatches(
        edition: edition,
        scope: scope,
        total: total,
        pending: pending,
        completed: completed,
      );
      return;
    } catch (e) {
      await _stateService.saveProgressSnapshot(
        pendingAyahs: pending,
        completedAyahs: completed,
      );
      if (!isClosed) {
        emit(
          TafsirDownloadFailed(
            message: _friendlyErrorMessage(e),
            edition: edition,
            pendingAyahs: List.unmodifiable(pending),
            completedAyahs: List.unmodifiable(completed),
          ),
        );
      }
    }
  }

  Future<void> _downloadBySurahBatches({
    required String edition,
    required String scope,
    required int total,
    required List<String> pending,
    required List<String> completed,
  }) async {
    final bySurah = <int, Set<int>>{};
    for (final ref in pending) {
      final parts = ref.split(':');
      if (parts.length != 2) continue;
      final surah = int.tryParse(parts[0]);
      final ayah = int.tryParse(parts[1]);
      if (surah == null || ayah == null) continue;
      bySurah.putIfAbsent(surah, () => <int>{}).add(ayah);
    }

    final surahQueue = bySurah.keys.toList()..sort();
    final startedAt = DateTime.now();
    int roundsCount = 0;

    final parallelSurahRequests = edition == ApiConstants.tafsirIbnKathir
        ? 2
        : 10; // Increased to 10 for faster alquran.cloud downloads
    final maxSurahAttempts = 5;

    debugPrint(
      '[TafsirDL] start-surah edition=$edition scope=$scope total=$total '
      'pendingAyahs=${pending.length} pendingSurahs=${surahQueue.length} '
      'parallelSurahs=$parallelSurahRequests',
    );

    Future<List<_FetchedAyah>> processSurah(int surah) async {
      final needed = bySurah[surah];
      if (needed == null || needed.isEmpty) return const [];

      for (int attempt = 1; attempt <= maxSurahAttempts; attempt++) {
        try {
          if (edition == ApiConstants.tafsirIbnKathir) {
            final tafsirMap = await _ibnKathirDataSource.getTafsirForSurah(
              surah,
            );
            final map = <int, String>{};
            final fetched = <_FetchedAyah>[];

            for (final ayahNumber in needed) {
              String txt = (tafsirMap[ayahNumber] ?? '').trim();
              if (txt.isEmpty) {
                txt = 'تفسير هذه الآية غير متوفر في المصدر المتاح حالياً.';
              }
              map[ayahNumber] = txt;
              fetched.add(
                _FetchedAyah(
                  ref: '$surah:$ayahNumber',
                  surah: surah,
                  ayah: ayahNumber,
                  text: txt,
                ),
              );
            }
            if (map.isNotEmpty) {
              await _localTafsir.cacheAyahBatchForSurah(
                edition: edition,
                surahNumber: surah,
                ayahTexts: map,
              );
            }
            return fetched;
          }

          final result = await _getSurah(
            GetSurahParams(surahNumber: surah, edition: edition),
          );
          if (result.isLeft()) {
            return const <_FetchedAyah>[];
          }

          final surahEntity = result.getOrElse(() => throw ServerException());

          final map = <int, String>{};
          final fetched = <_FetchedAyah>[];
          for (final a in surahEntity.ayahs ?? const []) {
            if (!needed.contains(a.numberInSurah)) continue;
            final txt = a.text.trim();
            if (txt.isEmpty) continue;
            map[a.numberInSurah] = txt;
            fetched.add(
              _FetchedAyah(
                ref: '$surah:${a.numberInSurah}',
                surah: surah,
                ayah: a.numberInSurah,
                text: txt,
              ),
            );
          }

          if (map.isNotEmpty) {
            // Write surah content once instead of per-ayah writes.
            await _localTafsir.cacheAyahBatchForSurah(
              edition: edition,
              surahNumber: surah,
              ayahTexts: map,
            );
          }

          return fetched;
        } catch (_) {
          if (attempt < maxSurahAttempts) {
            await Future.delayed(Duration(milliseconds: 1000 * attempt));
          }
        }
      }

      return const [];
    }

    while (!_cancelRequested && surahQueue.isNotEmpty) {
      roundsCount++;

      final current = <int>[];
      for (int i = 0; i < parallelSurahRequests && surahQueue.isNotEmpty; i++) {
        current.add(surahQueue.removeAt(0));
      }

      final results = await Future.wait(current.map(processSurah));

      int fetchedThisRound = 0;
      for (final fetched in results) {
        for (final item in fetched) {
          completed.add(item.ref);
          pending.remove(item.ref);
          bySurah[item.surah]?.remove(item.ayah);
          _dirtySinceLastPersist++;
          fetchedThisRound++;
        }
      }

      // Requeue surahs that still have missing ayahs.
      for (final s in current) {
        final remain = bySurah[s];
        if (remain != null && remain.isNotEmpty) {
          surahQueue.add(s);
        }
      }

      if (!isClosed && fetchedThisRound > 0) {
        emit(
          TafsirDownloadInProgress(
            edition: edition,
            scope: scope,
            completed: completed.length,
            total: total,
            currentAyahRef: completed.last,
          ),
        );
      }

      if (_dirtySinceLastPersist > 0) {
        await _stateService.saveProgressSnapshot(
          pendingAyahs: pending,
          completedAyahs: completed,
        );
        _dirtySinceLastPersist = 0;
      }

      final elapsedSec =
          DateTime.now().difference(startedAt).inMilliseconds / 1000.0;
      final rate = elapsedSec <= 0 ? 0.0 : completed.length / elapsedSec;
      final remaining = total - completed.length;
      final etaSec = rate > 0 ? (remaining / rate) : double.infinity;
      final etaText = etaSec.isFinite
          ? '${(etaSec / 60).toStringAsFixed(1)}m'
          : '∞';
      debugPrint(
        '[TafsirDL] round-surah=$roundsCount done=${completed.length}/$total '
        'fetched=$fetchedThisRound pendingAyahs=${pending.length} '
        'pendingSurahs=${surahQueue.length} '
        'rate=${rate.toStringAsFixed(2)} ayah/s eta=$etaText',
      );

      // Avoid infinite cycles in hostile API conditions.
      if (fetchedThisRound == 0 && roundsCount >= 10) {
        break;
      }
    }

    if (_cancelRequested || pending.isNotEmpty) {
      await _stateService.saveProgressSnapshot(
        pendingAyahs: pending,
        completedAyahs: completed,
      );
      if (!isClosed) {
        emit(
          TafsirDownloadResumable(
            edition: edition,
            scope: scope,
            pendingAyahs: List.unmodifiable(pending),
            completedAyahs: List.unmodifiable(completed),
            totalAyahs: total,
          ),
        );
      }
      return;
    }

    await _stateService.clearSession();
    if (!isClosed) {
      emit(TafsirDownloadCompleted(edition: edition, totalAyahs: total));
    }
  }

  Future<List<String>> _findVerifiedCachedRefs({
    required String edition,
    required List<String> refs,
  }) async {
    final verified = <String>[];
    final refsBySurah = <int, List<int>>{};

    for (final ref in refs) {
      final parts = ref.split(':');
      if (parts.length != 2) continue;
      final surah = int.tryParse(parts[0]);
      final ayah = int.tryParse(parts[1]);
      if (surah == null || ayah == null) continue;
      refsBySurah.putIfAbsent(surah, () => <int>[]).add(ayah);
    }

    for (final entry in refsBySurah.entries) {
      final surah = entry.key;
      final ayahs = entry.value;

      try {
        final cachedAyahs = await _localTafsir.getCachedAyahNumbersForSurah(
          edition: edition,
          surahNumber: surah,
        );
        for (final ayah in ayahs) {
          if (cachedAyahs.contains(ayah)) {
            verified.add('$surah:$ayah');
          }
        }
      } catch (_) {
        // Missing/corrupted surah cache -> skip verification for that surah.
      }
    }

    return verified;
  }

  String _friendlyErrorMessage(Object error) {
    if (error is ServerException) {
      return 'تعذر الوصول لخادم التفسير مؤقتا. تم حفظ التقدم ويمكنك الاستكمال.';
    }
    final msg = error.toString();
    if (msg.contains('SocketException') || msg.contains('TimeoutException')) {
      return 'مشكلة اتصال بالشبكة. تم حفظ التقدم ويمكنك الاستكمال لاحقا.';
    }
    return 'حدث خطأ غير متوقع أثناء التحميل. تم حفظ التقدم ويمكنك الاستكمال.';
  }
}
