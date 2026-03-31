import 'package:flutter/foundation.dart';

/// Global singleton that tracks the in-progress app update download so that
/// any widget in the tree can show a persistent progress indicator.
///
/// Flow:
///   1. User taps "تحديث الآن" in the update dialog.
///   2. Dialog calls [AppUpdateManager.instance.startDownload(...)].
///   3. Dialog can be dismissed — download continues in background.
///   4. [MainNavigator] (or any widget) listens via [addListener] and shows
///      a banner at the bottom with live progress.
///   5. When download + install finishes, [isComplete] = true.
class AppUpdateManager extends ChangeNotifier {
  AppUpdateManager._();

  static final AppUpdateManager instance = AppUpdateManager._();

  // ── State ───────────────────────────────────────────────────────────────────

  bool _isDownloading = false;
  bool _isComplete = false;
  bool _hasError = false;
  double _progress = 0.0;
  String _latestVersion = '';
  bool _has90PercentNotified = false;
  bool _needsInstallPermission = false;

  // ── Getters ─────────────────────────────────────────────────────────────────

  bool get isDownloading => _isDownloading;
  bool get isComplete => _isComplete;
  bool get hasError => _hasError;
  double get progress => _progress;
  String get latestVersion => _latestVersion;
  bool get has90PercentNotified => _has90PercentNotified;
  bool get needsInstallPermission => _needsInstallPermission;

  /// True while a download is active (show persistent banner).
  bool get isActive => _isDownloading || _hasError;

  // ── Public API ───────────────────────────────────────────────────────────────

  /// Start tracking a new download. Called by the update dialog when the user
  /// taps "تحديث الآن".
  void startDownload(String version, {bool needsInstallPermission = false}) {
    _isDownloading = true;
    _isComplete = false;
    _hasError = false;
    _progress = 0.0;
    _latestVersion = version;
    _has90PercentNotified = false;
    _needsInstallPermission = needsInstallPermission;
    notifyListeners();
  }

  /// Update download progress (0.0 → 1.0). Called from the download callback.
  /// Returns true when progress crosses 90% for the first time.
  bool updateProgress(double progress) {
    final crossed90 = _progress < 0.90 && progress >= 0.90 && !_has90PercentNotified;
    _progress = progress;
    if (crossed90) _has90PercentNotified = true;
    notifyListeners();
    return crossed90;
  }

  /// Mark download as complete (triggers install prompt).
  void markComplete() {
    _isDownloading = false;
    _isComplete = true;
    _progress = 1.0;
    notifyListeners();
  }

  /// Mark as failed.
  void markError() {
    _isDownloading = false;
    _hasError = true;
    notifyListeners();
  }

  /// Reset state (e.g. after install dialog is dismissed).
  void reset() {
    _isDownloading = false;
    _isComplete = false;
    _hasError = false;
    _progress = 0.0;
    _has90PercentNotified = false;
    _needsInstallPermission = false;
    notifyListeners();
  }
}
