import 'dart:io' if (dart.library.html) 'stubs/mobile_platform_stub.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_update/in_app_update.dart' as iap
    // ignore: uri_does_not_exist
    if (dart.library.html) 'stubs/in_app_update_stub.dart';
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

  static const String _androidPackageId = 'com.nooraliman.quran';
  static const String _androidPlayStoreWebUrl =
      'https://play.google.com/store/apps/details?id=$_androidPackageId';

  // Remote Config keys
  static const String _keyLatestVersion = 'latest_version';
  static const String _keyMinimumVersion = 'minimum_version';
  static const String _keyIsMandatory = 'is_mandatory';
  // Backward-compat aliases still used in some Firebase templates.
  static const String _keyIsMandatoryLegacy = 'mandatory_update';
  // Generic download URL � used for iOS and as fallback when an ABI-specific URL
  // is not set in Remote Config.
  static const String _keyDownloadUrl = 'download_url';
  // Per-ABI download URLs for split-per-ABI Android APKs.
  // If the device ABI has a specific URL it will be preferred over _keyDownloadUrl.
  // Leave empty in Remote Config to fall back to the generic URL.
  static const String _keyDownloadUrlArm64   = 'download_url_arm64_v8a';
  static const String _keyDownloadUrlArmeabi = 'download_url_armeabi_v7a';
  static const String _keyDownloadUrlX86_64  = 'download_url_x86_64';
  static const String _keyChangelogAr = 'changelog_ar';
  static const String _keyChangelogEn = 'changelog_en';
  static const String _keyReleaseDate = 'release_date';
  static const String _keyEnableInAppUpdate = 'enable_in_app_update'; // Android only
  static const String _keyEnableInAppUpdateLegacy = 'use_in_app_update'; // Android only (legacy)
  static const String _keyUpdatePriority = 'update_priority';

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
    print('?? Initializing Firebase Remote Config...');
    try {
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          // In debug we always fetch the latest published template immediately.
          // Production: 12 h interval is enough for non-urgent config updates
          // and avoids unnecessary network + CPU wake-ups.
          minimumFetchInterval:
              kDebugMode ? Duration.zero : const Duration(hours: 12),
        ),
      );
      print('? Remote Config settings configured');

      // Set default values - these will be overridden by Firebase Console
      await _remoteConfig.setDefaults({
        _keyLatestVersion: '1.0.3',
        _keyMinimumVersion: '1.0.3',
        _keyIsMandatory: false,
        _keyIsMandatoryLegacy: false,
        _keyDownloadUrl: '',
        // ABI-specific defaults � empty means "fall back to generic download_url"
        _keyDownloadUrlArm64: '',
        _keyDownloadUrlArmeabi: '',
        _keyDownloadUrlX86_64: '',
        _keyChangelogAr: '',
        _keyChangelogEn: '',
        _keyReleaseDate: DateTime.now().toIso8601String(),
        _keyEnableInAppUpdate: true,
        _keyEnableInAppUpdateLegacy: true,
        _keyUpdatePriority: 3,
      });
      print('? Remote Config defaults set');

      // Fetch and activate
      final activated = await _remoteConfig.fetchAndActivate();
      print('? Remote Config fetched and activated: $activated');
    } catch (e) {
      print('? Error initializing Remote Config: $e');
      // If Remote Config fails, use defaults
      // This ensures the app still works without Firebase
    }
  }

  /// Check for app updates using Firebase Remote Config
  Future<AppUpdateInfo?> checkForUpdate({bool forceRefresh = false}) async {
    try {
      print('?? Checking for updates...');

      // Fetch latest config from Firebase.
      // forceRefresh=true bypasses cache (used by manual check).
      await _refreshRemoteConfig(force: forceRefresh);
      print('? Remote Config fetched and activated');

      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      print('?? Current version: $currentVersion');

      // Get update info from Remote Config and log value source for diagnostics.
      // This makes it obvious whether a value came from Firebase Console
      // (remote) or from local defaults (setDefaults).
      final latestVersionValue = _remoteConfig.getValue(_keyLatestVersion);
      final minimumVersionValue = _remoteConfig.getValue(_keyMinimumVersion);
      final latestVersion = latestVersionValue.asString();
      final minimumVersion = minimumVersionValue.asString();
        final isMandatory =
          _remoteConfig.getBool(_keyIsMandatory) ||
          _remoteConfig.getBool(_keyIsMandatoryLegacy);
      // Resolve URL from Remote Config, then sanitize for current platform.
      // On Android we only allow Play Store destinations.
      final rawDownloadUrl = _getAbiSpecificDownloadUrl();
      final downloadUrl = _sanitizeDownloadUrl(rawDownloadUrl);
      final changelogAr = _remoteConfig.getString(_keyChangelogAr);
      final changelogEn = _remoteConfig.getString(_keyChangelogEn);
      final releaseDateStr = _remoteConfig.getString(_keyReleaseDate);

      if (latestVersion.trim().isEmpty) {
        print('?? latest_version is empty in Remote Config');
        return null;
      }

      print('?? Latest version: $latestVersion');
      print('?? Minimum version: $minimumVersion');
      print('?? latest_version source: ${latestVersionValue.source}');
      print('?? minimum_version source: ${minimumVersionValue.source}');
        print('?? Mandatory: $isMandatory '
          '(is_mandatory=${_remoteConfig.getBool(_keyIsMandatory)}, '
          'mandatory_update=${_remoteConfig.getBool(_keyIsMandatoryLegacy)})');
      print('?? Download URL (raw): $rawDownloadUrl');
      print('?? Download URL (sanitized): $downloadUrl');

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
        print('?? No update available');
        return null;
      }

      print('?? Update available!');
      print('?? isBelowMinimum: ${updateInfo.isBelowMinimum}');
      print('?? isMandatory from config: ${updateInfo.isMandatory}');
      
      // If current version is below minimum, it's mandatory
      final shouldBeMandatory = updateInfo.isBelowMinimum || updateInfo.isMandatory;
      print('?? Final mandatory status: $shouldBeMandatory');
      
      // If update is optional and user skipped this version, return null
      if (!shouldBeMandatory) {
        final skippedVersion = _prefs.getString(_keySkippedVersion);
        if (skippedVersion == updateInfo.latestVersion) {
          print('?? User skipped this version');
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
      print('? Error checking for update: $e');
      return null;
    }
  }

  /// Check if in-app update is available (Android only)
  Future<bool> checkInAppUpdateAvailability() async {
    if (!Platform.isAndroid) return false;

    try {
      final enableInAppUpdate =
          _remoteConfig.getBool(_keyEnableInAppUpdate) ||
          _remoteConfig.getBool(_keyEnableInAppUpdateLegacy);
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
    return checkForUpdate(forceRefresh: true);
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

  // ---------------------------------------------------------------------------
  // ABI resolution helpers
  // ---------------------------------------------------------------------------

  /// Returns the device's primary ABI as a Remote Config key suffix, or an
  /// empty string if the ABI cannot be determined (e.g. non-Android platforms).
  ///
  /// Possible return values:
  ///   'arm64_v8a'   ? 64-bit ARM  (most modern Android phones)
  ///   'armeabi_v7a' ? 32-bit ARM  (older / low-end devices)
  ///   'x86_64'      ? 64-bit x86  (emulators, some Chromebooks)
  ///   ''            ? unknown / iOS / web ? fall back to generic download_url
  String _detectAbi() {
    if (kIsWeb) return '';
    if (!Platform.isAndroid) return '';
    try {
      // Use the platform version string to infer ABI without dart:ffi.
      // e.g. "android-arm64", "android-arm", "android-x64"
      final triple = Platform.version.toLowerCase();
      if (triple.contains('arm64') || triple.contains('aarch64')) {
        return 'arm64_v8a';
      }
      if (triple.contains('arm')) return 'armeabi_v7a';
      if (triple.contains('x64') || triple.contains('x86_64')) {
        return 'x86_64';
      }
      return '';
    } catch (_) {
      return '';
    }
  }

  /// Returns the download URL that matches this device's CPU architecture.
  ///
  /// Priority:
  ///   1. ABI-specific Remote Config key  (e.g. download_url_arm64_v8a)
  ///   2. Generic download_url key
  ///   3. Empty string if nothing is set
  String _getAbiSpecificDownloadUrl() {
    final abiSuffix = _detectAbi();
    if (abiSuffix.isNotEmpty) {
      final key     = 'download_url_$abiSuffix';
      final abiUrl  = _remoteConfig.getString(key);
      if (abiUrl.isNotEmpty) {
        print('?? [Update] ABI=$abiSuffix ? using per-ABI URL ($key)');
        return abiUrl;
      }
      print('?? [Update] ABI=$abiSuffix ? per-ABI URL empty, falling back to generic');
    }
    return _remoteConfig.getString(_keyDownloadUrl);
  }

  /// Enforces platform-specific URL policy.
  ///
  /// Android policy:
  /// - Only Play Store URLs are allowed.
  /// - Any non-Play link (including direct APK links) falls back to the
  ///   official Play listing for this package.
  String _sanitizeDownloadUrl(String rawUrl) {
    final candidate = rawUrl.trim();

    if (!Platform.isAndroid) {
      return candidate;
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

    if (kDebugMode) {
      print('?? [Update] Blocked non-Play Android URL: $candidate');
    }
    return _androidPlayStoreWebUrl;
  }
}
