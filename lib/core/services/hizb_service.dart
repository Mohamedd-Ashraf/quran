import 'package:qcf_quran_plus/qcf_quran_plus.dart';

/// Information about a Hizb quarter at a specific page
class HizbInfo {
  final int hizbNumber;
  final int quarterInHizb;
  final String arabicText;

  const HizbInfo({
    required this.hizbNumber,
    required this.quarterInHizb,
    required this.arabicText,
  });

  @override
  String toString() => arabicText;
}

/// Service for managing Hizb (حزب) information in the Quran
class HizbService {
  static final HizbService _instance = HizbService._internal();
  factory HizbService() => _instance;
  HizbService._internal() {
    _initialize();
  }

  final Map<int, HizbInfo> _pageToHizbInfo = {};

  void _initialize() {
    if (_pageToHizbInfo.isNotEmpty) return;

    for (int i = 0; i < quarters.length; i++) {
      final quarter = quarters[i];
      final surah = quarter['surah'] as int;
      final ayah = quarter['ayah'] as int;
      final pageNumber = getPageNumber(surah, ayah);

      final hizbNumber = (i ~/ 4) + 1;
      final quarterInHizb = (i % 4) + 1;
      final arabicText = _generateArabicText(hizbNumber, quarterInHizb);

      _pageToHizbInfo[pageNumber] = HizbInfo(
        hizbNumber: hizbNumber,
        quarterInHizb: quarterInHizb,
        arabicText: arabicText,
      );
    }
  }

  String _generateArabicText(int hizbNumber, int quarterInHizb) {
    final hizbNum = _toArabicNumerals(hizbNumber);

    switch (quarterInHizb) {
      case 1:
        return 'الحزب $hizbNum';
      case 2:
        return 'ربع الحزب $hizbNum';
      case 3:
        return 'نصف الحزب $hizbNum';
      case 4:
        return 'ثلاثة أرباع الحزب $hizbNum';
      default:
        return 'الحزب $hizbNum';
    }
  }

  /// Converts number to Arabic numerals (٠١٢٣٤٥٦٧٨٩)
  String _toArabicNumerals(int n) {
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return n.toString().split('').map((d) => arabicDigits[int.parse(d)]).join();
  }

  HizbInfo? getHizbInfoForPage(int pageNumber) => _pageToHizbInfo[pageNumber];

  bool isQuarterStart(int pageNumber) => _pageToHizbInfo.containsKey(pageNumber);
}
