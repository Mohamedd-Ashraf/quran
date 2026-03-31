import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../di/injection_container.dart' as di;
import '../models/app_update_info.dart';
import '../services/app_update_service_firebase.dart';
import '../services/app_update_manager.dart';
import '../services/update_download_notification_service.dart';

/// Show premium update dialog
Future<void> showPremiumUpdateDialog({
  required BuildContext context,
  required AppUpdateInfo updateInfo,
  required AppUpdateServiceFirebase updateService,
  String languageCode = 'ar',
}) {
  return showDialog(
    context: context,
    barrierDismissible: !updateInfo.isMandatory && !updateInfo.isBelowMinimum,
    builder: (context) => AppUpdateDialogPremium(
      updateInfo: updateInfo,
      updateService: updateService,
      languageCode: languageCode,
    ),
  );
}

/// Premium update dialog with In-App Update support for Android
class AppUpdateDialogPremium extends StatefulWidget {
  final AppUpdateInfo updateInfo;
  final AppUpdateServiceFirebase updateService;
  final String languageCode;

  const AppUpdateDialogPremium({
    super.key,
    required this.updateInfo,
    required this.updateService,
    this.languageCode = 'ar',
  });

  @override
  State<AppUpdateDialogPremium> createState() => _AppUpdateDialogPremiumState();
}

class _AppUpdateDialogPremiumState extends State<AppUpdateDialogPremium> {
  bool _isUpdating = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  bool _dismissedToBackground = false;
  int _lastNotifPct = -1;

  @override
  Widget build(BuildContext context) {
    final isArabic = widget.languageCode.startsWith('ar');
    final changelog = widget.updateInfo.getChangelog(widget.languageCode);

    return PopScope(
      canPop: !widget.updateInfo.isMandatory,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.system_update_rounded,
                color: Colors.blue.shade700,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isArabic ? 'تحديث متاح' : 'Update Available',
                textAlign: isArabic ? TextAlign.right : TextAlign.left,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
            // Close button for non-mandatory updates
            if (!widget.updateInfo.isMandatory && !widget.updateInfo.isBelowMinimum)
              IconButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.close_rounded),
                tooltip: isArabic ? 'تذكيرى لاحقاً' : 'Remind me later',
                iconSize: 24,
              ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // Version badges
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _VersionBadge(
                    label: isArabic ? 'الحالي' : 'Current',
                    version: widget.updateInfo.currentVersion,
                    color: Colors.grey,
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.grey.shade400,
                  ),
                  _VersionBadge(
                    label: isArabic ? 'الجديد' : 'New',
                    version: widget.updateInfo.latestVersion,
                    color: Colors.green,
                  ),
                ],
              ),

              // Mandatory badge
              if (widget.updateInfo.isMandatory ||
                  widget.updateInfo.isBelowMinimum) ...[
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.red.shade400, Colors.red.shade600],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_rounded,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          isArabic
                              ? 'تحديث إلزامي - يجب التحديث للاستمرار'
                              : 'Mandatory Update Required',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: isArabic ? TextAlign.right : TextAlign.left,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Platform indicator
              if (Platform.isAndroid) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.android, color: Colors.green.shade700, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        isArabic
                            ? 'التحديث مباشرة من داخل التطبيق'
                            : 'In-App Update Available',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
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
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  textAlign: isArabic ? TextAlign.right : TextAlign.left,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Text(
                    changelog,
                    textAlign: isArabic ? TextAlign.right : TextAlign.left,
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      height: 1.5,
                    ),
                  ),
                ),
              ],

              // Background-download info shown briefly before dialog auto-closes
              if (_dismissedToBackground) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.notifications_active_rounded,
                          color: Colors.blue.shade600, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isArabic
                                  ? 'التحميل يجري في الخلفية'
                                  : 'Downloading in background',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isArabic
                                  ? 'ستصلك إشعار عند الاكتمال، وسيبدأ التثبيت تلقائياً'
                                  : 'You\'ll get a notification when done. Installation starts automatically.',
                              style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 13,
                                  height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (_isUpdating || _isDownloading) ...[
                const SizedBox(height: 16),
                if (_isDownloading) ...[
                  // Download progress bar
                  LinearProgressIndicator(
                    value: _downloadProgress,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isArabic
                        ? 'جاري التحميل... ${(_downloadProgress * 100).toStringAsFixed(0)}%'
                        : 'Downloading... ${(_downloadProgress * 100).toStringAsFixed(0)}%',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ] else ...[
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isArabic ? 'جاري التحديث...' : 'Updating...',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ],
            ],
          ),
        ),
        actions: (_isUpdating || _isDownloading || _dismissedToBackground)
            ? null
            : [
                // "Later" button (only for optional updates)
                if (!widget.updateInfo.isMandatory &&
                    !widget.updateInfo.isBelowMinimum)
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.schedule_rounded),
                    label: Text(isArabic ? 'لاحقاً' : 'Later'),
                  ),

                // "Update" button
                FilledButton.icon(
                  onPressed: _handleUpdate,
                  icon: const Icon(Icons.download_rounded),
                  label: Text(isArabic ? 'تحديث الآن' : 'Update Now'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                ),
              ],
      ),
    );
  }

  Future<void> _handleUpdate() async {
    final isArabic = widget.languageCode.startsWith('ar');

    setState(() => _isUpdating = true);

    try {
      if (Platform.isAndroid && widget.updateInfo.downloadUrl != null) {
        // Try in-app update first (Google Play).
        final inAppAvailable =
            await widget.updateService.checkInAppUpdateAvailability();

        if (inAppAvailable) {
          bool success;
          if (widget.updateInfo.isMandatory ||
              widget.updateInfo.isBelowMinimum) {
            success = await widget.updateService.performImmediateUpdate();
          } else {
            success = await widget.updateService.performFlexibleUpdate();
            if (success && context.mounted) {
              // Dismiss dialog — Play Store handles background download.
              Navigator.of(context).pop();
              // AppUpdateManager will show a banner via MainNavigator.
              AppUpdateManager.instance.startDownload(
                widget.updateInfo.latestVersion,
              );
              AppUpdateManager.instance.markComplete(); // play store owns it
            }
            return;
          }
          if (success) return;
        }

        // Fallback: direct APK download with system notification progress.
        final notifService = di.sl<UpdateDownloadNotificationService>();

        // Check install permission BEFORE starting download so we can inform the user
        final permissionStatus = await Permission.requestInstallPackages.status;
        final needsInstallPermission = !permissionStatus.isGranted;

        AppUpdateManager.instance.startDownload(
          widget.updateInfo.latestVersion,
          needsInstallPermission: needsInstallPermission,
        );

        setState(() {
          _isUpdating = false;
          _isDownloading = true;
          _downloadProgress = 0.0;
        });

        // Show initial notification so user can see progress after dismissing dialog.
        unawaited(notifService.showProgress(
          progress: 0,
          version: widget.updateInfo.latestVersion,
          isArabic: isArabic,
        ));

        // For optional updates: briefly show "downloading in background" message,
        // then auto-dismiss so the user can keep exploring.
        if (!widget.updateInfo.isMandatory &&
            !widget.updateInfo.isBelowMinimum &&
            mounted) {
          setState(() => _dismissedToBackground = true);
          await Future<void>.delayed(const Duration(seconds: 2));
          if (mounted) Navigator.of(context).pop();
        }

        final success = await widget.updateService.downloadAndInstallApk(
          url: widget.updateInfo.downloadUrl!,
          onProgress: (p) {
            final crossed90 = AppUpdateManager.instance.updateProgress(p);
            // Throttle notification calls to once per 1% to avoid Android
            // dropping rapid updates and the notification appearing frozen.
            final pct = (p * 100).round();
            if (pct != _lastNotifPct) {
              _lastNotifPct = pct;
              // Show special notification at 90%
              if (crossed90) {
                unawaited(notifService.showAlmostComplete(
                  version: widget.updateInfo.latestVersion,
                  isArabic: isArabic,
                  needsInstallPermission: needsInstallPermission,
                ));
              } else {
                unawaited(notifService.showProgress(
                  progress: p,
                  version: widget.updateInfo.latestVersion,
                  isArabic: isArabic,
                ));
              }
            }
            if (mounted) setState(() => _downloadProgress = p);
          },
        );

        if (success) {
          AppUpdateManager.instance.markComplete();
          unawaited(notifService.showComplete(
            version: widget.updateInfo.latestVersion,
            isArabic: isArabic,
          ));
        } else {
          AppUpdateManager.instance.markError();
          unawaited(notifService.showError(isArabic: isArabic));
        }
      } else {
        // iOS or no download URL — open store.
        await _openStore();
      }
    } catch (e) {
      AppUpdateManager.instance.markError();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isArabic ? 'حدث خطأ أثناء التحديث' : 'An error occurred',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
          _isDownloading = false;
        });
      }
    }
  }

  Future<void> _openStore() async {
    if (widget.updateInfo.downloadUrl != null) {
      final url = Uri.parse(widget.updateInfo.downloadUrl!);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    }
    if (context.mounted && !widget.updateInfo.isMandatory) {
      Navigator.of(context).pop();
    }
  }
}

class _VersionBadge extends StatelessWidget {
  final String label;
  final String version;
  final Color color;

  const _VersionBadge({
    required this.label,
    required this.version,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(
            version,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
