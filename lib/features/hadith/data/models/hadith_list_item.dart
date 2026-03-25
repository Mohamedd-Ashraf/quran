import 'hadith_item.dart';

/// Lightweight hadith model for list views.
/// Only contains fields needed for preview cards — no sanad, explanation, or full text.
class HadithListItem {
  final String id;
  final String categoryId;
  final String arabicPreview;
  final String topicAr;
  final String topicEn;
  final String narrator;
  final String reference;
  final HadithGrade grade;
  final int sortOrder;

  /// True for the 117 bundled hadiths; false for online CDN hadiths.
  final bool isOffline;

  const HadithListItem({
    required this.id,
    required this.categoryId,
    required this.arabicPreview,
    required this.topicAr,
    required this.topicEn,
    required this.narrator,
    required this.reference,
    required this.grade,
    required this.sortOrder,
    this.isOffline = true,
  });

  factory HadithListItem.fromMap(Map<String, dynamic> map) => HadithListItem(
    id: map['id'] as String,
    categoryId: map['category_id'] as String,
    arabicPreview: map['arabic_preview'] as String,
    topicAr: map['topic_ar'] as String,
    topicEn: map['topic_en'] as String,
    narrator: map['narrator'] as String,
    reference: map['reference'] as String,
    grade: HadithGrade.values.firstWhere(
      (g) => g.name == map['grade'],
      orElse: () => HadithGrade.sahih,
    ),
    sortOrder: (map['sort_order'] as int?) ?? 0,
    isOffline: (map['is_offline'] as int? ?? 1) == 1,
  );
}
