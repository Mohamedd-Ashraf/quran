import 'package:adhan/adhan.dart';

/// Prayer calculation methods and configurations
class PrayerCalculationConstants {
  /// Available calculation methods
  static const Map<String, ({String nameEn, String nameAr, String description})> calculationMethods = {
    'muslim_world_league': (
      nameEn: 'Muslim World League',
      nameAr: 'رابطة العالم الإسلامي',
      description: 'Standard method used by many countries',
    ),
    'egyptian': (
      nameEn: 'Egyptian General Authority',
      nameAr: 'الهيئة المصرية العامة للمساحة',
      description: 'Used in Egypt, Syria, Iraq, Lebanon, Malaysia',
    ),
    'karachi': (
      nameEn: 'University of Islamic Sciences, Karachi',
      nameAr: 'جامعة العلوم الإسلامية، كراتشي',
      description: 'Used in Pakistan, Bangladesh, India, Afghanistan',
    ),
    'umm_al_qura': (
      nameEn: 'Umm Al-Qura University',
      nameAr: 'جامعة أم القرى',
      description: 'Used in Saudi Arabia',
    ),
    'dubai': (
      nameEn: 'Dubai',
      nameAr: 'دبي',
      description: 'Used in UAE',
    ),
    'moonsighting': (
      nameEn: 'Moonsighting Committee',
      nameAr: 'لجنة رؤية الهلال',
      description: 'Used in some parts of USA',
    ),
    'north_america': (
      nameEn: 'ISNA (Islamic Society of North America)',
      nameAr: 'الجمعية الإسلامية لأمريكا الشمالية',
      description: 'Used in North America',
    ),
    'kuwait': (
      nameEn: 'Kuwait',
      nameAr: 'الكويت',
      description: 'Used in Kuwait',
    ),
    'qatar': (
      nameEn: 'Qatar',
      nameAr: 'قطر',
      description: 'Used in Qatar',
    ),
    'singapore': (
      nameEn: 'Singapore',
      nameAr: 'سنغافورة',
      description: 'Used in Singapore',
    ),
    'turkey': (
      nameEn: 'Turkey',
      nameAr: 'تركيا',
      description: 'Used in Turkey',
    ),
    'tehran': (
      nameEn: 'Institute of Geophysics, Tehran',
      nameAr: 'معهد الجيوفيزياء، طهران',
      description: 'Used in Iran',
    ),
  };
//TODO 
  /// Asr calculation methods
  static const Map<String, ({String nameEn, String nameAr, String description, String descriptionAr})> asrMethods = {
    'standard': (
      nameEn: 'Standard (Shafi, Maliki, Hanbali)',
      nameAr: 'القياسي (الشافعي، المالكي، الحنبلي)',
      description: 'Shadow length = object length + noon shadow',
      descriptionAr: 'طول الظل = طول الجسم + ظل الظهيرة',
    ),
    'hanafi': (
      nameEn: 'Hanafi',
      nameAr: 'الحنفي',
      description: 'Shadow length = 2 × object length + noon shadow',
      descriptionAr: 'طول الظل = 2 × طول الجسم + ظل الظهيرة',
    ),
  };

  /// Get CalculationParameters for a given method identifier
  static CalculationParameters getCalculationParameters(String methodId) {
    switch (methodId) {
      case 'muslim_world_league':
        return CalculationMethod.muslim_world_league.getParameters();
      case 'egyptian':
        return CalculationMethod.egyptian.getParameters();
      case 'karachi':
        return CalculationMethod.karachi.getParameters();
      case 'umm_al_qura':
        return CalculationMethod.umm_al_qura.getParameters();
      case 'dubai':
        return CalculationMethod.dubai.getParameters();
      case 'moonsighting':
        return CalculationMethod.moon_sighting_committee.getParameters();
      case 'north_america':
        return CalculationMethod.north_america.getParameters();
      case 'kuwait':
        return CalculationMethod.kuwait.getParameters();
      case 'qatar':
        return CalculationMethod.qatar.getParameters();
      case 'singapore':
        return CalculationMethod.singapore.getParameters();
      case 'turkey':
        return CalculationMethod.turkey.getParameters();
      case 'tehran':
        return CalculationMethod.tehran.getParameters();
      default:
        return CalculationMethod.muslim_world_league.getParameters();
    }
  }

  /// Apply Asr method to calculation parameters
  static CalculationParameters applyAsrMethod(
    CalculationParameters params,
    String asrMethodId,
  ) {
    if (asrMethodId == 'hanafi') {
      params.madhab = Madhab.hanafi;
    } else {
      params.madhab = Madhab.shafi;
    }
    return params;
  }

  /// Get complete calculation parameters with both method and Asr setting
  static CalculationParameters getCompleteParameters({
    required String calculationMethod,
    required String asrMethod,
  }) {
    var params = getCalculationParameters(calculationMethod);
    params = applyAsrMethod(params, asrMethod);
    return params;
  }

  /// Guess the best calculation method based on GPS coordinates.
  /// Returns a method ID string matching [calculationMethods].
  /// Defaults to 'egyptian' when no region matches.
  static String methodFromCoordinates(double lat, double lng) {
    // Saudi Arabia
    if (lat >= 16.0 && lat <= 32.5 && lng >= 34.5 && lng <= 55.5) {
      return 'umm_al_qura';
    }
    // Egypt / Libya / Syria / Lebanon / Iraq / Sudan
    if (lat >= 20.0 && lat <= 37.0 && lng >= 24.0 && lng <= 48.0) {
      return 'egyptian';
    }
    // UAE / Bahrain / Oman
    if (lat >= 22.0 && lat <= 26.5 && lng >= 51.0 && lng <= 60.0) {
      return 'dubai';
    }
    // Qatar
    if (lat >= 24.4 && lat <= 26.3 && lng >= 50.5 && lng <= 51.7) {
      return 'qatar';
    }
    // Kuwait
    if (lat >= 28.5 && lat <= 30.1 && lng >= 46.5 && lng <= 48.5) {
      return 'kuwait';
    }
    // Turkey
    if (lat >= 36.0 && lat <= 42.5 && lng >= 26.0 && lng <= 44.8) {
      return 'turkey';
    }
    // Pakistan / Bangladesh / India / Afghanistan
    if (lat >= 7.0 && lat <= 38.0 && lng >= 60.0 && lng <= 97.5) {
      return 'karachi';
    }
    // Iran
    if (lat >= 25.0 && lat <= 40.0 && lng >= 44.0 && lng <= 63.5) {
      return 'tehran';
    }
    // Singapore / Malaysia / Indonesia
    if (lat >= -11.0 && lat <= 7.5 && lng >= 95.0 && lng <= 141.0) {
      return 'singapore';
    }
    // North America
    if (lat >= 24.0 && lat <= 71.0 && lng >= -170.0 && lng <= -52.0) {
      return 'north_america';
    }
    // Morocco / Algeria / Tunisia (Northwest Africa)
    if (lat >= 19.0 && lat <= 38.0 && lng >= -17.5 && lng <= 15.0) {
      return 'muslim_world_league';
    }
    // Default: Egyptian (widely used in Arab world)
    return 'egyptian';
  }
}
