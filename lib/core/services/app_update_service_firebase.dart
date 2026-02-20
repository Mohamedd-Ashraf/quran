import 'dart:io';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_update/in_app_update.dart' as iap;
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/app_update_info.dart';

/// Premium app update service using Firebase Remote Config and In-App Updates
/// 
/// Features:
/// - Firebase Remote Config for centralized update management
/// - In-App Updates for Android (flexible and immediate updates)
/// - App Store redirect for iOS
/// - No need for external server hosting
/// - Real-time update configuration changes
class AppUpdateServiceFirebase {
  final FirebaseRemoteConfig _remoteConfig;
  final SharedPreferences _prefs;

  // Remote Config keys
  static const String _keyLatestVersion = 'latest_version';
  static const String _keyMinimumVersion = 'minimum_version';
  static const String _keyIsMandatory = 'mandatory_update';
  static const String _keyDownloadUrl = 'download_url';
  static const String _keyChangelogAr = 'changelog_ar';
  static const String _keyChangelogEn = 'changelog_en';
  static const String _keyReleaseDate = 'release_date';
  static const String _keyEnableInAppUpdate = 'use_in_app_update'; // Android only
  static const String _keyUpdatePriority = 'update_priority';

  // Preference keys
  static const String _keyLastCheckTime = 'last_update_check_time';
  static const String _keySkippedVersion = 'skipped_update_version';

  AppUpdateServiceFirebase(this._remoteConfig, this._prefs);

  /// Initialize Firebase Remote Config with default values
  Future<void> initialize() async {
    print('🚀 Initializing Firebase Remote Config...');
    try {
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: Duration.zero, // For testing - fetch immediately
        ),
      );
      print('✅ Remote Config settings configured');

      // Set default values - these will be overridden by Firebase Console
      await _remoteConfig.setDefaults({
        _keyLatestVersion: '1.0.0',
        _keyMinimumVersion: '1.0.0',
        _keyIsMandatory: false,
        _keyDownloadUrl: '',
        _keyChangelogAr: '',
        _keyChangelogEn: '',
        _keyReleaseDate: DateTime.now().toIso8601String(),
        _keyEnableInAppUpdate: true,
        _keyUpdatePriority: 3,
      });
      print('✅ Remote Config defaults set');

      // Fetch and activate
      final activated = await _remoteConfig.fetchAndActivate();
      print('✅ Remote Config fetched and activated: $activated');
    } catch (e) {
      print('❌ Error initializing Remote Config: $e');
      // If Remote Config fails, use defaults
      // This ensures the app still works without Firebase
    }
  }

  /// Check for app updates using Firebase Remote Config
  Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      print('🔄 Checking for updates...');
      
      // Fetch latest config from Firebase
      await _remoteConfig.fetchAndActivate();
      print('✅ Remote Config fetched and activated');

      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      print('📱 Current version: $currentVersion');

      // Get update info from Remote Config
      final latestVersion = _remoteConfig.getString(_keyLatestVersion);
      final minimumVersion = _remoteConfig.getString(_keyMinimumVersion);
      final isMandatory = _remoteConfig.getBool(_keyIsMandatory);
      final downloadUrl = _remoteConfig.getString(_keyDownloadUrl);
      final changelogAr = _remoteConfig.getString(_keyChangelogAr);
      final changelogEn = _remoteConfig.getString(_keyChangelogEn);
      final releaseDateStr = _remoteConfig.getString(_keyReleaseDate);

      print('🆕 Latest version: $latestVersion');
      print('📦 Minimum version: $minimumVersion');
      print('⚠️ Mandatory: $isMandatory');
      print('🔗 Download URL: $downloadUrl');

      // Build changelog map
      final changelogMap = <String, String>{};
      if (changelogAr.isNotEmpty) changelogMap['ar'] = changelogAr;
      if (changelogEn.isNotEmpty) changelogMap['en'] = changelogEn;

      // Parse release date
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
        downloadUrl: downloadUrl.isNotEmpty ? downloadUrl : null,
        changelogByLanguage: changelogMap.isNotEmpty ? changelogMap : null,
        releaseDate: releaseDate,
      );

      // Update last check time
      await _saveLastCheckTime();

      // If no update available, return null
      if (!updateInfo.hasUpdate) {
        print('ℹ️ No update available');
        return null;
      }

      print('🎯 Update available!');
      print('🔍 isBelowMinimum: ${updateInfo.isBelowMinimum}');
      print('🔍 isMandatory from config: ${updateInfo.isMandatory}');
      
      // If current version is below minimum, it's mandatory
      final shouldBeMandatory = updateInfo.isBelowMinimum || updateInfo.isMandatory;
      print('🎯 Final mandatory status: $shouldBeMandatory');
      
      // If update is optional and user skipped this version, return null
      if (!shouldBeMandatory) {
        final skippedVersion = _prefs.getString(_keySkippedVersion);
        if (skippedVersion == updateInfo.latestVersion) {
          print('⏭️ User skipped this version');
          return null;
        }
      }

      // Return update info with correct mandatory status
      return AppUpdateInfo(
        latestVersion: updateInfo.latestVersion,
        currentVersion: updateInfo.currentVersion,
        minimumVersion: updateInfo.minimumVersion,
        isMandatory: shouldBeMandatory,
        downloadUrl: updateInfo.downloadUrl,
        changelogByLanguage: updateInfo.changelogByLanguage,
        releaseDate: updateInfo.releaseDate,
      );
    } catch (e) {
      print('❌ Error checking for update: $e');
      return null;
    }
  }

  /// Check if in-app update is available (Android only)
  Future<bool> checkInAppUpdateAvailability() async {
    if (!Platform.isAndroid) return false;

    try {
      final enableInAppUpdate = _remoteConfig.getBool(_keyEnableInAppUpdate);
      if (!enableInAppUpdate) return false;

      final updateInfo = await iap.InAppUpdate.checkForUpdate();
      return updateInfo.updateAvailability == iap.UpdateAvailability.updateAvailable;
    } catch (e) {
      return false;
    }
  }

  /// Perform flexible in-app update (Android only)
  /// User can continue using the app while downloading
  Future<bool> performFlexibleUpdate() async {
    if (!Platform.isAndroid) return false;

    try {
      final updateInfo = await iap.InAppUpdate.checkForUpdate();
      if (updateInfo.updateAvailability != iap.UpdateAvailability.updateAvailable) {
        return false;
      }

      if (updateInfo.flexibleUpdateAllowed) {
        await iap.InAppUpdate.startFlexibleUpdate();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Perform immediate in-app update (Android only)
  /// Blocks the app until update is completed - for mandatory updates
  Future<bool> performImmediateUpdate() async {
    if (!Platform.isAndroid) return false;

    try {
      final updateInfo = await iap.InAppUpdate.checkForUpdate();
      if (updateInfo.updateAvailability != iap.UpdateAvailability.updateAvailable) {
        return false;
      }

      if (updateInfo.immediateUpdateAllowed) {
        await iap.InAppUpdate.performImmediateUpdate();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Complete flexible update if one was downloaded
  Future<void> completeFlexibleUpdate() async {
    if (!Platform.isAndroid) return;

    try {
      await iap.InAppUpdate.completeFlexibleUpdate();
    } catch (e) {
      // Ignore errors
    }
  }

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

  /// Mark a version as skipped (user chose "Later" for optional update)
  Future<void> skipVersion(String version) async {
    await _prefs.setString(_keySkippedVersion, version);
  }

  /// Clear skipped version
  Future<void> clearSkippedVersion() async {
    await _prefs.remove(_keySkippedVersion);
  }

  /// Force check for updates (ignores time interval and skipped versions)
  Future<AppUpdateInfo?> forceCheckForUpdate() async {
    await clearSkippedVersion();
    return checkForUpdate();
  }

  /// Get update availability status (for UI indicators)
  Future<iap.UpdateAvailability> getUpdateAvailability() async {
    if (!Platform.isAndroid) {
      return iap.UpdateAvailability.updateNotAvailable;
    }

    try {
      final info = await iap.InAppUpdate.checkForUpdate();
      return info.updateAvailability;
    } catch (e) {
      return iap.UpdateAvailability.updateNotAvailable;
    }
  }

  /// Download APK file directly from URL with progress callback
  /// Returns the path to the downloaded file
  Future<String?> downloadApk({
    required String url,
    required void Function(double progress) onProgress,
  }) async {
    try {
      print('📥 Starting APK download from: $url');
      
      // Get temporary directory
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/app_update.apk';
      
      // Delete old file if exists
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        print('🗑️ Deleted old APK file');
      }

      // Download with progress
      final dio = Dio();
      await dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            onProgress(progress);
            print('📊 Download progress: ${(progress * 100).toStringAsFixed(1)}%');
          }
        },
      );

      print('✅ APK downloaded successfully to: $filePath');
      return filePath;
    } catch (e) {
      print('❌ Error downloading APK: $e');
      return null;
    }
  }

  /// Install APK file (opens installation prompt)
  Future<bool> installApk(String filePath) async {
    if (!Platform.isAndroid) {
      print('⚠️ APK installation only supported on Android');
      return false;
    }

    try {
      print('� Checking install packages permission...');
      
      // Request permission to install packages
      var status = await Permission.requestInstallPackages.status;
      print('📋 Current permission status: $status');
      
      if (!status.isGranted) {
        print('🙏 Requesting install packages permission...');
        status = await Permission.requestInstallPackages.request();
        print('📋 New permission status: $status');
      }
      
      if (!status.isGranted) {
        print('❌ Install packages permission denied');
        return false;
      }
      
      print('✅ Permission granted, opening APK for installation: $filePath');
      
      final result = await OpenFile.open(filePath);
      
      if (result.type == ResultType.done) {
        print('✅ APK installation started');
        return true;
      } else {
        print('❌ Failed to open APK: ${result.message}');
        return false;
      }
    } catch (e) {
      print('❌ Error installing APK: $e');
      return false;
    }
  }

  /// Download and install APK in one step
  Future<bool> downloadAndInstallApk({
    required String url,
    required void Function(double progress) onProgress,
  }) async {
    final filePath = await downloadApk(url: url, onProgress: onProgress);
    
    if (filePath == null) {
      return false;
    }

    return await installApk(filePath);
  }
}
