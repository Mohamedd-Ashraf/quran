import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../practice/presentation/screens/practice_home_screen.dart';
import '../screens/quiz_screen.dart';
import 'quiz_sign_in_sheet.dart';

/// Entry-point modal for unauthenticated users.
///
/// Presents two paths:
///  1. **Practice Mode** – no sign-in required, goes to [PracticeHomeScreen].
///  2. **Daily Challenge** – sign-in required, funnels through [showQuizSignInSheet].
Future<void> showQuizModeEntrySheet(
  BuildContext context, {
  required bool isArabic,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _QuizModeEntrySheet(isArabic: isArabic),
  );
}

class _QuizModeEntrySheet extends StatelessWidget {
  final bool isArabic;
  const _QuizModeEntrySheet({required this.isArabic});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 36,
        left: 20,
        right: 20,
        top: 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle bar ──────────────────────────────────────────────────
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBorder : AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Title ───────────────────────────────────────────────────────
          Text(
            isArabic ? 'اختر طريقة المشاركة' : 'Choose how to play',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color:
                  isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isArabic
                ? 'يمكنك التمرين بدون حساب أو المشاركة في التحدي اليومي'
                : 'Practice without an account or join the daily challenge',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.55,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),

          // ── Practice Mode card ──────────────────────────────────────────
          _ModeCard(
            isDark: isDark,
            isArabic: isArabic,
            icon: Icons.school_rounded,
            iconColor: const Color(0xFF1565C0),
            iconBg: const Color(0xFFE3F0FF),
            iconBgDark: const Color(0xFF1A2B3D),
            title: isArabic ? 'وضع التمرين' : 'Practice Mode',
            subtitle: isArabic
                ? 'أسئلة متنوعة بدون مؤقت أو ضغط — لا يلزم تسجيل الدخول'
                : 'Varied questions, no pressure — no sign-in needed',
            badge: isArabic ? 'لا يتطلب تسجيل الدخول' : 'Sign in optional',
            badgeColor: const Color(0xFF1565C0),
            features: isArabic
                ? [
                    'اختر التصنيف والمستوى',
                    'تعلّم من الإجابات الصحيحة',
                    'تقدّم سريع بدون حساب',
                  ]
                : [
                    'Choose category & difficulty',
                    'Learn from correct answers',
                    'Quick progress, no account needed',
                  ],
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PracticeHomeScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 14),

          // ── Daily Challenge card ────────────────────────────────────────
          _ModeCard(
            isDark: isDark,
            isArabic: isArabic,
            icon: Icons.emoji_events_rounded,
            iconColor: const Color(0xFFC17900),
            iconBg: const Color(0xFFFFF8E1),
            iconBgDark: const Color(0xFF2D2000),
            title: isArabic ? 'التحدي اليومي' : 'Daily Challenge',
            subtitle: isArabic
                ? 'سؤال ديني يومي مع لوحة المتصدرين حول العالم'
                : 'Daily religious question with a global leaderboard',
            badge: isArabic ? 'يتطلب تسجيل الدخول' : 'Sign-in required',
            badgeColor: AppColors.primary,
            features: isArabic
                ? [
                    'سؤال جديد كل يوم',
                    'تتبّع سلسلة أيامك المتواصلة',
                    'تنافس مع المسلمين حول العالم',
                  ]
                : [
                    'Fresh question every day',
                    'Track your daily streak',
                    'Compete with Muslims worldwide',
                  ],
            onTap: () {
              Navigator.of(context).pop();
              // Re-use the existing sign-in sheet, then navigate to QuizScreen
              showQuizSignInSheet(
                context,
                isArabic: isArabic,
                onAuthenticated: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const QuizScreen()),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Mode card ────────────────────────────────────────────────────────────────

class _ModeCard extends StatelessWidget {
  final bool isDark;
  final bool isArabic;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final Color iconBgDark;
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final List<String> features;
  final VoidCallback onTap;

  const _ModeCard({
    required this.isDark,
    required this.isArabic,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.iconBgDark,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
    required this.features,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.darkCard : const Color(0xFFF8F9FA);
    final borderColor = isDark ? AppColors.darkBorder : const Color(0xFFE8E8E8);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon circle
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isDark ? iconBgDark : iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 14),

            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + badge row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: badgeColor.withValues(alpha: 0.35),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Subtitle
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Feature bullets
                  ...features.map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: badgeColor,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              f,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Chevron
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
