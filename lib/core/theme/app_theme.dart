import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import 'app_design_system.dart';

class AppTheme {
  AppTheme._();

  // ─── Light Theme ──────────────────────────────────────────────────────────
  static ThemeData lightTheme({required bool isArabicUi}) {
    final baseTextTheme =
        (isArabicUi ? GoogleFonts.cairoTextTheme : GoogleFonts.poppinsTextTheme)(
            ThemeData.light().textTheme);
    final titleFont = isArabicUi ? GoogleFonts.amiri : GoogleFonts.cinzel;
    final bodyFont = isArabicUi ? GoogleFonts.cairo : GoogleFonts.poppins;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
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

      // ── AppBar ──────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 2,
        shadowColor: AppColors.primary.withValues(alpha: 0.15),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        centerTitle: true,
        titleTextStyle: titleFont(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.onPrimary,
          letterSpacing: isArabicUi ? 0 : 0.8,
        ),
      ),

      // ── Typography ──────────────────────────────────────────────
      textTheme: baseTextTheme.copyWith(
        headlineLarge: bodyFont(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        headlineMedium: bodyFont(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        titleLarge: bodyFont(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        titleMedium: bodyFont(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        bodyLarge: bodyFont(
          fontSize: 15,
          fontWeight: FontWeight.normal,
          color: AppColors.textPrimary,
        ),
        bodyMedium: bodyFont(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: AppColors.textPrimary,
        ),
        bodySmall: bodyFont(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: AppColors.textSecondary,
        ),
        labelLarge: bodyFont(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
        labelSmall: bodyFont(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
      ),

      // ── Card ────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: AppDesignSystem.elevationSm,
        shadowColor: AppColors.primary.withValues(alpha: 0.06),
        color: AppColors.cardBackground,
        margin: AppDesignSystem.cardMargin,
        shape: RoundedRectangleBorder(
          borderRadius: AppDesignSystem.borderRadiusLg,
          side: BorderSide(color: AppColors.cardBorder, width: 1),
        ),
      ),

      // ── ElevatedButton ──────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: AppDesignSystem.elevationMd,
          shadowColor: AppColors.primary.withValues(alpha: 0.25),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: AppDesignSystem.borderRadiusMd,
          ),
          textStyle: bodyFont(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── OutlinedButton ──────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: AppDesignSystem.borderRadiusMd,
          ),
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          textStyle: bodyFont(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── TextButton ──────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: bodyFont(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── FilledButton ────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: AppDesignSystem.borderRadiusMd,
          ),
        ),
      ),

      // ── ListTile ────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        iconColor: AppColors.primary,
        titleTextStyle: bodyFont(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        subtitleTextStyle: bodyFont(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: AppColors.textSecondary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppDesignSystem.borderRadiusMd,
        ),
      ),

      // ── Switch ──────────────────────────────────────────────────
      // switchTheme: SwitchThemeData(
      //   thumbColor: WidgetStateProperty.resolveWith((s) {
      //     if (s.contains(WidgetState.selected)) return AppColors.primary;
      //     return Colors.white;
      //   }),
      //   trackColor: WidgetStateProperty.resolveWith((s) {
      //     if (s.contains(WidgetState.selected)) {
      //       return AppColors.primary.withValues(alpha: 0.3);
      //     }
      //     return Colors.grey.shade300;
      //   }),
      // ),

      // ── Slider ──────────────────────────────────────────────────
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: AppColors.primary.withValues(alpha: 0.15),
        thumbColor: AppColors.primary,
        overlayColor: AppColors.primary.withValues(alpha: 0.1),
        valueIndicatorColor: AppColors.primary,
        valueIndicatorTextStyle: bodyFont(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.onPrimary,
        ),
      ),

      // ── BottomNavigationBar ─────────────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textHint,
        selectedLabelStyle: bodyFont(
          fontSize: AppDesignSystem.bottomNavFontSize,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: bodyFont(
          fontSize: AppDesignSystem.bottomNavFontSize,
          fontWeight: FontWeight.w500,
        ),
        selectedIconTheme: const IconThemeData(
          size: AppDesignSystem.bottomNavIconSize,
        ),
        unselectedIconTheme: const IconThemeData(
          size: AppDesignSystem.bottomNavIconSize,
        ),
        elevation: 0,
      ),

      // ── BottomSheet ─────────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
        dragHandleColor: AppColors.divider,
      ),

      // ── Dialog ──────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: AppDesignSystem.borderRadiusXl,
        ),
        backgroundColor: AppColors.surface,
        titleTextStyle: bodyFont(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),

      // ── InputDecoration ─────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: AppDesignSystem.borderRadiusMd,
          borderSide: BorderSide(color: AppColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppDesignSystem.borderRadiusMd,
          borderSide: BorderSide(color: AppColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppDesignSystem.borderRadiusMd,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppDesignSystem.borderRadiusMd,
          borderSide: const BorderSide(color: AppColors.error),
        ),
        hintStyle: bodyFont(
          fontSize: 14,
          color: AppColors.textHint,
        ),
      ),

      // ── SnackBar ────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: AppDesignSystem.borderRadiusMd,
        ),
        backgroundColor: AppColors.primary,
        contentTextStyle: bodyFont(
          fontSize: 14,
          color: Colors.white,
        ),
      ),

      // ── Divider ─────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 0.8,
        space: 0,
      ),

      // ── Segmented Button ────────────────────────────────────────
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? Colors.white
                : AppColors.primary,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? AppColors.primary
                : Colors.white,
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: AppDesignSystem.borderRadiusSm,
            ),
          ),
          textStyle: WidgetStatePropertyAll(
            bodyFont(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ),

      // ── Chip (for filters) ──────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.primary.withValues(alpha: 0.07),
        selectedColor: AppColors.primary,
        labelStyle: bodyFont(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppDesignSystem.borderRadiusXl,
        ),
        side: BorderSide(
          color: AppColors.primary.withValues(alpha: 0.2),
        ),
      ),

      // ── Tooltip ─────────────────────────────────────────────────
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.textPrimary,
          borderRadius: AppDesignSystem.borderRadiusSm,
        ),
        textStyle: bodyFont(fontSize: 12, color: AppColors.onPrimary),
      ),

      // ── ProgressIndicator ───────────────────────────────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: Color(0x220D5E3A),
      ),
    );
  }

  // ─── Dark Theme ───────────────────────────────────────────────────────────
  static ThemeData darkTheme({required bool isArabicUi}) {
    final baseTextTheme =
        (isArabicUi ? GoogleFonts.cairoTextTheme : GoogleFonts.poppinsTextTheme)(
            ThemeData.dark().textTheme);
    final titleFont = isArabicUi ? GoogleFonts.amiri : GoogleFonts.cinzel;
    final bodyFont = isArabicUi ? GoogleFonts.cairo : GoogleFonts.poppins;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.darkSurface,
        error: AppColors.error,
        onPrimary: AppColors.onPrimary,
        onSecondary: AppColors.onSecondary,
        onSurface: AppColors.darkTextPrimary,
        onError: AppColors.onError,
        surfaceContainerHighest: AppColors.darkCard,
      ),
      scaffoldBackgroundColor: AppColors.darkBackground,

      // ── AppBar ──────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 2,
        shadowColor: Colors.black26,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        centerTitle: true,
        titleTextStyle: titleFont(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.onPrimary,
          letterSpacing: isArabicUi ? 0 : 0.8,
        ),
      ),

      // ── Typography ──────────────────────────────────────────────
      textTheme: baseTextTheme.copyWith(
        headlineLarge: bodyFont(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AppColors.darkTextPrimary,
        ),
        headlineMedium: bodyFont(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.darkTextPrimary,
        ),
        titleLarge: bodyFont(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.darkTextPrimary,
        ),
        titleMedium: bodyFont(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.darkTextPrimary,
        ),
        bodyLarge: bodyFont(
          fontSize: 15,
          fontWeight: FontWeight.normal,
          color: AppColors.darkTextPrimary,
        ),
        bodyMedium: bodyFont(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: AppColors.darkTextPrimary,
        ),
        bodySmall: bodyFont(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: AppColors.darkTextSecondary,
        ),
        labelLarge: bodyFont(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryLight,
        ),
        labelSmall: bodyFont(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.darkTextSecondary,
        ),
      ),

      // ── Card ────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: AppDesignSystem.elevationSm,
        shadowColor: Colors.black12,
        color: AppColors.darkCard,
        margin: AppDesignSystem.cardMargin,
        shape: RoundedRectangleBorder(
          borderRadius: AppDesignSystem.borderRadiusLg,
          side: BorderSide(color: AppColors.darkBorder, width: 1),
        ),
      ),

      // ── ElevatedButton ──────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: AppDesignSystem.elevationMd,
          shadowColor: Colors.black26,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: AppDesignSystem.borderRadiusMd,
          ),
          textStyle: bodyFont(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── OutlinedButton ──────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: AppDesignSystem.borderRadiusMd,
          ),
          side: BorderSide(color: AppColors.primaryLight, width: 1.5),
          textStyle: bodyFont(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── TextButton ──────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
          textStyle: bodyFont(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── FilledButton ────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: AppDesignSystem.borderRadiusMd,
          ),
        ),
      ),

      // ── ListTile ────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        iconColor: AppColors.primaryLight,
        titleTextStyle: bodyFont(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.darkTextPrimary,
        ),
        subtitleTextStyle: bodyFont(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: AppColors.darkTextSecondary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppDesignSystem.borderRadiusMd,
        ),
      ),

      // ── Switch ──────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return AppColors.primaryLight;
          return AppColors.darkTextSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) {
            return AppColors.primary.withValues(alpha: 0.4);
          }
          return AppColors.darkBorder;
        }),
      ),

      // ── Slider ──────────────────────────────────────────────────
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.primaryLight,
        inactiveTrackColor: AppColors.primaryLight.withValues(alpha: 0.2),
        thumbColor: AppColors.primaryLight,
        overlayColor: AppColors.primaryLight.withValues(alpha: 0.1),
        valueIndicatorColor: AppColors.primary,
        valueIndicatorTextStyle: bodyFont(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.onPrimary,
        ),
      ),

      // ── BottomNavigationBar ─────────────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.darkSurface,
        selectedItemColor: AppColors.primaryLight,
        unselectedItemColor: AppColors.darkTextSecondary,
        selectedLabelStyle: bodyFont(
          fontSize: AppDesignSystem.bottomNavFontSize,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: bodyFont(
          fontSize: AppDesignSystem.bottomNavFontSize,
          fontWeight: FontWeight.w500,
        ),
        selectedIconTheme: const IconThemeData(
          size: AppDesignSystem.bottomNavIconSize,
        ),
        unselectedIconTheme: const IconThemeData(
          size: AppDesignSystem.bottomNavIconSize,
        ),
        elevation: 0,
      ),

      // ── BottomSheet ─────────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.darkSurface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
        dragHandleColor: AppColors.darkBorder,
      ),

      // ── Dialog ──────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: AppDesignSystem.borderRadiusXl,
        ),
        backgroundColor: AppColors.darkCard,
        titleTextStyle: bodyFont(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.darkTextPrimary,
        ),
      ),

      // ── InputDecoration ─────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkBackground,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: AppDesignSystem.borderRadiusMd,
          borderSide: BorderSide(color: AppColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppDesignSystem.borderRadiusMd,
          borderSide: BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppDesignSystem.borderRadiusMd,
          borderSide: BorderSide(color: AppColors.primaryLight, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppDesignSystem.borderRadiusMd,
          borderSide: const BorderSide(color: AppColors.error),
        ),
        hintStyle: bodyFont(
          fontSize: 14,
          color: AppColors.darkTextSecondary,
        ),
      ),

      // ── SnackBar ────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: AppDesignSystem.borderRadiusMd,
        ),
        backgroundColor: AppColors.darkCard,
        contentTextStyle: bodyFont(
          fontSize: 14,
          color: AppColors.darkTextPrimary,
        ),
      ),

      // ── Divider ─────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.darkDivider,
        thickness: 0.8,
        space: 0,
      ),

      // ── Segmented Button ────────────────────────────────────────
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? Colors.white
                : AppColors.primaryLight,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? AppColors.primary : null,
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: AppDesignSystem.borderRadiusSm,
            ),
          ),
          textStyle: WidgetStatePropertyAll(
            bodyFont(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ),

      // ── Chip ────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
        selectedColor: AppColors.primary,
        labelStyle: bodyFont(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryLight,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppDesignSystem.borderRadiusXl,
        ),
        side: BorderSide(
          color: AppColors.primary.withValues(alpha: 0.25),
        ),
      ),

      // ── Tooltip ─────────────────────────────────────────────────
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.darkTextPrimary,
          borderRadius: AppDesignSystem.borderRadiusSm,
        ),
        textStyle: bodyFont(fontSize: 12, color: AppColors.darkBackground),
      ),

      // ── ProgressIndicator ───────────────────────────────────────
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.primaryLight,
        linearTrackColor: AppColors.primaryLight.withValues(alpha: 0.15),
      ),
    );
  }
}
