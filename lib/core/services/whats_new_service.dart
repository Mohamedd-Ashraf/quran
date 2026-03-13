import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WhatsNewService {
  static const String _keyLastSeenVersion = 'last_seen_whats_new_version';
  static const Map<String, String> _changelogVersionAliases = {
    '1.1.0': '1.0.10',
  };

  /// ─── DEV FLAG ───────────────────────────────────────────────────────────
  /// Set to [true]  → screen shows on EVERY app launch (for design review).
  /// Set to [false] → screen shows only once per app version (production).
  /// ────────────────────────────────────────────────────────────────────────
  /// 
  //TODO : Remove this flag and related logic before release, to ensure users see the screen only on new versions.
  static const bool alwaysShow = false;


  final SharedPreferences _prefs;

  WhatsNewService(this._prefs);

  static String normalizeVersionForChangelog(String version) {
    return _changelogVersionAliases[version] ?? version;
  }

  /// Returns true if the What's New screen should be shown.
  Future<bool> shouldShow() async {
    if (alwaysShow) return true;
    final info = await PackageInfo.fromPlatform();
    final currentVersion = info.version;
    final lastSeen = _prefs.getString(_keyLastSeenVersion);
    return normalizeVersionForChangelog(lastSeen ?? '') !=
        normalizeVersionForChangelog(currentVersion);
  }

  /// Returns the current app version string.
  Future<String> currentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  /// Returns the last version the user has seen the What's New screen for,
  /// or null if the user has never seen it (new install).
  Future<String?> lastSeenVersion() async {
    return _prefs.getString(_keyLastSeenVersion);
  }

  /// Mark the current version as seen so the screen won't show again
  /// until the next app update. No-op when [alwaysShow] is true.
  Future<void> markAsSeen() async {
    if (alwaysShow) return;
    final info = await PackageInfo.fromPlatform();
    await _prefs.setString(_keyLastSeenVersion, info.version);
  }
}
