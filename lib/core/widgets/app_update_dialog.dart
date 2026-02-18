import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_update_info.dart';
import '../services/app_update_service.dart';

/// Dialog widget for showing app update notification
class AppUpdateDialog extends StatelessWidget {
  final AppUpdateInfo updateInfo;
  final AppUpdateService updateService;
  final String languageCode;

  const AppUpdateDialog({
    super.key,
    required this.updateInfo,
    required this.updateService,
    this.languageCode = 'ar',
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = languageCode.startsWith('ar');
    final changelog = updateInfo.getChangelog(languageCode);

    return PopScope(
      // Prevent dismissing mandatory updates
      canPop: !updateInfo.isMandatory,
      child: AlertDialog(
        title: Text(
          isArabic ? 'تحديث متاح' : 'Update Available',
          textAlign: isArabic ? TextAlign.right : TextAlign.left,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // Version info
              RichText(
                textAlign: isArabic ? TextAlign.right : TextAlign.left,
                text: TextSpan(
                  style: DefaultTextStyle.of(context).style,
                  children: [
                    TextSpan(
                      text: isArabic ? 'الإصدار الجديد: ' : 'New Version: ',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: updateInfo.latestVersion),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              RichText(
                textAlign: isArabic ? TextAlign.right : TextAlign.left,
                text: TextSpan(
                  style: DefaultTextStyle.of(context).style,
                  children: [
                    TextSpan(
                      text: isArabic ? 'الإصدار الحالي: ' : 'Current Version: ',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: updateInfo.currentVersion),
                  ],
                ),
              ),

              // Mandatory badge
              if (updateInfo.isMandatory || updateInfo.isBelowMinimum) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_rounded, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          isArabic
                              ? 'تحديث إلزامي - يجب التحديث للاستمرار'
                              : 'Mandatory Update - Required to Continue',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: isArabic ? TextAlign.right : TextAlign.left,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Changelog
              if (changelog.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  isArabic ? 'ما الجديد:' : 'What\'s New:',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  textAlign: isArabic ? TextAlign.right : TextAlign.left,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    changelog,
                    textAlign: isArabic ? TextAlign.right : TextAlign.left,
                    style: TextStyle(color: Colors.grey.shade800),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          // "Later" button (only for optional updates)
          if (!updateInfo.isMandatory && !updateInfo.isBelowMinimum)
            TextButton(
              onPressed: () async {
                await updateService.skipVersion(updateInfo.latestVersion);
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: Text(isArabic ? 'لاحقاً' : 'Later'),
            ),

          // "Update" button
          FilledButton(
            onPressed: () async {
              if (updateInfo.downloadUrl != null) {
                final url = Uri.parse(updateInfo.downloadUrl!);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              }
              if (context.mounted && !updateInfo.isMandatory) {
                Navigator.of(context).pop();
              }
            },
            child: Text(isArabic ? 'تحديث الآن' : 'Update Now'),
          ),
        ],
      ),
    );
  }

  /// Show the update dialog
  static Future<void> show({
    required BuildContext context,
    required AppUpdateInfo updateInfo,
    required AppUpdateService updateService,
    String languageCode = 'ar',
  }) {
    return showDialog(
      context: context,
      barrierDismissible: !updateInfo.isMandatory && !updateInfo.isBelowMinimum,
      builder: (context) => AppUpdateDialog(
        updateInfo: updateInfo,
        updateService: updateService,
        languageCode: languageCode,
      ),
    );
  }
}
