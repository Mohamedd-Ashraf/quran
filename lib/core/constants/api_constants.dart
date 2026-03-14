class ApiConstants {
  static const String baseUrl = 'https://api.alquran.cloud/v1';

  // Endpoints
  static const String surahEndpoint = '/surah';
  static const String ayahEndpoint = '/ayah';
  static const String juzEndpoint = '/juz';
  static const String editionEndpoint = '/edition';
  static const String searchEndpoint = '/search';

  // Default edition
  static const String defaultEdition = 'quran-uthmani';
  static const String simpleEdition = 'quran-simple';
  static const String defaultTranslation = 'en.asad';

  // ─── Tafsir / Commentary editions ────────────────────────────────────────
  // Ibn Kathir – served via api.quran.com (separate API, not alquran.cloud)
  static const String tafsirIbnKathir = 'ar.ibnkathir'; // تفسير ابن كثير
  static const String quranComBaseUrl = 'https://api.quran.com/api/v4';
  static const int ibnKathirTafsirId =
      14; // quran.com tafsir ID for Ibn Kathir Arabic (ar-tafsir-ibn-kathir)

  // Arabic tafsirs (alquran.cloud)
  static const String tafsirMuyassar = 'ar.muyassar'; // التفسير الميسر
  static const String tafsirJalalayn = 'ar.jalalayn'; // تفسير الجلالين
  static const String tafsirWahidi = 'ar.wahidi'; // أسباب النزول
  static const String tafsirQurtubi = 'ar.qurtubi'; // تفسير القرطبي
  static const String tafsirMiqbas = 'ar.miqbas'; // تنوير المقباس (ابن عباس)
  static const String tafsirWaseet = 'ar.waseet'; // التفسير الوسيط
  static const String tafsirBaghawi = 'ar.baghawi'; // تفسير البغوي

  // English translations / commentaries
  static const String tafsirAsad = 'en.asad'; // Muhammad Asad
  static const String tafsirMaududi = 'en.maududi'; // Maududi
  static const String tafsirPickthall = 'en.pickthall'; // Pickthall

  // Ordered list used by the Tafsir screen
  static const List<Map<String, String>> tafsirEditions = [
    {
      'id': tafsirMuyassar,
      'nameAr': 'الميسر',
      'nameEn': 'Al-Muyassar (AR)',
      'lang': 'ar',
    },
    {
      'id': tafsirIbnKathir,
      'nameAr': 'ابن كثير',
      'nameEn': 'Ibn Kathir (AR)',
      'lang': 'ar',
    },
    {
      'id': tafsirJalalayn,
      'nameAr': 'الجلالين',
      'nameEn': 'Al-Jalalayn (AR)',
      'lang': 'ar',
    },
    {
      'id': tafsirQurtubi,
      'nameAr': 'القرطبي',
      'nameEn': 'Al-Qurtubi (AR)',
      'lang': 'ar',
    },
    {
      'id': tafsirBaghawi,
      'nameAr': 'البغوي',
      'nameEn': 'Al-Baghawi (AR)',
      'lang': 'ar',
    },
    {
      'id': tafsirWaseet,
      'nameAr': 'الوسيط',
      'nameEn': 'Al-Waseet (AR)',
      'lang': 'ar',
    },
    {
      'id': tafsirMiqbas,
      'nameAr': 'ابن عباس',
      'nameEn': 'Ibn Abbas (AR)',
      'lang': 'ar',
    },
    {
      'id': tafsirWahidi,
      'nameAr': 'أسباب النزول',
      'nameEn': 'Al-Wahidi (AR)',
      'lang': 'ar',
    },
    {
      'id': tafsirAsad,
      'nameAr': 'محمد أسد',
      'nameEn': 'Asad (EN)',
      'lang': 'en',
    },
    {
      'id': tafsirMaududi,
      'nameAr': 'المودودي',
      'nameEn': 'Maududi (EN)',
      'lang': 'en',
    },
    {
      'id': tafsirPickthall,
      'nameAr': 'بيكثال',
      'nameEn': 'Pickthall (EN)',
      'lang': 'en',
    },
  ];

  /// Approximate on-disk size (MB) for downloading all ayahs of each tafsir.
  /// Actual size varies by encoding and content length per ayah.
  static const Map<String, double> tafsirEstimatedSizeMb = {
    tafsirMuyassar: 1.5,
    tafsirIbnKathir: 15.0,
    tafsirJalalayn: 1.0,
    tafsirQurtubi: 15.5,
    tafsirBaghawi: 8.0,
    tafsirWaseet: 10.0,
    tafsirMiqbas: 3.5,
    tafsirWahidi: 1.5,
    tafsirAsad: 2.0,
    tafsirMaududi: 4.5,
    tafsirPickthall: 1.2,
  };

  // ─── Arabic Quran Text Editions ──────────────────────────────────────────
  /// All available Arabic Quran text editions from api.alquran.cloud
  /// Based on the Arabic Font Edition Tester: https://alquran.cloud/arabic-font-edition-tester
  static const List<Map<String, String>> quranEditions = [
    {
      'id': 'quran-uthmani',
      'nameAr': 'عثماني (كامل)',
      'nameEn': 'Uthmani (Full)',
      'descAr': 'الرسم العثماني مع تشكيل كامل',
      'descEn': 'Full Uthmani script with complete diacritics',
    },
    {
      'id': 'quran-uthmani-min',
      'nameAr': 'عثماني (مختصر)',
      'nameEn': 'Uthmani Minimal',
      'descAr': 'الرسم العثماني بتشكيل بسيط',
      'descEn': 'Uthmani script with minimal diacritics',
    },
    {
      'id': 'quran-uthmani-quran-academy',
      'nameAr': 'عثماني (أكاديمية القرآن)',
      'nameEn': 'Uthmani — Quran Academy',
      'descAr': 'نص عثماني مُعدَّل للعمل مع خط كتاب',
      'descEn': 'Modified Uthmani text for Kitab font',
    },
    {
      'id': 'quran-simple',
      'nameAr': 'مبسط (بتشكيل)',
      'nameEn': 'Simple (with diacritics)',
      'descAr': 'خط مبسط مع تشكيل بسيط',
      'descEn': 'Simplified script with basic diacritics',
    },
    {
      'id': 'quran-simple-clean',
      'nameAr': 'مبسط (بلا تشكيل)',
      'nameEn': 'Simple (no diacritics)',
      'descAr': 'خط مبسط بدون تشكيل',
      'descEn': 'Simplified script without any diacritics',
    },
    {
      'id': 'quran-simple-enhanced',
      'nameAr': 'مبسط محسَّن',
      'nameEn': 'Simple Enhanced',
      'descAr': 'نسخة مبسطة محسَّنة بلا تشكيل',
      'descEn': 'Enhanced simplified version without diacritics',
    },
    {
      'id': 'quran-simple-min',
      'nameAr': 'مبسط (حد أدنى)',
      'nameEn': 'Simple Minimal',
      'descAr': 'نسخة مبسطة بحد أدنى من الرموز',
      'descEn': 'Simplified version with minimal symbols',
    },
    {
      'id': 'quran-unicode',
      'nameAr': 'عثماني يونيكود',
      'nameEn': 'Unicode Uthmani',
      'descAr': 'نص عثماني بترميز يونيكود (خالد حسني)',
      'descEn': 'Uthmani Unicode text by Khaled Hosny',
    },
    {
      'id': 'quran-kids',
      'nameAr': 'نسخة الأطفال',
      'nameEn': 'Kids Edition',
      'descAr': 'نص مبسط مخصص للأطفال',
      'descEn': 'Simplified text designed for children',
    },
    {
      'id': 'quran-wordbyword',
      'nameAr': 'كلمة بكلمة',
      'nameEn': 'Word by Word',
      'descAr': 'مع معاني المفردات',
      'descEn': 'Word-by-word meanings included',
    },
    {
      'id': 'quran-wordbyword-2',
      'nameAr': 'كلمة بكلمة (د. شهناز)',
      'nameEn': 'Word by Word v2',
      'descAr': 'ترجمة مفردات القرآن — د. شهناز شيخ',
      'descEn': 'Word-by-word translation by Dr. Shehnaz Shaikh',
    },
    {
      'id': 'quran-tajweed',
      'nameAr': 'تجويد ملوّن',
      'nameEn': 'Tajweed (Colored)',
      'descAr': 'نص القرآن مع علامات التجويد الملوّنة',
      'descEn': 'Quran text with colored tajweed markers',
    },
    {
      'id': 'quran-corpus-qd',
      'nameAr': 'كوربس',
      'nameEn': 'Corpus',
      'descAr': 'نص القرآن من مشروع الكوربس',
      'descEn': 'Quran text from the Corpus project',
    },
  ];

  // ─── Quran Display Fonts ─────────────────────────────────────────────────
  /// Font options for displaying Quran Arabic text in the app.
  /// 'id' matches the key used in AppSettingsState.quranFont
  static const List<Map<String, String>> quranFonts = [
    {
      'id': 'amiri_quran',
      'nameAr': 'أميري قرآن',
      'nameEn': 'Amiri Quran',
      'descAr': 'خط متخصص لعرض المصحف الشريف',
      'sample': 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ',
    },
    {
      'id': 'scheherazade',
      'nameAr': 'شهرزاد',
      'nameEn': 'Scheherazade New',
      'descAr': 'خط نسخي كلاسيكي يدعم الرسم العثماني كاملاً',
      'sample': 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ',
    },
    {
      'id': 'amiri',
      'nameAr': 'أميري',
      'nameEn': 'Amiri',
      'descAr': 'خط نسخي أنيق مستوحى من الخط الحجازي',
      'sample': 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ',
    },
    {
      'id': 'noto_naskh',
      'nameAr': 'نوتو نسخ',
      'nameEn': 'Noto Naskh Arabic',
      'descAr': 'خط نسخي واضح من مجموعة Noto',
      'sample': 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ',
    },
    {
      'id': 'lateef',
      'nameAr': 'لطيف',
      'nameEn': 'Lateef',
      'descAr': 'خط نسخي مصمم خصيصاً للعربية والأردية',
      'sample': 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ',
    },
    {
      'id': 'markazi',
      'nameAr': 'مرکزی',
      'nameEn': 'Markazi Text',
      'descAr': 'خط عربي-لاتيني أنيق للنصوص الطويلة',
      'sample': 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ',
    },
    {
      'id': 'noto_kufi',
      'nameAr': 'نوتو كوفي',
      'nameEn': 'Noto Kufi Arabic',
      'descAr': 'خط كوفي حديث من مجموعة Noto',
      'sample': 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ',
    },
    {
      'id': 'reem_kufi',
      'nameAr': 'ريم كوفي',
      'nameEn': 'Reem Kufi',
      'descAr': 'خط كوفي عربي بتصميم هندسي متوازن',
      'sample': 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ',
    },
    {
      'id': 'tajawal',
      'nameAr': 'تجوال',
      'nameEn': 'Tajawal',
      'descAr': 'خط عربي حديث وقابل للقراءة',
      'sample': 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ',
    },
    {
      'id': 'cairo',
      'nameAr': 'القاهرة',
      'nameEn': 'Cairo',
      'descAr': 'خط بدون تشريف مناسب للنصوص المبسطة',
      'sample': 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ',
    },
  ];
}
