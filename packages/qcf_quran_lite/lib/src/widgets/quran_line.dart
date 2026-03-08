import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../qcf_quran_lite.dart';
import '../models/highlight_verse.dart';
import '../models/quran_page.dart';

/// An internal widget responsible for precisely rendering a single line of Quranic text.
///
/// It correctly aligns the QCF font, applies requested styles, and overlays
/// highlight colors seamlessly without disrupting the ligature rendering.
class QuranLine extends StatelessWidget {
  const QuranLine(
    this.line,
    this.bookmarks, {
    super.key,
    this.boxFit = BoxFit.fill,
    this.onTap,
    this.onLongPress,
    this.ayahStyle,
  });

  /// The processed line containing the Ayahs to be displayed.
  final Line line;

  /// A list of active highlights (bookmarks) to overlay on specific verses.
  final List<HighlightVerse> bookmarks;

  /// Controls how the text scales to fit the available line width. Default is [BoxFit.fill].
  final BoxFit boxFit;

  /// Callback triggered when a verse in this line is tapped.
  final void Function(int surahNumber, int verseNumber)? onTap;

  /// Callback triggered when a verse in this line is long-pressed.
  final void Function(
    int surahNumber,
    int verseNumber,
    LongPressStartDetails details,
  )?
  onLongPress;

  /// Custom [TextStyle] provided by the developer to override color or font size.
  final TextStyle? ayahStyle;

  @override
  Widget build(BuildContext context) {
    final defaultStyle = QuranTextStyles.hafsStyle(
      color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
      fontSize: 23.55,
    );

    final finalStyle = ayahStyle != null
        ? defaultStyle.merge(ayahStyle)
        : defaultStyle;

    return FittedBox(
      fit: boxFit,
      child: RichText(
        text: TextSpan(
          children: line.ayahs.reversed.map((ayah) {
            final highlight = bookmarks.firstWhere(
              (h) =>
                  h.surah == ayah.surahNumber &&
                  h.verseNumber == ayah.ayahNumber,
              orElse: () => HighlightVerse(
                surah: 0,
                verseNumber: 0,
                page: 0,
                color: Colors.transparent,
              ),
            );

            bool isHighlighted = highlight.color != Colors.transparent;

            return WidgetSpan(
              child: GestureDetector(
                onTap: () => onTap?.call(ayah.surahNumber, ayah.ayahNumber),
                onLongPressStart: (details) => onLongPress?.call(
                  ayah.surahNumber,
                  ayah.ayahNumber,
                  details,
                ),
                child: Container(
                  decoration: isHighlighted
                      ? BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: highlight.color.withOpacity(0.18),
                          border: Border.all(
                            color: highlight.color.withOpacity(0.6),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: highlight.color.withOpacity(0.25),
                              blurRadius: 6,
                              spreadRadius: 0,
                            ),
                          ],
                        )
                      : null,
                  child: Text(
                    "${ayah.othmanicAyah}\u2009",
                    style: finalStyle.copyWith(height: null),
                  ),
                ),
              ),
            );
          }).toList(),
          style: finalStyle,
        ),
      ),
    );
  }
}
