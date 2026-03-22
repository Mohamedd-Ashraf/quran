import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ─── Primary Palette (Islamic Green) ──────────────────────────────────────
  static const Color primary = Color(0xFF0D5E3A);
  static const Color primaryDark = Color(0xFF064428);
  static const Color primaryLight = Color(0xFF1A8A58);

  // ─── Secondary Palette (Islamic Gold) ─────────────────────────────────────
  static const Color secondary = Color(0xFFD4AF37);
  static const Color accent = Color(0xFFB8860B);
  static const Color tertiary = Color(0xFF8B4513);

  // ─── Light Theme Surfaces ─────────────────────────────────────────────────
  static const Color background = Color(0xFFF8F6F2);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFFAF8F5);

  // ─── Semantic / Functional ────────────────────────────────────────────────
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF9A825);
  static const Color info = Color(0xFF1976D2);

  // ─── On-Colors ────────────────────────────────────────────────────────────
  static const Color onPrimary = Color(0xFFFFFDF7);
  static const Color onSecondary = Color(0xFF212121);
  static const Color onBackground = Color(0xFF2C2416);
  static const Color onSurface = Color(0xFF2C2416);
  static const Color onError = Color(0xFFFFFFFF);

  // ─── Text ─────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF2C2416);
  static const Color textSecondary = Color(0xFF6B5C47);
  static const Color textHint = Color(0xFF9E8E78);

  // ─── Dividers & Borders ───────────────────────────────────────────────────
  static const Color divider = Color(0xFFD4C4B0);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFE8DCC8);

  // ─── Arabic Text ──────────────────────────────────────────────────────────
  static const Color arabicText = Color(0xFF0D5E3A);

  // ─── Gradients ────────────────────────────────────────────────────────────
  static const Color gradientStart = Color(0xFF0D5E3A);
  static const Color gradientMid = Color(0xFF1B7A4A);
  static const Color gradientEnd = Color(0xFF2E8B57);

  static const Color goldGradientStart = Color(0xFFD4AF37);
  static const Color goldGradientEnd = Color(0xFFF4D03F);

  // ─── Dark Theme Surfaces (softer, eye-friendly) ───────────────────────────
  static const Color darkBackground = Color(0xFF141A21);   // Softer than pure #0F1419
  static const Color darkSurface = Color(0xFF1C232B);      // Slightly warmer
  static const Color darkCard = Color(0xFF242D37);          // Warmer card bg
  static const Color darkBorder = Color(0xFF3A4550);        // Softer border
  static const Color darkTextPrimary = Color(0xFFE4DDD0);   // Warm cream text
  static const Color darkTextSecondary = Color(0xFF9DA5AD);  // Muted but readable
  static const Color darkDivider = Color(0xFF2E3740);       // Subtle dividers

  // ─── Convenience Gradient ─────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gradientStart, gradientMid, gradientEnd],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [goldGradientStart, goldGradientEnd],
  );
}

