import 'package:flutter/material.dart';

/// All 17 tajweed rule types from https://alquran.cloud/tajweed-guide.
///
/// The API encodes rules as bracket tags: `[X:optionalId[text]`
/// where X is a single letter identifying the rule.
enum TajweedRule {
  hamzaWasl,            // [h — همزة الوصل
  laamShamsiyyah,       // [l — لام شمسية
  silent,               // [s — حرف ساكن
  maddaNormal,          // [n — مد طبيعي
  maddaPermissible,     // [p — مد جائز
  maddaNecessary,       // [m — مد لازم
  maddaObligatory,      // [o — مد واجب
  qalqala,              // [q — قلقلة
  ikhfa,                // [f — إخفاء
  ikhfaShafawi,         // [c — إخفاء شفوي
  idghamShafawi,        // [w — إدغام شفوي
  iqlab,                // [i — إقلاب
  idghamWithGhunnah,    // [a — إدغام بغنة
  idghamWithoutGhunnah, // [u — إدغام بلا غنة
  idghamMutajanisayn,   // [d — إدغام متجانسين
  idghamMutaqaribayn,   // [b — إدغام متقاربين
  ghunnah,              // [g — غنة
}

/// A single segment of parsed tajweed text — either plain or colored.
class TajweedSegment {
  final String text;
  final TajweedRule? rule;

  const TajweedSegment(this.text, [this.rule]);

  bool get isPlain => rule == null;
}

// ─── Color maps (exact hex values from alquran.cloud/tajweed-guide) ─────────

const Map<TajweedRule, Color> kTajweedColorsLight = {
  TajweedRule.hamzaWasl:            Color(0xFFAAAA00), // grey — display as dark-ish for light bg
  TajweedRule.laamShamsiyyah:       Color(0xFFAAAA00), // grey
  TajweedRule.silent:               Color(0xFFAAAA00), // grey
  TajweedRule.maddaNormal:          Color(0xFF537FFF), // blue
  TajweedRule.maddaPermissible:     Color(0xFF4050FF), // blue-violet
  TajweedRule.maddaNecessary:       Color(0xFF000EBC), // dark blue
  TajweedRule.maddaObligatory:      Color(0xFF2144C1), // blue
  TajweedRule.qalqala:              Color(0xFFDD0008), // red
  TajweedRule.ikhfa:                Color(0xFF9400A8), // purple
  TajweedRule.ikhfaShafawi:         Color(0xFFD500B7), // pink
  TajweedRule.idghamShafawi:        Color(0xFF58B800), // green
  TajweedRule.iqlab:                Color(0xFF26BFFD), // cyan
  TajweedRule.idghamWithGhunnah:    Color(0xFF169777), // teal
  TajweedRule.idghamWithoutGhunnah: Color(0xFF169200), // green
  TajweedRule.idghamMutajanisayn:   Color(0xFFA1A1A1), // grey
  TajweedRule.idghamMutaqaribayn:   Color(0xFFA1A1A1), // grey
  TajweedRule.ghunnah:              Color(0xFFFF7E1E), // orange
};

/// Dark-mode colors — brighter variants for readability on dark surfaces.
const Map<TajweedRule, Color> kTajweedColorsDark = {
  TajweedRule.hamzaWasl:            Color(0xFFCCCCCC),
  TajweedRule.laamShamsiyyah:       Color(0xFFCCCCCC),
  TajweedRule.silent:               Color(0xFFCCCCCC),
  TajweedRule.maddaNormal:          Color(0xFF7FA3FF),
  TajweedRule.maddaPermissible:     Color(0xFF7B8AFF),
  TajweedRule.maddaNecessary:       Color(0xFF5566E8),
  TajweedRule.maddaObligatory:      Color(0xFF5B7DE8),
  TajweedRule.qalqala:              Color(0xFFFF4444),
  TajweedRule.ikhfa:                Color(0xFFC44CDD),
  TajweedRule.ikhfaShafawi:         Color(0xFFFF44DD),
  TajweedRule.idghamShafawi:        Color(0xFF7FE040),
  TajweedRule.iqlab:                Color(0xFF5ADDFF),
  TajweedRule.idghamWithGhunnah:    Color(0xFF40CCA0),
  TajweedRule.idghamWithoutGhunnah: Color(0xFF40CC44),
  TajweedRule.idghamMutajanisayn:   Color(0xFFCCCCCC),
  TajweedRule.idghamMutaqaribayn:   Color(0xFFCCCCCC),
  TajweedRule.ghunnah:              Color(0xFFFF9F55),
};

/// Human-readable Arabic names for the color legend.
const Map<TajweedRule, String> kTajweedRuleNamesAr = {
  TajweedRule.ghunnah:              'غنة',
  TajweedRule.ikhfa:                'إخفاء',
  TajweedRule.ikhfaShafawi:         'إخفاء شفوي',
  TajweedRule.iqlab:                'إقلاب',
  TajweedRule.idghamWithGhunnah:    'إدغام بغنة',
  TajweedRule.idghamWithoutGhunnah: 'إدغام بلا غنة',
  TajweedRule.idghamShafawi:        'إدغام شفوي',
  TajweedRule.idghamMutajanisayn:   'إدغام متجانسين',
  TajweedRule.idghamMutaqaribayn:   'إدغام متقاربين',
  TajweedRule.qalqala:              'قلقلة',
  TajweedRule.maddaNormal:          'مد طبيعي',
  TajweedRule.maddaPermissible:     'مد جائز',
  TajweedRule.maddaObligatory:      'مد واجب',
  TajweedRule.maddaNecessary:       'مد لازم',
  TajweedRule.hamzaWasl:            'همزة الوصل',
  TajweedRule.laamShamsiyyah:       'لام شمسية',
  TajweedRule.silent:               'حرف ساكن',
};

/// Brief Arabic description for each tajweed rule, shown in the legend.
const Map<TajweedRule, String> kTajweedRuleDescriptionsAr = {
  TajweedRule.ghunnah:
      'صوت رنّان يخرج من الخيشوم مع النون والميم المشددتين — مدّته حركتان',
  TajweedRule.ikhfa:
      'يُخفى صوت النون الساكنة أو التنوين عند أحرف الإخفاء الخمسة عشر مع الغنة',
  TajweedRule.ikhfaShafawi:
      'تُخفى الميم الساكنة عند حرف الباء مع غنة خفيفة',
  TajweedRule.iqlab:
      'تُقلب النون الساكنة أو التنوين ميماً خفية عند الباء مع الغنة',
  TajweedRule.idghamWithGhunnah:
      'تُدغم النون الساكنة أو التنوين في حروف (ي ن م و) مع غنة',
  TajweedRule.idghamWithoutGhunnah:
      'تُدغم النون الساكنة أو التنوين في اللام والراء بغير غنة',
  TajweedRule.idghamShafawi:
      'تُدغم الميم الساكنة في الميم التالية مع غنة',
  TajweedRule.idghamMutajanisayn:
      'إدغام حرف في حرف من مخرجه لكن صفاتهما مختلفة (مثل ت+ط)',
  TajweedRule.idghamMutaqaribayn:
      'إدغام حرف في حرف يقاربه مخرجاً وصفةً (مثل ق+ك)',
  TajweedRule.qalqala:
      'اضطراب ونبذ في الصوت عند سكون أحد حروف (قطب جد) — خاصةً عند الوقف',
  TajweedRule.maddaNormal:
      'مد الحروف الثلاثة (ا و ي) مدةً طبيعية حركتين بغير سبب',
  TajweedRule.maddaPermissible:
      'مد عند التقاء حرف المد بهمز في كلمتين — جائز من ٢ إلى ٦ حركات',
  TajweedRule.maddaObligatory:
      'مد حرف المد إذا جاء الهمز في نفس الكلمة — واجب ٤ أو ٥ حركات',
  TajweedRule.maddaNecessary:
      'مد حرف مد أو لين يعقبه سكون أصلي — لازم ٦ حركات دائماً',
  TajweedRule.hamzaWasl:
      'همزة زائدة في أول الكلمة تُنطق ابتداءً وتسقط وصلاً',
  TajweedRule.laamShamsiyyah:
      'لام (أل) تُدغم في الحرف الشمسي التالي فلا تُلفظ',
  TajweedRule.silent:
      'حرف لا يُلفظ في حالة الوصل أو الوقف — يُكتب ولا يُقرأ',
};

/// Rules displayed in the legend bottom sheet (grouped logically).
const List<TajweedRule> kLegendRules = [
  TajweedRule.ghunnah,
  TajweedRule.ikhfa,
  TajweedRule.ikhfaShafawi,
  TajweedRule.iqlab,
  TajweedRule.idghamWithGhunnah,
  TajweedRule.idghamWithoutGhunnah,
  TajweedRule.idghamShafawi,
  TajweedRule.idghamMutajanisayn,
  TajweedRule.idghamMutaqaribayn,
  TajweedRule.qalqala,
  TajweedRule.maddaNormal,
  TajweedRule.maddaPermissible,
  TajweedRule.maddaObligatory,
  TajweedRule.maddaNecessary,
  TajweedRule.hamzaWasl,
  TajweedRule.laamShamsiyyah,
  TajweedRule.silent,
];

// ─── Tag mapping ────────────────────────────────────────────────────────────

/// Maps the single-letter tag from the API to its [TajweedRule].
TajweedRule? _letterToRule(String tag) {
  final letter = tag.isNotEmpty ? tag[0] : '';
  switch (letter) {
    case 'h': return TajweedRule.hamzaWasl;
    case 'l': return TajweedRule.laamShamsiyyah;
    case 's': return TajweedRule.silent;
    case 'n': return TajweedRule.maddaNormal;
    case 'p': return TajweedRule.maddaPermissible;
    case 'm': return TajweedRule.maddaNecessary;
    case 'o': return TajweedRule.maddaObligatory;
    case 'q': return TajweedRule.qalqala;
    case 'f': return TajweedRule.ikhfa;
    case 'c': return TajweedRule.ikhfaShafawi;
    case 'w': return TajweedRule.idghamShafawi;
    case 'i': return TajweedRule.iqlab;
    case 'a': return TajweedRule.idghamWithGhunnah;
    case 'u': return TajweedRule.idghamWithoutGhunnah;
    case 'd': return TajweedRule.idghamMutajanisayn;
    case 'b': return TajweedRule.idghamMutaqaribayn;
    case 'g': return TajweedRule.ghunnah;
    default:  return null;
  }
}

/// Priority for choosing dominant rule per word (lower = higher priority).
/// Grey/silent rules have lowest priority so colorful rules take precedence.
const Map<TajweedRule, int> _rulePriority = {
  TajweedRule.ghunnah:              1,
  TajweedRule.ikhfa:                2,
  TajweedRule.ikhfaShafawi:         3,
  TajweedRule.iqlab:                4,
  TajweedRule.idghamWithGhunnah:    5,
  TajweedRule.idghamWithoutGhunnah: 6,
  TajweedRule.idghamShafawi:        7,
  TajweedRule.idghamMutajanisayn:   8,
  TajweedRule.idghamMutaqaribayn:   9,
  TajweedRule.qalqala:              10,
  TajweedRule.maddaNecessary:       11,
  TajweedRule.maddaObligatory:      12,
  TajweedRule.maddaPermissible:     13,
  TajweedRule.maddaNormal:          14,
  TajweedRule.hamzaWasl:            20,
  TajweedRule.laamShamsiyyah:       21,
  TajweedRule.silent:               22,
};

// ─── Regex-based parser ─────────────────────────────────────────────────────

/// Matches all tajweed bracket tags: `[h:N[text]`, `[l[text]`, `[n[text]`, etc.
/// Group 1 = full tag letter+optional colon+digits (e.g. "h:1", "l", "n", "m")
/// Group 2 = the enclosed text
final RegExp _tajweedTagRegex = RegExp(
  r'\[([a-z](?::\d+)?)\[([^\]]*)\]',
  unicode: true,
);

/// Parses raw tajweed-edition text into a list of [TajweedSegment]s.
///
/// Plain text is returned as segments with `rule == null`.
/// Tagged text is returned with its corresponding [TajweedRule].
List<TajweedSegment> parseTajweedText(String raw) {
  if (raw.isEmpty) return const [];

  final segments = <TajweedSegment>[];
  int cursor = 0;

  for (final match in _tajweedTagRegex.allMatches(raw)) {
    if (match.start > cursor) {
      final plain = raw.substring(cursor, match.start);
      if (plain.isNotEmpty) segments.add(TajweedSegment(plain));
    }
    final tag = match.group(1)!;
    final text = match.group(2)!;
    if (text.isNotEmpty) {
      final rule = _letterToRule(tag);
      segments.add(TajweedSegment(text, rule));
    }
    cursor = match.end;
  }

  if (cursor < raw.length) {
    final tail = raw.substring(cursor);
    if (tail.isNotEmpty) segments.add(TajweedSegment(tail));
  }

  return segments;
}

/// Returns `true` if the text contains any tajweed bracket markers.
bool hasTajweedMarkers(String text) => _tajweedTagRegex.hasMatch(text);

// ─── TextSpan builder (for Normal Font mode) ────────────────────────────────

List<TextSpan> buildTajweedSpans({
  required String text,
  required TextStyle baseStyle,
  required bool isDark,
}) {
  final segments = parseTajweedText(text);
  if (segments.isEmpty) return [TextSpan(text: text, style: baseStyle)];

  final colorMap = isDark ? kTajweedColorsDark : kTajweedColorsLight;

  // ── Merge combining-only segments into the preceding segment ─────────────
  // Flutter's text shaper cannot combine Unicode diacritics (e.g. U+0670
  // superscript alef) across TextSpan boundaries, causing them to render as
  // isolated floating glyphs (the "circle" above letters).
  // Fix: if a segment's text is entirely Arabic combining marks, append its
  // characters to the preceding segment so they share the same span and the
  // shaper keeps them attached to their base letter.
  final merged = <TajweedSegment>[];
  for (final seg in segments) {
    if (merged.isNotEmpty && _isCombiningOnly(seg.text)) {
      final prev = merged.last;
      merged[merged.length - 1] = TajweedSegment(prev.text + seg.text, prev.rule);
    } else {
      merged.add(seg);
    }
  }

  final spans = <TextSpan>[];
  for (final seg in merged) {
    if (seg.isPlain) {
      spans.add(TextSpan(text: seg.text, style: baseStyle));
    } else {
      final ruleColor = colorMap[seg.rule];
      if (ruleColor != null) {
        spans.add(TextSpan(
          text: seg.text,
          style: baseStyle.copyWith(color: ruleColor),
        ));
      } else {
        spans.add(TextSpan(text: seg.text, style: baseStyle));
      }
    }
  }

  return spans;
}

/// Returns true when every code-point in [text] is an Arabic combining mark
/// (diacritics, superscript alef, waqf signs, etc.) — i.e. no base letter.
bool _isCombiningOnly(String text) {
  if (text.isEmpty) return false;
  return text.runes.every(_isArabicCombining);
}

bool _isArabicCombining(int cp) =>
    (cp >= 0x0610 && cp <= 0x061A) || // Arabic combining ext-A
    (cp >= 0x064B && cp <= 0x065F) || // Arabic tashkeel (fatha, damma, …)
    cp == 0x0670 ||                    // Superscript alef ـٰ (the circle culprit)
    (cp >= 0x06D6 && cp <= 0x06DC) || // Arabic small high letters / waqf
    (cp >= 0x06DF && cp <= 0x06E4) || // Arabic small high letters
    cp == 0x06E7 || cp == 0x06E8 ||
    (cp >= 0x06EA && cp <= 0x06ED);   // Arabic ligature marks

// ─── QCF word-level tajweed helpers ─────────────────────────────────────────

/// Waqf sign Unicode range (U+06D6–U+06DC) — these appear as separate QCF
/// glyphs but are embedded at word-end in the tajweed API text.
bool _isWaqfSign(int codeUnit) => codeUnit >= 0x06D6 && codeUnit <= 0x06DC;

/// Strips all tajweed bracket markup, leaving only the visible Arabic text.
String _stripTajweedTags(String raw) {
  return raw.replaceAllMapped(_tajweedTagRegex, (m) => m.group(2) ?? '');
}

/// Picks the highest-priority (most prominent) tajweed rule from a word.
TajweedRule? _dominantRule(String wordMarkup) {
  TajweedRule? best;
  int bestPri = 999;
  for (final m in _tajweedTagRegex.allMatches(wordMarkup)) {
    final rule = _letterToRule(m.group(1)!);
    if (rule == null) continue;
    final pri = _rulePriority[rule] ?? 50;
    if (pri < bestPri) {
      bestPri = pri;
      best = rule;
    }
  }
  return best;
}

/// Given the raw tajweed-edition text of a single verse, returns a map of
/// QCF word-glyph index → Color, accounting for:
///   - waqf signs being separate QCF glyphs but embedded in API words
///   - Rub el Hizb (۞) symbol
///   - picking the most prominent rule per word
///
/// The returned indices correspond to non-newline characters in the QCF glyph
/// string (excluding the final verse-end symbol which the caller strips).
Map<int, Color> extractWordColors(String tajweedText, bool isDark) {
  if (tajweedText.isEmpty) return const {};
  final colorMap = isDark ? kTajweedColorsDark : kTajweedColorsLight;
  final result = <int, Color>{};

  final apiWords = tajweedText.split(' ');
  int qcfIndex = 0;

  for (int i = 0; i < apiWords.length; i++) {
    final rawWord = apiWords[i];
    final plainWord = _stripTajweedTags(rawWord);

    // Find the dominant tajweed rule for this word
    final rule = _dominantRule(rawWord);
    if (rule != null) {
      final color = colorMap[rule];
      if (color != null) result[qcfIndex] = color;
    }
    qcfIndex++;

    // Check if this word ends with a waqf sign (possibly preceded by ZWNJ).
    // In QCF, the waqf is a separate glyph, so we advance the index.
    if (plainWord.isNotEmpty) {
      final lastUnit = plainWord.codeUnits.last;
      if (_isWaqfSign(lastUnit)) {
        // The waqf glyph — no color (it's just a pause marker)
        qcfIndex++;
      } else if (plainWord.length >= 2) {
        // Sometimes ZWNJ (U+200C) sits between the word and waqf
        final secondLast = plainWord.codeUnits[plainWord.length - 2];
        if (_isWaqfSign(secondLast)) {
          qcfIndex++;
        }
      }
    }
  }

  return result;
}

/// Builds colored [InlineSpan]s for a QCF glyph string.
///
/// Each non-newline character = one word glyph. `\n` = line break.
/// [wordColors] maps glyph index → color (from [extractWordColors]).
List<InlineSpan> buildQcfTajweedSpans(
  String verseText,
  Map<int, Color> wordColors,
) {
  if (verseText.isEmpty) return const [];
  final spans = <InlineSpan>[];
  int wordIndex = 0;
  for (int i = 0; i < verseText.length; i++) {
    final char = verseText[i];
    if (char == '\n') {
      spans.add(const TextSpan(text: '\n'));
      continue;
    }
    final color = wordColors[wordIndex];
    spans.add(TextSpan(
      text: char,
      style: color != null ? TextStyle(color: color) : null,
    ));
    wordIndex++;
  }
  return spans;
}
