import 'dart:io' if (dart.library.html) 'stubs/mobile_platform_stub.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_update_info.dart';

/// Service for checking app updates
class AppUpdateService {
  final http.Client _client;
  final SharedPreferences _prefs;

  static const String _androidPackageId = 'com.nooraliman.quran';
  static const String _androidPlayStoreWebUrl =
      'https://play.google.com/store/apps/details?id=$_androidPackageId';

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
      final safeDownloadUrl = _sanitizeDownloadUrl(updateInfo.downloadUrl);

      final safeUpdateInfo = AppUpdateInfo(
        latestVersion: updateInfo.latestVersion,
        currentVersion: updateInfo.currentVersion,
        minimumVersion: updateInfo.minimumVersion,
        isMandatory: updateInfo.isMandatory,
        downloadUrl: safeDownloadUrl,
        changelogByLanguage: updateInfo.changelogByLanguage,
        releaseDate: updateInfo.releaseDate,
      );

      // Update last check time
      await _saveLastCheckTime();

      // If no update available, return null
      if (!safeUpdateInfo.hasUpdate) {
        return null;
      }

      // If update is optional and user skipped this version, return null
      if (!safeUpdateInfo.isMandatory && !safeUpdateInfo.isBelowMinimum) {
        final skippedVersion = _prefs.getString(_keySkippedVersion);
        if (skippedVersion == safeUpdateInfo.latestVersion) {
          return null;
        }
      }

      // If current version is below minimum, it's mandatory
      if (safeUpdateInfo.isBelowMinimum) {
        return AppUpdateInfo(
          latestVersion: safeUpdateInfo.latestVersion,
          currentVersion: safeUpdateInfo.currentVersion,
          minimumVersion: safeUpdateInfo.minimumVersion,
          isMandatory: true, // Force mandatory
          downloadUrl: safeUpdateInfo.downloadUrl,
          changelogByLanguage: safeUpdateInfo.changelogByLanguage,
          releaseDate: safeUpdateInfo.releaseDate,
        );
      }

      return safeUpdateInfo;
    } catch (e) {
      // Log error if needed
      return null;
    }
  }

  /// Enforces platform-specific update URL policy.
  ///
  /// Android: only Play Store links are allowed.
  /// Any other link falls back to the official Play listing.
  String? _sanitizeDownloadUrl(String? rawUrl) {
    if (rawUrl == null) {
      return Platform.isAndroid ? _androidPlayStoreWebUrl : null;
    }

    final candidate = rawUrl.trim();

    if (!Platform.isAndroid) {
      return candidate.isEmpty ? null : candidate;
    }

    if (candidate.isEmpty) {
      return _androidPlayStoreWebUrl;
    }

    final uri = Uri.tryParse(candidate);
    if (uri == null) {
      return _androidPlayStoreWebUrl;
    }

    final appId = uri.queryParameters['id'];
    final isPlayWeb =
        uri.scheme == 'https' &&
        uri.host == 'play.google.com' &&
        uri.path.startsWith('/store/apps/details') &&
        appId == _androidPackageId;

    final isPlayMarket =
        uri.scheme == 'market' &&
        uri.host == 'details' &&
        appId == _androidPackageId;

    if (isPlayWeb || isPlayMarket) {
      return candidate;
    }

    return _androidPlayStoreWebUrl;
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
