import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../constants/api_constants.dart';
import '../network/network_info.dart';

class AudioEdition {
  final String identifier;
  final String? name;
  final String? englishName;
  final String? language;
  final String? format;
  final String? type;

  const AudioEdition({
    required this.identifier,
    this.name,
    this.englishName,
    this.language,
    this.format,
    this.type,
  });

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
      };

  factory AudioEdition.fromJson(Map<String, dynamic> json) {
    return AudioEdition(
      identifier: (json['identifier'] as String?) ?? '',
      name: json['name'] as String?,
      englishName: json['englishName'] as String?,
      language: json['language'] as String?,
      format: json['format'] as String?,
      type: json['type'] as String?,
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
  ];

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
    final merged = existing.values.toList()
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

    final res = await _client.get(uri);
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
        AudioEdition(
          identifier: identifier,
          name: item['name'] as String?,
          englishName: item['englishName'] as String?,
          language: item['language'] as String?,
          format: item['format'] as String?,
          type: item['type'] as String?,
        ),
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
