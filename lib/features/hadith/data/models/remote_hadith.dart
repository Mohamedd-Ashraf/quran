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

  int get count => (hadithLast - hadithFirst + 1).clamp(0, 9999);

  /// Parse from the API metadata response.
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
  /// The sanad is the part ending at the narrator keyword.
  /// Returns (sanad, matn).
  static (String, String) _splitSanadMatn(String raw) {
    // Common markers that indicate where the matn begins
    const markers = [
      'قَالَ رَسُولُ اللَّهِ',
      'قَالَ رَسُولُ اللَّهِ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ',
      'أَنَّ النَّبِيَّ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ',
      'عَنِ النَّبِيِّ صَلَّى',
      'سَمِعْتُ رَسُولَ اللَّهِ',
      'أَنَّ رَسُولَ اللَّهِ',
      'عَنْ رَسُولِ اللَّهِ',
      'قَالَ النَّبِيُّ',
    ];

    for (final marker in markers) {
      final idx = raw.indexOf(marker);
      if (idx > 30) {
        // Enough sanad before marker
        return (raw.substring(0, idx).trim(), raw.substring(idx).trim());
      }
    }
    // Fallback: entire text is both
    return ('', raw.trim());
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
}
