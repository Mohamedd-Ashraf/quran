import 'package:flutter/material.dart';
import 'package:qcf_quran_plus/qcf_quran_plus.dart' show quran, getaya_noQCF;

/// Widget to render multiple verses using QCF glyphs (Mushaf drawing style).
///
/// Each Mushaf line (separated by \n in qcfData) is rendered in its own
/// [FittedBox] so every line fills the full container width — exactly like
/// the QuranLine widget does on the full-page Mushaf view.
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
  // stripNewlines is kept for API compatibility but is no longer used.
  final bool stripNewlines;

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
    this.stripNewlines = false,
  });

  @override
  Widget build(BuildContext context) {
    final lineWidgets = _buildMushafLineWidgets();
    if (lineWidgets.isEmpty) return const SizedBox.shrink();

    return ExcludeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: lineWidgets,
      ),
    );
  }

  List<Widget> _buildMushafLineWidgets() {
    final widgets = <Widget>[];

    for (int verseNum = firstVerse; verseNum <= lastVerse; verseNum++) {
      try {
        final verseData = _getVerseData(surahNumber, verseNum);
        if (verseData == null) continue;

        String qcfText = verseData['qcfData']?.toString() ?? '';
        final pageNumber = verseData['page'] as int;
        if (qcfText.isEmpty) continue;

        // Trim trailing whitespace/newlines
        qcfText = qcfText.trimRight();

        // Remove leading \n that belongs to the previous verse's last Mushaf line
        if (verseNum == firstVerse && qcfText.startsWith('\n')) {
          qcfText = qcfText.substring(1);
        }

        final fontFamily =
            'QCF4_tajweed_${pageNumber.toString().padLeft(3, '0')}';

        // The verse-number circle glyph (always the last character)
        final String verseGlyph = getaya_noQCF(surahNumber, verseNum);
        final bool endsWithGlyph = qcfText.endsWith(verseGlyph);
        final String textBody = endsWithGlyph
            ? qcfText.substring(0, qcfText.length - verseGlyph.length)
            : qcfText;

        // Split into individual Mushaf page lines
        final List<String> mushafLines = textBody.split('\n');

        final TextStyle baseStyle = _makeStyle(fontFamily, textColor);
        final TextStyle glyphStyle =
            _makeStyle(fontFamily, verseNumberColor ?? textColor);

        for (int i = 0; i < mushafLines.length; i++) {
          final lineText = mushafLines[i];
          final bool isLastLine = i == mushafLines.length - 1;

          // Skip empty non-final lines (artifact of split)
          if (lineText.isEmpty && !isLastLine) continue;

          // The last line of each verse gets the circle-number glyph appended
          final Widget lineContent = isLastLine && endsWithGlyph
              ? Text.rich(
                  TextSpan(children: [
                    TextSpan(text: lineText, style: baseStyle),
                    TextSpan(text: verseGlyph, style: glyphStyle),
                  ]),
                  textDirection: TextDirection.rtl,
                  maxLines: 1,
                )
              : Text(
                  lineText,
                  textDirection: TextDirection.rtl,
                  style: baseStyle,
                  maxLines: 1,
                );

          // Use AlignmentDirectional so the layout respects the app's text
          // direction (RTL for Arabic) regardless of the device language.
          // - centerStart = right side in RTL → full Mushaf lines
          // - centerEnd   = left  side in RTL → last partial line (verse number)
          final alignment = (isLastLine && mushafLines.length > 1)
              ? AlignmentDirectional.centerStart
              : AlignmentDirectional.centerEnd;

          widgets.add(
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: alignment,
              child: lineContent,
            ),
          );
        }
      } catch (_) {
        continue;
      }
    }

    return widgets;
  }

  TextStyle _makeStyle(String fontFamily, Color? color) {
    TextStyle style = TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      height: verseHeight,
      color: color,
    );

    if (isDark) {
      style = style.copyWith(color: null).merge(
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

    return style;
  }

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

