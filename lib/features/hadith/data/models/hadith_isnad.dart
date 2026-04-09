/// A single link in an isnad (chain of narration).
class IsnadNarrator {
  /// 1-based position in the chain (collector → ... → Prophet ﷺ).
  final int order;

  /// The transmission verb used to receive the narration.
  /// Examples: حَدَّثَنَا / حَدَّثَنِي / أَخْبَرَنِي / سَمِعْتُ / عَنْ / أَنَّهُ سَمِعَ
  final String transmissionVerb;

  /// The narrator's name and any accompanying descriptor
  /// (e.g. نسب, كنية, رضي الله عنه, صلى الله عليه وسلم).
  final String name;

  const IsnadNarrator({
    required this.order,
    required this.transmissionVerb,
    required this.name,
  });

  Map<String, dynamic> toMap() => {
        'order': order,
        'transmissionVerb': transmissionVerb,
        'name': name,
      };

  @override
  String toString() => '$order. [$transmissionVerb] $name';
}

/// Parses a raw Arabic sanad string into a structured [IsnadNarrator] list.
///
/// Supports both fully-diacritical text (e.g. from `ara-bukhari.json`) and
/// diacritics-stripped text (e.g. from `ara-bukhari1.json`).
///
/// ### Example
/// ```dart
/// const sanad = 'حَدَّثَنَا الْحُمَيْدِيُّ ... سَمِعْتُ رَسُولَ اللَّهِ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ';
/// final chain = IsnadParser.parse(sanad);
/// // chain[0] → [حَدَّثَنَا] الْحُمَيْدِيُّ عَبْدُ اللَّهِ بْنُ الزُّبَيْرِ
/// // chain[1] → [حَدَّثَنَا] سُفْيَانُ
/// // ...
/// // chain[6] → [سَمِعْتُ] رَسُولَ اللَّهِ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ
/// ```
class IsnadParser {
  IsnadParser._();

  /// Known transmission verbs — diacritical forms checked first.
  static const _verbs = <String>[
    // With diacritics
    'حَدَّثَنَا',
    'حَدَّثَنِي',
    'أَخْبَرَنَا',
    'أَخْبَرَنِي',
    'أَخْبَرَهُ',
    'سَمِعْتُ',
    'سَمِعَ',
    'عَنْ',
    // Without diacritics
    'حدثنا',
    'حدثني',
    'أخبرنا',
    'أخبرني',
    'أخبره',
    'سمعت',
    'سمع',
    'عن',
  ];

  /// Splits the sanad into narrator segments at قال: / يقول: boundaries.
  static final _primarySplitter = RegExp(
    r'\s*[،,]\s*(?:قَالَ|قَالَتْ|يَقُولُ|قال|قالت|يقول)\s*:?\s*',
  );

  /// Secondary split for أنه سمع constructs embedded inside a segment.
  static final _secondarySplitter = RegExp(
    r'\s*[،,]\s*(?:أَنَّهُ سَمِعَ|أنه سمع)\s+',
  );

  // ─── Public API ────────────────────────────────────────────────────────────

  /// Parse [sanad] into an ordered list of [IsnadNarrator]s.
  ///
  /// Returns an empty list when [sanad] is blank.
  static List<IsnadNarrator> parse(String sanad) {
    if (sanad.trim().isEmpty) return const [];

    final narrators = <IsnadNarrator>[];
    int order = 1;

    for (final seg in sanad.split(_primarySplitter)) {
      final trimmed = seg.trim();
      if (trimmed.isEmpty) continue;

      // Handle أنه سمع sub-pattern embedded in this segment
      final subParts = trimmed.split(_secondarySplitter);
      if (subParts.length > 1) {
        _addNarrator(subParts.first.trim(), narrators, order++);
        for (int i = 1; i < subParts.length; i++) {
          _addNarrator(
            subParts[i].trim(),
            narrators,
            order++,
            fallbackVerb: 'أَنَّهُ سَمِعَ',
          );
        }
        continue;
      }

      _addNarrator(trimmed, narrators, order++);
    }

    return narrators;
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  static void _addNarrator(
    String segment,
    List<IsnadNarrator> out,
    int order, {
    String fallbackVerb = '',
  }) {
    if (segment.isEmpty) return;

    for (final verb in _verbs) {
      if (segment.startsWith(verb)) {
        final name = _clean(segment.substring(verb.length));
        if (name.isNotEmpty) {
          out.add(IsnadNarrator(
            order: order,
            transmissionVerb: verb,
            name: name,
          ));
        }
        return;
      }
    }

    // No known verb found — store as-is with fallback label
    final name = _clean(segment);
    if (name.isNotEmpty) {
      out.add(IsnadNarrator(
        order: order,
        transmissionVerb: fallbackVerb,
        name: name,
      ));
    }
  }

  /// Strip leading/trailing punctuation, quotes and whitespace.
  static String _clean(String s) => s
      .replaceAll(RegExp(r'^[\s،,]+'), '')
      .replaceAll(RegExp(r'["\u201c\u201d\s،,]+$'), '')
      .trim();
}
