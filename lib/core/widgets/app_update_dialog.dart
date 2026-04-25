import 'dart:io' if (dart.library.html) '../services/stubs/mobile_platform_stub.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';
import '../theme/app_design_system.dart';
import '../models/app_update_info.dart';
import '../services/app_update_service.dart';

/// Dialog widget for showing app update notification (Google Play only)
class AppUpdateDialog extends StatelessWidget {
  static const String _androidPackageId = 'com.nooraliman.quran';
  static final Uri _marketUri =
      Uri.parse('market://details?id=$_androidPackageId');
  static final Uri _playStoreUri = Uri.parse(
    'https://play.google.com/store/apps/details?id=$_androidPackageId',
  );

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
    final theme = Theme.of(context);

    return PopScope(
      canPop: !updateInfo.isMandatory,
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: AppDesignSystem.borderRadiusXl,
        ),
        backgroundColor: AppColors.surface,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with gradient
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppDesignSystem.radiusXl),
                  ),
                ),
                padding: const EdgeInsets.all(AppDesignSystem.spacingXxl),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppDesignSystem.spacingMd),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_circle_filled_rounded,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: AppDesignSystem.spacingLg),
                    Text(
                      isArabic ? 'تحديث متاح' : 'Update Available',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: AppColors.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDesignSystem.spacingXs),
                    Text(
                      isArabic
                          ? 'يتوفر إصدار جديد على Google Play'
                          : 'A new version is available on Google Play',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.onPrimary.withValues(alpha: 0.9),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // Content (scrollable)
              Flexible(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDesignSystem.spacingXxl),
                    child: Column(
                      crossAxisAlignment: isArabic
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        // Version badges
                        _buildVersionBadges(isArabic),

                        // Mandatory badge
                        if (updateInfo.isMandatory || updateInfo.isBelowMinimum) ...[
                          const SizedBox(height: AppDesignSystem.spacingLg),
                          _buildMandatoryBadge(isArabic),
                        ],

                        // Changelog
                        if (changelog.isNotEmpty) ...[
                          const SizedBox(height: AppDesignSystem.spacingLg),
                          _buildChangelog(changelog, isArabic, theme),
                        ],

                        const SizedBox(height: AppDesignSystem.spacingXxl),

                        // Action buttons
                        _buildActions(context, isArabic),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVersionBadges(bool isArabic) {
    final textDirection = isArabic ? TextDirection.rtl : TextDirection.ltr;

    return Directionality(
      textDirection: textDirection,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Current version (start in reading order)
          _VersionBadge(
            label: isArabic ? 'الحالي' : 'Current',
            version: updateInfo.currentVersion,
            isCurrent: true,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDesignSystem.spacingMd,
            ),
            child: Icon(
              isArabic
                  ? Icons.arrow_back_rounded
                  : Icons.arrow_forward_rounded,
              color: AppColors.primary.withValues(alpha: 0.5),
              size: 20,
            ),
          ),
          // New version (end in reading order)
          _VersionBadge(
            label: isArabic ? 'الجديد' : 'New',
            version: updateInfo.latestVersion,
            isCurrent: false,
          ),
        ],
      ),
    );
  }

  Widget _buildMandatoryBadge(bool isArabic) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesignSystem.spacingLg,
        vertical: AppDesignSystem.spacingMd,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.error.withValues(alpha: 0.1),
            AppColors.error.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: AppDesignSystem.borderRadiusMd,
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_rounded,
            color: AppColors.error,
            size: 22,
          ),
          const SizedBox(width: AppDesignSystem.spacingSm),
          Expanded(
            child: Text(
              isArabic
                  ? 'تحديث إلزامي - يجب التحديث للاستمرار'
                  : 'Mandatory Update - Required to continue',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChangelog(String changelog, bool isArabic, ThemeData theme) {
    return Column(
      crossAxisAlignment:
          isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          isArabic ? 'ما الجديد:' : "What's New:",
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppDesignSystem.spacingSm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppDesignSystem.spacingLg),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: AppDesignSystem.borderRadiusMd,
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Text(
            changelog,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
            textAlign: isArabic ? TextAlign.right : TextAlign.left,
          ),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context, bool isArabic) {
    return Column(
      children: [
        // Update button
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _openGooglePlay(context),
            icon: const Icon(Icons.open_in_new_rounded),
            label: Text(isArabic ? 'فتح Google Play' : 'Open Google Play'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              padding: const EdgeInsets.symmetric(
                horizontal: AppDesignSystem.spacingXl,
                vertical: AppDesignSystem.spacingMd,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: AppDesignSystem.borderRadiusMd,
              ),
            ),
          ),
        ),

        // Later button (optional updates only)
        if (!updateInfo.isMandatory && !updateInfo.isBelowMinimum)
          Padding(
            padding: const EdgeInsets.only(top: AppDesignSystem.spacingSm),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await updateService.skipVersion(updateInfo.latestVersion);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                icon: const Icon(Icons.schedule_rounded),
                label: Text(isArabic ? 'لاحقاً' : 'Later'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDesignSystem.spacingXl,
                    vertical: AppDesignSystem.spacingMd,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppDesignSystem.borderRadiusMd,
                  ),
                  side: BorderSide(color: AppColors.cardBorder),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _openGooglePlay(BuildContext context) async {
    try {
      // Try market:// first on Android, fallback to web URL
      if (Platform.isAndroid && await canLaunchUrl(_marketUri)) {
        final opened = await launchUrl(
          _marketUri,
          mode: LaunchMode.externalApplication,
        );
        if (!opened) {
          await launchUrl(_playStoreUri, mode: LaunchMode.externalApplication);
        }
      } else {
        await launchUrl(_playStoreUri, mode: LaunchMode.externalApplication);
      }

      if (context.mounted && !updateInfo.isMandatory) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        final isArabicLang = languageCode.startsWith('ar');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isArabicLang
                  ? 'تعذر فتح Google Play'
                  : 'Could not open Google Play',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
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

class _VersionBadge extends StatelessWidget {
  final String label;
  final String version;
  final bool isCurrent;

  const _VersionBadge({
    required this.label,
    required this.version,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    final color = isCurrent ? AppColors.textHint : AppColors.primary;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDesignSystem.spacingLg,
            vertical: AppDesignSystem.spacingSm,
          ),
          decoration: BoxDecoration(
            color: isCurrent
                ? AppColors.surfaceVariant
                : AppColors.primary.withValues(alpha: 0.1),
            borderRadius: AppDesignSystem.borderRadiusMd,
            border: Border.all(
              color: isCurrent
                  ? AppColors.cardBorder
                  : AppColors.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            version,
            style: TextStyle(
              color: isCurrent ? AppColors.textSecondary : AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: AppDesignSystem.spacingXs),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
