/// Quran structure: Juz (أجزاء), Surahs mapping
class QuranStructure {
  // Juz names in order (1-30)
  static const List<Map<String, String>> juzNames = [
    {'number': '1', 'nameAr': 'الجزء الأول', 'nameEn': 'Juz 1'},
    {'number': '2', 'nameAr': 'الجزء الثاني', 'nameEn': 'Juz 2'},
    {'number': '3', 'nameAr': 'الجزء الثالث', 'nameEn': 'Juz 3'},
    {'number': '4', 'nameAr': 'الجزء الرابع', 'nameEn': 'Juz 4'},
    {'number': '5', 'nameAr': 'الجزء الخامس', 'nameEn': 'Juz 5'},
    {'number': '6', 'nameAr': 'الجزء السادس', 'nameEn': 'Juz 6'},
    {'number': '7', 'nameAr': 'الجزء السابع', 'nameEn': 'Juz 7'},
    {'number': '8', 'nameAr': 'الجزء الثامن', 'nameEn': 'Juz 8'},
    {'number': '9', 'nameAr': 'الجزء التاسع', 'nameEn': 'Juz 9'},
    {'number': '10', 'nameAr': 'الجزء العاشر', 'nameEn': 'Juz 10'},
    {'number': '11', 'nameAr': 'الجزء الحادي عشر', 'nameEn': 'Juz 11'},
    {'number': '12', 'nameAr': 'الجزء الثاني عشر', 'nameEn': 'Juz 12'},
    {'number': '13', 'nameAr': 'الجزء الثالث عشر', 'nameEn': 'Juz 13'},
    {'number': '14', 'nameAr': 'الجزء الرابع عشر', 'nameEn': 'Juz 14'},
    {'number': '15', 'nameAr': 'الجزء الخامس عشر', 'nameEn': 'Juz 15'},
    {'number': '16', 'nameAr': 'الجزء السادس عشر', 'nameEn': 'Juz 16'},
    {'number': '17', 'nameAr': 'الجزء السابع عشر', 'nameEn': 'Juz 17'},
    {'number': '18', 'nameAr': 'الجزء الثامن عشر', 'nameEn': 'Juz 18'},
    {'number': '19', 'nameAr': 'الجزء التاسع عشر', 'nameEn': 'Juz 19'},
    {'number': '20', 'nameAr': 'الجزء العشرون', 'nameEn': 'Juz 20'},
    {'number': '21', 'nameAr': 'الجزء الحادي والعشرون', 'nameEn': 'Juz 21'},
    {'number': '22', 'nameAr': 'الجزء الثاني والعشرون', 'nameEn': 'Juz 22'},
    {'number': '23', 'nameAr': 'الجزء الثالث والعشرون', 'nameEn': 'Juz 23'},
    {'number': '24', 'nameAr': 'الجزء الرابع والعشرون', 'nameEn': 'Juz 24'},
    {'number': '25', 'nameAr': 'الجزء الخامس والعشرون', 'nameEn': 'Juz 25'},
    {'number': '26', 'nameAr': 'الجزء السادس والعشرون', 'nameEn': 'Juz 26'},
    {'number': '27', 'nameAr': 'الجزء السابع والعشرون', 'nameEn': 'Juz 27'},
    {'number': '28', 'nameAr': 'الجزء الثامن والعشرون', 'nameEn': 'Juz 28'},
    {'number': '29', 'nameAr': 'الجزء التاسع والعشرون', 'nameEn': 'Juz 29'},
    {'number': '30', 'nameAr': 'الجزء الثلاثون', 'nameEn': 'Juz 30'},
  ];

  // Juz to Surahs mapping (which surahs are in which Juz)
  // Note: Some surahs span multiple Juz, we list the primary/starting Juz
  static const Map<int, List<int>> juzToSurahs = {
    1: [1, 2], // Al-Fatiha(complete) + Al-Baqarah(1-141)
    2: [2], // Al-Baqarah(142-252)
    3: [2, 3], // Al-Baqarah(253-286) + Al-Imran(1-92)
    4: [3, 4], // Al-Imran(93-200) + An-Nisa(1-23)
    5: [4], // An-Nisa(24-147)
    6: [4, 5], // An-Nisa(148-176) + Al-Ma'idah(1-81)
    7: [5, 6], // Al-Ma'idah(82-120) + Al-An'am(1-110)
    8: [6, 7], // Al-An'am(111-165) + Al-A'raf(1-87)
    9: [7, 8], // Al-A'raf(88-206) + Al-Anfal(1-40)
    10: [8, 9], // Al-Anfal(41-75) + At-Tawbah(1-92)
    11: [9, 10, 11], // At-Tawbah(93-129) + Yunus + Hud(1-5)
    12: [11, 12], // Hud(6-123) + Yusuf(1-52)
    13: [12, 13, 14, 15], // Yusuf(53-111) + Ar-Ra'd + Ibrahim + Al-Hijr(1-1)
    14: [15, 16], // Al-Hijr(2-99) + An-Nahl(1-128)
    15: [17, 18], // Al-Isra + Al-Kahf(1-74)
    16: [18, 19, 20], // Al-Kahf(75-110) + Maryam + Ta-Ha(1-135)
    17: [21, 22], // Al-Anbiya + Al-Hajj(1-78)
    18: [23, 24, 25], // Al-Mu'minun + An-Nur + Al-Furqan(1-20)
    19: [25, 26, 27], // Al-Furqan(21-77) + Ash-Shu'ara + An-Naml(1-55)
    20: [27, 28, 29], // An-Naml(56-93) + Al-Qasas + Al-Ankabut(1-45)
    21: [29, 30, 31, 32, 33], // Al-Ankabut(46-69) + Ar-Rum + Luqman + As-Sajda + Al-Ahzab(1-30)
    22: [33, 34, 35, 36], // Al-Ahzab(31-73) + Saba + Fatir + Ya-Sin(1-27)
    23: [36, 37, 38, 39], // Ya-Sin(28-83) + As-Saffat + Sad + Az-Zumar(1-31)
    24: [39, 40, 41], // Az-Zumar(32-75) + Ghafir + Fussilat(1-46)
    25: [41, 42, 43, 44, 45], // Fussilat(47-54) + Ash-Shura + Az-Zukhruf + Ad-Dukhan + Al-Jathiya
    26: [46, 47, 48, 49, 50, 51], // Al-Ahqaf + Muhammad + Al-Fath + Al-Hujurat + Qaf + Adh-Dhariyat(1-30)
    27: [51, 52, 53, 54, 55, 56, 57], // Adh-Dhariyat(31-60) + At-Tur + An-Najm + Al-Qamar + Ar-Rahman + Al-Waqi'a + Al-Hadid(1-29)
    28: [58, 59, 60, 61, 62, 63, 64, 65, 66], // Al-Mujadila + Al-Hashr + Al-Mumtahana + As-Saff + Al-Jumu'a + Al-Munafiqun + At-Taghabun + At-Talaq + At-Tahrim
    29: [67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77], // Al-Mulk to Al-Mursalat
    30: [78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114], // An-Naba to An-Nas
  };

  // Popular named sections
  static const List<Map<String, dynamic>> popularSections = [
    {
      'nameAr': 'جزء عمّ',
      'nameEn': "Juz 'Amma",
      'surahs': [78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114],
    },
    {
      'nameAr': 'جزء تبارك',
      'nameEn': 'Juz Tabarak',
      'surahs': [67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77],
    },
    {
      'nameAr': 'جزء قد سمع',
      'nameEn': "Juz Qad Sami'a",
      'surahs': [58, 59, 60, 61, 62, 63, 64, 65, 66],
    },
  ];

  /// Get surahs for a specific Juz
  static List<int> getSurahsForJuz(int juzNumber) {
    return juzToSurahs[juzNumber] ?? [];
  }

  /// Get all surahs for multiple Juz
  static Set<int> getSurahsForMultipleJuz(List<int> juzNumbers) {
    final surahs = <int>{};
    for (final juz in juzNumbers) {
      surahs.addAll(getSurahsForJuz(juz));
    }
    return surahs;
  }

  /// Get popular section surahs
  static List<int> getSurahsForSection(String sectionName) {
    final section = popularSections.firstWhere(
      (s) => s['nameAr'] == sectionName || s['nameEn'] == sectionName,
      orElse: () => {'surahs': <int>[]},
    );
    return List<int>.from(section['surahs'] ?? []);
  }
}
