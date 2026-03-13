import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/feedback_service.dart';
import '../../features/quran/presentation/screens/feedback_screen.dart';

/// Shows the feedback prompt dialog.
/// Navigates to [FeedbackScreen] if the user accepts.
/// Returns true if the user actually submitted feedback.
Future<bool> showFeedbackDialog({
  required BuildContext context,
  required FeedbackService feedbackService,
  String languageCode = 'ar',
}) async {
  final isArabic = languageCode.startsWith('ar');
  await feedbackService.markShown();

  if (!context.mounted) return false;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _FeedbackDialog(
      feedbackService: feedbackService,
      isArabic: isArabic,
    ),
  );

  return result == true;
}

class _FeedbackDialog extends StatefulWidget {
  final FeedbackService feedbackService;
  final bool isArabic;

  const _FeedbackDialog({
    required this.feedbackService,
    required this.isArabic,
  });

  @override
  State<_FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<_FeedbackDialog> {
  bool _navigating = false;

  Future<void> _openFeedbackScreen() async {
    if (_navigating) return;
    setState(() => _navigating = true);

    // Track whether the user actually submitted inside FeedbackScreen.
    bool wasSubmitted = false;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FeedbackScreen(
          onSubmitted: () => wasSubmitted = true,
        ),
      ),
    );

    if (!mounted) return;
    setState(() => _navigating = false);

    if (wasSubmitted) {
      await widget.feedbackService.markSubmitted();
      if (mounted) Navigator.of(context).pop(true);
    }
    // If user came back without submitting, dialog stays open so they can skip.
  }

  void _dismiss() => Navigator.of(context).pop(false);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isArabic = widget.isArabic;

    final cardColor = isDark ? AppColors.darkCard : theme.colorScheme.surface;
    final borderColor =
        isDark ? AppColors.darkBorder : AppColors.cardBorder;
    final bodyTextColor = theme.colorScheme.onSurface;
    final subtleTextColor = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final hadithBg = AppColors.secondary.withValues(alpha: isDark ? 0.12 : 0.08);
    final hadithBorder = AppColors.secondary.withValues(alpha: isDark ? 0.4 : 0.3);

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.secondary.withValues(alpha: isDark ? 0.08 : 0.15),
                blurRadius: 24,
                spreadRadius: 2,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header strip ──────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.gradientStart, AppColors.gradientEnd],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.secondary.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.volunteer_activism_rounded,
                        color: AppColors.goldGradientEnd,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        isArabic ? 'رأيك يهمّنا' : 'Your Feedback Matters',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: AppColors.onPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: _dismiss,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          color: AppColors.onPrimary.withValues(alpha: 0.7),
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Body ──────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Decorative gold divider
                    Container(
                      height: 2,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Colors.transparent,
                            AppColors.secondary,
                            Colors.transparent,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Main message
                    Text(
                      isArabic
                          ? 'شارك مقترحاتك أو أي ملاحظة تراها،\nوالدال على الخير كفاعله 🤍'
                          : 'Share your suggestions or any feedback you have.\nGuiding others to good is like doing it yourself 🤍',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: bodyTextColor,
                        height: 1.6,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Subtle hadith / encouragement
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: hadithBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: hadithBorder, width: 1),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.format_quote_rounded,
                              color: AppColors.secondary, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isArabic
                                  ? 'الدِّينُ النَّصِيحةُ — صحيح مسلم'
                                  : '"Religion is sincere advice." — Sahih Muslim',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.secondary,
                                fontStyle: FontStyle.italic,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // ── Action button ─────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _navigating ? null : _openFeedbackScreen,
                        icon: _navigating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 20),
                        label: Text(
                          isArabic ? 'شارك رأيك الآن' : 'Share Feedback Now',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    TextButton(
                      onPressed: _dismiss,
                      style: TextButton.styleFrom(
                        foregroundColor: subtleTextColor,
                      ),
                      child: Text(
                        isArabic ? 'لاحقاً' : 'Remind me later',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),

                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
