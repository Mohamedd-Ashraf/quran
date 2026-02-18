import 'package:flutter/material.dart';
import '../services/app_update_service.dart';
import '../widgets/app_update_dialog.dart';

/// Helper class to easily trigger update checks from anywhere in the app
class UpdateChecker {
  /// Manually check for updates (useful for settings screen "Check for Updates" button)
  /// 
  /// Shows:
  /// - Update dialog if update is available
  /// - Success snackbar if app is up to date
  /// - Error snackbar if check fails
  static Future<void> manualCheck({
    required BuildContext context,
    required AppUpdateService updateService,
    String languageCode = 'ar',
    bool showLoading = true,
  }) async {
    final isArabic = languageCode.startsWith('ar');
    
    // Show loading if requested
    if (showLoading && context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    try {
      // Force check (ignores time interval and skipped versions)
      final updateInfo = await updateService.forceCheckForUpdate();

      // Hide loading
      if (showLoading && context.mounted) {
        Navigator.of(context).pop();
      }

      if (updateInfo != null) {
        // Show update dialog
        if (context.mounted) {
          await AppUpdateDialog.show(
            context: context,
            updateInfo: updateInfo,
            updateService: updateService,
            languageCode: languageCode,
          );
        }
      } else {
        // App is up to date
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isArabic
                    ? '🎉 أنت تستخدم أحدث إصدار من التطبيق'
                    : '🎉 You are using the latest version',
                textAlign: isArabic ? TextAlign.right : TextAlign.left,
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      // Hide loading
      if (showLoading && context.mounted) {
        Navigator.of(context).pop();
      }

      // Show error
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isArabic
                  ? '❌ فشل التحقق من التحديثات. تأكد من اتصالك بالإنترنت.'
                  : '❌ Failed to check for updates. Check your internet connection.',
              textAlign: isArabic ? TextAlign.right : TextAlign.left,
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Silent check for updates (no loading indicator, no success message)
  /// Only shows dialog if update is available
  static Future<void> silentCheck({
    required BuildContext context,
    required AppUpdateService updateService,
    String languageCode = 'ar',
  }) async {
    try {
      final updateInfo = await updateService.checkForUpdate();

      if (updateInfo != null && context.mounted) {
        await AppUpdateDialog.show(
          context: context,
          updateInfo: updateInfo,
          updateService: updateService,
          languageCode: languageCode,
        );
      }
    } catch (e) {
      // Silent failure - don't show error to user
    }
  }
}
