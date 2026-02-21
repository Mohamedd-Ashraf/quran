import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../services/audio_download_notification_service.dart';
import '../services/audio_download_state_service.dart';
import '../services/audio_edition_service.dart';
import '../services/offline_audio_service.dart';
import 'download_manager_state.dart';

/// App-level cubit that manages offline audio downloads.
///
/// Lives inside [MultiBlocProvider] at the root [MaterialApp] level so it
/// persists across screen navigations.  The UI (OfflineAudioScreen) watches
/// this cubit instead of managing download state locally.
class DownloadManagerCubit extends Cubit<DownloadManagerState> {
  final OfflineAudioService _audioService;
  final AudioDownloadStateService _stateService;
  final AudioDownloadNotificationService _notifService;
  final AudioEditionService _editionService;

  bool _cancelRequested = false;

  /// Tracks when we last emitted a [DownloadInProgress] state, so we can
  /// throttle UI updates to at most one per ~200 ms.  Without throttling,
  /// dozens of emits fired in the same Dart event-loop cycle all arrive at
  /// [BlocBuilder] before the next vsync, causing Flutter to skip every
  /// intermediate frame and only render the last value.
  int _lastProgressEmitMs = 0;

  DownloadManagerCubit({
    required OfflineAudioService audioService,
    required AudioDownloadStateService stateService,
    required AudioDownloadNotificationService notifService,
    required AudioEditionService editionService,
  })  : _audioService = audioService,
        _stateService = stateService,
        _notifService = notifService,
        _editionService = editionService,
        super(const DownloadIdle());

  // ──────────────────────────────────────────────────────────────
  //  Init – called once on app start to restore interrupted session
  // ──────────────────────────────────────────────────────────────

  Future<void> checkForResumableSession() async {
    if (!_stateService.isActive) {
      emit(const DownloadIdle());
      return;
    }

    final pending = _stateService.pendingSurahs;
    final completed = _stateService.completedSurahs;

    if (pending.isEmpty) {
      // Session was marked active but nothing is left → clean up.
      await _stateService.clearSession();
      emit(const DownloadIdle());
      return;
    }

    emit(DownloadResumable(
      edition: _stateService.edition,
      pendingSurahs: pending,
      completedSurahs: completed,
      totalSurahs: _stateService.totalSurahs,
      mode: _stateService.mode,
      startedAt: _stateService.startedAt,
    ));

    // Show a system notification so user sees it even in notification tray.
    final editionDisplayName = await _resolveEditionName(_stateService.edition);
    await _notifService.showResumeAvailable(
      remainingSurahs: pending.length,
      reciterName: editionDisplayName,
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  Public actions
  // ──────────────────────────────────────────────────────────────

  /// Start downloading all 114 surahs.
  Future<void> downloadAll() async {
    final surahs = List.generate(114, (i) => i + 1);
    await _startDownload(surahs: surahs, mode: 'all');
  }

  /// Start downloading specific surahs.
  Future<void> downloadSelective(List<int> surahs) async {
    await _startDownload(surahs: surahs, mode: 'selective');
  }

  /// Resume a previously interrupted session.
  Future<void> resume() async {
    if (_stateService.isActive && _stateService.pendingSurahs.isNotEmpty) {
      await _startDownload(
        surahs: _stateService.pendingSurahs,
        mode: _stateService.mode,
        existingCompleted: _stateService.completedSurahs,
        existingTotal: _stateService.totalSurahs,
        isResume: true,
      );
    }
  }

  /// Request cancellation of the running download.
  void cancel() {
    _cancelRequested = true;
    emit(const DownloadCancelling());
  }

  /// Dismiss a resumable session without resuming.
  Future<void> dismissResumable() async {
    await _stateService.clearSession();
    await _notifService.cancel();
    emit(const DownloadIdle());
  }

  // ──────────────────────────────────────────────────────────────
  //  Core download orchestration
  // ──────────────────────────────────────────────────────────────

  Future<void> _startDownload({
    required List<int> surahs,
    required String mode,
    List<int>? existingCompleted,
    int? existingTotal,
    bool isResume = false,
  }) async {
    _cancelRequested = false;
    _lastProgressEmitMs = 0; // reset throttle for new session

    final edition = _audioService.edition;
    final totalSurahs = existingTotal ?? surahs.length;
    final completedSurahs = List<int>.from(existingCompleted ?? []);
    final pendingSurahs = List<int>.from(surahs);

    // Persist session so it survives app kill / phone restart.
    await _stateService.saveSession(
      edition: edition,
      pendingSurahs: pendingSurahs,
      completedSurahs: completedSurahs,
      totalSurahs: totalSurahs,
      mode: mode,
    );

    try {
      await _audioService.downloadSurahsWithCallbacks(
        surahNumbers: surahs,
        onProgress: (p) {
          if (isClosed) return;

          // Throttle UI updates: emit at most once per 200 ms so Flutter can
          // render each frame.  Always emit the very first call (elapsed will
          // be large) and the very last call (completedFiles == totalFiles).
          final nowMs = DateTime.now().millisecondsSinceEpoch;
          final elapsed = nowMs - _lastProgressEmitMs;
          final isLast = p.totalFiles > 0 && p.completedFiles >= p.totalFiles;
          if (elapsed < 200 && !isLast) return;
          _lastProgressEmitMs = nowMs;

          emit(DownloadInProgress(
            progress: p,
            completedSurahs: List.unmodifiable(completedSurahs),
            pendingSurahs: List.unmodifiable(pendingSurahs),
            totalSurahs: totalSurahs,
            edition: edition,
          ));

          // Throttle notification updates (every ~2%).
          if (p.completedFiles % 120 == 0 || isLast) {
            _notifService.showProgress(
              completed: p.completedFiles,
              total: p.totalFiles,
              reciterName: edition,
            );
          }
        },
        onSurahCompleted: (surahNumber) async {
          completedSurahs.add(surahNumber);
          pendingSurahs.remove(surahNumber);
          await _stateService.onSurahCompleted(surahNumber);
          // Reset throttle so the next surah's first progress fires immediately.
          _lastProgressEmitMs = 0;
        },
        shouldCancel: () => _cancelRequested,
      );

      if (_cancelRequested) {
        // Keep session so user can resume later.
        final editionName = await _resolveEditionName(edition);
        await _notifService.showResumeAvailable(
          remainingSurahs: pendingSurahs.length,
          reciterName: editionName,
        );
        if (!isClosed) {
          emit(DownloadResumable(
            edition: edition,
            pendingSurahs: List.unmodifiable(pendingSurahs),
            completedSurahs: List.unmodifiable(completedSurahs),
            totalSurahs: totalSurahs,
            mode: mode,
          ));
        }
      } else {
        // Full success.
        await _stateService.clearSession();
        final stats = await _audioService.getDownloadStatistics();
        final totalFiles =
            (stats['downloadedFiles'] as num?)?.toInt() ?? 0;
        final editionName = await _resolveEditionName(edition);
        await _notifService.showCompleted(
          reciterName: editionName,
          totalFiles: totalFiles,
        );
        if (!isClosed) {
          emit(DownloadCompleted(totalFiles: totalFiles, edition: edition));
        }
      }
    } catch (e) {
      // Keep session so user can resume after error.
      final isNetworkErr = e is DownloadNetworkException;
      if (!isClosed) {
        emit(DownloadFailed(
          message: e.toString(),
          completedSurahs: List.unmodifiable(completedSurahs),
          pendingSurahs: List.unmodifiable(pendingSurahs),
          isNetworkError: isNetworkErr,
        ));
      }
      await _notifService.cancel();
    }
  }

  // ──────────────────────────────────────────────────────────────
  //  Helpers
  // ──────────────────────────────────────────────────────────────

  Future<String> _resolveEditionName(String identifier) async {
    try {
      final editions = await _editionService.getVerseByVerseAudioEditions();
      final match = editions
          .where((e) => e.identifier == identifier)
          .cast<AudioEdition?>()
          .firstOrNull;
      return match?.englishName ?? identifier;
    } catch (_) {
      return identifier;
    }
  }
}
