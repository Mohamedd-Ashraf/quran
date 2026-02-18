import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

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
}
