import 'package:flutter/material.dart';

/// Category metadata without embedded hadith items.
/// Used for display in the categories screen. Counts are loaded from the database.
class HadithCategoryInfo {
  final String id;
  final String titleAr;
  final String titleEn;
  final String subtitleAr;
  final String subtitleEn;
  final IconData icon;
  final Color color;
  final int count;

  /// True for CDN-based online books; false for the curated offline set.
  final bool isOnline;

  /// CDN edition key, e.g. "ara-bukhari". Only set when [isOnline] is true.
  final String? apiEdition;

  const HadithCategoryInfo({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.subtitleAr,
    required this.subtitleEn,
    required this.icon,
    required this.color,
    this.count = 0,
    this.isOnline = false,
    this.apiEdition,
  });

  HadithCategoryInfo copyWith({int? count}) => HadithCategoryInfo(
    id: id,
    titleAr: titleAr,
    titleEn: titleEn,
    subtitleAr: subtitleAr,
    subtitleEn: subtitleEn,
    icon: icon,
    color: color,
    count: count ?? this.count,
    isOnline: isOnline,
    apiEdition: apiEdition,
  );

  /// Static metadata for all hadith categories.
  static const List<HadithCategoryInfo> all = [
    HadithCategoryInfo(
      id: 'iman',
      titleAr: 'الإيمان والتوحيد',
      titleEn: 'Faith & Monotheism',
      subtitleAr: 'أحاديث عن أركان الإيمان والتوحيد',
      subtitleEn: 'Hadiths on pillars of faith',
      icon: Icons.favorite_rounded,
      color: Color(0xFF1A8A58),
    ),
    HadithCategoryInfo(
      id: 'akhlaq',
      titleAr: 'الأخلاق والآداب',
      titleEn: 'Morals & Manners',
      subtitleAr: 'أحاديث عن حسن الخلق والمعاملة',
      subtitleEn: 'Hadiths on good character',
      icon: Icons.people_rounded,
      color: Color(0xFFD4AF37),
    ),
    HadithCategoryInfo(
      id: 'ibadat',
      titleAr: 'العبادات',
      titleEn: 'Worship',
      subtitleAr: 'أحاديث عن الصلاة والصيام والعبادة',
      subtitleEn: 'Hadiths on prayer, fasting & worship',
      icon: Icons.mosque_rounded,
      color: Color(0xFF0D5E3A),
    ),
    HadithCategoryInfo(
      id: 'muamalat',
      titleAr: 'المعاملات',
      titleEn: 'Transactions & Dealings',
      subtitleAr: 'أحاديث عن البيع والشراء والمعاملات',
      subtitleEn: 'Hadiths on trade, dealings & relations',
      icon: Icons.handshake_rounded,
      color: Color(0xFF8B4513),
    ),
    HadithCategoryInfo(
      id: 'nawawi40',
      titleAr: 'الأربعين النووية',
      titleEn: "Nawawi's 40 Hadith",
      subtitleAr: 'مختارات من جوامع الكلم',
      subtitleEn: 'Selected comprehensive sayings',
      icon: Icons.auto_stories_rounded,
      color: Color(0xFF1976D2),
    ),
    HadithCategoryInfo(
      id: 'fadail',
      titleAr: 'فضائل الأعمال',
      titleEn: 'Virtuous Deeds',
      subtitleAr: 'أحاديث عن فضائل الأذكار والأعمال الصالحة',
      subtitleEn: 'Hadiths on virtues of remembrance & good deeds',
      icon: Icons.star_rounded,
      color: Color(0xFFB8860B),
    ),
    HadithCategoryInfo(
      id: 'qudsi',
      titleAr: 'الأحاديث القدسية',
      titleEn: 'Qudsi Hadiths',
      subtitleAr: 'كلام الله على لسان نبيه ﷺ',
      subtitleEn: 'Words of Allah narrated by the Prophet ﷺ',
      icon: Icons.brightness_7_rounded,
      color: Color(0xFF7B1FA2),
    ),
  ];

  static HadithCategoryInfo? findById(String id) {
    try {
      return all.firstWhere((c) => c.id == id);
    } catch (_) {
      try {
        return allOnline.firstWhere((c) => c.id == id);
      } catch (_) {
        return null;
      }
    }
  }

  // ── Online book categories ──────────────────────────────────────────

  /// Sahih al-Bukhari (7592 hadiths) served from Firestore.
  static const List<HadithCategoryInfo> allOnline = [
    HadithCategoryInfo(
      id: 'bukhari',
      titleAr: 'صحيح البخاري',
      titleEn: 'Sahih al-Bukhari',
      subtitleAr: 'أصح كتاب بعد القرآن الكريم – ٧٥٩٢ حديث',
      subtitleEn: 'Most authentic hadith collection – 7592 hadiths',
      icon: Icons.menu_book_rounded,
      color: Color(0xFF1A5276),
      isOnline: true,
      count: 7592,
    ),
  ];
}
