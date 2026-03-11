import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:qcf_quran/qcf_quran.dart';

class AppQcfPage extends StatelessWidget {
  final int pageNumber;
  final QcfThemeData theme;
  final double? fontSize;
  final double sp;
  final double h;
  final void Function(int surahNumber, int verseNumber, TapDownDetails details)?
      onTapDown;
  final void Function(int surahNumber, int verseNumber)? onTap;
  final Color? Function(int surahNumber, int verseNumber)? verseBackgroundColor;

  const AppQcfPage({
    super.key,
    required this.pageNumber,
    this.theme = const QcfThemeData(),
    this.fontSize,
    this.sp = 1.0,
    this.h = 1.0,
    this.onTapDown,
    this.onTap,
    this.verseBackgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    if (pageNumber < 1 || pageNumber > 604) {
      return Center(child: Text('Invalid page number: $pageNumber'));
    }

    final ranges = getPageData(pageNumber);
    final pageFont = 'QCF_P${pageNumber.toString().padLeft(3, '0')}';
    final baseFontSize = (fontSize ?? getFontSize(pageNumber, context)) * sp;
    final screenSize = MediaQuery.of(context).size;
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : screenSize.width;
        final double availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : screenSize.height;

        final List<Widget> blocks = [];
        final List<InlineSpan> currentSpans = [];

        void flushTextBlock() {
          if (currentSpans.isEmpty) return;
          final spans = List<InlineSpan>.of(currentSpans);
          currentSpans.clear();
          blocks.add(
            SizedBox(
              width: double.infinity,
              child: Padding(
                padding: EdgeInsets.zero,
                child: Text.rich(
                  TextSpan(children: spans),
                  locale: const Locale('ar'),
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontFamily: pageFont,
                    package: 'qcf_quran',
                    fontSize: isPortrait
                        ? baseFontSize
                        : (pageNumber == 1 || pageNumber == 2)
                            ? 20 * sp
                            : baseFontSize - (17 * sp),
                    color: theme.verseTextColor,
                    height: isPortrait
                        ? (pageNumber == 1 || pageNumber == 2)
                            ? 2.2 * h
                            : theme.verseHeight * h
                        : (pageNumber == 1 || pageNumber == 2)
                            ? 4 * h
                            : 4 * h,
                    letterSpacing: theme.letterSpacing,
                    wordSpacing: theme.wordSpacing,
                  ),
                ),
              ),
            ),
          );
        }

        if (pageNumber == 1 || pageNumber == 2) {
          blocks.add(SizedBox(height: screenSize.height * .175));
        }

        for (final r in ranges) {
          final surah = int.parse(r['surah'].toString());
          final start = int.parse(r['start'].toString());
          final end = int.parse(r['end'].toString());

          if (start == 1) {
            // Flush any verses from the previous surah into their own block.
            flushTextBlock();

            // Add the surah header and basmala as inline spans so they share
            // the same Text.rich line-height as the verse content — exactly
            // matching how QcfPage renders them.  Using separate widgets
            // (the old approach) gave them their natural heights, which are
            // much shorter than a full line-height, leaving blank space at
            // the bottom of every surah-opening page.
            if (theme.showHeader) {
              currentSpans.add(
                WidgetSpan(child: HeaderWidget(suraNumber: surah, theme: theme)),
              );
              currentSpans.add(const TextSpan(text: '\n'));
            }
            if (theme.showBasmala && pageNumber != 1 && pageNumber != 187) {
              if (theme.basmalaBuilder != null) {
                currentSpans.add(
                  WidgetSpan(child: theme.basmalaBuilder!(surah)),
                );
              } else {
                final bool largeScreen =
                    MediaQuery.of(context).size.width >= 600;
                currentSpans.add(
                  TextSpan(
                    text: ' ﱁ  ﱂﱃﱄ',
                    style: TextStyle(
                      fontFamily: 'QCF_P001',
                      package: 'qcf_quran',
                      fontSize: (largeScreen
                              ? theme.basmalaFontSizeLarge
                              : theme.basmalaFontSizeSmall) *
                          sp,
                      color: theme.basmalaColor,
                    ),
                  ),
                );
              }
              currentSpans.add(const TextSpan(text: '\n'));
            }
          }

          for (int v = start; v <= end; v++) {
            GestureRecognizer? recognizer;
            if (onTap != null) {
              final tapRecognizer = TapGestureRecognizer();
              tapRecognizer.onTap = () => onTap?.call(surah, v);
              tapRecognizer.onTapDown =
                  (details) => onTapDown?.call(surah, v, details);
              recognizer = tapRecognizer;
            }

            final verseBgColor =
                theme.verseBackgroundColor?.call(surah, v) ??
                    verseBackgroundColor?.call(surah, v);

            final rawQcf = getVerseQCF(surah, v, verseEndSymbol: true);
            final startsWithNewline = rawQcf.startsWith('\n');
            if (startsWithNewline && currentSpans.isNotEmpty) {
              currentSpans.add(const TextSpan(text: '\n'));
            }

            final stripped = startsWithNewline ? rawQcf.substring(1) : rawQcf;
            final trailingNewline = stripped.endsWith('\n');
            final noTrail = trailingNewline
                ? stripped.substring(0, stripped.length - 1)
                : stripped;
            final glyph = noTrail.isEmpty ? '' : noTrail[noTrail.length - 1];
            final verseText = noTrail.isEmpty ? '' : noTrail.substring(0, noTrail.length - 1);

            final InlineSpan verseNumberSpan = theme.verseNumberBuilder != null
                ? theme.verseNumberBuilder!(surah, v, glyph)
                : TextSpan(
                    text: glyph,
                    style: TextStyle(
                      fontFamily: pageFont,
                      package: 'qcf_quran',
                      color: theme.verseNumberColor,
                      height: theme.verseNumberHeight * h,
                      backgroundColor:
                          theme.verseNumberBackgroundColor ?? verseBgColor,
                    ),
                  );

            currentSpans.add(
              TextSpan(
                text: verseText,
                recognizer: recognizer,
                style: verseBgColor != null
                    ? TextStyle(backgroundColor: verseBgColor)
                    : null,
                children: [
                  verseNumberSpan,
                  if (trailingNewline) const TextSpan(text: '\n'),
                ],
              ),
            );
          }
        }

        flushTextBlock();

        return Scrollbar(
          child: SingleChildScrollView(
            child: SizedBox(
              height: availableHeight,
              width: availableWidth,
              child: ListView(
                shrinkWrap: true,
                children: blocks,
              ),
            ),
          ),
        );
      },
    );
  }
}