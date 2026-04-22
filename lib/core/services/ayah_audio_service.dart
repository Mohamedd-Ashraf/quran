import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../constants/api_constants.dart';
import '../network/network_info.dart';
import 'offline_audio_service.dart';

class AyahAudioSource {
  final String? localFilePath;
  final Uri? remoteUri;
  /// Start offset within a surah-level file (timed editions only).
  final Duration? startTime;
  /// End offset within a surah-level file (timed editions only).
  final Duration? endTime;

  const AyahAudioSource._({this.localFilePath, this.remoteUri, this.startTime, this.endTime});

  factory AyahAudioSource.local(String path) => AyahAudioSource._(localFilePath: path);

  factory AyahAudioSource.remote(Uri uri) => AyahAudioSource._(remoteUri: uri);

  /// Creates a remote timed source: plays [start]..[end] from a surah-level file.
  /// Used with [ClippingAudioSource] in the player.
  factory AyahAudioSource.timedRemote(Uri uri, Duration start, Duration end) =>
      AyahAudioSource._(remoteUri: uri, startTime: start, endTime: end);

  /// Creates a local timed source: plays [start]..[end] from a surah-level file.
  factory AyahAudioSource.timedLocal(String path, Duration start, Duration end) =>
      AyahAudioSource._(localFilePath: path, startTime: start, endTime: end);

  bool get isLocal => localFilePath != null;
  /// True when this source should be played via [ClippingAudioSource].
  bool get isTimed => startTime != null && endTime != null;
}

/// Maps alquran.cloud edition IDs to their everyayah.com folder names.
/// everyayah.com is more reliable than cdn.islamic.network used by alquran.cloud.
const Map<String, String> _everyAyahFolders = {
  'ar.alafasy':             'Alafasy_128kbps',
  'ar.abdurrahmaansudais':  'Abdurrahmaan_As-Sudais_192kbps',
  'ar.husary':              'Husary_128kbps',
  'ar.husarymujawwad':      'Husary_128kbps_Mujawwad',           // الفولدر الصحيح على everyayah.com
  'ar.minshawi':            'Minshawy_Murattal_128kbps',         // محمد صديق المنشاوي (مرتل)
  'ar.minshawimujawwad':    'Minshawy_Mujawwad_192kbps',         // محمد صديق المنشاوي (مجود) - 192kbps
  'ar.muhammadayyoub':      'Muhammad_Ayyoub_128kbps',
  'ar.muhammadjibreel':     'Muhammad_Jibreel_128kbps',          // تصحيح: M كبير
  'ar.saoodshuraym':        'Saood_ash-Shuraym_128kbps',
  'ar.shaatree':            'Abu_Bakr_Ash-Shaatree_128kbps',
  'ar.parhizgar':           'Parhizgar_48kbps',
  // ─── قراء مضافون يدوياً ────────────────────────────────────────────────────
  'ar.alijaber':            'Ali_Jaber_64kbps',                  // علي عبد الله جابر
  'ar.abdulsamad':          'Abdul_Basit_Murattal_64kbps',       // عبد الباسط المرتل (ar.abdulsamad في API)
  'ar.abdulbasitmujawwad':  'Abdul_Basit_Mujawwad_128kbps',      // عبد الباسط المجود
  'ar.mahermuaiqly':        'Maher_AlMuaiqly_64kbps',            // ماهر المعيقلي
  'ar.nasserqatami':        'Nasser_Alqatami_128kbps',           // ناصر القطامي
  'ar.yasiradussary':       'Yasser_Ad-Dussary_128kbps',         // ياسر الدوسري
  'ar.ahmedajamy':          'ahmed_ibn_ali_al_ajamy_128kbps',    // تصحيح: الحروف الصغيرة
  // ─── قراء إضافيون ──────────────────────────────────────────────────────────
  'ar.ghamadi':             'Ghamadi_40kbps',                    // سعد الغامدي
  'ar.hudhaify':            'Hudhaify_128kbps',                  // علي الحذيفي
  'ar.hanirifai':           'Hani_Rifai_192kbps',                // هاني الرفاعي
  'ar.abdullahbasfar':      'Abdullah_Basfar_192kbps',           // عبدالله بصفر
  'ar.aymanswoaid':         'Ayman_Sowaid_64kbps',               // أيمن سويد
  'ar.ibrahimakhbar':       'Ibrahim_Akhdar_64kbps',             // إبراهيم الأخضر
  'ar.muhsinqasim':         'Muhsin_Al_Qasim_192kbps',           // محسن القاسم
  'ar.mohammadaltablawi':   'Mohammad_al_Tablaway_128kbps',      // محمد الطبلاوي
  'ar.mustafaismail':       'Mustafa_Ismail_48kbps',             // مصطفى إسماعيل
  'ar.salahbudair':         'Salah_Al_Budair_128kbps',           // صلاح البدير
  'ar.salaahbukhatir':      'Salaah_AbdulRahman_Bukhatir_128kbps', // صلاح بو خاطر
  'ar.abdullahjuhani':      'Abdullaah_3awwaad_Al-Juhaynee_128kbps', // عبدالله الجهني
  'ar.yaserslama':          'Yaser_Salamah_128kbps',             // ياسر سلامة
  'ar.khaledtunaiji':       'khalefa_al_tunaiji_64kbps',         // خليفة الطنيجي
  'ar.khaalidqahtani':      'Khaalid_Abdullaah_al-Qahtaanee_192kbps', // خالد القحطاني
  'ar.nabilerrifaai':       'Nabil_Rifa3i_48kbps',               // نبيل الرفاعي
  'ar.sahlyssin':           'Sahl_Yassin_128kbps',               // سهل ياسين
  'ar.faresabbad':          'Fares_Abbad_64kbps',                // فارس عباد
  'ar.mahmoudbanna':        'mahmoud_ali_al_banna_32kbps',       // محمود علي البنا
  'ar.alisuesy':            'Ali_Hajjaj_AlSuesy_128kbps',        // علي حجاج السويسي
  'ar.karimmansoori':       'Karim_Mansoori_40kbps',             // كريم منصوري
  // ─── قراء إضافيون جدد ──────────────────────────────────────────────────────
  'ar.abdullahmatroud':     'Abdullah_Matroud_128kbps',          // عبدالله مطرود
  'ar.ahmedneana':          'Ahmed_Neana_128kbps',               // أحمد نعينع
  'ar.akramalalaqimy':      'Akram_AlAlaqimy_128kbps',           // أكرم العلاقمي
  'ar.husarymuallim':       'Husary_Muallim_128kbps',            // الحصري (معلم)
  'ar.mahermuaiqly128':     'MaherAlMuaiqly128kbps',             // ماهر المعيقلي (128kbps)
  'ar.muhammadabdulkareem': 'Muhammad_AbdulKareem_128kbps',      // محمد عبدالكريم
  'ar.minshawiteacher':     'Minshawy_Teacher_128kbps',          // المنشاوي (معلم)
  'ar.azizalili':           'aziz_alili_128kbps',                // عزيز عليلي
  // ─── قراءة ورش عن نافع ─────────────────────────────────────────────────────
  'ar.warsh.ibrahimdosary': 'warsh/warsh_ibrahim_aldosary_128kbps', // إبراهيم الدوسري (ورش)
  'ar.warsh.yassinjazaery': 'warsh/warsh_yassin_al_jazaery_64kbps', // ياسين الجزائري (ورش)
  'ar.warsh.abdulbasit':    'warsh/warsh_Abdul_Basit_128kbps',      // عبد الباسط (ورش)
};

const Map<String, int> _everyAyahBitratesKbps = {
  'ar.alafasy':             128,
  'ar.abdurrahmaansudais':  192,
  'ar.husary':              128,
  'ar.husarymujawwad':      128,
  'ar.minshawi':            128,
  'ar.minshawimujawwad':    192,
  'ar.muhammadayyoub':      128,
  'ar.muhammadjibreel':     128,
  'ar.saoodshuraym':        128,
  'ar.shaatree':            128,
  'ar.parhizgar':            48,
  'ar.alijaber':             64,
  'ar.abdulsamad':           64,
  'ar.abdulbasitmujawwad':  128,
  'ar.mahermuaiqly':         64,
  'ar.nasserqatami':        128,
  'ar.yasiradussary':       128,
  'ar.ahmedajamy':          128,
  'ar.ghamadi':              40,
  'ar.hudhaify':            128,
  'ar.hanirifai':           192,
  'ar.abdullahbasfar':      192,
  'ar.aymanswoaid':          64,
  'ar.ibrahimakhbar':        64,
  'ar.muhsinqasim':         192,
  'ar.mohammadaltablawi':   128,
  'ar.mustafaismail':        48,
  'ar.salahbudair':         128,
  'ar.salaahbukhatir':      128,
  'ar.abdullahjuhani':      128,
  'ar.yaserslama':          128,
  'ar.khaledtunaiji':        64,
  'ar.khaalidqahtani':      192,
  'ar.nabilerrifaai':        48,
  'ar.sahlyssin':           128,
  'ar.faresabbad':           64,
  'ar.mahmoudbanna':         32,
  'ar.alisuesy':            128,
  'ar.karimmansoori':        40,
  'ar.abdullahmatroud':     128,
  'ar.ahmedneana':          128,
  'ar.akramalalaqimy':      128,
  'ar.husarymuallim':       128,
  'ar.mahermuaiqly128':     128,
  'ar.muhammadabdulkareem': 128,
  'ar.minshawiteacher':     128,
  'ar.azizalili':           128,
  'ar.warsh.ibrahimdosary': 128,
  'ar.warsh.yassinjazaery':  64,
  'ar.warsh.abdulbasit':    128,
};

/// Maps edition identifiers (for the 10 Qira'at) to their mp3quran.net server URLs.
/// URL format: {server}{surah3}{ayah3}.mp3  — the server string already includes a trailing slash.
/// Source: https://mp3quran.net/api/v3/reciters
const Map<String, String> _mp3QuranServers = {
  // ── نافع المدني: قالون (عبد الرؤوف الترابلسي) ────────────────────────────
  'ar.qiraat.qalon':        'https://server10.mp3quran.net/trablsi/',
  // ── ابن كثير المكي: البزي (على دبان) ────────────────────────────────────
  'ar.qiraat.bazi':         'https://server16.mp3quran.net/deban/Rewayat-Albizi-A-n-Ibn-Katheer/',
  // ── ابن كثير المكي: قنبل (على دبان) ────────────────────────────────────
  'ar.qiraat.qunbol':       'https://server16.mp3quran.net/deban/Rewayat-Qunbol-A-n-Ibn-Katheer/',
  // ── أبو عمرو البصري: الدوري (على دبان) ─────────────────────────────────
  'ar.qiraat.duri.abuamr':  'https://server16.mp3quran.net/deban/Rewayat-Aldori-A-n-Abi-Amr/',
  // ── ابن عامر الشامي: ابن ذكوان (مفتاح السلطاني) ─────────────────────────
  'ar.qiraat.ibndhakwan':   'https://server14.mp3quran.net/muftah_sultany/Rewayat_Ibn-Thakwan-A-n-Ibn-Amer/',
  // ── عاصم الكوفي: شعبة (على دبان) ────────────────────────────────────────
  'ar.qiraat.shuba':        'https://server16.mp3quran.net/deban/Rewayat-Sho-bah-A-n-Asim/',
  // ── الكسائي الكوفي: الدوري (مفتاح السلطاني) ─────────────────────────────
  'ar.qiraat.duri.kisai':   'https://server14.mp3quran.net/muftah_sultany/Rewayat-AlDorai-A-n-Al-Kisa-ai/',
  // ── نافع المدني: ورش من طريق الأزرق (على دبان) ──────────────────────────
  'ar.qiraat.warsh.azraq':  'https://server16.mp3quran.net/deban/Rewayat-Warsh-A-n-Nafi-Men-Tariq-Alazraq/',
  // ── أبو عمرو البصري: السوسي (عبدالرشيد الصوفي) ──────────────────────────
  'ar.qiraat.sosi.abuamr':  'https://server16.mp3quran.net/soufi/Rewayat-Assosi-A-n-Abi-Amr/',
  // ── حمزة الكوفي: خلف (عبدالرشيد الصوفي) ─────────────────────────────────
  'ar.qiraat.khalaf.hamza': 'https://server16.mp3quran.net/soufi/Rewayat-Khalaf-A-n-Hamzah/',
  // ── نافع المدني: قالون (محمود خليل الحصري) ──────────────────────────────
  'ar.qiraat.husary.qalon': 'https://server13.mp3quran.net/husr/Rewayat-Qalon-A-n-Nafi/',
  // ── نافع المدني: ورش (محمود خليل الحصري) ────────────────────────────────
  'ar.qiraat.husary.warsh': 'https://server13.mp3quran.net/husr/Rewayat-Warsh-A-n-Nafi/',
  // ── أبو عمرو البصري: الدوري (محمود خليل الحصري) ─────────────────────────
  'ar.qiraat.husary.duri':  'https://server13.mp3quran.net/husr/Rewayat-Aldori-A-n-Abi-Amr/',
  // ── نافع المدني: قالون (علي الحذيفي) ────────────────────────────────────
  'ar.qiraat.huthifi.qalon': 'https://server9.mp3quran.net/huthifi_qalon/',
  // ── نافع المدني: ورش (العيون الكوشي) ─────────────────────────────────────
  'ar.qiraat.koshi.warsh':   'https://server11.mp3quran.net/koshi/',
  // ── نافع المدني: ورش (القارئ ياسين) ─────────────────────────────────────
  'ar.qiraat.yasseen.warsh': 'https://server11.mp3quran.net/qari/',
  // ── نافع المدني: ورش (عمر القزابري) ─────────────────────────────────────
  'ar.qiraat.qazabri.warsh': 'https://server9.mp3quran.net/omar_warsh/',
  // ── نافع المدني: قالون (الدوكالي محمد العالم) ────────────────────────────
  'ar.qiraat.dokali.qalon':  'https://server7.mp3quran.net/dokali/',
  // ── ابن كثير المكي: البزي (عكاشة كميني) ─────────────────────────────────
  'ar.qiraat.okasha.bazi':   'https://server16.mp3quran.net/okasha/Rewayat-Albizi-A-n-Ibn-Katheer/',
  // ── حفص عن عاصم — قراء mp3quran.net (توقيتات) ───────────────────────────
  'ar.khaledjleel':          'https://server10.mp3quran.net/jleel/',
  'ar.raadialkurdi':         'https://server6.mp3quran.net/kurdi/',
  'ar.abdulaziahahmad':      'https://server11.mp3quran.net/a_ahmed/',
};
/// Maps edition IDs (subset of [_mp3QuranServers]) to the mp3quran.net "read id"
/// that has ayat timing available at `https://mp3quran.net/api/v3/ayat_timing`.
/// Only these editions support per-ayah playback via [ClippingAudioSource].
const Map<String, int> _mp3QuranTimingReadIds = {
  'ar.qiraat.husary.qalon':  270,
  'ar.qiraat.husary.warsh':  120,
  'ar.qiraat.husary.duri':   269,
  'ar.qiraat.sosi.abuamr':    65,
  // ── قراءات ورش وقالون — reciters with timing ──────────────────────────────
  'ar.qiraat.huthifi.qalon':  75,
  'ar.qiraat.koshi.warsh':    16,
  'ar.qiraat.yasseen.warsh':  14,
  'ar.qiraat.qazabri.warsh':  80,
  'ar.qiraat.dokali.qalon':  208,
  'ar.qiraat.okasha.bazi':   296,
  // ── حفص — قراء mp3quran.net مع توقيتات ───────────────────────────────────
  'ar.khaledjleel':           20,
  'ar.raadialkurdi':         221,
  'ar.abdulaziahahmad':       55,
};

/// Surahs whose Hafs Ayah 1 is a fawatih (opening letter sequence)
/// e.g. "الم", "الر", "يس" — which is always very short (≤ 5 s to recite).
/// Some readers' timing APIs do NOT include the fawatih as a separate ayah,
/// so the API's Ayah 1 is actually Hafs's Ayah 2, causing a systematic 1-off.
const Set<int> _fawatihSurahs = {
  2, 3, 7, 10, 11, 12, 13, 14, 15,
  19, 20, 26, 27, 28,
  29, 30, 31, 32, 36, 38,
  40, 41, 42, 43, 44, 45, 46,
  50, 68,
};

/// Maximum plausible duration (ms) for a fawatih ayah even with a slow
/// reader.  "كهيعص" (the longest) should still take well under 8 seconds.
const int _kMaxFawatihDurationMs = 8000;

class MergedSurahAudio {
  final String filePath;
  final List<Duration> ayahDurations;

  const MergedSurahAudio({
    required this.filePath,
    required this.ayahDurations,
  });
}

class AyahAudioService {
  final http.Client _client;
  final NetworkInfo _networkInfo;
  final OfflineAudioService _offlineAudio;

  final Map<String, Uri> _urlCache = {};
  final Map<String, List<Uri>> _surahUrlCache = {};
  final Map<String, List<({int ayah, int startMs, int endMs})>> _timingCache = {};

  AyahAudioService(this._client, this._networkInfo, this._offlineAudio);

  String get currentEdition => _offlineAudio.edition;

  int? get currentEditionBitrateKbps => _everyAyahBitratesKbps[currentEdition];

  /// True when the currently selected edition stores ONE file per surah
  /// (mp3quran.net Qira'at editions WITHOUT timing data).
  /// Per-ayah playback is not possible; callers redirect to surah-level.
  bool get isSurahLevelEdition =>
      _mp3QuranServers.containsKey(currentEdition) &&
      !_mp3QuranTimingReadIds.containsKey(currentEdition);

  /// True when the edition stores one surah file per surah (mp3quran.net)
  /// AND ayat timing data is available — enabling per-ayah [ClippingAudioSource].
  bool get isTimedSurahEdition => _mp3QuranTimingReadIds.containsKey(currentEdition);

  String _key(int surahNumber, int ayahNumber, String edition) => '$edition:$surahNumber:$ayahNumber';

  String _surahKey(int surahNumber, String edition) => '$edition:$surahNumber';

  /// Builds an everyayah.com URL directly without hitting the alquran.cloud API.
  /// Returns null if the edition is not supported by everyayah.com.
  Uri? _buildDirectUri(int surahNumber, int ayahNumber, String edition) {
    final folder = _everyAyahFolders[edition];
    if (folder == null) return null;
    final s = surahNumber.toString().padLeft(3, '0');
    final a = ayahNumber.toString().padLeft(3, '0');
    return Uri.parse('https://everyayah.com/data/$folder/$s$a.mp3');
  }

  /// Builds an mp3quran.net surah-level URL for a 10-Qira'at edition.
  /// mp3quran.net stores ONE file per surah (001.mp3, 002.mp3, …),
  /// NOT per-ayah files. Playback starts from the beginning of the surah.
  /// Returns null if the edition is not in [_mp3QuranServers].
  Uri? _buildMp3QuranUri(int surahNumber, int ayahNumber, String edition) {
    final server = _mp3QuranServers[edition];
    if (server == null) return null;
    final s = surahNumber.toString().padLeft(3, '0');
    // mp3quran.net stores whole-surah files: 001.mp3 = full Surah 1, etc.
    // Per-ayah files (001001.mp3) do NOT exist on this server.
    return Uri.parse('$server$s.mp3');
  }

  // ── Ayat Timing API (mp3quran.net) ───────────────────────────────────────────────────────

  // ── Disk-based timing cache ────────────────────────────────────────────────

  Future<Directory> _timingCacheDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(
      '${base.path}${Platform.pathSeparator}timing_cache',
    );
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<List<({int ayah, int startMs, int endMs})>?> _loadTimingFromDisk(
    String edition,
    int surahNumber,
  ) async {
    try {
      final dir = await _timingCacheDir();
      final safeEdition = edition.replaceAll(RegExp(r'[\\/:.]+'), '_');
      final file = File(
        '${dir.path}${Platform.pathSeparator}${safeEdition}_$surahNumber.json',
      );
      if (!file.existsSync()) return null;
      final decoded = json.decode(await file.readAsString()) as List;
      return (decoded.map((e) {
        final m = e as Map<String, dynamic>;
        return (
          ayah: (m['ayah'] as int),
          startMs: (m['start_time'] as int),
          endMs: (m['end_time'] as int),
        );
      }).toList())
        ..sort((a, b) => a.ayah.compareTo(b.ayah));
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveTimingToDisk(
    String edition,
    int surahNumber,
    List<({int ayah, int startMs, int endMs})> timing,
  ) async {
    try {
      final dir = await _timingCacheDir();
      final safeEdition = edition.replaceAll(RegExp(r'[\\/:.]+'), '_');
      final file = File(
        '${dir.path}${Platform.pathSeparator}${safeEdition}_$surahNumber.json',
      );
      final data = timing
          .map((t) => {
                'ayah': t.ayah,
                'start_time': t.startMs,
                'end_time': t.endMs,
              })
          .toList();
      await file.writeAsString(json.encode(data));
    } catch (_) {}
  }

  /// Fetches and caches (in-memory + disk) ayat timing for [edition]'s [surahNumber].
  /// Returns a list sorted by ayah; entry with ayah==0 is the Basmala/intro.
  /// Throws on network error, API error, or timeout.
  Future<List<({int ayah, int startMs, int endMs})>> _fetchAyatTiming({
    required int surahNumber,
    required String edition,
  }) async {
    final readId = _mp3QuranTimingReadIds[edition];
    if (readId == null) throw Exception('No timing read ID for $edition');

    final cacheKey = '$edition:timing:$surahNumber';

    // 1. Memory cache.
    final memCached = _timingCache[cacheKey];
    if (memCached != null) return memCached;

    // 2. Disk cache — available offline after first use.
    //    Apply the same numbering corrections as the network path so that
    //    stale cache files from before the fix are corrected on next read.
    final diskCached = await _loadTimingFromDisk(edition, surahNumber);
    if (diskCached != null) {
      final fixed = _applyTimingCorrections(surahNumber, diskCached);
      // Re-persist if the data changed (old stale cache detected and fixed).
      if (!identical(fixed, diskCached)) {
        await _saveTimingToDisk(edition, surahNumber, fixed);
      }
      _timingCache[cacheKey] = fixed;
      return fixed;
    }

    // 3. Network fetch.
    final uri = Uri.parse(
      'https://mp3quran.net/api/v3/ayat_timing?surah=$surahNumber&read=$readId',
    );
    final res = await _client
        .get(uri)
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw Exception('Timing API ${res.statusCode} for surah $surahNumber');
    }

    final decoded = json.decode(res.body) as List;
    var result = decoded.map((e) {
      final m = e as Map<String, dynamic>;
      return (
        ayah: (m['ayah'] as int),
        startMs: (m['start_time'] as int),
        endMs: (m['end_time'] as int),
      );
    }).toList()
      ..sort((a, b) => a.ayah.compareTo(b.ayah));

    result = _applyTimingCorrections(surahNumber, result);

    _timingCache[cacheKey] = result;
    // Persist to disk so next offline session can use it.
    await _saveTimingToDisk(edition, surahNumber, result);
    return result;
  }

  /// Central place to apply all off-by-one timing corrections.
  /// Called for both network-fetched and disk-cached data so old cache
  /// files are healed automatically on the next app launch.
  List<({int ayah, int startMs, int endMs})> _applyTimingCorrections(
    int surahNumber,
    List<({int ayah, int startMs, int endMs})> raw,
  ) {
    if (raw.isEmpty || raw.first.ayah != 1) return raw;

    // Surah 1 (Al-Fatiha): some readers don't count the Basmala as Ayah 1.
    // Detection: API's Ayah 1 starts after 6 500 ms (isti'adha + Basmala).
    if (surahNumber == 1 && raw.first.startMs > 6500) {
      return _fixFatihaTiming(raw);
    }

    // Fawatih surahs: some readers don't count "الم" / "الر" / … as Ayah 1.
    // Detection: API's Ayah 1 duration far exceeds any realistic fawatih recitation.
    if (surahNumber != 1 &&
        _fawatihSurahs.contains(surahNumber) &&
        (raw.first.endMs - raw.first.startMs) > _kMaxFawatihDurationMs) {
      return _fixFawatihTiming(raw);
    }

    return raw;
  }

  /// Fixes the timing list for fawatih surahs (2, 3, 7, …) when the
  /// reader's API omits the fawatih letter sequence as a separate ayah.
  /// The API's Ayah 1 is then Hafs's Ayah 2, causing a systematic 1-off.
  ///
  /// Fix: prepend a synthetic Ayah 1 covering [0, first.startMs) — which
  /// captures the isti'adha + Basmala + the fawatih pronunciation — then
  /// shift every existing entry up by 1 so they align with Hafs numbering.
  List<({int ayah, int startMs, int endMs})> _fixFawatihTiming(
    List<({int ayah, int startMs, int endMs})> raw,
  ) {
    final fawatihCutMs = raw.first.startMs;
    return [
      (ayah: 1, startMs: 0, endMs: fawatihCutMs),
      ...raw.map((t) => (ayah: t.ayah + 1, startMs: t.startMs, endMs: t.endMs)),
    ];
  }

  /// Fixes the Surah-1 timing list for readers where the API's Ayah 1 is
  /// "الحمد لله رب العالمين" (Hafs Ayah 2), not the Basmala.
  ///
  /// Strategy:
  /// 1. Insert synthetic Ayah 0 + Ayah 1 spanning [0, first.startMs) so the
  ///    Basmala block maps to the correct mushaf position.
  /// 2. Shift all existing API entries up by 1 (API ayah N → mushaf N+1).
  /// 3. Extend the entry that lands at mushaf Ayah 7 to cover the entire
  ///    remaining audio, which in Qalon-style counting ends later.
  List<({int ayah, int startMs, int endMs})> _fixFatihaTiming(
    List<({int ayah, int startMs, int endMs})> raw,
  ) {
    final basmalaCutMs = raw.first.startMs;
    final lastEndMs    = raw.last.endMs;

    // Shift every API entry up by 1 (API 1→mushaf 2, API 2→mushaf 3, …).
    final shifted = raw
        .map((t) => (ayah: t.ayah + 1, startMs: t.startMs, endMs: t.endMs))
        .toList();

    // The entry that falls at mushaf position 7 (old API ayah 6) covers only
    // the first half of Hafs's final verse.  Extend its endMs to absorb the
    // old API ayah 7 so nothing is clipped during surah playback.
    if (shifted.length >= 7) {
      shifted[5] = (ayah: 7, startMs: shifted[5].startMs, endMs: lastEndMs);
      if (shifted.length > 6) shifted.removeAt(6); // drop excess entry
    }

    return [
      (ayah: 0, startMs: 0, endMs: basmalaCutMs), // separator marker
      (ayah: 1, startMs: 0, endMs: basmalaCutMs), // mushaf Ayah 1 = Basmala
      ...shifted,
    ];
  }

  /// Resolves a single timed [AyahAudioSource] for [ayahNumber] from the
  /// surah-level mp3quran.net file.  Falls back silently to the full surah
  /// when timing is unavailable (offline without cache, API error, etc.).
  Future<AyahAudioSource> _resolveTimedAyahAudio({
    required int surahNumber,
    required int ayahNumber,
    required String edition,
  }) async {
    final localSurah = await _offlineAudio.getLocalAyahAudioFile(
      surahNumber: surahNumber,
      ayahNumber: 1,
    );
    final surahUri = _buildMp3QuranUri(surahNumber, 1, edition)!;

    if (localSurah == null && !await _networkInfo.isConnected) {
      throw Exception('No internet connection and audio is not downloaded.');
    }

    try {
      final timing = await _fetchAyatTiming(
        surahNumber: surahNumber,
        edition: edition,
      );
      final timingMap = <int, ({int ayah, int startMs, int endMs})>{
        for (final t in timing) t.ayah: t,
      };
      final basmala = timingMap[0];
      final entry = timingMap[ayahNumber];
      if (entry != null) {
        // When ayahNumber==1, start from the Basmala if it has an explicit
        // timing entry; otherwise seek to 0 (beginning of file) so the
        // Basmala is not skipped even when the API omits a ayah-0 entry.
        final startMs = ayahNumber == 1
            ? (basmala?.startMs ?? 0)
            : entry.startMs;
        final start = Duration(milliseconds: startMs);
        final end = Duration(milliseconds: entry.endMs);
        return localSurah != null
            ? AyahAudioSource.timedLocal(localSurah.path, start, end)
            : AyahAudioSource.timedRemote(surahUri, start, end);
      }
    } catch (_) {
      // Timing unavailable — fall through to whole-surah fallback.
    }

    // Fallback: play the whole surah file (no clip).
    return localSurah != null
        ? AyahAudioSource.local(localSurah.path)
        : AyahAudioSource.remote(surahUri);
  }

  /// Resolves per-ayah timed [AyahAudioSource]s for a surah in a timed edition.
  /// Each source clips a different [startTime]..[endTime] from the same surah file.
  ///
  /// Ayah 0 (Basmala) is merged into ayah 1: the first clip starts at
  /// the Basmala's start_time so the Basmala is included in recitation.
  ///
  /// Falls back silently to a single whole-surah source when timing is
  /// unavailable (offline without cache, API error, etc.).
  Future<List<AyahAudioSource>> _resolveTimedSurahAudio({
    required int surahNumber,
    required int numberOfAyahs,
    required String edition,
  }) async {
    final localSurah = await _offlineAudio.getLocalAyahAudioFile(
      surahNumber: surahNumber,
      ayahNumber: 1,
    );
    final surahUri = _buildMp3QuranUri(surahNumber, 1, edition)!;

    List<({int ayah, int startMs, int endMs})> timing;
    try {
      timing = await _fetchAyatTiming(
        surahNumber: surahNumber,
        edition: edition,
      );
    } catch (_) {
      // Silent fallback — timing unavailable; play the whole surah file.
      return [
        localSurah != null
            ? AyahAudioSource.local(localSurah.path)
            : AyahAudioSource.remote(surahUri),
      ];
    }

    final timingMap = <int, ({int ayah, int startMs, int endMs})>{
      for (final t in timing) t.ayah: t,
    };
    final basmala = timingMap[0];
    final results = <AyahAudioSource>[];
    for (var i = 1; i <= numberOfAyahs; i++) {
      final entry = timingMap[i];
      if (entry == null) {
        // Timing entry missing — fall back to the whole surah file.
        return [
          localSurah != null
              ? AyahAudioSource.local(localSurah.path)
              : AyahAudioSource.remote(surahUri),
        ];
      }
      // Same Basmala-inclusive logic: use ayah-0 startMs when available;
      // fall back to 0 so the Basmala at the head of the file is never skipped.
      final startMs = i == 1 ? (basmala?.startMs ?? 0) : entry.startMs;
      final start = Duration(milliseconds: startMs);
      final end = Duration(milliseconds: entry.endMs);
      results.add(
        localSurah != null
            ? AyahAudioSource.timedLocal(localSurah.path, start, end)
            : AyahAudioSource.timedRemote(surahUri, start, end),
      );
    }
    return results;
  }

  /// Returns the single surah-level audio source PLUS the complete ayat timing
  /// list for the current timed edition.  Used by the cubit for position-based
  /// per-ayah tracking so the same surah file is loaded only once.
  ///
  /// Pre-fetches and persists timing data for each surah in [surahs] when
  /// the current edition supports ayat timing.  Called automatically after an
  /// offline audio download so timing is available without a network connection.
  /// Errors are silenced — a failed fetch for one surah does not abort others.
  Future<void> preCacheTimingForSurahs(List<int> surahs) async {
    if (!isTimedSurahEdition) return;
    for (final surah in surahs) {
      try {
        await _fetchAyatTiming(surahNumber: surah, edition: currentEdition);
      } catch (_) {
        // Non-fatal: skip surahs that could not be fetched.
      }
    }
  }

  /// Throws if offline and the surah is not downloaded.
  /// Throws (propagated) if the timing API fails and there is no cached data.
  Future<({
    AyahAudioSource source,
    List<({int ayah, int startMs, int endMs})> segments,
  })> resolveTimedSurahSource({required int surahNumber}) async {
    assert(
      _mp3QuranTimingReadIds.containsKey(currentEdition),
      'resolveTimedSurahSource called for non-timed edition "$currentEdition"',
    );
    final localSurah = await _offlineAudio.getLocalAyahAudioFile(
      surahNumber: surahNumber,
      ayahNumber: 1,
    );
    if (localSurah == null && !await _networkInfo.isConnected) {
      throw Exception('No internet connection and audio is not downloaded.');
    }
    final segments = await _fetchAyatTiming(
      surahNumber: surahNumber,
      edition: currentEdition,
    );
    final surahUri = _buildMp3QuranUri(surahNumber, 1, currentEdition)!;
    final source = localSurah != null
        ? AyahAudioSource.local(localSurah.path)
        : AyahAudioSource.remote(surahUri);
    return (source: source, segments: segments);
  }

  Future<List<Uri>> _fetchSurahAyahAudioUris({
    required int surahNumber,
    required String edition,
  }) async {
    final cacheKey = _surahKey(surahNumber, edition);
    final cached = _surahUrlCache[cacheKey];
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    final uri = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.surahEndpoint}/$surahNumber/$edition',
    );
    final res = await _client.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Failed to fetch surah audio URLs');
    }

    final decoded = json.decode(res.body) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>;
    final ayahs = (data['ayahs'] as List).cast<Map<String, dynamic>>();

    final urls = <Uri>[];
    for (final a in ayahs) {
      final url = a['audio'];
      if (url is String && url.isNotEmpty) {
        urls.add(Uri.parse(url));
      } else {
        urls.add(Uri());
      }
    }

    _surahUrlCache[cacheKey] = urls;
    return urls;
  }

  Future<AyahAudioSource> resolveAyahAudio({
    required int surahNumber,
    required int ayahNumber,
  }) async {
    final edition = _offlineAudio.edition;

    // ── Timed surah editions (mp3quran.net with timing) ────────────────────────────────
    // These editions store one surah-level file; serve per-ayah clips.
    if (_mp3QuranTimingReadIds.containsKey(edition)) {
      return _resolveTimedAyahAudio(
        surahNumber: surahNumber,
        ayahNumber: ayahNumber,
        edition: edition,
      );
    }

    // Always prefer a local file when it exists – regardless of the
    // 'enabled' flag so that downloaded audio is used even if the user
    // hasn't explicitly toggled offline mode in settings.
    final local = await _offlineAudio.getLocalAyahAudioFile(
      surahNumber: surahNumber,
      ayahNumber: ayahNumber,
    );
    if (local != null) {
      return AyahAudioSource.local(local.path);
    }

    // Fallback to streaming.
    if (!await _networkInfo.isConnected) {
      throw Exception('No internet connection and audio is not downloaded.');
    }

    final cacheKey = _key(surahNumber, ayahNumber, edition);
    final cached = _urlCache[cacheKey];
    if (cached != null) {
      return AyahAudioSource.remote(cached);
    }

    // Try direct everyayah.com URL first (reliable, no API call needed).
    final directUri = _buildDirectUri(surahNumber, ayahNumber, edition);
    if (directUri != null) {
      _urlCache[cacheKey] = directUri;
      return AyahAudioSource.remote(directUri);
    }

    // Try mp3quran.net for Qira'at editions not on everyayah.com.
    final mp3QuranUri = _buildMp3QuranUri(surahNumber, ayahNumber, edition);
    if (mp3QuranUri != null) {
      _urlCache[cacheKey] = mp3QuranUri;
      return AyahAudioSource.remote(mp3QuranUri);
    }

    // Fall back to alquran.cloud API for editions not on everyayah.com.
    final reference = '$surahNumber:$ayahNumber';
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.ayahEndpoint}/$reference/$edition',
    );

    final res = await _client.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Failed to fetch ayah audio URL');
    }

    final decoded = json.decode(res.body) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>;
    final audioUrl = data['audio'];

    if (audioUrl is! String || audioUrl.isEmpty) {
      throw Exception('Audio URL is not available for this ayah');
    }

    final audioUri = Uri.parse(audioUrl);
    _urlCache[cacheKey] = audioUri;
    return AyahAudioSource.remote(audioUri);
  }

  /// Resolves audio sources for ALL ayahs in a surah (1..[numberOfAyahs]).
  ///
  /// - Prefers local files if offline audio is enabled and present.
  /// - Falls back to remote streaming URLs if connected.
  /// - Throws if an ayah is missing both locally and remotely.
  Future<List<AyahAudioSource>> resolveSurahAyahAudio({
    required int surahNumber,
    required int numberOfAyahs,
  }) async {
    final edition = _offlineAudio.edition;

    // ── Surah-level editions (mp3quran.net) ──────────────────────────────────
    // These servers store ONE file per surah (001.mp3 = full Surah 1).
    // Return a single-item list so the player plays the surah file once
    // rather than replaying it once per ayah.
    if (_mp3QuranServers.containsKey(edition)) {
      // ── Timed editions: per-ayah via ClippingAudioSource ──────────────────────────────
      if (_mp3QuranTimingReadIds.containsKey(edition)) {
        return _resolveTimedSurahAudio(
          surahNumber: surahNumber,
          numberOfAyahs: numberOfAyahs,
          edition: edition,
        );
      }
      // ── Pure surah-level editions: one file for the whole surah ───────────────────────
      final local = await _offlineAudio.getLocalAyahAudioFile(
        surahNumber: surahNumber,
        ayahNumber: 1,
      );
      if (local != null) {
        return [AyahAudioSource.local(local.path)];
      }
      if (!await _networkInfo.isConnected) {
        throw Exception('No internet connection and surah audio is not downloaded.');
      }
      final surahUri = _buildMp3QuranUri(surahNumber, 1, edition)!;
      return [AyahAudioSource.remote(surahUri)];
    }

    // 1) Always prefer local files when available – the 'enabled' flag only
    //    controls the UI, not whether we serve files that are already on disk.
    final sources = List<AyahAudioSource?>.filled(numberOfAyahs, null);
    for (var i = 0; i < numberOfAyahs; i++) {
      final ayahNumber = i + 1;
      final local = await _offlineAudio.getLocalAyahAudioFile(
        surahNumber: surahNumber,
        ayahNumber: ayahNumber,
      );
      if (local != null) {
        sources[i] = AyahAudioSource.local(local.path);
      }
    }

    // 2) Fill missing with remote URLs if connected.
    final hasMissing = sources.any((e) => e == null);
    if (hasMissing) {
      if (!await _networkInfo.isConnected) {
        throw Exception('No internet connection and surah audio is not downloaded.');
      }

      // Prefer direct everyayah.com URLs if edition is supported (avoids unreliable CDN).
      final directSupported = _everyAyahFolders.containsKey(edition);
      if (directSupported) {
        for (var i = 0; i < numberOfAyahs; i++) {
          if (sources[i] != null) continue;
          final ayahNumber = i + 1;
          final uri = _buildDirectUri(surahNumber, ayahNumber, edition)!;
          sources[i] = AyahAudioSource.remote(uri);
        }
      } else {
        final uris = await _fetchSurahAyahAudioUris(surahNumber: surahNumber, edition: edition);
        for (var i = 0; i < numberOfAyahs; i++) {
          if (sources[i] != null) continue;
          if (i >= uris.length) {
            throw Exception('Audio is not available for this surah.');
          }
          final uri = uris[i];
          if (uri.toString().isEmpty) {
            throw Exception('Audio URL is not available for this ayah');
          }
          sources[i] = AyahAudioSource.remote(uri);
        }
      }
    }

    return sources.cast<AyahAudioSource>();
  }

  /// Fast cache lookup — returns a [MergedSurahAudio] if the merged MP3 and
  /// its metadata are already on disk, otherwise returns null immediately.
  /// Does NOT concatenate files; call [prepareMergedSurahAudio] to build the
  /// cache when it is missing.
  Future<MergedSurahAudio?> checkMergedSurahCache({
    required int surahNumber,
    required int numberOfAyahs,
  }) async {
    final bitrateKbps = currentEditionBitrateKbps;
    if (bitrateKbps == null) return null;

    final tmpDir = await getTemporaryDirectory();
    final mergedDir = Directory('${tmpDir.path}/merged_surahs');
    if (!mergedDir.existsSync()) return null;

    final editionSafe = currentEdition.replaceAll('.', '_');
    final baseName = '${editionSafe}_${surahNumber}_$numberOfAyahs';
    final mergedFile = File('${mergedDir.path}/$baseName.mp3');
    final metaFile = File('${mergedDir.path}/$baseName.json');

    if (!mergedFile.existsSync() || !metaFile.existsSync()) return null;

    try {
      final raw = jsonDecode(await metaFile.readAsString()) as List;
      return MergedSurahAudio(
        filePath: mergedFile.path,
        ayahDurations: raw
            .whereType<num>()
            .map((ms) => Duration(milliseconds: ms.toInt()))
            .toList(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<MergedSurahAudio?> prepareMergedSurahAudio({
    required int surahNumber,
    required int numberOfAyahs,
    required List<AyahAudioSource> sources,
  }) async {
    final bitrateKbps = currentEditionBitrateKbps;
    if (bitrateKbps == null || sources.length != numberOfAyahs) return null;

    final tmpDir = await getTemporaryDirectory();
    final mergedDir = Directory('${tmpDir.path}/merged_surahs');
    if (!mergedDir.existsSync()) mergedDir.createSync(recursive: true);

    final editionSafe = currentEdition.replaceAll('.', '_');
    final baseName = '${editionSafe}_${surahNumber}_$numberOfAyahs';
    final mergedFile = File('${mergedDir.path}/$baseName.mp3');
    final metaFile = File('${mergedDir.path}/$baseName.json');

    if (mergedFile.existsSync() && metaFile.existsSync()) {
      try {
        final raw = jsonDecode(await metaFile.readAsString()) as List;
        return MergedSurahAudio(
          filePath: mergedFile.path,
          ayahDurations: raw
              .whereType<num>()
              .map((ms) => Duration(milliseconds: ms.toInt()))
              .toList(),
        );
      } catch (_) {}
    }

    final tmpFile = File('${mergedFile.path}.tmp');
    final sink = tmpFile.openWrite();
    final ayahDurations = <Duration>[];

    try {
      bool isFirstSource = true;
      for (final source in sources) {
        int byteCount = 0;
        if (source.isLocal) {
          // Read bytes so we can strip the ID3+Xing header from the first
          // segment.  Ayah files are small (~100–500 KB) so this is fine.
          var bytes = await File(source.localFilePath!).readAsBytes();
          if (isFirstSource) bytes = _stripLeadingId3AndXing(bytes);
          byteCount = bytes.length;
          sink.add(bytes);
        } else {
          final request = http.Request('GET', source.remoteUri!);
          final response = await _client.send(request);
          if (response.statusCode != 200) {
            throw Exception('Failed to download surah segment');
          }
          if (isFirstSource) {
            // Buffer the whole segment so we can strip the ID3+Xing header.
            final bb = BytesBuilder();
            await for (final chunk in response.stream) {
              bb.add(chunk);
            }
            final stripped = _stripLeadingId3AndXing(bb.toBytes());
            byteCount = stripped.length;
            sink.add(stripped);
          } else {
            await for (final chunk in response.stream) {
              byteCount += chunk.length;
              sink.add(chunk);
            }
          }
        }
        isFirstSource = false;

        final durationMs = ((byteCount * 8) / (bitrateKbps * 1000) * 1000).round();
        ayahDurations.add(Duration(milliseconds: durationMs.clamp(1, 3600000)));
      }

      await sink.close();
      if (mergedFile.existsSync()) mergedFile.deleteSync();
      await tmpFile.rename(mergedFile.path);
      await metaFile.writeAsString(jsonEncode(
        ayahDurations.map((d) => d.inMilliseconds).toList(),
      ));

      return MergedSurahAudio(
        filePath: mergedFile.path,
        ayahDurations: ayahDurations,
      );
    } catch (_) {
      try { await sink.close(); } catch (_) {}
      try { if (tmpFile.existsSync()) tmpFile.deleteSync(); } catch (_) {}
      return null;
    }
  }

  // ── MP3 header helpers ────────────────────────────────────────────────────

  /// Returns a copy of [data] with any leading ID3v2 tag(s) and Xing/Info
  /// VBR frame removed.
  ///
  /// When MP3 ayah files are concatenated into one merged file, the first
  /// ayah's Xing frame still contains the frame-count for that single ayah.
  /// ExoPlayer reads this and reports only that ayah's duration as the total
  /// duration of the merged file.  Stripping the Xing frame forces ExoPlayer
  /// to fall back to `fileSize × 8 / bitrate`, which is correct for the
  /// whole merged CBR file.
  static Uint8List _stripLeadingId3AndXing(Uint8List data) {
    int offset = 0;

    // Skip any ID3v2 headers.
    while (offset + 10 <= data.length &&
        data[offset] == 0x49 && // 'I'
        data[offset + 1] == 0x44 && // 'D'
        data[offset + 2] == 0x33) { // '3'
      // Size is stored as a 4-byte synchsafe integer at bytes [6..9].
      final tagSize = ((data[offset + 6] & 0x7F) << 21) |
          ((data[offset + 7] & 0x7F) << 14) |
          ((data[offset + 8] & 0x7F) << 7) |
          (data[offset + 9] & 0x7F);
      offset += 10 + tagSize;
    }

    // Locate the first MPEG sync word.
    final syncPos = _findMpegSync(data, offset);
    if (syncPos < 0) {
      return Uint8List.sublistView(data, offset.clamp(0, data.length));
    }
    if (syncPos + 4 > data.length) {
      return Uint8List.sublistView(data, syncPos);
    }

    final b1 = data[syncPos + 1];
    final b2 = data[syncPos + 2];
    final b3 = data[syncPos + 3];

    // Parse MPEG header fields.
    final mpegVersion = (b1 >> 3) & 0x03; // 3=MPEG1, 2=MPEG2, 0=MPEG2.5
    final layer = (b1 >> 1) & 0x03; // 1=Layer3
    final bitrateIdx = (b2 >> 4) & 0x0F;
    final sampleRateIdx = (b2 >> 2) & 0x03;
    final paddingBit = (b2 >> 1) & 0x01;
    final channelMode = (b3 >> 6) & 0x03; // 3=Mono

    // Only handle MPEG Layer 3 (MP3); bail out for anything else.
    if (layer != 1 || bitrateIdx == 0 || bitrateIdx == 15 || sampleRateIdx == 3) {
      return Uint8List.sublistView(data, syncPos);
    }

    // kbps tables for Layer 3.
    const v1Kbps = [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320];
    const v2Kbps = [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160];
    // Sample-rate tables.
    const v1Hz = [44100, 48000, 32000];
    const v2Hz = [22050, 24000, 16000];
    const v25Hz = [11025, 12000, 8000];

    final kbps = mpegVersion == 3 ? v1Kbps[bitrateIdx] : v2Kbps[bitrateIdx];
    final hz = mpegVersion == 3
        ? v1Hz[sampleRateIdx]
        : (mpegVersion == 2 ? v2Hz[sampleRateIdx] : v25Hz[sampleRateIdx]);

    // Frame size = floor(144 × bitrateBps / sampleRate) + paddingBit.
    final frameSize = (144 * kbps * 1000 ~/ hz) + paddingBit;

    // Xing/Info tag offset: 4 (frame header) + side-info bytes.
    // MPEG1 stereo=32, MPEG1 mono=17; MPEG2/2.5 stereo=17, MPEG2/2.5 mono=9.
    final sideInfoSize =
        mpegVersion == 3 ? (channelMode == 3 ? 17 : 32) : (channelMode == 3 ? 9 : 17);
    final xingPos = syncPos + 4 + sideInfoSize;

    if (xingPos + 4 <= data.length) {
      final tag = String.fromCharCodes(data.sublist(xingPos, xingPos + 4));
      if (tag == 'Xing' || tag == 'Info') {
        // Skip the entire Xing frame and return data starting from the next frame.
        final nextSync = _findMpegSync(data, syncPos + frameSize);
        if (nextSync >= 0) return Uint8List.sublistView(data, nextSync);
      }
    }

    // No Xing frame — just skip the ID3 header and start from the first sync.
    return Uint8List.sublistView(data, syncPos);
  }

  /// Returns the byte index of the first MPEG sync word at or after [from],
  /// or -1 if none is found.  A sync word is 0xFF followed by a byte whose
  /// top 3 bits are all 1 (0xEx or 0xFx).
  static int _findMpegSync(Uint8List data, int from) {
    final start = from.clamp(0, data.length);
    for (var i = start; i < data.length - 1; i++) {
      if (data[i] == 0xFF && (data[i + 1] & 0xE0) == 0xE0) return i;
    }
    return -1;
  }
}
