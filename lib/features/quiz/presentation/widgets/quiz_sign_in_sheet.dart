import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/screens/auth_screen.dart';

/// Shows a modal bottom sheet asking the user to sign in before accessing
/// quiz features. Navigates to [AuthScreen] if they confirm.
///
/// [onAuthenticated] is called after successful authentication so the caller
/// can proceed with the intended navigation.
Future<void> showQuizSignInSheet(
  BuildContext context, {
  required bool isArabic,
  required VoidCallback onAuthenticated,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _QuizSignInSheet(
      isArabic: isArabic,
      onAuthenticated: onAuthenticated,
    ),
  );
}

class _QuizSignInSheet extends StatelessWidget {
  final bool isArabic;
  final VoidCallback onAuthenticated;

  const _QuizSignInSheet({
    required this.isArabic,
    required this.onAuthenticated,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        left: 24,
        right: 24,
        top: 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBorder : AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 28),

          // Icon with gradient background
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: Colors.white,
              size: 44,
            ),
          ),
          const SizedBox(height: 24),

          // Title
          Text(
            isArabic ? 'تسجيل الدخول مطلوب' : 'Sign In Required',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),

          // Subtitle
          Text(
            isArabic
                ? 'للمشاركة في المسابقة اليومية وظهورك\nفي لوحة المتصدرين، يلزمك تسجيل الدخول أولاً.'
                : 'You need to sign in to participate in the\ndaily quiz and appear on the leaderboard.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),

          // Feature highlights
          _FeatureTile(
            icon: Icons.quiz_rounded,
            text: isArabic
                ? 'سؤال ديني يومي يتحداك'
                : 'A new religious challenge every day',
            isDark: isDark,
          ),
          _FeatureTile(
            icon: Icons.local_fire_department,
            text: isArabic
                ? 'تتبّع سلسلة أيامك المتواصلة'
                : 'Track your daily answer streak',
            isDark: isDark,
          ),
          _FeatureTile(
            icon: Icons.leaderboard_rounded,
            text: isArabic
                ? 'تنافس مع المسلمين حول العالم'
                : 'Compete with Muslims worldwide',
            isDark: isDark,
          ),

          const SizedBox(height: 28),

          // Sign-in button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AuthScreen(
                      onAuthComplete: onAuthenticated,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                shadowColor: AppColors.primary.withValues(alpha: 0.4),
              ),
              child: Text(
                isArabic
                    ? 'تسجيل الدخول / إنشاء حساب'
                    : 'Sign In / Create Account',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Later button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                isArabic ? 'لاحقًا' : 'Maybe Later',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isDark;

  const _FeatureTile({
    required this.icon,
    required this.text,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
              ),
            ),
          ),
          Icon(
            Icons.check_circle_rounded,
            color: AppColors.secondary,
            size: 18,
          ),
        ],
      ),
    );
  }
}
