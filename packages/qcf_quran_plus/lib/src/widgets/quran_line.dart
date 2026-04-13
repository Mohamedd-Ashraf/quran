import 'package:flutter/material.dart';
import '../../qcf_quran_plus.dart';

/// Renders a single line of Quran text using QCF fonts with highlight support.
///
/// **Performance optimizations applied:**
/// - All heavy text processing (trim, substring, glyph lookup) is moved
///   to `initState` and `didUpdateWidget`.
/// - Processing happens **once** per line instead of 60 times a second during UI rendering.
/// - Removed `Isolate` because package functions (like getaya_noQCF) may contain
///   unsendable objects (like Completers). Synchronous caching is fast enough to prevent jank.
class QuranLine extends StatefulWidget {
  const QuranLine(
      this.line,
      this.bookmarks, {
        super.key,
        this.boxFit = BoxFit.fill,
        this.onLongPress,
        this.onTap,
        this.onWordTap,
        this.ayahStyle,
        this.isTajweed = true,
        this.isDark = false,
      });

  final Line line;
  final List<HighlightVerse> bookmarks;
  final BoxFit boxFit;
  final void Function(int surahNumber, int verseNumber, LongPressStartDetails details)? onLongPress;
  final void Function(int surahNumber, int verseNumber)? onTap;

  /// Called when the user taps a single word in word-by-word mode.
  /// [wordIndex] is 1-based within the ayah.
  final void Function(int surahNumber, int verseNumber, int wordIndex)? onWordTap;

  final TextStyle? ayahStyle;
  final bool isTajweed;
  final bool isDark;

  @override
  State<QuranLine> createState() => _QuranLineState();
}

class _QuranLineState extends State<QuranLine> {
  /// Pre-processed data (text, glyph, etc.) stored in memory
  late List<_AyahDisplayData> _displayData;

  @override
  void initState() {
    super.initState();
    _displayData = _processData();
  }
  List<_AyahDisplayData> _processData() {
    return widget.line.ayahs.reversed.map((ayah) {
      final currentQcfText = ayah.qcfData.trimRight();
      final glyph = getaya_noQCF(ayah.surahNumber, ayah.ayahNumber);
      final hasGlyph = currentQcfText.endsWith(glyph);

      final textWithoutGlyph = hasGlyph
          ? currentQcfText.substring(0, currentQcfText.length - glyph.length)
          : currentQcfText;

      return _AyahDisplayData(
        textWithoutGlyph: textWithoutGlyph,
        glyph: glyph,
        hasGlyph: hasGlyph,
        surahNumber: ayah.surahNumber,
        ayahNumber: ayah.ayahNumber,
        wordStartIndex: ayah.wordStartIndex,
      );
    }).toList();
  }

  @override
  void didUpdateWidget(covariant QuranLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-process only if the actual line data has changed
    if (oldWidget.line != widget.line) {
      setState(() {
        _displayData = _processData();
      });
    }
  }

  /// Processes text strings ONCE synchronously.
  /// This eliminates scroll jank without the need for Isolates.

  @override
  Widget build(BuildContext context) {
    // If empty (safety check), return invisible box
    if (_displayData.isEmpty) {
      return const SizedBox.shrink();
    }

    final defaultStyle = QuranTextStyles.qcfStyle(
      fontSize: 23.55,
      height: 1.45,
      pageNumber: widget.line.ayahs.first.page,
    );

    final finalStyle = widget.ayahStyle != null
        ? defaultStyle.merge(widget.ayahStyle!)
        : defaultStyle;

    ColorFilter? textFilter;
    if (widget.isDark && widget.isTajweed) {
      textFilter = const ColorFilter.matrix([
        -1, 0, 0, 0, 255,
        0, -1, 0, 0, 255,
        0, 0, -1, 0, 255,
        0, 0, 0, 1, 0,
      ]);
    } else if (widget.isDark && !widget.isTajweed) {
      textFilter = const ColorFilter.mode(Colors.white, BlendMode.srcIn);
    } else if (!widget.isDark && !widget.isTajweed) {
      textFilter = const ColorFilter.mode(Colors.black, BlendMode.srcIn);
    }
    final highlightMap = {
      for (var h in widget.bookmarks)
        '${h.surah}_${h.verseNumber}': h
    };
    final textWidget = RichText(
      text: TextSpan(
        // Build is now ultra-light and fast!
        children: _displayData.map((data) {
          final highlight = highlightMap['${data.surahNumber}_${data.ayahNumber}'];

          final isHighlighted = highlight?.color != Colors.transparent;

          TextStyle mainTextStyle = finalStyle.copyWith(height: null);
          if (textFilter != null) {
            mainTextStyle = mainTextStyle.copyWith(color: null).merge(
              TextStyle(foreground: Paint()..colorFilter = textFilter),
            );
          }

          TextStyle numberTextStyle = finalStyle.copyWith(height: null);
          if (widget.isDark) {
            numberTextStyle = numberTextStyle.copyWith(color: null).merge(
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

          // ── Word-by-word mode ──────────────────────────────────────────────
          // When onWordTap is provided, render each QCF glyph character as its
          // own tappable widget so the user can tap individual words.
          if (widget.onWordTap != null) {
            return _buildWordByWordSpan(
              data: data,
              mainTextStyle: mainTextStyle,
              numberTextStyle: numberTextStyle,
              isHighlighted: isHighlighted,
              highlight: highlight,
            );
          }

          // ── Normal (ayah-level) rendering ──────────────────────────────────
          final ayahTextWidget = Text.rich(
        TextSpan(
              children: [
                TextSpan(text: data.textWithoutGlyph, style: mainTextStyle),
                if (data.hasGlyph) TextSpan(text: data.glyph, style: numberTextStyle),
              ],
            ),
          );

          return WidgetSpan(
            child: GestureDetector(
              onTap: () => widget.onTap?.call(data.surahNumber, data.ayahNumber),
              onLongPressStart: (details) =>
                  widget.onLongPress?.call(data.surahNumber, data.ayahNumber, details),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4.0),
                  color: isHighlighted ? highlight?.color.withValues(alpha: 0.4) : null,
                ),
                child: ayahTextWidget,
              ),
            ),
          );
        }).toList(),
        style: finalStyle,
      ),
    );

    return FittedBox(
      fit: widget.boxFit,
      child: textWidget,
    );
  }

  /// Builds a [WidgetSpan] where each QCF glyph character is individually
  /// tappable, enabling word-by-word audio playback.
  WidgetSpan _buildWordByWordSpan({
    required _AyahDisplayData data,
    required TextStyle mainTextStyle,
    required TextStyle numberTextStyle,
    required bool isHighlighted,
    required HighlightVerse? highlight,
  }) {
    // Build one widget per character in textWithoutGlyph:
    // - non-space chars  → each is a tappable word with its own GestureDetector
    // - space chars      → rendered as plain text (layout separator)
    // The verse-number glyph is appended at the end (non-tappable).
    int wordIdx = data.wordStartIndex;
    final wordWidgets = <Widget>[];

    for (final rune in data.textWithoutGlyph.runes) {
      final char = String.fromCharCode(rune);
      if (char == ' ') {
        // Layout separator – not a separate Quranic word.
        wordWidgets.add(Text(char, style: mainTextStyle));
      } else {
        final capturedSurah = data.surahNumber;
        final capturedAyah  = data.ayahNumber;
        final capturedIdx   = ++wordIdx; // 1-based within the ayah
        wordWidgets.add(
          GestureDetector(
            onTap: () => widget.onWordTap?.call(capturedSurah, capturedAyah, capturedIdx),
            onLongPressStart: (details) =>
                widget.onLongPress?.call(capturedSurah, capturedAyah, details),
            child: Text(char, style: mainTextStyle),
          ),
        );
      }
    }

    // Verse-number glyph at the end (not a word, not tappable for audio).
    if (data.hasGlyph) {
      wordWidgets.add(Text(data.glyph, style: numberTextStyle));
    }

    return WidgetSpan(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4.0),
          color: isHighlighted ? highlight?.color.withValues(alpha: 0.4) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          textDirection: TextDirection.rtl,
          children: wordWidgets,
        ),
      ),
    );
  }
}

/// Lightweight immutable data class.
/// Contains everything needed to build the spans instantly.
class _AyahDisplayData {
  final String textWithoutGlyph;
  final String glyph;
  final bool hasGlyph;
  final int surahNumber;
  final int ayahNumber;

  /// 0-based index of the first word in this (sub-)ayah within its parent ayah.
  /// Needed to compute correct 1-based word indices for word-by-word audio.
  final int wordStartIndex;

  const _AyahDisplayData({
    required this.textWithoutGlyph,
    required this.glyph,
    required this.hasGlyph,
    required this.surahNumber,
    required this.ayahNumber,
    required this.wordStartIndex,
  });
}