import 'package:flutter/material.dart';

import 'app_colors.dart';

class RecitationCatalog {
  RecitationCatalog._();

  static const List<int> fullQuranSurahs = [
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
    11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
    21, 22, 23, 24, 25, 26, 27, 28, 29, 30,
    31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
    41, 42, 43, 44, 45, 46, 47, 48, 49, 50,
    51, 52, 53, 54, 55, 56, 57, 58, 59, 60,
    61, 62, 63, 64, 65, 66, 67, 68, 69, 70,
    71, 72, 73, 74, 75, 76, 77, 78, 79, 80,
    81, 82, 83, 84, 85, 86, 87, 88, 89, 90,
    91, 92, 93, 94, 95, 96, 97, 98, 99, 100,
    101, 102, 103, 104, 105, 106, 107, 108, 109, 110,
    111, 112, 113, 114,
  ];

  static const Set<String> warshEditionIds = {
    'ar.warsh.ibrahimdosary',
    'ar.warsh.yassinjazaery',
    'ar.warsh.abdulbasit',
  };

  static const Set<String> timedEditionIds = {
    'ar.qiraat.husary.qalon',
    'ar.qiraat.husary.warsh',
    'ar.qiraat.husary.duri',
    'ar.qiraat.sosi.abuamr',
    'ar.qiraat.huthifi.qalon',
    'ar.qiraat.koshi.warsh',
    'ar.qiraat.yasseen.warsh',
    'ar.qiraat.qazabri.warsh',
    'ar.qiraat.dokali.qalon',
    'ar.qiraat.okasha.bazi',
    'ar.khaledjleel',
    'ar.raadialkurdi',
    'ar.abdulaziahahmad',
  };

  static const Set<String> teacherEditionIds = {
    'ar.husarymuallim',
    'ar.minshawiteacher',
  };

    // Editions played from mp3quran servers (surah-level source).
    static const Map<String, String> mp3QuranServersByEditionId = {
    'ar.qiraat.qalon': 'https://server10.mp3quran.net/trablsi/',
    'ar.qiraat.bazi':
      'https://server16.mp3quran.net/deban/Rewayat-Albizi-A-n-Ibn-Katheer/',
    'ar.qiraat.qunbol':
      'https://server16.mp3quran.net/deban/Rewayat-Qunbol-A-n-Ibn-Katheer/',
    'ar.qiraat.duri.abuamr':
      'https://server16.mp3quran.net/deban/Rewayat-Aldori-A-n-Abi-Amr/',
    'ar.qiraat.ibndhakwan':
      'https://server14.mp3quran.net/muftah_sultany/Rewayat_Ibn-Thakwan-A-n-Ibn-Amer/',
    'ar.qiraat.shuba':
      'https://server16.mp3quran.net/deban/Rewayat-Sho-bah-A-n-Asim/',
    'ar.qiraat.duri.kisai':
      'https://server14.mp3quran.net/muftah_sultany/Rewayat-AlDorai-A-n-Al-Kisa-ai/',
    'ar.qiraat.warsh.azraq':
      'https://server16.mp3quran.net/deban/Rewayat-Warsh-A-n-Nafi-Men-Tariq-Alazraq/',
    'ar.qiraat.sosi.abuamr':
      'https://server16.mp3quran.net/soufi/Rewayat-Assosi-A-n-Abi-Amr/',
    'ar.qiraat.khalaf.hamza':
      'https://server16.mp3quran.net/soufi/Rewayat-Khalaf-A-n-Hamzah/',
    'ar.qiraat.husary.qalon':
      'https://server13.mp3quran.net/husr/Rewayat-Qalon-A-n-Nafi/',
    'ar.qiraat.husary.warsh':
      'https://server13.mp3quran.net/husr/Rewayat-Warsh-A-n-Nafi/',
    'ar.qiraat.husary.duri':
      'https://server13.mp3quran.net/husr/Rewayat-Aldori-A-n-Abi-Amr/',
    'ar.qiraat.huthifi.qalon': 'https://server9.mp3quran.net/huthifi_qalon/',
    'ar.qiraat.koshi.warsh': 'https://server11.mp3quran.net/koshi/',
    'ar.qiraat.yasseen.warsh': 'https://server11.mp3quran.net/qari/',
    'ar.qiraat.qazabri.warsh': 'https://server9.mp3quran.net/omar_warsh/',
    'ar.qiraat.dokali.qalon': 'https://server7.mp3quran.net/dokali/',
    'ar.qiraat.okasha.bazi':
      'https://server16.mp3quran.net/okasha/Rewayat-Albizi-A-n-Ibn-Katheer/',
    'ar.khaledjleel': 'https://server10.mp3quran.net/jleel/',
    'ar.raadialkurdi': 'https://server6.mp3quran.net/kurdi/',
    'ar.abdulaziahahmad': 'https://server11.mp3quran.net/a_ahmed/',
    };

    // Partial coverage map for future-proofing; null means full 114 coverage.
    static const Map<String, List<int>> limitedSurahCoverageByEditionId = {
    // Keep empty until a reciter with verified partial coverage is added.
    };

  static const Map<String, String> _majorQiraahByEditionId = {
    // Nafi'
    'ar.qiraat.qalon': 'nafi',
    'ar.qiraat.husary.qalon': 'nafi',
    'ar.qiraat.huthifi.qalon': 'nafi',
    'ar.qiraat.dokali.qalon': 'nafi',
    'ar.qiraat.warsh.azraq': 'nafi',
    'ar.qiraat.husary.warsh': 'nafi',
    'ar.qiraat.koshi.warsh': 'nafi',
    'ar.qiraat.yasseen.warsh': 'nafi',
    'ar.qiraat.qazabri.warsh': 'nafi',
    'ar.warsh.ibrahimdosary': 'nafi',
    'ar.warsh.yassinjazaery': 'nafi',
    'ar.warsh.abdulbasit': 'nafi',

    // Ibn Kathir
    'ar.qiraat.bazi': 'ibn_kathir',
    'ar.qiraat.okasha.bazi': 'ibn_kathir',
    'ar.qiraat.qunbol': 'ibn_kathir',

    // Abu Amr
    'ar.qiraat.duri.abuamr': 'abu_amr',
    'ar.qiraat.husary.duri': 'abu_amr',
    'ar.qiraat.sosi.abuamr': 'abu_amr',

    // Ibn Amir
    'ar.qiraat.ibndhakwan': 'ibn_amir',

    // Asim
    'ar.qiraat.shuba': 'asim',
    'ar.khaledjleel': 'asim',
    'ar.raadialkurdi': 'asim',
    'ar.abdulaziahahmad': 'asim',

    // Hamza
    'ar.qiraat.khalaf.hamza': 'hamza',

    // Kisai
    'ar.qiraat.duri.kisai': 'kisai',
  };

  static bool isWarshEdition(String identifier) {
    return warshEditionIds.contains(identifier);
  }

  static bool isQiraatEdition({
    required String identifier,
    String? name,
    String? englishName,
  }) {
    return identifier.startsWith('ar.qiraat.') ||
        warshEditionIds.contains(identifier) ||
        (name ?? '').contains('ورش') ||
        (englishName ?? '').toLowerCase().contains('warsh');
  }

  static bool isTimedEdition(String identifier) {
    return timedEditionIds.contains(identifier);
  }

  static bool isSurahLevelOnlyEdition(String identifier) {
    return identifier.startsWith('ar.qiraat.') &&
        !timedEditionIds.contains(identifier);
  }

  static bool usesMp3QuranSource(String identifier) {
    return mp3QuranServersByEditionId.containsKey(identifier);
  }

  static bool isSurahLevelEdition(String identifier) {
    return usesMp3QuranSource(identifier);
  }

  static String sourceKeyForEditionId(String identifier) {
    if (usesMp3QuranSource(identifier)) return 'mp3quran';
    return 'everyayah';
  }

  static List<int>? availableSurahsForEditionId(String identifier) {
    return limitedSurahCoverageByEditionId[identifier];
  }

  static bool hasLimitedSurahCoverage(String identifier) {
    return limitedSurahCoverageByEditionId.containsKey(identifier);
  }

  static bool isSurahAvailableForEdition(String identifier, int surahNumber) {
    if (surahNumber < 1 || surahNumber > 114) return false;
    final available = availableSurahsForEditionId(identifier);
    if (available == null || available.isEmpty) return true;
    return available.contains(surahNumber);
  }

  static List<int> effectiveDownloadSurahsForEdition(String identifier) {
    final available = availableSurahsForEditionId(identifier);
    if (available == null || available.isEmpty) return fullQuranSurahs;
    return available;
  }

  static String? majorQiraahKeyForEditionId(String identifier) {
    final mapped = _majorQiraahByEditionId[identifier];
    if (mapped != null) return mapped;

    if (identifier.startsWith('ar.warsh.') ||
        identifier.contains('.qalon') ||
        identifier.contains('.warsh')) {
      return 'nafi';
    }
    if (identifier.contains('.bazi') || identifier.contains('.qunbol')) {
      return 'ibn_kathir';
    }
    if (identifier.contains('.sosi.abuamr') ||
        identifier.contains('.duri.abuamr')) {
      return 'abu_amr';
    }
    if (identifier.contains('.ibndhakwan') ||
        identifier.contains('.hisham')) {
      return 'ibn_amir';
    }
    if (identifier.contains('.shuba') ||
        identifier == 'ar.khaledjleel' ||
        identifier == 'ar.raadialkurdi' ||
        identifier == 'ar.abdulaziahahmad') {
      return 'asim';
    }
    if (identifier.contains('.khalaf.hamza') || identifier.contains('.khallad')) {
      return 'hamza';
    }
    if (identifier.contains('.duri.kisai') ||
        identifier.contains('.abulharith')) {
      return 'kisai';
    }
    if (identifier.contains('.abujafar') ||
        identifier.contains('.ibnjammaz') ||
        identifier.contains('.ibnwardan')) {
      return 'abu_jafar';
    }
    if (identifier.contains('.yaqub') ||
        identifier.contains('.ruwais') ||
        identifier.contains('.rawh')) {
      return 'yaqub';
    }
    if (identifier.contains('.khalaf.ashir') ||
        identifier.contains('.ishaq') ||
        identifier.contains('.idris')) {
      return 'khalaf';
    }

    return null;
  }

  static String majorQiraahLabel(String qiraahKey, {required bool isArabic}) {
    if (isArabic) {
      switch (qiraahKey) {
        case 'nafi':
          return 'نافع';
        case 'ibn_kathir':
          return 'ابن كثير';
        case 'abu_amr':
          return 'أبو عمرو';
        case 'ibn_amir':
          return 'ابن عامر';
        case 'asim':
          return 'عاصم';
        case 'hamza':
          return 'حمزة';
        case 'kisai':
          return 'الكسائي';
        case 'abu_jafar':
          return 'أبو جعفر';
        case 'yaqub':
          return 'يعقوب';
        case 'khalaf':
          return 'خلف';
        default:
          return 'قراءة';
      }
    }

    switch (qiraahKey) {
      case 'nafi':
        return 'Nafi';
      case 'ibn_kathir':
        return 'Ibn Kathir';
      case 'abu_amr':
        return 'Abu Amr';
      case 'ibn_amir':
        return 'Ibn Amir';
      case 'asim':
        return 'Asim';
      case 'hamza':
        return 'Hamza';
      case 'kisai':
        return 'Al-Kisai';
      case 'abu_jafar':
        return 'Abu Jaafar';
      case 'yaqub':
        return 'Yaqub';
      case 'khalaf':
        return 'Khalaf';
      default:
        return 'Qiraah';
    }
  }

  static String? majorQiraahLabelForEditionId(
    String identifier, {
    required bool isArabic,
  }) {
    final key = majorQiraahKeyForEditionId(identifier);
    if (key == null) return null;
    return majorQiraahLabel(key, isArabic: isArabic);
  }

  static Color majorQiraahColor(String qiraahKey) {
    return AppColors.qiraahColor(qiraahKey);
  }

  static Color majorQiraahColorForEditionId(String identifier) {
    final key = majorQiraahKeyForEditionId(identifier);
    if (key == null) return AppColors.secondary;
    return AppColors.qiraahColor(key);
  }
}
