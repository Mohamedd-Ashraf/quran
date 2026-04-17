import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';

/// Helper class to split Arabic text into text spans with different colors
/// for base text and diacritics (tashkeel)
class ArabicTextStyleHelper {
  /// Arabic diacritics Unicode range
  /// Includes: Fatha, Damma, Kasra, Sukun, Shadda, Tanween, etc.
  static final RegExp _diacriticsRegex = RegExp(r'[\u064B-\u065F\u0670]');

  /// Split Arabic text into TextSpans with different colors for diacritics
  ///
  /// [text] - The Arabic text to split
  /// [baseStyle] - TextStyle for base letters
  /// [diacriticsStyle] - TextStyle for diacritics (can have different color)
  static List<TextSpan> buildColoredTextSpans({
    required String text,
    required TextStyle baseStyle,
    required TextStyle diacriticsStyle,
  }) {
    final List<TextSpan> spans = [];
    final StringBuffer baseBuffer = StringBuffer();
    final StringBuffer diacriticsBuffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      final char = text[i];

      if (_diacriticsRegex.hasMatch(char)) {
        // This is a diacritic
        // First, add any accumulated base text
        if (baseBuffer.isNotEmpty) {
          spans.add(TextSpan(text: baseBuffer.toString(), style: baseStyle));
          baseBuffer.clear();
        }

        // Add diacritic to buffer
        diacriticsBuffer.write(char);

        // Look ahead - if next char is not a diacritic, flush the buffer
        if (i == text.length - 1 || !_diacriticsRegex.hasMatch(text[i + 1])) {
          spans.add(
            TextSpan(text: diacriticsBuffer.toString(), style: diacriticsStyle),
          );
          diacriticsBuffer.clear();
        }
      } else {
        // This is a base character
        // First, flush any accumulated diacritics
        if (diacriticsBuffer.isNotEmpty) {
          spans.add(
            TextSpan(text: diacriticsBuffer.toString(), style: diacriticsStyle),
          );
          diacriticsBuffer.clear();
        }

        // Add to base buffer
        baseBuffer.write(char);
      }
    }

    // Flush any remaining text
    if (baseBuffer.isNotEmpty) {
      spans.add(TextSpan(text: baseBuffer.toString(), style: baseStyle));
    }
    if (diacriticsBuffer.isNotEmpty) {
      spans.add(
        TextSpan(text: diacriticsBuffer.toString(), style: diacriticsStyle),
      );
    }

    return spans;
  }

  /// Build a TextSpan from Arabic text with optional different color for diacritics
  ///
  /// [text] - The Arabic text
  /// [baseStyle] - TextStyle for base letters
  /// [useDifferentColorForDiacritics] - Whether to use different color for diacritics
  /// [diacriticsColor] - Color to use for diacritics (if different)
  /// [recognizer] - Optional gesture recognizer for the entire text
  static TextSpan buildTextSpan({
    required String text,
    required TextStyle baseStyle,
    bool useDifferentColorForDiacritics = false,
    Color? diacriticsColor,
    GestureRecognizer? recognizer,
  }) {
    print('📝 buildTextSpan called:');
    print('   useDifferentColorForDiacritics: $useDifferentColorForDiacritics');
    print('   diacriticsColor: $diacriticsColor');
    print('   baseStyle.color: ${baseStyle.color}');

    if (!useDifferentColorForDiacritics || diacriticsColor == null) {
      // Use same color for everything
      print('   ➡️ Using SAME color for everything');
      return TextSpan(text: text, style: baseStyle, recognizer: recognizer);
    }

    // Use different color for diacritics
    final diacriticsStyle = baseStyle.copyWith(color: diacriticsColor);
    print(
      '   ➡️ Using DIFFERENT color - diacriticsStyle.color: ${diacriticsStyle.color}',
    );

    final spans = buildColoredTextSpans(
      text: text,
      baseStyle: baseStyle,
      diacriticsStyle: diacriticsStyle,
    );

    // Apply recognizer to each child span so taps work
    if (recognizer != null) {
      final spansWithRecognizer = spans.map((span) {
        return TextSpan(
          text: span.text,
          style: span.style,
          recognizer: recognizer,
        );
      }).toList();
      return TextSpan(children: spansWithRecognizer);
    }

    return TextSpan(children: spans);
  }

  /// Returns a [TextStyle] for the given Quran font key.
  /// Falls back to Amiri Quran if the key is unrecognised.
  ///
  /// Supported keys: 'amiri_quran', 'amiri', 'scheherazade', 'noto_naskh',
  ///   'lateef', 'markazi', 'noto_kufi', 'reem_kufi', 'tajawal', 'cairo'
  static TextStyle quranFontStyle({
    required String fontKey,
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
  }) {
    final size   = fontSize   ?? 24.0;
    final weight = fontWeight ?? FontWeight.w400;

    TextStyle base;
    switch (fontKey) {
      case 'scheherazade':
        // ScheherazadeNew is not bundled in assets/google_fonts/ — fall back
        // to Amiri Quran which is bundled and has full Quranic glyph coverage.
        base = GoogleFonts.amiriQuran(
            fontSize: size, fontWeight: weight, height: height);
      case 'amiri':
      //TODO: consider switching to Amiri Regular for non-Quran text, as it has better readability and more complete glyph coverage than Amiri Quran
        base = GoogleFonts.cairo(
            fontSize: size, fontWeight: weight, height: height);
      case 'noto_naskh':
        // Bundled variants: Regular (w400), SemiBold (w600), Bold (w700).
        // Clamp w500 (Medium) to w400 to avoid missing-font exceptions.
        final notoWeight = weight == FontWeight.w500 ? FontWeight.w400 : weight;
        base = GoogleFonts.notoNaskhArabic(
            fontSize: size, fontWeight: notoWeight, height: height);
      case 'lateef':
        base = GoogleFonts.lateef(
            fontSize: size, fontWeight: weight, height: height);
      case 'markazi':
        base = GoogleFonts.markaziText(
            fontSize: size, fontWeight: weight, height: height);
      case 'noto_kufi':
        base = GoogleFonts.notoKufiArabic(
            fontSize: size, fontWeight: weight, height: height);
      case 'reem_kufi':
        base = GoogleFonts.reemKufi(
            fontSize: size, fontWeight: weight, height: height);
      case 'tajawal':
        base = GoogleFonts.tajawal(
            fontSize: size, fontWeight: weight, height: height);
      case 'cairo':
        // Cairo lacks full Quranic glyph coverage.
        // Use Amiri Quran as fallback (bundled) for Quranic diacritics.
        // ScheherazadeNew is NOT bundled — do not call GoogleFonts.scheherazadeNew()
        // as it triggers an async load that throws at runtime.
        final cairoStyle = GoogleFonts.cairo(
            fontSize: size, fontWeight: weight, height: height);
        final aq = GoogleFonts.amiriQuran().fontFamily;
        base = cairoStyle.copyWith(
          fontFamilyFallback: [
            if (aq != null) aq,
            ...?cairoStyle.fontFamilyFallback,
          ],
        );
      case 'amiri_quran':
      default:
        base = GoogleFonts.amiriQuran(
            fontSize: size, fontWeight: weight, height: height);
    }

    return color != null ? base.copyWith(color: color) : base;
  }
}
