import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../constants/api_constants.dart';
import '../constants/recitation_catalog.dart';
import '../network/network_info.dart';

class AudioEdition {
  final String identifier;
  final String? name;
  final String? englishName;
  final String? language;
  final String? format;
  final String? type;
  final String? sourceKey;
  final bool isSurahLevelSource;
  final bool hasTiming;
  final List<int>? availableSurahs;

  const AudioEdition({
    required this.identifier,
    this.name,
    this.englishName,
    this.language,
    this.format,
    this.type,
    this.sourceKey,
    this.isSurahLevelSource = false,
    this.hasTiming = false,
    this.availableSurahs,
  });

  AudioEdition copyWith({
    String? identifier,
    String? name,
    String? englishName,
    String? language,
    String? format,
    String? type,
    String? sourceKey,
    bool? isSurahLevelSource,
    bool? hasTiming,
    List<int>? availableSurahs,
    bool clearAvailableSurahs = false,
  }) {
    return AudioEdition(
      identifier: identifier ?? this.identifier,
      name: name ?? this.name,
      englishName: englishName ?? this.englishName,
      language: language ?? this.language,
      format: format ?? this.format,
      type: type ?? this.type,
      sourceKey: sourceKey ?? this.sourceKey,
      isSurahLevelSource: isSurahLevelSource ?? this.isSurahLevelSource,
      hasTiming: hasTiming ?? this.hasTiming,
      availableSurahs: clearAvailableSurahs
          ? null
          : (availableSurahs ?? this.availableSurahs),
    );
  }

  /// Default (legacy) display name.
  ///
  /// Prefers `englishName` then `name`, falling back to `identifier`.
  String get displayName => displayNameForAppLanguage('en');

  /// Display name that matches the app UI language.
  ///
  /// - If app language is Arabic, prefer `name` (often Arabic) then `englishName`.
  /// - Otherwise, prefer `englishName` then `name`.
  String displayNameForAppLanguage(String appLanguageCode) {
    final isArabicUi = appLanguageCode.toLowerCase().startsWith('ar');

    String? primary;
    String? secondary;

    if (isArabicUi) {
      primary = name;
      secondary = englishName;
    } else {
      primary = englishName;
      secondary = name;
    }

    final best = (primary?.trim().isNotEmpty ?? false)
        ? primary!.trim()
        : (secondary?.trim().isNotEmpty ?? false)
            ? secondary!.trim()
            : identifier;

    if (best == identifier) return identifier;
    // In Arabic UI, the Arabic name alone is sufficient — skip the identifier suffix.
    if (isArabicUi) return best;
    return '$best ($identifier)';
  }

  Map<String, dynamic> toJson() => {
        'identifier': identifier,
        'name': name,
        'englishName': englishName,
        'language': language,
        'format': format,
        'type': type,
      'sourceKey': sourceKey,
      'isSurahLevelSource': isSurahLevelSource,
      'hasTiming': hasTiming,
      'availableSurahs': availableSurahs,
      };

  factory AudioEdition.fromJson(Map<String, dynamic> json) {
    return AudioEdition(
      identifier: (json['identifier'] as String?) ?? '',
      name: json['name'] as String?,
      englishName: json['englishName'] as String?,
      language: json['language'] as String?,
      format: json['format'] as String?,
      type: json['type'] as String?,
      sourceKey: json['sourceKey'] as String?,
      isSurahLevelSource: json['isSurahLevelSource'] as bool? ?? false,
      hasTiming: json['hasTiming'] as bool? ?? false,
      availableSurahs: (json['availableSurahs'] as List<dynamic>?)
          ?.whereType<num>()
          .map((e) => e.toInt())
          .toList(),
    );
  }
}

class AudioEditionService {
  static const _cacheKey = 'audio_editions_cache_v1';

  final SharedPreferences _prefs;
  final http.Client _client;
  final NetworkInfo _networkInfo;

  AudioEditionService(this._prefs, this._client, this._networkInfo);

  /// قراء مضافون يدوياً — الأولوية للأسماء المحددة هنا على أسماء AlQuran.cloud API
  /// (أسماؤنا أكثر وصفاً وتفصيلاً من الأسماء المختصرة في الـ API).
  /// هؤلاء القراء مدعومون عبر everyayah.com مباشرةً.
  static const List<AudioEdition> _extraEditions = [
    AudioEdition(
      identifier: 'ar.alijaber',
      name: 'علي عبد الله جابر',
      englishName: 'Ali Abdullah Jaber',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // ─── الشيخ محمد صديق المنشاوي ────────────────────────────────────────
    // نسخة المرتل (ترتيل): everyayah.com/data/Minshawy_Murattal_128kbps/
    AudioEdition(
      identifier: 'ar.minshawi',
      name: 'محمد صديق المنشاوي (مرتل)',
      englishName: 'Muhammad Siddiq al-Minshawi (Murattal)',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // نسخة المجود (تجويد): everyayah.com/data/Minshawy_Mujawwad_128kbps/
    AudioEdition(
      identifier: 'ar.minshawimujawwad',
      name: 'محمد صديق المنشاوي (مجود)',
      englishName: 'Muhammad Siddiq al-Minshawi (Mujawwad)',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // ─── الشيخ عبد الباسط عبد الصمد ─────────────────────────────────────────
    // نسخة المرتل: everyayah.com/data/Abdul_Basit_Murattal_64kbps/
    // (ar.abdulsamad هو المعرّف الصحيح في alquran.cloud API)
    AudioEdition(
      identifier: 'ar.abdulsamad',
      name: 'عبد الباسط عبد الصمد (مرتل)',
      englishName: 'Abdul Basit Abd as-Samad (Murattal)',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // نسخة المجود: everyayah.com/data/Abdul_Basit_Mujawwad_128kbps/
    AudioEdition(
      identifier: 'ar.abdulbasitmujawwad',
      name: 'عبد الباسط عبد الصمد (مجود)',
      englishName: 'Abdul Basit Abd as-Samad (Mujawwad)',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // ─── الشيخ ماهر المعيقلي ──────────────────────────────────────────────────
    // everyayah.com/data/Maher_AlMuaiqly_64kbps/
    AudioEdition(
      identifier: 'ar.mahermuaiqly',
      name: 'ماهر المعيقلي',
      englishName: 'Maher Al-Muaiqly',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // ─── الشيخ ناصر القطامي ───────────────────────────────────────────────────
    // everyayah.com/data/Nasser_Alqatami_128kbps/
    AudioEdition(
      identifier: 'ar.nasserqatami',
      name: 'ناصر القطامي',
      englishName: 'Nasser Al-Qatami',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // ─── الشيخ ياسر الدوسري ───────────────────────────────────────────────────
    // everyayah.com/data/Yasser_Ad-Dussary_128kbps/
    AudioEdition(
      identifier: 'ar.yasiradussary',
      name: 'ياسر الدوسري',
      englishName: 'Yasser Ad-Dossari',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // ─── الشيخ أحمد ابن علي العجمي ──────────────────────────────────────────
    // everyayah.com/data/ahmed_ibn_ali_al_ajamy_128kbps/
    AudioEdition(
      identifier: 'ar.ahmedajamy',
      name: 'أحمد ابن علي العجمي',
      englishName: 'Ahmed ibn Ali al-Ajamy',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // ─── الشيخ محمود خليل الحصري ─────────────────────────────────────────────
    // نسخة المجود: everyayah.com/data/Husary_128kbps_Mujawwad/
    AudioEdition(
      identifier: 'ar.husarymujawwad',
      name: 'محمود خليل الحصري (مجود)',
      englishName: 'Mahmoud Khalil Al-Husary (Mujawwad)',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // ─────────────────────────────────────────────────────────────────────────
    //  قراء إضافيون من alquran.cloud API + everyayah.com
    // ─────────────────────────────────────────────────────────────────────────

    // ─── الشيخ سعد الغامدي ───────────────────────────────────────────────────
    // everyayah.com/data/Ghamadi_40kbps/
    AudioEdition(
      identifier: 'ar.ghamadi',
      name: 'سعد الغامدي',
      englishName: 'Saad Al-Ghamdi',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // ─── الشيخ علي الحذيفي ───────────────────────────────────────────────────
    // everyayah.com/data/Hudhaify_128kbps/
    AudioEdition(
      identifier: 'ar.hudhaify',
      name: 'علي بن عبدالرحمن الحذيفي',
      englishName: 'Ali ibn Abdurrahman Al-Hudhaify',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // ─── الشيخ هاني الرفاعي ──────────────────────────────────────────────────
    // everyayah.com/data/Hani_Rifai_192kbps/
    AudioEdition(
      identifier: 'ar.hanirifai',
      name: 'هاني الرفاعي',
      englishName: 'Hani Rifai',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // ─── الشيخ عبدالله بصفر ──────────────────────────────────────────────────
    // everyayah.com/data/Abdullah_Basfar_192kbps/
    AudioEdition(
      identifier: 'ar.abdullahbasfar',
      name: 'عبدالله بصفر',
      englishName: 'Abdullah Basfar',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // ─── الشيخ أيمن سويد ─────────────────────────────────────────────────────
    // everyayah.com/data/Ayman_Sowaid_64kbps/
    AudioEdition(
      identifier: 'ar.aymanswoaid',
      name: 'أيمن سويد',
      englishName: 'Ayman Sowaid',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // ─── الشيخ إبراهيم الأخضر ────────────────────────────────────────────────
    // everyayah.com/data/Ibrahim_Akhdar_64kbps/
    // (المعرّف في API هو ar.ibrahimakhbar)
    AudioEdition(
      identifier: 'ar.ibrahimakhbar',
      name: 'إبراهيم الأخضر',
      englishName: 'Ibrahim Akhdar',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // ─── الشيخ محسن القاسم ───────────────────────────────────────────────────
    // everyayah.com/data/Muhsin_Al_Qasim_192kbps/
    AudioEdition(
      identifier: 'ar.muhsinqasim',
      name: 'محسن القاسم',
      englishName: 'Muhsin Al-Qasim',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // ─── الشيخ محمد الطبلاوي ─────────────────────────────────────────────────
    // everyayah.com/data/Mohammad_al_Tablaway_128kbps/
    AudioEdition(
      identifier: 'ar.mohammadaltablawi',
      name: 'محمد الطبلاوي',
      englishName: 'Muhammad Al-Tablawi',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // ─── الشيخ مصطفى إسماعيل ─────────────────────────────────────────────────
    // everyayah.com/data/Mustafa_Ismail_48kbps/
    AudioEdition(
      identifier: 'ar.mustafaismail',
      name: 'مصطفى إسماعيل',
      englishName: 'Mustafa Ismail',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // ─── الشيخ صلاح البدير ───────────────────────────────────────────────────
    // everyayah.com/data/Salah_Al_Budair_128kbps/
    AudioEdition(
      identifier: 'ar.salahbudair',
      name: 'صلاح البدير',
      englishName: 'Salah Al-Budair',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // ─── الشيخ صلاح بو خاطر ──────────────────────────────────────────────────
    // everyayah.com/data/Salaah_AbdulRahman_Bukhatir_128kbps/
    AudioEdition(
      identifier: 'ar.salaahbukhatir',
      name: 'صلاح عبدالرحمن بو خاطر',
      englishName: 'Salaah AbdulRahman Bukhatir',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // ─── الشيخ عبدالله عوّاد الجهني ──────────────────────────────────────────
    // everyayah.com/data/Abdullaah_3awwaad_Al-Juhaynee_128kbps/
    AudioEdition(
      identifier: 'ar.abdullahjuhani',
      name: 'عبدالله عوّاد الجهني',
      englishName: 'Abdullah Awwad Al-Juhani',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // ─── الشيخ ياسر سلامة ────────────────────────────────────────────────────
    // everyayah.com/data/Yaser_Salamah_128kbps/
    AudioEdition(
      identifier: 'ar.yaserslama',
      name: 'ياسر سلامة',
      englishName: 'Yaser Salamah',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // ─── الشيخ خليفة الطنيجي ─────────────────────────────────────────────────
    // everyayah.com/data/khalefa_al_tunaiji_64kbps/
    AudioEdition(
      identifier: 'ar.khaledtunaiji',
      name: 'خليفة الطنيجي',
      englishName: 'Khalefa Al-Tunaiji',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // ─── الشيخ خالد عبدالله القحطاني ────────────────────────────────────────
    // everyayah.com/data/Khaalid_Abdullaah_al-Qahtaanee_192kbps/
    AudioEdition(
      identifier: 'ar.khaalidqahtani',
      name: 'خالد عبدالله القحطاني',
      englishName: 'Khaalid Abdullaah al-Qahtaani',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // ─── الشيخ نبيل الرفاعي ──────────────────────────────────────────────────
    // everyayah.com/data/Nabil_Rifa3i_48kbps/
    AudioEdition(
      identifier: 'ar.nabilerrifaai',
      name: 'نبيل الرفاعي',
      englishName: 'Nabil Al-Rifai',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // ─── الشيخ سهل ياسين ─────────────────────────────────────────────────────
    // everyayah.com/data/Sahl_Yassin_128kbps/
    AudioEdition(
      identifier: 'ar.sahlyssin',
      name: 'سهل ياسين',
      englishName: 'Sahl Yassin',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // ─── الشيخ فارس عباد ─────────────────────────────────────────────────────
    // everyayah.com/data/Fares_Abbad_64kbps/
    AudioEdition(
      identifier: 'ar.faresabbad',
      name: 'فارس عباد',
      englishName: 'Fares Abbad',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // ─── الشيخ محمود علي البنّا ──────────────────────────────────────────────
    // everyayah.com/data/mahmoud_ali_al_banna_32kbps/
    AudioEdition(
      identifier: 'ar.mahmoudbanna',
      name: 'محمود علي البنّا',
      englishName: 'Mahmoud Ali Al-Banna',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // ─── الشيخ علي حجاج السويسي ──────────────────────────────────────────────
    // everyayah.com/data/Ali_Hajjaj_AlSuesy_128kbps/
    AudioEdition(
      identifier: 'ar.alisuesy',
      name: 'علي حجاج السويسي',
      englishName: 'Ali Hajjaj Al-Suesy',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // ─── القارئ كريم منصوري ──────────────────────────────────────────────────
    // everyayah.com/data/Karim_Mansoori_40kbps/ (قارئ إيراني)
    AudioEdition(
      identifier: 'ar.karimmansoori',
      name: 'كريم منصوري',
      englishName: 'Karim Mansoori',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // ─── قراء إضافيون جدد من everyayah.com ────────────────────────────────────
    // everyayah.com/data/Abdullah_Matroud_128kbps/
    AudioEdition(
      identifier: 'ar.abdullahmatroud',
      name: 'عبدالله مطرود',
      englishName: 'Abdullah Matroud',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // everyayah.com/data/Ahmed_Neana_128kbps/
    AudioEdition(
      identifier: 'ar.ahmedneana',
      name: 'أحمد نعينع',
      englishName: 'Ahmed Neana',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // everyayah.com/data/Akram_AlAlaqimy_128kbps/
    AudioEdition(
      identifier: 'ar.akramalalaqimy',
      name: 'أكرم العلاقمي',
      englishName: 'Akram Al-Alaqimy',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // everyayah.com/data/Husary_Muallim_128kbps/ (الحصري - المعلم)
    AudioEdition(
      identifier: 'ar.husarymuallim',
      name: 'محمود خليل الحصري (معلم)',
      englishName: 'Mahmoud Khalil Al-Husary (Muallim)',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // everyayah.com/data/MaherAlMuaiqly128kbps/
    AudioEdition(
      identifier: 'ar.mahermuaiqly128',
      name: 'ماهر المعيقلي (جودة عالية)',
      englishName: 'Maher Al-Muaiqly (HQ)',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // everyayah.com/data/Muhammad_AbdulKareem_128kbps/
    AudioEdition(
      identifier: 'ar.muhammadabdulkareem',
      name: 'محمد عبدالكريم',
      englishName: 'Muhammad AbdulKareem',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // everyayah.com/data/Minshawy_Teacher_128kbps/ (المنشاوي - المعلم)
    AudioEdition(
      identifier: 'ar.minshawiteacher',
      name: 'محمد صديق المنشاوي (معلم)',
      englishName: 'Muhammad Siddiq al-Minshawi (Teacher)',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // everyayah.com/data/aziz_alili_128kbps/
    AudioEdition(
      identifier: 'ar.azizalili',
      name: 'عزيز عليلي',
      englishName: 'Aziz Alili',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // ─── قراءة ورش عن نافع (القراءات العشر) ──────────────────────────────────
    // everyayah.com/data/warsh/warsh_ibrahim_aldosary_128kbps/
    AudioEdition(
      identifier: 'ar.warsh.ibrahimdosary',
      name: 'إبراهيم الدوسري (ورش عن نافع)',
      englishName: 'Ibrahim Al-Dosary (Warsh)',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // everyayah.com/data/warsh/warsh_yassin_al_jazaery_64kbps/
    AudioEdition(
      identifier: 'ar.warsh.yassinjazaery',
      name: 'ياسين الجزائري (ورش عن نافع)',
      englishName: 'Yassin Al-Jazaery (Warsh)',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // everyayah.com/data/warsh/warsh_Abdul_Basit_128kbps/
    AudioEdition(
      identifier: 'ar.warsh.abdulbasit',
      name: 'عبد الباسط عبد الصمد (ورش عن نافع)',
      englishName: 'Abdul Basit (Warsh)',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // ─── القراءات العشر — مصدر mp3quran.net ────────────────────────────────
    // نافع المدني: قالون (عبد الرؤوف الترابلسي) ─────────────────────────────
    AudioEdition(
      identifier: 'ar.qiraat.qalon',
      name: 'أحمد الطرابلسي (قالون عن نافع)',
      englishName: 'Ahmad Al-Tarabulsi (Qalon an Nafi)',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // نافع المدني: ورش من طريق الأزرق (على دبان) ─────────────────────────────
    AudioEdition(
      identifier: 'ar.qiraat.warsh.azraq',
      name: 'أحمد ديبان (ورش عن نافع - طريق الأزرق)',
      englishName: 'Ahmad Deban (Warsh an Nafi - Tariq Al-Azraq)',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // ابن كثير المكي: البزي (على دبان) ───────────────────────────────────────
    AudioEdition(
      identifier: 'ar.qiraat.bazi',
      name: 'أحمد ديبان (البزي عن ابن كثير)',
      englishName: 'Ahmad Deban (Al-Bazi an Ibn Katheer)',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // ابن كثير المكي: قنبل (على دبان) ────────────────────────────────────────
    AudioEdition(
      identifier: 'ar.qiraat.qunbol',
      name: 'أحمد ديبان (قنبل عن ابن كثير)',
      englishName: 'Ahmad Deban (Qunbol an Ibn Katheer)',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // أبو عمرو البصري: الدوري (على دبان) ─────────────────────────────────────
    AudioEdition(
      identifier: 'ar.qiraat.duri.abuamr',
      name: 'أحمد ديبان (الدوري عن أبي عمرو)',
      englishName: 'Ahmad Deban (Al-Duri an Abi Amr)',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // ابن عامر الشامي: ابن ذكوان (مفتاح السلطاني) ────────────────────────────
    AudioEdition(
      identifier: 'ar.qiraat.ibndhakwan',
      name: 'مفتاح السلطاني (ابن ذكوان عن ابن عامر)',
      englishName: 'Muftah Al-Sultani (Ibn Dhakwan an Ibn Amer)',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // عاصم الكوفي: شعبة (على دبان) ───────────────────────────────────────────
    AudioEdition(
      identifier: 'ar.qiraat.shuba',
      name: 'أحمد ديبان (شعبة عن عاصم)',
      englishName: 'Ahmad Deban (Shu\'ba an Asim)',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // الكسائي الكوفي: الدوري (مفتاح السلطاني) ───────────────────────────────
    AudioEdition(
      identifier: 'ar.qiraat.duri.kisai',
      name: 'مفتاح السلطاني (الدوري عن الكسائي)',
      englishName: 'Muftah Al-Sultani (Al-Duri an Al-Kisai)',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),    // ─── القراءات العشر — الحصري ────────────────────────────────────────────
    // نافع المدني: قالون (محمود خليل الحصري) ─────────────────────────────────
    AudioEdition(
      identifier: 'ar.qiraat.husary.qalon',
      name: 'محمود خليل الحصري (قالون عن نافع)',
      englishName: 'Mahmoud Khalil Al-Husary (Qalon an Nafi)',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // نافع المدني: ورش (محمود خليل الحصري) ───────────────────────────────────
    AudioEdition(
      identifier: 'ar.qiraat.husary.warsh',
      name: 'محمود خليل الحصري (ورش عن نافع)',
      englishName: 'Mahmoud Khalil Al-Husary (Warsh an Nafi)',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // أبو عمرو البصري: الدوري (محمود خليل الحصري) ────────────────────────────
    AudioEdition(
      identifier: 'ar.qiraat.husary.duri',
      name: 'محمود خليل الحصري (الدوري عن أبي عمرو)',
      englishName: 'Mahmoud Khalil Al-Husary (Al-Duri an Abi Amr)',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // ─── القراءات العشر — الصوفي ────────────────────────────────────────────
    // أبو عمرو البصري: السوسي (عبدالرشيد الصوفي) ─────────────────────────────
    AudioEdition(
      identifier: 'ar.qiraat.sosi.abuamr',
      name: 'عبدالرشيد الصوفي (السوسي عن أبي عمرو)',
      englishName: 'Abdulrashid Al-Sufi (Al-Sosi an Abi Amr)',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // حمزة الكوفي: خلف (عبدالرشيد الصوفي) ───────────────────────────────────
    AudioEdition(
      identifier: 'ar.qiraat.khalaf.hamza',
      name: 'عبدالرشيد الصوفي (خلف عن حمزة)',
      englishName: 'Abdulrashid Al-Sufi (Khalaf an Hamza)',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // ─── قراءات إضافية — توقيتات ⏱ ─────────────────────────────────────────
    // نافع المدني: قالون (علي الحذيفي) ───────────────────────────────────────
    AudioEdition(
      identifier: 'ar.qiraat.huthifi.qalon',
      name: 'علي الحذيفي (قالون عن نافع)',
      englishName: "Ali Al-Huthaifi (Qalon an Nafi')",
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // نافع المدني: ورش (العيون الكوشي) ───────────────────────────────────────
    AudioEdition(
      identifier: 'ar.qiraat.koshi.warsh',
      name: 'العيون الكوشي (ورش عن نافع)',
      englishName: "Al-Oyoun Al-Koshi (Warsh an Nafi')",
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // نافع المدني: ورش (القارئ ياسين) ────────────────────────────────────────
    AudioEdition(
      identifier: 'ar.qiraat.yasseen.warsh',
      name: 'القارئ ياسين (ورش عن نافع)',
      englishName: "Al-Qari Yasseen (Warsh an Nafi')",
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // نافع المدني: ورش (عمر القزابري) ────────────────────────────────────────
    AudioEdition(
      identifier: 'ar.qiraat.qazabri.warsh',
      name: 'عمر القزابري (ورش عن نافع)',
      englishName: "Omar Al-Qazabri (Warsh an Nafi')",
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // نافع المدني: قالون (الدوكالي محمد العالم) ──────────────────────────────
    AudioEdition(
      identifier: 'ar.qiraat.dokali.qalon',
      name: 'الدوكالي محمد العالم (قالون عن نافع)',
      englishName: "Al-Dokali Muhammad Al-Alam (Qalon an Nafi')",
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // ابن كثير المكي: البزي (عكاشة كميني) ────────────────────────────────────
    AudioEdition(
      identifier: 'ar.qiraat.okasha.bazi',
      name: 'عكاشة كميني (البزي عن ابن كثير)',
      englishName: 'Okasha Kameny (Al-Bazi an Ibn Katheer)',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // ─── قراء حفص — mp3quran.net (توقيتات) ──────────────────────────────────
    AudioEdition(
      identifier: 'ar.khaledjleel',
      name: 'خالد الجليل',
      englishName: 'Khaled Al-Jaleel',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    AudioEdition(
      identifier: 'ar.raadialkurdi',
      name: 'رعد محمد الكردي',
      englishName: 'Raad Muhammad Al-Kurdi',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    AudioEdition(
      identifier: 'ar.abdulaziahahmad',
      name: 'عبدالعزيز الأحمد',
      englishName: 'AbdulAziz Al-Ahmad',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
    // ── يعقوب الحضرمي: روايتي رويس وروح (ياسر المزروعي) ──────────────
    AudioEdition(
      identifier: 'ar.qiraat.mazrouei.yaqub',
      name: 'ياسر المزروعي (يعقوب الحضرمي)',
      englishName: 'Yasser Al-Mazrouei (Yaqub Al-Hadhrami)',
      language: 'ar',
      format: 'audio',
      type: 'versebyverse',
    ),
  ];

  /// Returns an edition by its identifier using only the local cache (no network call).
  /// Falls back to [_extraEditions] if the identifier is not in the stored cache.
  /// Returns null only if the identifier is completely unknown.
  AudioEdition? findEditionById(String identifier) {
    return _readCache()
        .where((e) => e.identifier == identifier)
        .cast<AudioEdition?>()
        .firstOrNull;
  }

  AudioEdition _withMetadata(AudioEdition edition) {
    final available = RecitationCatalog.availableSurahsForEditionId(
      edition.identifier,
    );
    return edition.copyWith(
      sourceKey: RecitationCatalog.sourceKeyForEditionId(edition.identifier),
      isSurahLevelSource: RecitationCatalog.isSurahLevelEdition(
        edition.identifier,
      ),
      hasTiming: RecitationCatalog.isTimedEdition(edition.identifier),
      availableSurahs: available,
      clearAvailableSurahs: available == null,
    );
  }

  List<AudioEdition> _readCache() {
    final raw = _prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) return _mergeExtras(const []);

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final cached = decoded
          .whereType<Map<String, dynamic>>()
          .map(AudioEdition.fromJson)
          .where((e) => e.identifier.trim().isNotEmpty)
          .toList();
      return _mergeExtras(cached);
    } catch (_) {
      return _mergeExtras(const []);
    }
  }

  /// دمج القراء المضافين يدوياً مع القائمة المُستلمة.
  ///
  /// الأولوية دائماً للأسماء المحددة يدوياً (name / englishName) لأنها
  /// أكثر وصفاً وتفصيلاً من الأسماء المختصرة التي يعيدها الـ API.
  /// الحقول الأخرى (language / format / type) تُؤخذ من الـ API إن توفرت.
  List<AudioEdition> _mergeExtras(List<AudioEdition> editions) {
    final existing = {for (final e in editions) e.identifier: e};
    for (final extra in _extraEditions) {
      final current = existing[extra.identifier];
      if (current == null) {
        // القارئ غير موجود في الـ API — نضيفه من قائمتنا مباشرةً.
        existing[extra.identifier] = extra;
      } else {
        // القارئ موجود في الـ API — نستخدم أسماءنا الوصفية ونحتفظ
        // بالحقول الأخرى من الـ API (language / format / type).
        existing[extra.identifier] = AudioEdition(
          identifier: extra.identifier,
          name: extra.name ?? current.name,
          englishName: extra.englishName ?? current.englishName,
          language: current.language ?? extra.language,
          format: current.format ?? extra.format,
          type: current.type ?? extra.type,
        );
      }
    }
    final merged = existing.values
      .map(_withMetadata)
      .toList()
      ..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    return merged;
  }

  Future<void> _writeCache(List<AudioEdition> editions) async {
    final payload = jsonEncode(editions.map((e) => e.toJson()).toList());
    await _prefs.setString(_cacheKey, payload);
  }

  /// Returns the available *verse-by-verse* audio editions (reciters) from AlQuran.cloud.
  ///
  /// Uses a cache so it still shows options when offline (after one successful fetch).
  Future<List<AudioEdition>> getVerseByVerseAudioEditions() async {
    final cached = _readCache();

    if (!await _networkInfo.isConnected) {
      return cached;
    }

    // AlQuran.cloud: /edition?format=audio&type=versebyverse
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.editionEndpoint}?format=audio&type=versebyverse',
    );

    final http.Response res;
    try {
      res = await _client.get(uri);
    } catch (_) {
      // Network error (connection closed, timeout, etc.) — fall back to cache.
      return cached;
    }
    if (res.statusCode != 200) {
      // If request fails, fall back to cache.
      return cached;
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final data = decoded['data'];
    if (data is! List) {
      return cached;
    }

    final editions = <AudioEdition>[];
    for (final item in data) {
      if (item is! Map<String, dynamic>) continue;
      final identifier = item['identifier'];
      if (identifier is! String || identifier.trim().isEmpty) continue;

      editions.add(
        _withMetadata(AudioEdition(
          identifier: identifier,
          name: item['name'] as String?,
          englishName: item['englishName'] as String?,
          language: item['language'] as String?,
          format: item['format'] as String?,
          type: item['type'] as String?,
        )),
      );
    }

    editions.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));

    if (editions.isNotEmpty) {
      await _writeCache(editions);
      return _mergeExtras(editions);
    }

    return cached;
  }
}
