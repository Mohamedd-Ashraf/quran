// Stub for package:in_app_update on web.
// None of these are ever called at runtime on web.

// ignore_for_file: avoid_classes_with_only_static_members

class InAppUpdate {
  static Future<AppUpdateInfo> checkForUpdate() async =>
      const AppUpdateInfo._(UpdateAvailability.unknown);
  static Future<AppUpdateResult> performFlexibleUpdate() async =>
      AppUpdateResult.success;
  static Future<AppUpdateResult> performImmediateUpdate() async =>
      AppUpdateResult.success;
}

class AppUpdateInfo {
  final UpdateAvailability updateAvailability;
  const AppUpdateInfo._(this.updateAvailability);
}

enum UpdateAvailability { unknown, updateNotAvailable, updateAvailable, developerTriggeredUpdateInProgress }
enum AppUpdateType { flexible, immediate }
enum AppUpdateResult { success, inAppUpdateFailed, userDeniedUpdate }
enum InstallStatus { unknown, pending, downloading, downloaded, installing, installed, failed, canceled }
