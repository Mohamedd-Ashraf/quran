import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_update_info.dart';

/// Service for checking app updates
class AppUpdateService {
  final http.Client _client;
  final SharedPreferences _prefs;

  // You can host this JSON file on your server, GitHub, or Firebase
  // Example: https://your-domain.com/app-config/update-info.json
  static const String _updateCheckUrl = 
      'https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/update-config.json';

  // Preference keys
  static const String _keyLastCheckTime = 'last_update_check_time';
  static const String _keySkippedVersion = 'skipped_update_version';

  AppUpdateService(this._client, this._prefs);

  /// Check for app updates
  /// 
  /// Returns null if:
  /// - No internet connection
  /// - Update check failed
  /// - No update available
  /// - User has already skipped this version (and it's optional)
  Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // Fetch update info from server
      final response = await _client.get(
        Uri.parse(_updateCheckUrl),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return null;
      }

      final jsonData = json.decode(response.body) as Map<String, dynamic>;
      final updateInfo = AppUpdateInfo.fromJson(jsonData, currentVersion);

      // Update last check time
      await _saveLastCheckTime();

      // If no update available, return null
      if (!updateInfo.hasUpdate) {
        return null;
      }

      // If update is optional and user skipped this version, return null
      if (!updateInfo.isMandatory && !updateInfo.isBelowMinimum) {
        final skippedVersion = _prefs.getString(_keySkippedVersion);
        if (skippedVersion == updateInfo.latestVersion) {
          return null;
        }
      }

      // If current version is below minimum, it's mandatory
      if (updateInfo.isBelowMinimum) {
        return AppUpdateInfo(
          latestVersion: updateInfo.latestVersion,
          currentVersion: updateInfo.currentVersion,
          minimumVersion: updateInfo.minimumVersion,
          isMandatory: true, // Force mandatory
          downloadUrl: updateInfo.downloadUrl,
          changelogByLanguage: updateInfo.changelogByLanguage,
          releaseDate: updateInfo.releaseDate,
        );
      }

      return updateInfo;
    } catch (e) {
      // Log error if needed
      return null;
    }
  }

  /// Check if enough time has passed since last check (to avoid frequent checks)
  /// Default: check once per day
  Future<bool> shouldCheckForUpdate({Duration minInterval = const Duration(hours: 24)}) async {
    final lastCheck = _prefs.getInt(_keyLastCheckTime);
    if (lastCheck == null) return true;

    final lastCheckTime = DateTime.fromMillisecondsSinceEpoch(lastCheck);
    final now = DateTime.now();

    return now.difference(lastCheckTime) >= minInterval;
  }

  /// Save the time of last update check
  Future<void> _saveLastCheckTime() async {
    await _prefs.setInt(
      _keyLastCheckTime,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Mark a version as skipped (user chose "Later" for optional update)
  Future<void> skipVersion(String version) async {
    await _prefs.setString(_keySkippedVersion, version);
  }

  /// Clear skipped version (e.g., when user manually checks for updates)
  Future<void> clearSkippedVersion() async {
    await _prefs.remove(_keySkippedVersion);
  }

  /// Force check for updates (ignores time interval and skipped versions)
  Future<AppUpdateInfo?> forceCheckForUpdate() async {
    await clearSkippedVersion();
    return checkForUpdate();
  }
}
