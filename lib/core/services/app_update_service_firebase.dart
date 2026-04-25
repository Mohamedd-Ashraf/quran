import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_update_info.dart';

/// App update service using Firebase Remote Config
/// 
/// Features:
/// - Firebase Remote Config for version management
/// - Always redirects to Google Play Store
/// - No need for external server hosting
/// - Real-time update configuration changes
class AppUpdateServiceFirebase {
  final FirebaseRemoteConfig _remoteConfig;
  final SharedPreferences _prefs;

  static const String _androidPackageId = 'com.nooraliman.quran';
  static const String _playStoreUrl =
      'https://play.google.com/store/apps/details?id=$_androidPackageId';

  // Remote Config keys
  static const String _keyLatestVersion = 'latest_version';
  static const String _keyMinimumVersion = 'minimum_version';
  static const String _keyIsMandatory = 'is_mandatory';
  // Backward-compat aliases
  static const String _keyIsMandatoryLegacy = 'mandatory_update';
  static const String _keyChangelogAr = 'changelog_ar';
  static const String _keyChangelogEn = 'changelog_en';
  static const String _keyReleaseDate = 'release_date';

  // Preference keys
  static const String _keyLastCheckTime = 'last_update_check_time';
  static const String _keySkippedVersion = 'skipped_update_version';

  AppUpdateServiceFirebase(this._remoteConfig, this._prefs);

  Future<void> _refreshRemoteConfig({bool force = false}) async {
    if (force || kDebugMode) {
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: Duration.zero,
        ),
      );
    }
    await _remoteConfig.fetchAndActivate();
  }

  /// Initialize Firebase Remote Config with default values
  Future<void> initialize() async {
    print('🔄 Initializing Firebase Remote Config...');
    try {
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval:
              kDebugMode ? Duration.zero : const Duration(hours: 12),
        ),
      );
      print('✅ Remote Config settings configured');

      await _remoteConfig.setDefaults({
        _keyLatestVersion: '1.0.3',
        _keyMinimumVersion: '1.0.3',
        _keyIsMandatory: false,
        _keyIsMandatoryLegacy: false,
        _keyChangelogAr: '',
        _keyChangelogEn: '',
        _keyReleaseDate: DateTime.now().toIso8601String(),
      });
      print('✅ Remote Config defaults set');

      final activated = await _remoteConfig.fetchAndActivate();
      print('✅ Remote Config fetched and activated: $activated');
    } catch (e) {
      print('❌ Error initializing Remote Config: $e');
    }
  }

  /// Check for app updates using Firebase Remote Config
  Future<AppUpdateInfo?> checkForUpdate({bool forceRefresh = false}) async {
    try {
      print('🔍 Checking for updates...');

      await _refreshRemoteConfig(force: forceRefresh);
      print('✅ Remote Config fetched and activated');

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      print('📱 Current version: $currentVersion');

      final latestVersionValue = _remoteConfig.getValue(_keyLatestVersion);
      final minimumVersionValue = _remoteConfig.getValue(_keyMinimumVersion);
      final latestVersion = latestVersionValue.asString();
      final minimumVersion = minimumVersionValue.asString();
      final isMandatory =
          _remoteConfig.getBool(_keyIsMandatory) ||
          _remoteConfig.getBool(_keyIsMandatoryLegacy);
      final changelogAr = _remoteConfig.getString(_keyChangelogAr);
      final changelogEn = _remoteConfig.getString(_keyChangelogEn);
      final releaseDateStr = _remoteConfig.getString(_keyReleaseDate);

      if (latestVersion.trim().isEmpty) {
        print('⚠️ latest_version is empty in Remote Config');
        return null;
      }

      print('📦 Latest version: $latestVersion');
      print('📦 Minimum version: $minimumVersion');
      print('📦 Mandatory: $isMandatory');

      final changelogMap = <String, String>{};
      if (changelogAr.isNotEmpty) changelogMap['ar'] = changelogAr;
      if (changelogEn.isNotEmpty) changelogMap['en'] = changelogEn;

      DateTime? releaseDate;
      try {
        releaseDate = DateTime.parse(releaseDateStr);
      } catch (_) {
        releaseDate = null;
      }

      final updateInfo = AppUpdateInfo(
        latestVersion: latestVersion,
        currentVersion: currentVersion,
        minimumVersion: minimumVersion.isNotEmpty ? minimumVersion : null,
        isMandatory: isMandatory,
        downloadUrl: _playStoreUrl,
        changelogByLanguage: changelogMap.isNotEmpty ? changelogMap : null,
        releaseDate: releaseDate,
      );

      await _saveLastCheckTime();

      if (!updateInfo.hasUpdate) {
        print('✅ No update available');
        return null;
      }

      print('🚀 Update available!');
      
      final shouldBeMandatory = updateInfo.isBelowMinimum || updateInfo.isMandatory;
      print('📦 Final mandatory status: $shouldBeMandatory');
      
      if (!shouldBeMandatory) {
        final skippedVersion = _prefs.getString(_keySkippedVersion);
        if (skippedVersion == updateInfo.latestVersion) {
          print('⏭️ User skipped this version');
          return null;
        }
      }

      return AppUpdateInfo(
        latestVersion: updateInfo.latestVersion,
        currentVersion: updateInfo.currentVersion,
        minimumVersion: updateInfo.minimumVersion,
        isMandatory: shouldBeMandatory,
        downloadUrl: _playStoreUrl,
        changelogByLanguage: updateInfo.changelogByLanguage,
        releaseDate: updateInfo.releaseDate,
      );
    } catch (e) {
      print('❌ Error checking for update: $e');
      return null;
    }
  }

  /// Get the Google Play Store URL
  String getPlayStoreUrl() => _playStoreUrl;

  /// Check if enough time has passed since last check
  Future<bool> shouldCheckForUpdate({
    Duration minInterval = const Duration(hours: 12),
  }) async {
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

  /// Mark a version as skipped
  Future<void> skipVersion(String version) async {
    await _prefs.setString(_keySkippedVersion, version);
  }

  /// Clear skipped version
  Future<void> clearSkippedVersion() async {
    await _prefs.remove(_keySkippedVersion);
  }

  /// Force check for updates
  Future<AppUpdateInfo?> forceCheckForUpdate() async {
    await clearSkippedVersion();
    return checkForUpdate(forceRefresh: true);
  }
}
