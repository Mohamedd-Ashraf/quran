/// Represents a single hadith with full metadata.
class HadithItem {
  final String id;

  /// The Arabic text of the hadith.
  final String arabicText;

  /// Primary source reference (e.g. "صحيح البخاري 6018").
  final String reference;

  /// The book & hadith number (e.g. "البخاري: كتاب الأدب، حديث رقم 6018").
  final String bookReference;

  /// Narrator chain in Arabic (full isnad).
  final String sanad;

  /// The companion who narrated to the Prophet ﷺ.
  final String narrator;

  /// Grading: صحيح / حسن / متفق عليه
  final HadithGrade grade;

  /// The scholar or source that graded this hadith.
  final String gradedBy;

  /// Topic / chapter in Arabic.
  final String topicAr;

  /// Topic / chapter in English.
  final String topicEn;

  /// Optional explanation / sharh in Arabic.
  final String? explanation;

  /// Category id this hadith belongs to.
  final String? categoryId;

  /// Sort order within the category.
  final int sortOrder;

  /// True for the 117 bundled hadiths; false for online CDN hadiths.
  final bool isOffline;

  const HadithItem({
    required this.id,
    required this.arabicText,
    required this.reference,
    required this.bookReference,
    required this.sanad,
    required this.narrator,
    required this.grade,
    required this.gradedBy,
    required this.topicAr,
    required this.topicEn,
    this.explanation,
    this.categoryId,
    this.sortOrder = 0,
    this.isOffline = true,
  });

  Map<String, dynamic> toMap(String catId, int order) => {
    'id': id,
    'category_id': catId,
    'arabic_text': arabicText,
    'reference': reference,
    'book_reference': bookReference,
    'sanad': sanad,
    'narrator': narrator,
    'grade': grade.name,
    'graded_by': gradedBy,
    'topic_ar': topicAr,
    'topic_en': topicEn,
    'explanation': explanation,
    'sort_order': order,
  };

  factory HadithItem.fromMap(Map<String, dynamic> map) => HadithItem(
    id: map['id'] as String,
    arabicText: map['arabic_text'] as String,
    reference: map['reference'] as String,
    bookReference: map['book_reference'] as String,
    sanad: map['sanad'] as String,
    narrator: map['narrator'] as String,
    grade: HadithGrade.values.firstWhere(
      (g) => g.name == map['grade'],
      orElse: () => HadithGrade.sahih,
    ),
    gradedBy: map['graded_by'] as String,
    topicAr: map['topic_ar'] as String,
    topicEn: map['topic_en'] as String,
    explanation: map['explanation'] as String?,
    categoryId: map['category_id'] as String?,
    sortOrder: (map['sort_order'] as int?) ?? 0,
    isOffline: (map['is_offline'] as int? ?? 1) == 1,
  );
}

/// Hadith authenticity grading.
enum HadithGrade {
  sahih, // صحيح
  hasan, // حسن
  muttafaqAlayh, // متفق عليه
}

extension HadithGradeX on HadithGrade {
  String get labelAr {
    switch (this) {
      case HadithGrade.sahih:
        return 'صحيح';
      case HadithGrade.hasan:
        return 'حسن';
      case HadithGrade.muttafaqAlayh:
        return 'متفق عليه';
    }
  }

  String get labelEn {
    switch (this) {
      case HadithGrade.sahih:
        return 'Sahih (Authentic)';
      case HadithGrade.hasan:
        return 'Hasan (Good)';
      case HadithGrade.muttafaqAlayh:
        return 'Agreed Upon';
    }
  }
}
