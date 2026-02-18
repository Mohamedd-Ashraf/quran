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
}
