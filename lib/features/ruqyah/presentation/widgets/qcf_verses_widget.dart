import 'package:flutter/material.dart';
import 'package:qcf_quran_plus/qcf_quran_plus.dart' show quran;

/// Widget to render multiple verses using QCF glyphs (Mushaf drawing style)
/// Uses qcfData from quran_data.dart which contains the actual Mushaf glyphs
class QcfVersesWidget extends StatelessWidget {
  final int surahNumber;
  final int firstVerse;
  final int lastVerse;
  final Color? textColor;
  final Color? verseNumberColor;
  final double fontSize;
  final double verseHeight;
  final TextAlign textAlign;
  final bool isDark;

  const QcfVersesWidget({
    super.key,
    required this.surahNumber,
    required this.firstVerse,
    required this.lastVerse,
    this.textColor,
    this.verseNumberColor,
    this.fontSize = 28,
    this.verseHeight = 2.0,
    this.textAlign = TextAlign.center,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      textDirection: TextDirection.rtl,
      textAlign: textAlign,
      locale: const Locale("ar"),
      text: TextSpan(
        children: _buildVerseSpans(),
        style: TextStyle(color: textColor),
      ),
    );
  }

  List<InlineSpan> _buildVerseSpans() {
    List<InlineSpan> spans = [];

    for (int verseNumber = firstVerse; verseNumber <= lastVerse; verseNumber++) {
      try {
        // Get verse data from quran list
        final verseData = _getVerseData(surahNumber, verseNumber);
        if (verseData == null) continue;

        // Get the QCF glyph data (the actual Mushaf drawing)
        String qcfText = verseData['qcfData']?.toString() ?? '';
        final pageNumber = verseData['page'] as int;

        if (qcfText.isEmpty) continue;

        // Trim the text
        qcfText = qcfText.trimRight();

        // Check if verse ends with newline
        final bool endsWithNewline = qcfText.endsWith('\n');
        if (endsWithNewline) {
          qcfText = qcfText.substring(0, qcfText.length - 1).trimRight();
        }

        // Extract verse number glyph (last character in qcfData)
        String verseNumberGlyph = '';
        String verseTextWithoutNumber = qcfText;

        if (qcfText.isNotEmpty) {
          verseNumberGlyph = qcfText.substring(qcfText.length - 1);
          verseTextWithoutNumber = qcfText.substring(0, qcfText.length - 1);
        }

        // Remove leading \n for first verse
        if (verseNumber == firstVerse && verseTextWithoutNumber.startsWith('\n')) {
          verseTextWithoutNumber = verseTextWithoutNumber.replaceFirst('\n', '');
        }

        // Build the font family name for this page
        String fontFamily = 'QCF4_tajweed_${pageNumber.toString().padLeft(3, '0')}';

        // Create text style with optional dark mode ColorFilter
        TextStyle baseStyle = TextStyle(
          fontFamily: fontFamily,
          fontSize: fontSize,
          height: verseHeight,
          color: textColor,
        );

        // Apply ColorFilter for dark mode (invert colors like qcf_quran_plus does)
        if (isDark) {
          baseStyle = baseStyle.copyWith(color: null).merge(
            TextStyle(
              foreground: Paint()
                ..colorFilter = const ColorFilter.matrix([
                  -1, 0, 0, 0, 255,
                  0, -1, 0, 0, 255,
                  0, 0, -1, 0, 255,
                  0, 0, 0, 1, 0,
                ]),
            ),
          );
        }

        // Create verse number style
        TextStyle numberStyle = TextStyle(
          fontFamily: fontFamily,
          fontSize: fontSize,
          height: verseHeight,
          color: verseNumberColor ?? textColor,
        );

        if (isDark) {
          numberStyle = numberStyle.copyWith(color: null).merge(
            TextStyle(
              foreground: Paint()
                ..colorFilter = const ColorFilter.matrix([
                  -1, 0, 0, 0, 255,
                  0, -1, 0, 0, 255,
                  0, 0, -1, 0, 255,
                  0, 0, 0, 1, 0,
                ]),
            ),
          );
        }

        // Add verse text span
        spans.add(
          TextSpan(
            text: verseTextWithoutNumber,
            style: baseStyle,
            children: [
              // Add verse number glyph
              if (verseNumberGlyph.isNotEmpty)
                TextSpan(
                  text: verseNumberGlyph,
                  style: numberStyle,
                ),
              // Add spacing after verse
              if (verseNumber != lastVerse)
                TextSpan(
                  text: ' ',
                  style: TextStyle(fontSize: fontSize * 0.5),
                ),
            ],
          ),
        );
      } catch (e) {
        // Skip verses that cause errors
        continue;
      }
    }

    return spans;
  }

  /// Helper to get verse data from quran list
  Map<String, dynamic>? _getVerseData(int surahNumber, int ayaNo) {
    try {
      for (var verse in quran) {
        if (verse['sora'] == surahNumber && verse['aya_no'] == ayaNo) {
          return verse as Map<String, dynamic>;
        }
      }
    } catch (_) {}
    return null;
  }
}

