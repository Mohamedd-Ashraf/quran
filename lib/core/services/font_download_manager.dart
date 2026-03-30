import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:qcf_quran_plus/qcf_quran_plus.dart' show QcfFontLoader;
import 'package:shared_preferences/shared_preferences.dart';

import 'qcf_font_download_service.dart';

/// Global singleton that manages QCF font downloads in the background.
///
/// Behaviour:
///   • On Wi-Fi  → auto-starts download immediately when [startIfNeeded] is called.
///   • On mobile data → sets [awaitingMobileDataConsent] = true and waits for
///     the user to explicitly call [allowMobileDataDownload].
///   • Supports resume: if the user closes the app mid-download the archive
///     stays on disk and the next [startIfNeeded] continues from where it stopped.
///
/// Listen for state changes via [addListener] / [removeListener].
class FontDownloadManager extends ChangeNotifier {
  FontDownloadManager._();

  static final FontDownloadManager instance = FontDownloadManager._();

  // ── SharedPreferences key ────────────────────────────────────────────────
  static const String _prefMobileConsent = 'font_dl_mobile_consent';

  // ── State ───────────────────────────────────────────────────────────────────

  bool _isDownloading = false;
  bool _isComplete = false;
  double _progress = 0.0;
  int _pagesDownloaded = 0;
  int _totalPending = 0;
  String _phase = '';
  bool _hasError = false;
  CancelToken? _cancelToken;

  /// True when we're on mobile data and waiting for the user to confirm.
  bool _awaitingMobileDataConsent = false;

  // ── Getters ─────────────────────────────────────────────────────────────────

  bool get isDownloading => _isDownloading;
  bool get isComplete => _isComplete;
  double get progress => _progress;
  int get pagesDownloaded => _pagesDownloaded;
  int get totalPending => _totalPending;
  String get phase => _phase;
  bool get hasError => _hasError;
  bool get awaitingMobileDataConsent => _awaitingMobileDataConsent;

  /// True while fonts are downloading or after an error (fonts not done).
  bool get isActive => _isDownloading || _hasError || _awaitingMobileDataConsent;

  // ── Public API ───────────────────────────────────────────────────────────────

  /// Checks font status and starts download if appropriate.
  ///
  /// On Wi-Fi:  starts immediately.
  /// On mobile data: sets [awaitingMobileDataConsent] — the UI should ask first.
  /// No-op if already downloading, complete, or awaiting consent.
  Future<void> startIfNeeded() async {
    if (_isDownloading || _isComplete || _awaitingMobileDataConsent) return;

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

    final connectivity = await Connectivity().checkConnectivity();
    final isMobile = _isMobileData(connectivity);

    if (isMobile) {
      // Check if user already consented in a previous session.
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_prefMobileConsent) == true) {
        _run();
      } else {
        _awaitingMobileDataConsent = true;
        notifyListeners();
      }
    } else {
      _run();
    }
  }

  /// Called when the user accepts downloading over mobile data.
  /// [remember] — if true, consent is persisted so we never ask again.
  Future<void> allowMobileDataDownload({bool remember = false}) async {
    if (remember) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefMobileConsent, true);
    }
    _awaitingMobileDataConsent = false;
    notifyListeners();
    _run();
  }

  /// Called when the user declines to download over mobile data for now.
  void denyMobileDataDownload() {
    _awaitingMobileDataConsent = false;
    notifyListeners();
  }

  /// Retry after a download error.
  void retry() {
    if (_isDownloading) return;
    _hasError = false;
    _run();
  }

  /// Cancel the current download. Partial archive is kept for next resume.
  void cancel() {
    _cancelToken?.cancel('user_cancelled');
    _isDownloading = false;
    notifyListeners();
  }

  // ── Internal ─────────────────────────────────────────────────────────────────

  static bool _isMobileData(List<ConnectivityResult> results) {
    return results.contains(ConnectivityResult.mobile) &&
        !results.contains(ConnectivityResult.wifi) &&
        !results.contains(ConnectivityResult.ethernet);
  }

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
        // Immediately register the font in the Flutter engine so QuranPageView
        // switches from the fallback renderer to QCF without a restart.
        unawaited(
          QcfFontLoader.ensureFontLoaded(page).then((_) {
            notifyListeners();
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
