import 'hadith_isnad.dart';
import 'hadith_item.dart';
import 'hadith_list_item.dart';

/// A section (chapter) metadata from fawazahmed0/hadith-api.
class RemoteSection {
  final int sectionNumber;
  final String name;
  final int hadithFirst;
  final int hadithLast;

  const RemoteSection({
    required this.sectionNumber,
    required this.name,
    required this.hadithFirst,
    required this.hadithLast,
  });

  /// Number of hadiths in this section (0 if not yet known).
  int get count {
    if (hadithFirst <= 0 || hadithLast < hadithFirst) return 0;
    return (hadithLast - hadithFirst + 1).clamp(1, 9999);
  }

  /// Arabic name from the canonical Bukhari chapter list; falls back to [name].
  String get nameAr => _kBukhariNamesAr[sectionNumber] ?? name;

  /// Hardcoded list of all 96 books of Sahih al-Bukhari.
  /// The CDN per-section file only contains that section's own metadata so we
  /// embed the canonical chapter list directly in the app.
  static List<RemoteSection> hardcodedBukhari() {
    return _kBukhariData
        .map(
          (r) => RemoteSection(
            sectionNumber: r[0] as int,
            name: r[1] as String,
            hadithFirst: 0,
            hadithLast: 0,
          ),
        )
        .toList();
  }

  /// [sections] = { "1": "Revelation", "2": "Faith", ... }
  /// [sectionDetail] = { "1": { "hadithnumber_first": 1, "hadithnumber_last": 7 } ... }
  static List<RemoteSection> fromMetadata(
    Map<String, dynamic> sections,
    Map<String, dynamic> sectionDetail,
  ) {
    final result = <RemoteSection>[];
    for (final kv in sections.entries) {
      final detail = sectionDetail[kv.key] as Map<String, dynamic>?;
      if (detail == null) continue;
      final num = int.tryParse(kv.key);
      if (num == null) continue;
      result.add(
        RemoteSection(
          sectionNumber: num,
          name: kv.value as String? ?? '',
          hadithFirst: (detail['hadithnumber_first'] as int?) ?? 0,
          hadithLast: (detail['hadithnumber_last'] as int?) ?? 0,
        ),
      );
    }
    result.sort((a, b) => a.sectionNumber.compareTo(b.sectionNumber));
    return result;
  }

  // ── Static chapter data ───────────────────────────────────────────────

  /// Arabic names for the 96 canonical books of Sahih al-Bukhari.
  static const _kBukhariNamesAr = <int, String>{
    1: 'بدء الوحي',
    2: 'الإيمان',
    3: 'العلم',
    4: 'الوضوء',
    5: 'الغسل',
    6: 'الحيض',
    7: 'التيمم',
    8: 'الصلاة',
    9: 'مواقيت الصلاة',
    10: 'الأذان',
    11: 'الجمعة',
    12: 'صلاة الخوف',
    13: 'العيدين',
    14: 'الوتر',
    15: 'الاستسقاء',
    16: 'الكسوف',
    17: 'سجود القرآن',
    18: 'تقصير الصلاة',
    19: 'التهجد',
    20: 'فضل الصلاة في مسجد مكة والمدينة',
    21: 'العمل في الصلاة',
    22: 'السهو',
    23: 'الجنائز',
    24: 'الزكاة',
    25: 'فرض صدقة الفطر',
    26: 'الحج',
    27: 'العمرة',
    28: 'المحصر',
    29: 'جزاء الصيد',
    30: 'فضائل المدينة',
    31: 'الصوم',
    32: 'صلاة التراويح',
    33: 'الاعتكاف',
    34: 'البيوع',
    35: 'السلم',
    36: 'الشفعة',
    37: 'الإجارة',
    38: 'الحوالة',
    39: 'الكفالة',
    40: 'الوكالة',
    41: 'الحرث والمزارعة',
    42: 'المساقاة',
    43: 'الاستقراض',
    44: 'الخصومات',
    45: 'اللقطة',
    46: 'المظالم والغصب',
    47: 'الشراكة',
    48: 'الرهن',
    49: 'العتق',
    50: 'الهبة',
    51: 'الشهادات',
    52: 'الصلح',
    53: 'الشروط',
    54: 'الوصايا',
    55: 'الجهاد والسير',
    56: 'فرض الخمس',
    57: 'الجزية',
    58: 'بدء الخلق',
    59: 'أحاديث الأنبياء',
    60: 'المناقب',
    61: 'فضائل أصحاب النبي',
    62: 'مناقب الأنصار',
    63: 'المغازي',
    64: 'التفسير',
    65: 'فضائل القرآن',
    66: 'النكاح',
    67: 'الطلاق',
    68: 'النفقات',
    69: 'الأطعمة',
    70: 'العقيقة',
    71: 'الصيد والذبائح',
    72: 'الأضاحي',
    73: 'الأشربة',
    74: 'المرضى',
    75: 'الطب',
    76: 'اللباس',
    77: 'الأدب',
    78: 'الاستئذان',
    79: 'الدعوات',
    80: 'الرقاق',
    81: 'القدر',
    82: 'الأيمان والنذور',
    83: 'الكفارات',
    84: 'الفرائض',
    85: 'الحدود',
    86: 'الديات',
    87: 'استتابة المرتدين',
    88: 'الإكراه',
    89: 'الحيل',
    90: 'تعبير الرؤيا',
    91: 'الفتن',
    92: 'الأحكام',
    93: 'التمني',
    94: 'أخبار الآحاد',
    95: 'الاعتصام بالكتاب والسنة',
    96: 'التوحيد',
  };

  /// English names and numbers for all 96 books.
  static const _kBukhariData = <List<Object>>[
    [1, 'Revelation'],
    [2, 'Belief'],
    [3, 'Knowledge'],
    [4, 'Ablutions (Wudu)'],
    [5, 'Bathing (Ghusl)'],
    [6, 'Menstrual Periods'],
    [7, 'Dry Ablution (Tayammum)'],
    [8, 'Prayers (Salat)'],
    [9, 'Times of Prayer'],
    [10, 'Call to Prayers'],
    [11, 'Friday Prayer'],
    [12, 'Fear Prayer'],
    [13, 'Two Eid Festivals'],
    [14, 'Witr Prayer'],
    [15, 'Rain Prayer'],
    [16, 'Eclipses'],
    [17, 'Prostrations while reciting Quran'],
    [18, 'Shortening the Prayers'],
    [19, 'Night Prayer'],
    [20, 'Prayer in Mosques of Mecca and Medina'],
    [21, 'Actions while Praying'],
    [22, 'Forgetfulness in Prayer'],
    [23, 'Funerals'],
    [24, 'Obligatory Charity Tax (Zakat)'],
    [25, 'Obligatory Charity Tax After Ramadan'],
    [26, 'Pilgrimage (Hajj)'],
    [27, 'Umra'],
    [28, 'Pilgrims Prevented from Completing Pilgrimage'],
    [29, 'Penalty of Hunting while on Pilgrimage'],
    [30, 'Virtues of Medina'],
    [31, 'Fasting'],
    [32, 'Night Prayer in Ramadan (Tarawih)'],
    [33, 'Retiring to a Mosque (I\'tikaf)'],
    [34, 'Sales and Trade'],
    [35, 'Advance Payment (Salam)'],
    [36, 'Pre-emption (Shuf\'a)'],
    [37, 'Hiring'],
    [38, 'Debt Transfer (Hawala)'],
    [39, 'Guarantee (Kafala)'],
    [40, 'Agency (Wakala)'],
    [41, 'Agriculture'],
    [42, 'Water Distribution (Musaqat)'],
    [43, 'Loans and Bankruptcy'],
    [44, 'Quarrels (Disputes)'],
    [45, 'Lost and Found Property'],
    [46, 'Oppressions'],
    [47, 'Partnership'],
    [48, 'Mortgaging (Rahn)'],
    [49, 'Manumission of Slaves'],
    [50, 'Gifts'],
    [51, 'Witnesses'],
    [52, 'Peacemaking'],
    [53, 'Conditions'],
    [54, 'Wills and Testaments'],
    [55, 'Fighting for the Cause of Allah (Jihad)'],
    [56, 'One-fifth of Booty (Khumus)'],
    [57, 'Jizyah and Mawaada\''],
    [58, 'The Beginning of Creation'],
    [59, 'Prophets'],
    [60, 'Virtues and Merits (Manaqib)'],
    [61, 'Companions of the Prophet'],
    [62, 'Merits of the Helpers in Medina'],
    [63, 'Military Expeditions (Maghazi)'],
    [64, 'Prophetic Commentary on the Quran (Tafseer)'],
    [65, 'Virtues of the Quran'],
    [66, 'Marriage (Nikah)'],
    [67, 'Divorce (Talaq)'],
    [68, 'Supporting the Family'],
    [69, 'Foods and Meals'],
    [70, 'Sacrifice on Occasion of Birth'],
    [71, 'Hunting and Slaughtering (Zabaih)'],
    [72, 'Sacrifices (Adahi)'],
    [73, 'Drinks (Ashriba)'],
    [74, 'Patients'],
    [75, 'Medicine (Tibb)'],
    [76, 'Dress'],
    [77, 'Good Manners (Adab)'],
    [78, 'Asking Permission'],
    [79, 'Invocations (Du\'a)'],
    [80, 'Heart-Softening Traditions (Riqaq)'],
    [81, 'Divine Will (Al-Qadar)'],
    [82, 'Oaths and Vows'],
    [83, 'Expiation for Unfulfilled Oaths'],
    [84, 'Laws of Inheritance (Fara\'id)'],
    [85, 'Limits and Punishments (Hudud)'],
    [86, 'Blood Money (Diyat)'],
    [87, 'Dealing with Apostates'],
    [88, 'Coercion (Ikrah)'],
    [89, 'Tricks (Hiyal)'],
    [90, 'Interpretation of Dreams'],
    [91, 'Afflictions and the End of the World (Fitan)'],
    [92, 'Judgments (Ahkam)'],
    [93, 'Wishes (Tamanni)'],
    [94, 'Accepting Individual Report'],
    [95, 'Holding Fast to the Quran and Sunnah'],
    [96, 'Oneness of Allah (Tawhid)'],
  ];
}

/// A single hadith entry from fawazahmed0/hadith-api.
class RemoteHadith {
  final int hadithNumber;
  final int arabicNumber;
  final String text;
  final List<String> grades;
  final int referenceBook;
  final int referenceHadith;

  const RemoteHadith({
    required this.hadithNumber,
    required this.arabicNumber,
    required this.text,
    required this.grades,
    required this.referenceBook,
    required this.referenceHadith,
  });

  factory RemoteHadith.fromJson(Map<String, dynamic> json) {
    final ref = json['reference'] as Map<String, dynamic>? ?? {};
    final rawGrades = json['grades'] as List<dynamic>? ?? [];
    return RemoteHadith(
      hadithNumber: (json['hadithnumber'] as int?) ?? 0,
      arabicNumber: (json['arabicnumber'] as int?) ?? 0,
      text: (json['text'] as String?) ?? '',
      grades: rawGrades
          .map((g) => (g as Map<String, dynamic>)['grade']?.toString() ?? '')
          .where((g) => g.isNotEmpty)
          .toList(),
      referenceBook: (ref['book'] as int?) ?? 0,
      referenceHadith: (ref['hadith'] as int?) ?? 0,
    );
  }

  /// Stable unique ID: "{book}_{sectionNumber}_{hadithNumber}".
  String stableId(String book, int sectionNumber) =>
      '${book}_${sectionNumber}_$hadithNumber';

  /// Attempts to split the raw text into sanad (chain) and matn (content).
  /// Returns (sanad, matn).  If the split cannot be determined reliably the
  /// sanad is returned empty and the whole text is treated as matn.
  static (String, String) _splitSanadMatn(String raw) {
    if (raw.isEmpty) return ('', '');
    final total = raw.length;

    String stripTrailing(String s) =>
        s.replaceAll(RegExp(r'["\u201c\u201d\s.\u200f\u060c\u200e]+$'), '')
            .trim();

    // Strip tashkeel (diacritics) from a character.
    bool isTashkeel(int cp) =>
        (cp >= 0x0610 && cp <= 0x061A) ||
        (cp >= 0x064B && cp <= 0x065F) ||
        cp == 0x0670 ||
        (cp >= 0x06D6 && cp <= 0x06ED);

    // Build tashkeel-free version of [raw] plus an index map where
    // normMap[i] is the position of normalized char i in [raw].
    String normText;
    List<int> normMap;
    {
      final buf = StringBuffer();
      final map = <int>[];
      for (var i = 0; i < raw.length; i++) {
        if (!isTashkeel(raw.codeUnitAt(i))) {
          buf.writeCharCode(raw.codeUnitAt(i));
          map.add(i);
        }
      }
      normText = buf.toString();
      normMap = map;
    }

    // Maps a normalized-string index back to its position in [raw].
    int toRaw(int ni) => ni < normMap.length ? normMap[ni] : raw.length;

    // Find the first speech-quote character (" or \u201c) in [raw] starting
    // from [fromRaw].  Returns -1 if none is found.
    int firstQuoteAfter(int fromRaw) {
      int best = -1;
      for (final qc in ['"', '\u201c']) {
        final qi = raw.indexOf(qc, fromRaw);
        if (qi >= fromRaw && (best < 0 || qi < best)) best = qi;
      }
      return best;
    }

    // Extract matn from [rawFrom]: look for next quote; if none, start from
    // [rawFrom] directly.  Returns null when the result is too short.
    String? extractMatn(int rawFrom) {
      final qp = firstQuoteAfter(rawFrom);
      final start = qp >= 0 ? qp + 1 : rawFrom;
      final m = stripTrailing(
        raw
            .substring(start)
            .replaceFirst(RegExp(r'^[\s\u060c\u061b\u061f:,.!"«»\u0640]+'), '')
            .trim(),
      );
      return (m.length >= 20 && m.length >= total * 0.20) ? m : null;
    }

    // ── Strategy A: رضى/رضي الله + companion suffix (normalized search) ─
    for (final rida in ['رضى الله', 'رضي الله']) {
      final ridxN = normText.indexOf(rida);
      if (ridxN < 20) continue;
      final afterN = normText.substring(ridxN);
      for (final suffix in ['عنهما', 'عنهم', 'عنها', 'عنه']) {
        final sidx = afterN.indexOf(suffix);
        if (sidx < 0) continue;
        var endN = ridxN + sidx + suffix.length;
        while (endN < normText.length &&
            ' ـ\t\u060c,'.contains(normText[endN])) {
          endN++;
        }
        final rawContentStart = toRaw(endN);
        final m = extractMatn(rawContentStart);
        if (m != null) return (raw.substring(0, rawContentStart).trim(), m);
        break;
      }
    }

    // ── Strategy B: normalized Prophet ﷺ marker → next quote in raw ─────
    final prophetPat = RegExp(
      r'(?:\u0631\u0633\u0648\u0644 \u0627\u0644\u0644\u0647'
      r'|\u0627\u0644\u0646\u0628\u064a)'
      r' \u0635\u0644\u0649 \u0627\u0644\u0644\u0647 \u0639\u0644\u064a\u0647 \u0648\u0633\u0644\u0645',
    );
    for (final match in prophetPat.allMatches(normText)) {
      if (match.start <= 20) continue;

      // Skip occurrences where what follows is another sanad chain.
      final afterSmN = normText.substring(match.end).trimLeft();
      if (_looksLikeSanadContinuation(afterSmN)) continue;

      // Map the end of the match back to the raw string.
      final rawMarkerEnd = toRaw(match.end - 1) + 1;
      final m = extractMatn(rawMarkerEnd);
      if (m != null) return (raw.substring(0, rawMarkerEnd).trim(), m);
    }

    // ── Strategy C: first speech-quote within first 80 % of text ─────────
    {
      int bestQ = -1;
      for (final qc in ['"', '\u201c']) {
        final q = raw.indexOf(qc);
        if (q > 30 && q < total * 0.80 && (bestQ < 0 || q < bestQ)) {
          bestQ = q;
        }
      }
      if (bestQ >= 0) {
        final m = stripTrailing(raw.substring(bestQ + 1).trim());
        if (m.length >= 20) return (raw.substring(0, bestQ).trim(), m);
      }
    }

    // ── Fallback: whole text is the matn ──────────────────────────────────
    return ('', raw.trim());
  }

  static bool _looksLikeSanadContinuation(String text) {
    const sanadPrefixes = [
      'ح ',
      'ح.',
      'وحدثنا',
      'حدثنا',
      'وحدثني',
      'حدثني',
      'واخبرنا',
      'وأخبرنا',
      'اخبرنا',
      'أخبرنا',
      'واخبرني',
      'وأخبرني',
      'اخبرني',
      'أخبرني',
      'انبانا',
      'أنبأنا',
      'سمعت',
      'عن ',
      'قال حدثنا',
      'قال اخبرنا',
      'قال أخبرنا',
      'قال سمعت',
    ];
    return sanadPrefixes.any(text.startsWith);
  }

  // Legacy helpers kept for external callers; no longer used internally.
  static (String, List<int>) _normalizedWithIndexMap(String raw) {
    final buffer = StringBuffer();
    final indexMap = <int>[];
    for (var i = 0; i < raw.length; i++) {
      final cp = raw.codeUnitAt(i);
      final isTk = (cp >= 0x0610 && cp <= 0x061A) ||
          (cp >= 0x064B && cp <= 0x065F) ||
          cp == 0x0670 ||
          (cp >= 0x06D6 && cp <= 0x06ED);
      if (isTk) continue;
      buffer.writeCharCode(cp);
      indexMap.add(i);
    }
    return (buffer.toString(), indexMap);
  }

  static bool _isTashkeelChar(String char) {
    if (char.isEmpty) return false;
    final cp = char.codeUnitAt(0);
    return (cp >= 0x0610 && cp <= 0x061A) ||
        (cp >= 0x064B && cp <= 0x065F) ||
        cp == 0x0670 ||
        (cp >= 0x06D6 && cp <= 0x06ED);
  }

  // Kept for compatibility; no longer called internally.
  static int _skipLeadingPunctuation(String text, int start) {
    var index = start;
    while (index < text.length) {
      final cp = text.codeUnitAt(index);
      if (cp == 0x0020 || // space
          cp == 0x060C || // ،
          cp == 0x002C || // ,
          cp == 0x003A || // :
          cp == 0x061B || // ؛
          cp == 0x002E || // .
          cp == 0x061F || // ؟
          cp == 0x0021 || // !
          cp == 0x0022 || // "
          cp == 0x00AB || // «
          cp == 0x00BB || // »
          cp == 0x0640) { // ـ
        index++;
      } else {
        break;
      }
    }
    return index;
  }

  // Kept for compatibility; no longer called internally.
  static int _skipSpeechLeadIns(String text, int start) {
    var index = _skipLeadingPunctuation(text, start);
    const prefixes = [
      'قال',
      'قالت',
      'فقال',
      'وقالت',
      'يقول',
      'انه',
      'أنه',
      'ان',
      'أن',
    ];

    while (index < text.length) {
      String? matchedPrefix;
      for (final prefix in prefixes) {
        if (!text.startsWith(prefix, index)) continue;
        final end = index + prefix.length;
        if (end < text.length &&
            !RegExp(r'[\s،,:؛.؟!"«»ـ]').hasMatch(text[end])) {
          continue;
        }
        matchedPrefix = prefix;
        break;
      }
      if (matchedPrefix == null) break;
      index += matchedPrefix.length;
      index = _skipLeadingPunctuation(text, index);
    }

    return index;
  }

  /// Convert to a full [HadithItem].
  HadithItem toHadithItem({
    required String book,
    required int sectionNumber,
    required String bookNameAr,
    required String sectionNameAr,
    required int sortOrder,
  }) {
    final (sanad, matn) = _splitSanadMatn(text);
    final id = stableId(book, sectionNumber);
    final gradeLabel = grades.isNotEmpty ? grades.first : '';
    return HadithItem(
      id: id,
      arabicText: matn.isNotEmpty ? matn : text,
      reference: '$bookNameAr حديث $hadithNumber',
      bookReference: '$bookNameAr: $sectionNameAr، حديث $hadithNumber',
      sanad: sanad,
      narrator: '',
      grade: _parseGrade(gradeLabel),
      gradedBy: gradeLabel,
      topicAr: sectionNameAr,
      topicEn: '',
      explanation: null,
      categoryId: book,
      sortOrder: sortOrder,
      isOffline: false,
    );
  }

  /// Convert to a lightweight [HadithListItem].
  HadithListItem toHadithListItem({
    required String book,
    required int sectionNumber,
    required String bookNameAr,
    required String sectionNameAr,
    required int sortOrder,
  }) {
    final (_, matn) = _splitSanadMatn(text);
    final displayText = matn.isNotEmpty ? matn : text;
    final preview = displayText.length > 150
        ? displayText.substring(0, 150)
        : displayText;
    final id = stableId(book, sectionNumber);
    final gradeLabel = grades.isNotEmpty ? grades.first : '';
    return HadithListItem(
      id: id,
      categoryId: book,
      arabicPreview: preview,
      topicAr: sectionNameAr,
      topicEn: '',
      narrator: '',
      reference: '$bookNameAr $hadithNumber',
      grade: _parseGrade(gradeLabel),
      sortOrder: sortOrder,
      isOffline: false,
    );
  }

  static HadithGrade _parseGrade(String label) {
    if (label.contains('صحيح') || label.toLowerCase().contains('sahih')) {
      return HadithGrade.sahih;
    }
    if (label.contains('حسن') || label.toLowerCase().contains('hasan')) {
      return HadithGrade.hasan;
    }
    return HadithGrade.sahih;
  }

  /// Parse a list of hadiths from an API section response JSON.
  static List<RemoteHadith> listFromJson(List<dynamic> jsonList) {
    return jsonList
        .map((e) => RemoteHadith.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// The sanad (chain of narrators) extracted from [text].
  String get sanadText => _splitSanadMatn(text).$1;

  /// The matn (actual hadith content) extracted from [text].
  String get matnText {
    final m = _splitSanadMatn(text).$2;
    return m.isNotEmpty ? m : text;
  }

  /// Structured isnad: the sanad split into individual [IsnadNarrator]s.
  List<IsnadNarrator> get parsedIsnad => IsnadParser.parse(sanadText);
}
