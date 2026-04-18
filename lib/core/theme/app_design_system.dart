import 'package:flutter/material.dart';

/// Unified design tokens for consistent spacing, radii, and durations
/// across all screens. Import this alongside [AppColors] and [AppTheme].
class AppDesignSystem {
  AppDesignSystem._();

  // ─── Spacing ──────────────────────────────────────────────────────────────
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 12.0;
  static const double spacingLg = 16.0;
  static const double spacingXl = 20.0;
  static const double spacingXxl = 24.0;
  static const double spacingXxxl = 32.0;

  // ─── Page padding ─────────────────────────────────────────────────────────
  static const EdgeInsets pagePadding =
      EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0);
  static const EdgeInsets pagePaddingHorizontal =
      EdgeInsets.symmetric(horizontal: 16.0);

  // ─── Border Radius ────────────────────────────────────────────────────────
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  static const double radiusXxl = 24.0;
  static const double radiusFull = 100.0;

  static BorderRadius borderRadiusSm = BorderRadius.circular(radiusSm);
  static BorderRadius borderRadiusMd = BorderRadius.circular(radiusMd);
  static BorderRadius borderRadiusLg = BorderRadius.circular(radiusLg);
  static BorderRadius borderRadiusXl = BorderRadius.circular(radiusXl);
  static BorderRadius borderRadiusXxl = BorderRadius.circular(radiusXxl);

  // ─── Animation Durations ──────────────────────────────────────────────────
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 250);
  static const Duration durationSlow = Duration(milliseconds: 400);

  // ─── Elevation ────────────────────────────────────────────────────────────
  static const double elevationNone = 0.0;
  static const double elevationSm = 1.0;
  static const double elevationMd = 2.0;
  static const double elevationLg = 4.0;

  // ─── Icon Sizes ───────────────────────────────────────────────────────────
  static const double iconSizeSm = 16.0;
  static const double iconSizeMd = 20.0;
  static const double iconSizeLg = 24.0;

  // ─── Card Defaults ────────────────────────────────────────────────────────
  static const EdgeInsets cardMargin = EdgeInsets.only(bottom: 10.0);
  static const EdgeInsets cardPadding =
      EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0);

  // ─── Bottom Nav ───────────────────────────────────────────────────────────
  static const double bottomNavHeight = 64.0;
  static const double bottomNavIconSize = 22.0;
  static const double bottomNavFontSize = 11.0;

  // ─── Section Header ───────────────────────────────────────────────────────
  static const EdgeInsets sectionHeaderPadding =
      EdgeInsets.fromLTRB(2, 18, 2, 10);

  // ─── Section Gaps ─────────────────────────────────────────────────────────
  static const double sectionGap = 16.0;

  // ─── Standard Page Padding ────────────────────────────────────────────────
  static const EdgeInsets pagePaddingAll =
      EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 24.0);
}
