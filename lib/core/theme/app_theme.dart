import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class AppTheme {
  static ThemeData lightTheme({required bool isArabicUi}) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        error: AppColors.error,
        onPrimary: AppColors.onPrimary,
        onSecondary: AppColors.onSecondary,
        onSurface: AppColors.onSurface,
        onError: AppColors.onError,
        surfaceContainerHighest: AppColors.surfaceVariant,
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: AppBarTheme(
        elevation: 4,
        shadowColor: AppColors.secondary.withValues(alpha: 0.3),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        titleTextStyle: (isArabicUi ? GoogleFonts.amiri : GoogleFonts.cinzel)(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.onPrimary,
          letterSpacing: isArabicUi ? 0 : 1.2,
        ),
      ),
      textTheme:
          (isArabicUi
                  ? GoogleFonts.cairoTextTheme
                  : GoogleFonts.poppinsTextTheme)(ThemeData.light().textTheme)
              .copyWith(
                bodySmall:
                    (isArabicUi ? GoogleFonts.cairo : GoogleFonts.poppins)(
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                      color: AppColors.textSecondary,
                    ),
              ),
      cardTheme: CardThemeData(
        elevation: 3,
        shadowColor: AppColors.secondary.withValues(alpha: 0.15),
        color: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: AppColors.cardBorder,
            width: 1.5,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 4,
          shadowColor: AppColors.secondary.withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: (isArabicUi ? GoogleFonts.cairo : GoogleFonts.poppins)(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 16,
      ),
    );
  }

  static ThemeData darkTheme({required bool isArabicUi}) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.darkSurface,
        error: AppColors.error,
        onPrimary: AppColors.onPrimary,
        onSecondary: AppColors.onSecondary,
        onSurface: Color(0xFFE8DCC8),
        onError: AppColors.onError,
        surfaceContainerHighest: AppColors.darkCard,
      ),
      scaffoldBackgroundColor: AppColors.darkBackground,
      appBarTheme: AppBarTheme(
        elevation: 4,
        shadowColor: AppColors.secondary.withValues(alpha: 0.2),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        titleTextStyle: (isArabicUi ? GoogleFonts.amiri : GoogleFonts.cinzel)(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.onPrimary,
          letterSpacing: isArabicUi ? 0 : 1.2,
        ),
      ),
      textTheme:
          (isArabicUi
                  ? GoogleFonts.cairoTextTheme
                  : GoogleFonts.poppinsTextTheme)(ThemeData.dark().textTheme)
              .copyWith(
                bodySmall:
                    (isArabicUi ? GoogleFonts.cairo : GoogleFonts.poppins)(
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                      color: const Color(0xFFB0B0B0),
                    ),
              ),
      cardTheme: CardThemeData(
        elevation: 3,
        shadowColor: AppColors.secondary.withValues(alpha: 0.1),
        color: AppColors.darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: AppColors.darkBorder,
            width: 1.5,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 4,
          shadowColor: AppColors.secondary.withValues(alpha: 0.3),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: (isArabicUi ? GoogleFonts.cairo : GoogleFonts.poppins)(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.darkBorder,
        thickness: 1,
        space: 16,
      ),
    );
  }
}
