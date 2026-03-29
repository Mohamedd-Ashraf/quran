import 'package:shared_preferences/shared_preferences.dart';

/// Manages when to show the user-feedback prompt.
///
/// Rules:
///  - If the user has never submitted feedback → show every 3 days.
///  - If the user has submitted at least once   → show every 10 days.
class FeedbackService {
  static const String _keyLastShownMs  = 'feedback_last_shown_ms';
  static const String _keyHasSubmitted = 'feedback_has_submitted';

  static const int _snoozeAfterSkipDays     = 3;
  static const int _snoozeAfterSubmitDays   = 10;

  /// ─── DEV FLAG ───────────────────────────────────────────────────────────
  /// Set to [true]  → dialog shows on EVERY app launch (for testing/design).
  /// Set to [false] → normal interval logic (production).
  /// ────────────────────────────────────────────────────────────────────────
  //TODO: Set alwaysShow = false before release.
  static const bool alwaysShow = false;

  final SharedPreferences _prefs;

  FeedbackService(this._prefs);

  bool get hasSubmitted => _prefs.getBool(_keyHasSubmitted) ?? false;

  /// Returns [true] when the feedback prompt should be displayed.
  bool shouldShow() {
    if (alwaysShow) return true;
    final lastShownMs = _prefs.getInt(_keyLastShownMs);

    // First time ever – treat as if user pressed "Later".
    // Records the current time so the dialog appears again after 3 days.
    if (lastShownMs == null) {
      _prefs.setInt(_keyLastShownMs, DateTime.now().millisecondsSinceEpoch);
      return false;
    }

    final daysSinceLastShown = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(lastShownMs))
        .inDays;

    final requiredDays =
        hasSubmitted ? _snoozeAfterSubmitDays : _snoozeAfterSkipDays;

    return daysSinceLastShown >= requiredDays;
  }

  /// Call when the dialog is shown (whether dismissed or opened).
  Future<void> markShown() async {
    if (alwaysShow) return;
    await _prefs.setInt(
      _keyLastShownMs,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Call when the user confirms they have actually submitted feedback.
  Future<void> markSubmitted() async {
    await _prefs.setBool(_keyHasSubmitted, true);
    await markShown();
  }
}
