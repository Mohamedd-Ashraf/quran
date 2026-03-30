import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:qcf_quran_plus/qcf_quran_plus.dart' show QcfFontLoader;

import 'qcf_font_download_service.dart';

/// Global singleton that runs the QCF font download in the background and
/// notifies listeners of progress so any widget can react without blocking
/// the user.
///
/// Usage:
///   FontDownloadManager.instance.addListener(myCallback);
///   await FontDownloadManager.instance.startIfNeeded();
class FontDownloadManager extends ChangeNotifier {
  FontDownloadManager._();

  /// The single shared instance.
  static final FontDownloadManager instance = FontDownloadManager._();

  // ── State ───────────────────────────────────────────────────────────────────

  bool _isDownloading = false;
  bool _isComplete = false;
  double _progress = 0.0;
  int _pagesDownloaded = 0;
  int _totalPending = 0;
  String _phase = '';
  bool _hasError = false;
  CancelToken? _cancelToken;

  // ── Getters ─────────────────────────────────────────────────────────────────

  bool get isDownloading => _isDownloading;
  bool get isComplete => _isComplete;
  double get progress => _progress;
  int get pagesDownloaded => _pagesDownloaded;
  int get totalPending => _totalPending;
  String get phase => _phase;
  bool get hasError => _hasError;

  /// True while fonts are being downloaded or after an error (download not done).
  bool get isActive => _isDownloading || _hasError;

  // ── Public API ───────────────────────────────────────────────────────────────

  /// Starts the background download if fonts are not fully downloaded.
  /// Safe to call multiple times — no-op if already running or complete.
  Future<void> startIfNeeded() async {
    if (_isDownloading || _isComplete) return;

    final complete = await QcfFontDownloadService.isFullyDownloaded();
    if (complete) {
      _isComplete = true;
      _progress = 1.0;
      notifyListeners();
      return;
    }

    final pending = await QcfFontDownloadService.pendingDownloadCount();
    if (pending == 0) {
      _isComplete = true;
      _progress = 1.0;
      notifyListeners();
      return;
    }

    _totalPending = pending;
    _run();
  }

  /// Retry after a download error.
  void retry() {
    if (_isDownloading) return;
    _hasError = false;
    _run();
  }

  /// Cancel the current download (can be resumed later via [startIfNeeded]).
  void cancel() {
    _cancelToken?.cancel('user_cancelled');
    _isDownloading = false;
    notifyListeners();
  }

  // ── Internal ─────────────────────────────────────────────────────────────────

  void _run() {
    if (_isDownloading) return;
    _isDownloading = true;
    _hasError = false;
    _cancelToken = CancelToken();
    notifyListeners();

    QcfFontDownloadService.downloadAll(
      skipExisting: true,
      onProgress: (p) {
        _progress = p;
        notifyListeners();
      },
      onPhase: (ph) {
        _phase = ph;
        notifyListeners();
      },
      onPageDone: (page) {
        _pagesDownloaded++;
        notifyListeners();
        // Immediately load the font into the Flutter engine so QuranPageView
        // can switch from the fallback renderer to QCF without a restart.
        unawaited(
          QcfFontLoader.ensureFontLoaded(page).then((_) {
            notifyListeners(); // trigger rebuild in MushafPageView listeners
          }).catchError((_) {}),
        );
      },
      cancelToken: _cancelToken,
    ).then((ok) {
      _isDownloading = false;
      if (ok) {
        _isComplete = true;
        _progress = 1.0;
        _phase = '';
      } else {
        _hasError = true;
      }
      notifyListeners();
    });
  }
}
