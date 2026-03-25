/// Tutorial feature flags for development and production control.
///
/// ──────────────────────────────────────────────────────────────────────────
///  HOW TO USE
///  ----------
///  • During active development / testing: set both flags to `true` so every
///    screen shows its tutorial on every visit, regardless of SharedPreferences.
///  • Before a production release: set both flags to their release values as
///    noted in the TODO comments below.
/// ──────────────────────────────────────────────────────────────────────────
class TutorialConfig {
  TutorialConfig._();

  // TODO(release): Keep `kTutorialsEnabled = true` for production.
  //                Set to `false` ONLY if you want to ship with all tutorials
  //                completely disabled (e.g., during a hotfix rollout).
  /// Master switch — `false` silences all tutorial overlays app-wide.
  static const bool kTutorialsEnabled = false;

  // TODO(release): Set `kAlwaysShowTutorial = false` before production build.
  //                When `true` every screen shows its tutorial on every visit,
  //                bypassing the SharedPreferences "already completed" check.
  //                This is useful for rapid testing without manually resetting
  //                SharedPreferences each time.
  /// Force-show flag — when `true`, tutorials ignore the "already seen" state
  /// and show on every visit.  Safe to leave `true` locally; must be `false`
  /// in any release build.
  static const bool kAlwaysShowTutorial = false;
}
