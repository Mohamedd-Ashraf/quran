import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/api_constants.dart';

class OfflineAudioProgress {
  final int currentSurah;
  final int totalSurahs;
  final int currentAyah;
  final int totalAyahs;
  final int completedFiles;
  final int totalFiles;
  final double percentage;
  final String message;

  const OfflineAudioProgress({
    required this.currentSurah,
    required this.totalSurahs,
    required this.currentAyah,
    required this.totalAyahs,
    required this.completedFiles,
    required this.totalFiles,
    required this.percentage,
    required this.message,
  });

  /// Create progress with auto-calculated percentage
  factory OfflineAudioProgress.create({
    required int currentSurah,
    required int totalSurahs,
    required int currentAyah,
    required int totalAyahs,
    required int completedFiles,
    required int totalFiles,
    required String message,
  }) {
    final percentage = totalFiles > 0 ? (completedFiles / totalFiles) * 100 : 0.0;
    return OfflineAudioProgress(
      currentSurah: currentSurah,
      totalSurahs: totalSurahs,
      currentAyah: currentAyah,
      totalAyahs: totalAyahs,
      completedFiles: completedFiles,
      totalFiles: totalFiles,
      percentage: percentage,
      message: message,
    );
  }
}

/// Thrown when the download is interrupted due to a network outage.
class DownloadNetworkException implements Exception {
  final String message;
  const DownloadNetworkException(this.message);
  @override
  String toString() => message;
}

enum _DownloadOutcome { success, networkError, serverError, cancelled }

class _DownloadTask {
  final int surahNumber;
  final int ayahNumber;
  final String url;
  final File file;

  const _DownloadTask({
    required this.surahNumber,
    required this.ayahNumber,
    required this.url,
    required this.file,
  });
}

class OfflineAudioService {
  static const String _keyEnabled = 'offline_audio_enabled';
  static const String _keyEdition = 'offline_audio_edition';

  final SharedPreferences _prefs;
  final http.Client _client;

  static const int _totalQuranFiles = 6236;
  static const int _minValidAudioBytes = 1 * 1024; // 1 KB – short surahs can be < 8 KB

  // Authoritative ayah count per surah (index 0 = Surah 1 = Al-Fatiha).
  // Sum = 6236 – used to determine whether a surah is *fully* downloaded.
  static const List<int> _surahAyahCounts = [
     7, 286, 200, 176, 120, 165, 206,  75, 129, 109, // 1-10
   123, 111,  43,  52,  99, 128, 111, 110,  98, 135, // 11-20
   112,  78, 118,  64,  77, 227,  93,  88,  69,  60, // 21-30
    34,  30,  73,  54,  45,  83, 182,  88,  75,  85, // 31-40
    54,  53,  89,  59,  37,  35,  38,  29,  18,  45, // 41-50
    60,  49,  62,  55,  78,  96,  29,  22,  24,  13, // 51-60
    14,  11,  11,  18,  12,  12,  30,  52,  52,  44, // 61-70
    28,  28,  20,  56,  40,  31,  50,  40,  46,  42, // 71-80
    29,  19,  36,  25,  22,  17,  19,  26,  30,  20, // 81-90
    15,  21,  11,   8,   8,  19,   5,   8,   8,  11, // 91-100
    11,   8,   3,   9,   5,   4,   7,   3,   6,   3, // 101-110
     5,   4,   5,   6,                               // 111-114
  ];

  OfflineAudioService(this._prefs, this._client);

  /// Returns the number of ayahs in [surahNumber] (1-based, 1–114).
  static int getAyahCount(int surahNumber) => _surahAyahCounts[surahNumber - 1];

  bool get enabled => _prefs.getBool(_keyEnabled) ?? false;

  Future<void> setEnabled(bool value) async {
    await _prefs.setBool(_keyEnabled, value);
  }

  /// Default: verse-by-verse Ali Abdullah Jaber.
  String get edition => _prefs.getString(_keyEdition) ?? 'ar.alijaber';

  Future<void> setEdition(String value) async {
    await _prefs.setString(_keyEdition, value);
  }

  Future<Directory> _audioRootDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final root = Directory(
      '${dir.path}${Platform.pathSeparator}offline_audio${Platform.pathSeparator}$edition',
    );
    if (!root.existsSync()) {
      root.createSync(recursive: true);
    }
    return root;
  }

  Future<Directory> _audioBaseDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final base = Directory('${dir.path}${Platform.pathSeparator}offline_audio');
    if (!base.existsSync()) {
      base.createSync(recursive: true);
    }
    return base;
  }

  Future<Directory> _surahDir(int surahNumber) async {
    final root = await _audioRootDir();
    final dir = Directory('${root.path}${Platform.pathSeparator}surah_$surahNumber');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  Future<bool> hasAnyAudioDownloaded() async {
    final root = await _audioRootDir();
    if (!root.existsSync()) return false;
    return root.listSync(recursive: true).any((e) => e is File && e.path.endsWith('.mp3'));
  }

  Future<void> deleteAllAudio() async {
    final root = await _audioRootDir();
    if (root.existsSync()) {
      await root.delete(recursive: true);
    }
  }

  /// Delete audio for specific surahs
  Future<void> deleteSurahsAudio(List<int> surahNumbers) async {
    print('🗑️ [Delete] Deleting audio for surahs: $surahNumbers');
    for (final surah in surahNumbers) {
      final dir = await _surahDir(surah);
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
        print('✅ [Delete] Deleted surah $surah');
      }
    }
  }

  /// Returns the list of surahs that are **fully** downloaded.
  /// A surah is considered fully downloaded only when the number of valid
  /// `.mp3` files on disk equals the known ayah count for that surah.
  /// This method never creates directories as a side-effect.
  Future<List<int>> getDownloadedSurahs() async {
    final base = await getApplicationDocumentsDirectory();
    final sep = Platform.pathSeparator;
    final rootPath = '${base.path}${sep}offline_audio${sep}$edition';
    final root = Directory(rootPath);
    if (!root.existsSync()) return [];

    final downloaded = <int>[];
    // Surah-level editions store 1 file per surah (ayah_1.mp3 = whole surah).
    final expectedPerSurah = _isSurahLevelEdition ? 1 : -1;
    for (int i = 1; i <= 114; i++) {
      final dir = Directory('$rootPath${sep}surah_$i');
      if (!dir.existsSync()) continue;
      final expected = expectedPerSurah >= 0 ? expectedPerSurah : _surahAyahCounts[i - 1];
      final count = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.mp3') && f.lengthSync() >= _minValidAudioBytes)
          .length;
      if (count >= expected) downloaded.add(i);
    }
    return downloaded;
  }

  /// Returns `true` iff all expected files for [surahNumber] are on disk.
  /// For surah-level editions (mp3quran.net Qira'at), expects 1 file per surah.
  /// Never creates directories as a side-effect.
  Future<bool> isSurahFullyDownloaded(int surahNumber) async {
    final base = await getApplicationDocumentsDirectory();
    final sep = Platform.pathSeparator;
    final dir = Directory(
      '${base.path}${sep}offline_audio${sep}$edition${sep}surah_$surahNumber',
    );
    if (!dir.existsSync()) return false;
    // Surah-level editions store 1 file (the full surah); per-ayah editions
    // store one file per ayah.
    final expected = _isSurahLevelEdition ? 1 : _surahAyahCounts[surahNumber - 1];
    final count = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.mp3') && f.lengthSync() >= _minValidAudioBytes)
        .length;
    return count >= expected;
  }

  /// Get download statistics
  Future<Map<String, dynamic>> getDownloadStatistics() async {
    // Surah-level editions have 114 files (1 per surah); per-ayah editions have 6236.
    final totalExpectedFiles = _isSurahLevelEdition ? 114 : _totalQuranFiles;
    final root = await _audioRootDir();
    if (!root.existsSync()) {
      return {
        'downloadedFiles': 0,
        'totalFiles': totalExpectedFiles,
        'downloadedSurahs': 0,
        'totalSurahs': 114,
        'totalSizeMB': 0.0,
        'percentage': 0.0,
      };
    }

    int fileCount = 0;
    int totalSize = 0;
    final downloadedSurahs = await getDownloadedSurahs();

    final allFiles = root.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.mp3'));
    for (final file in allFiles) {
      fileCount++;
      totalSize += file.lengthSync();
    }

    return {
      'downloadedFiles': fileCount,
      'totalFiles': totalExpectedFiles,
      'downloadedSurahs': downloadedSurahs.length,
      'totalSurahs': 114,
      'totalSizeMB': totalSize / 1048576,
      'percentage': (fileCount / totalExpectedFiles) * 100,
    };
  }

  /// Quick quality check from local files (no network):
  /// returns whether files are likely old/high bitrate based on average file size.
  Future<Map<String, dynamic>> assessCurrentEditionAudioQuality() async {
    final stats = await getDownloadStatistics();
    final downloadedFiles = (stats['downloadedFiles'] as num?)?.toInt() ?? 0;
    final totalSizeMB = (stats['totalSizeMB'] as num?)?.toDouble() ?? 0.0;

    if (downloadedFiles == 0) {
      return {
        'status': 'empty',
        'averageFileKB': 0.0,
        'estimatedBitrate': 'unknown',
        'likelyHighBitrate': false,
      };
    }

    final avgFileKB = (totalSizeMB * 1024) / downloadedFiles;

    final bitrateStats = await analyzeCurrentEditionDownloadedBitrates(maxFiles: 300);
    final dominantBitrate = (bitrateStats['dominantBitrate'] as String?) ?? 'unknown';
    final dominantMatch = RegExp(r'^(\d+)kbps$').firstMatch(dominantBitrate);
    final dominantBitrateNum = int.tryParse(dominantMatch?.group(1) ?? '');
    final scannedFiles = (bitrateStats['scannedFiles'] as num?)?.toInt() ?? 0;

    final estimatedBitrate = dominantBitrate != 'unknown'
        ? dominantBitrate
        : (avgFileKB > 95 ? 'likely 128kbps+' : 'likely 64kbps');

    final likelyHighBitrate =
        scannedFiles >= 30 && dominantBitrateNum != null && dominantBitrateNum > 96;

    return {
      'status': 'ok',
      'averageFileKB': avgFileKB,
      'estimatedBitrate': estimatedBitrate,
      'likelyHighBitrate': likelyHighBitrate,
      'scannedFiles': scannedFiles,
      'dominantBitrate': dominantBitrate,
    };
  }

  /// Get storage stats across ALL downloaded reciters/editions
  Future<Map<String, dynamic>> getAllEditionsStorageStats() async {
    final base = await _audioBaseDir();
    if (!base.existsSync()) {
      return {
        'totalSizeMB': 0.0,
        'currentEditionSizeMB': 0.0,
        'otherEditionsSizeMB': 0.0,
        'editionsCount': 0,
        'otherEditionsCount': 0,
      };
    }

    final currentEditionRoot = await _audioRootDir();
    final editionDirs = base
        .listSync()
        .whereType<Directory>()
        .toList();

    int totalBytes = 0;
    int currentBytes = 0;

    for (final editionDir in editionDirs) {
      int editionBytes = 0;
      final files = editionDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.mp3'));
      for (final file in files) {
        editionBytes += file.lengthSync();
      }

      totalBytes += editionBytes;
      if (editionDir.path == currentEditionRoot.path) {
        currentBytes = editionBytes;
      }
    }

    final otherBytes = totalBytes - currentBytes;
    final otherCount = editionDirs.where((d) => d.path != currentEditionRoot.path).length;

    return {
      'totalSizeMB': totalBytes / 1048576,
      'currentEditionSizeMB': currentBytes / 1048576,
      'otherEditionsSizeMB': otherBytes / 1048576,
      'editionsCount': editionDirs.length,
      'otherEditionsCount': otherCount,
    };
  }

  /// Keep only the currently selected reciter files and remove old editions
  Future<void> deleteOtherEditionsAudio() async {
    final base = await _audioBaseDir();
    if (!base.existsSync()) return;

    final currentEditionRoot = await _audioRootDir();
    final editionDirs = base
        .listSync()
        .whereType<Directory>()
        .where((d) => d.path != currentEditionRoot.path)
        .toList();

    for (final dir in editionDirs) {
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
      }
    }
  }

  /// Delete audio for a specific edition by its identifier.
  Future<void> deleteEditionAudio(String editionId) async {
    final base = await _audioBaseDir();
    if (!base.existsSync()) return;
    final dir = Directory(
      '${base.path}${Platform.pathSeparator}$editionId',
    );
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  }

  /// Returns info about all OTHER editions (not the currently selected one)
  /// that have at least one downloaded MP3 file.
  ///
  /// Each entry: `{ 'editionId': String, 'downloadedSurahs': int, 'sizeMB': double }`
  Future<List<Map<String, dynamic>>> getOtherDownloadedEditionsInfo() async {
    final base = await _audioBaseDir();
    if (!base.existsSync()) return [];

    final currentEditionRoot = await _audioRootDir();
    final otherDirs = base
        .listSync()
        .whereType<Directory>()
        .where((d) => d.path != currentEditionRoot.path)
        .toList();

    final result = <Map<String, dynamic>>[];
    for (final dir in otherDirs) {
      final mp3Files = dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.mp3') && f.lengthSync() >= _minValidAudioBytes)
          .toList();
      if (mp3Files.isEmpty) continue;

      // Count fully downloaded surahs in this edition.
      final surahDirs = dir.listSync().whereType<Directory>().toList();
      int doneSurahs = 0;
      for (final sd in surahDirs) {
        final match = RegExp(r'surah_(\d+)$').firstMatch(sd.path);
        if (match == null) continue;
        final surahIdx = int.tryParse(match.group(1) ?? '');
        if (surahIdx == null || surahIdx < 1 || surahIdx > 114) continue;
        final expected = _surahAyahCounts[surahIdx - 1];
        final validCount = sd
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.mp3') && f.lengthSync() >= _minValidAudioBytes)
            .length;
        if (validCount >= expected) doneSurahs++;
      }

      int totalBytes = 0;
      for (final f in mp3Files) {
        totalBytes += f.lengthSync();
      }

      final editionId = dir.path.split(Platform.pathSeparator).last;
      result.add({
        'editionId': editionId,
        'downloadedSurahs': doneSurahs,
        'sizeMB': totalBytes / 1048576,
      });
    }
    return result;
  }

  /// Maps alquran.cloud edition IDs → everyayah.com folder names.
  /// When a folder is available, we download from everyayah.com (128 kbps)
  /// instead of cdn.islamic.network, which returns HTTP 200 + 0 bytes for
  /// many files at the 64 kbps path.
  static const Map<String, String> _everyAyahFolders = {
    'ar.alafasy'             : 'Alafasy_128kbps',
    'ar.abdurrahmaansudais'  : 'Abdurrahmaan_As-Sudais_192kbps',
    'ar.husary'              : 'Husary_128kbps',
    'ar.husarymujawwad'      : 'Husary_128kbps_Mujawwad',           // فولدر صحيح
    'ar.minshawi'            : 'Minshawy_Murattal_128kbps',         // محمد صديق المنشاوي (مرتل)
    'ar.minshawimujawwad'    : 'Minshawy_Mujawwad_192kbps',         // محمد صديق المنشاوي (مجود)
    'ar.muhammadayyoub'      : 'Muhammad_Ayyoub_128kbps',
    'ar.muhammadjibreel'     : 'Muhammad_Jibreel_128kbps',          // تصحيح: M كبير
    'ar.saoodshuraym'        : 'Saood_ash-Shuraym_128kbps',
    'ar.shaatree'            : 'Abu_Bakr_Ash-Shaatree_128kbps',
    'ar.parhizgar'           : 'Parhizgar_48kbps',
    // ─── قراء مضافون يدوياً ──────────────────────────────────────────────────
    'ar.alijaber'            : 'Ali_Jaber_64kbps',
    'ar.abdulsamad'          : 'Abdul_Basit_Murattal_64kbps',       // ar.abdulsamad في API
    'ar.abdulbasitmujawwad'  : 'Abdul_Basit_Mujawwad_128kbps',
    'ar.mahermuaiqly'        : 'Maher_AlMuaiqly_64kbps',
    'ar.nasserqatami'        : 'Nasser_Alqatami_128kbps',
    'ar.yasiradussary'       : 'Yasser_Ad-Dussary_128kbps',
    'ar.ahmedajamy'          : 'ahmed_ibn_ali_al_ajamy_128kbps',    // تصحيح
    // ─── قراء إضافيون ────────────────────────────────────────────────────────
    'ar.ghamadi'             : 'Ghamadi_40kbps',
    'ar.hudhaify'            : 'Hudhaify_128kbps',
    'ar.hanirifai'           : 'Hani_Rifai_192kbps',
    'ar.abdullahbasfar'      : 'Abdullah_Basfar_192kbps',
    'ar.aymanswoaid'         : 'Ayman_Sowaid_64kbps',
    'ar.ibrahimakhbar'       : 'Ibrahim_Akhdar_64kbps',
    'ar.muhsinqasim'         : 'Muhsin_Al_Qasim_192kbps',
    'ar.mohammadaltablawi'   : 'Mohammad_al_Tablaway_128kbps',
    'ar.mustafaismail'       : 'Mustafa_Ismail_48kbps',
    'ar.salahbudair'         : 'Salah_Al_Budair_128kbps',
    'ar.salaahbukhatir'      : 'Salaah_AbdulRahman_Bukhatir_128kbps',
    'ar.abdullahjuhani'      : 'Abdullaah_3awwaad_Al-Juhaynee_128kbps',
    'ar.yaserslama'          : 'Yaser_Salamah_128kbps',
    'ar.khaledtunaiji'       : 'khalefa_al_tunaiji_64kbps',
    'ar.khaalidqahtani'      : 'Khaalid_Abdullaah_al-Qahtaanee_192kbps',
    'ar.nabilerrifaai'       : 'Nabil_Rifa3i_48kbps',
    'ar.sahlyssin'           : 'Sahl_Yassin_128kbps',
    'ar.faresabbad'          : 'Fares_Abbad_64kbps',
    'ar.mahmoudbanna'        : 'mahmoud_ali_al_banna_32kbps',
    'ar.alisuesy'            : 'Ali_Hajjaj_AlSuesy_128kbps',
    'ar.karimmansoori'       : 'Karim_Mansoori_40kbps',
    // ─── قراءة ورش عن نافع (everyayah.com) ──────────────────────────────────
    'ar.warsh.ibrahimdosary' : 'warsh/warsh_ibrahim_aldosary_128kbps',
    'ar.warsh.yassinjazaery' : 'warsh/warsh_yassin_al_jazaery_64kbps',
    'ar.warsh.abdulbasit'    : 'warsh/warsh_Abdul_Basit_128kbps',
  };

  /// Maps Qira'at edition identifiers to their mp3quran.net server base URLs.
  /// mp3quran.net stores ONE mp3 file per surah (001.mp3 = full Surah 1).
  /// These are *surah-level* sources: download/play one file per surah,
  /// NOT individual ayah files.
  static const Map<String, String> _mp3QuranServers = {
    'ar.qiraat.qalon'       : 'https://server10.mp3quran.net/trablsi/',
    'ar.qiraat.bazi'        : 'https://server16.mp3quran.net/deban/Rewayat-Albizi-A-n-Ibn-Katheer/',
    'ar.qiraat.qunbol'      : 'https://server16.mp3quran.net/deban/Rewayat-Qunbol-A-n-Ibn-Katheer/',
    'ar.qiraat.duri.abuamr' : 'https://server16.mp3quran.net/deban/Rewayat-Aldori-A-n-Abi-Amr/',
    'ar.qiraat.ibndhakwan'  : 'https://server14.mp3quran.net/muftah_sultany/Rewayat_Ibn-Thakwan-A-n-Ibn-Amer/',
    'ar.qiraat.shuba'       : 'https://server16.mp3quran.net/deban/Rewayat-Sho-bah-A-n-Asim/',
    'ar.qiraat.duri.kisai'  : 'https://server14.mp3quran.net/muftah_sultany/Rewayat-AlDorai-A-n-Al-Kisa-ai/',
    'ar.qiraat.warsh.azraq' : 'https://server16.mp3quran.net/deban/Rewayat-Warsh-A-n-Nafi-Men-Tariq-Alazraq/',
    'ar.qiraat.sosi.abuamr' : 'https://server16.mp3quran.net/soufi/Rewayat-Assosi-A-n-Abi-Amr/',
    'ar.qiraat.khalaf.hamza': 'https://server16.mp3quran.net/soufi/Rewayat-Khalaf-A-n-Hamzah/',
    'ar.qiraat.husary.qalon': 'https://server13.mp3quran.net/husr/Rewayat-Qalon-A-n-Nafi/',
    'ar.qiraat.husary.warsh': 'https://server13.mp3quran.net/husr/Rewayat-Warsh-A-n-Nafi/',
    'ar.qiraat.husary.duri' : 'https://server13.mp3quran.net/husr/Rewayat-Aldori-A-n-Abi-Amr/',
    // ── قراءات ورش وقالون — reciters with timing ───────────────────────────
    'ar.qiraat.huthifi.qalon': 'https://server9.mp3quran.net/huthifi_qalon/',
    'ar.qiraat.koshi.warsh'  : 'https://server11.mp3quran.net/koshi/',
    'ar.qiraat.yasseen.warsh': 'https://server11.mp3quran.net/qari/',
    'ar.qiraat.qazabri.warsh': 'https://server9.mp3quran.net/omar_warsh/',
    'ar.qiraat.dokali.qalon' : 'https://server7.mp3quran.net/dokali/',
    'ar.qiraat.okasha.bazi'  : 'https://server16.mp3quran.net/okasha/Rewayat-Albizi-A-n-Ibn-Katheer/',
    // ── حفص — قراء mp3quran.net مع توقيتات ──────────────────────────────────
    'ar.khaledjleel'         : 'https://server10.mp3quran.net/jleel/',
    'ar.raadialkurdi'        : 'https://server6.mp3quran.net/kurdi/',
    'ar.abdulaziahahmad'     : 'https://server11.mp3quran.net/a_ahmed/',
  };

  /// True when the current edition stores one surah file per surah
  /// (mp3quran.net Qira'at editions) rather than individual ayah files.
  bool get _isSurahLevelEdition => _mp3QuranServers.containsKey(edition);

  /// Builds a direct everyayah.com URL (no API call needed).
  /// Returns null if the edition is not in [_everyAyahFolders].
  String? _buildEveryAyahUrl(int surahNumber, int ayahNumber) {
    final folder = _everyAyahFolders[edition];
    if (folder == null) return null;
    final s = surahNumber.toString().padLeft(3, '0');
    final a = ayahNumber.toString().padLeft(3, '0');
    return 'https://everyayah.com/data/$folder/$s$a.mp3';
  }

  int? _detectMp3BitrateFromBytes(Uint8List bytes) {
    if (bytes.length < 4) return null;

    int offset = 0;
    if (bytes.length >= 10 && bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33) {
      final tagSize = ((bytes[6] & 0x7F) << 21) |
          ((bytes[7] & 0x7F) << 14) |
          ((bytes[8] & 0x7F) << 7) |
          (bytes[9] & 0x7F);
      offset = 10 + tagSize;
    }

    for (int i = offset; i + 3 < bytes.length; i++) {
      final b1 = bytes[i];
      final b2 = bytes[i + 1];
      final b3 = bytes[i + 2];

      final isSync = b1 == 0xFF && (b2 & 0xE0) == 0xE0;
      if (!isSync) continue;

      final versionBits = (b2 >> 3) & 0x03; // 00=2.5, 10=2, 11=1
      final layerBits = (b2 >> 1) & 0x03; // 01=L3,10=L2,11=L1
      final bitrateIndex = (b3 >> 4) & 0x0F;

      if (versionBits == 0x01 || layerBits == 0x00 || bitrateIndex == 0x00 || bitrateIndex == 0x0F) {
        continue;
      }

      final isMpeg1 = versionBits == 0x03;

      const mpeg1Layer1 = [0, 32, 64, 96, 128, 160, 192, 224, 256, 288, 320, 352, 384, 416, 448, 0];
      const mpeg1Layer2 = [0, 32, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 384, 0];
      const mpeg1Layer3 = [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0];
      const mpeg2Layer1 = [0, 32, 48, 56, 64, 80, 96, 112, 128, 144, 160, 176, 192, 224, 256, 0];
      const mpeg2Layer2Or3 = [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, 0];

      List<int> table;
      switch (layerBits) {
        case 0x03: // Layer I
          table = isMpeg1 ? mpeg1Layer1 : mpeg2Layer1;
          break;
        case 0x02: // Layer II
          table = isMpeg1 ? mpeg1Layer2 : mpeg2Layer2Or3;
          break;
        case 0x01: // Layer III
          table = isMpeg1 ? mpeg1Layer3 : mpeg2Layer2Or3;
          break;
        default:
          return null;
      }

      final bitrate = table[bitrateIndex];
      if (bitrate > 0) return bitrate;
    }

    return null;
  }

  Future<int?> _detectMp3BitrateFromFile(File file) async {
    RandomAccessFile? raf;
    try {
      raf = await file.open();
      final bytes = await raf.read(16384);
      return _detectMp3BitrateFromBytes(bytes);
    } catch (_) {
      return null;
    } finally {
      await raf?.close();
    }
  }

  Future<Map<String, dynamic>> analyzeCurrentEditionDownloadedBitrates({
    int maxFiles = 0,
  }) async {
    final root = await _audioRootDir();
    if (!root.existsSync()) {
      return {
        'scannedFiles': 0,
        'unknownFiles': 0,
        'distribution': <String, int>{},
        'dominantBitrate': 'unknown',
      };
    }

    final files = root
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.mp3'))
        .toList();

    final toScan = maxFiles > 0 && files.length > maxFiles
        ? files.take(maxFiles).toList()
        : files;

    final distribution = <String, int>{};
    int unknownFiles = 0;

    for (final file in toScan) {
      final bitrate = await _detectMp3BitrateFromFile(file);
      if (bitrate == null) {
        unknownFiles++;
        continue;
      }
      final key = '${bitrate}kbps';
      distribution[key] = (distribution[key] ?? 0) + 1;
    }

    String dominantBitrate = 'unknown';
    if (distribution.isNotEmpty) {
      final sorted = distribution.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      dominantBitrate = sorted.first.key;
    }

    return {
      'scannedFiles': toScan.length,
      'unknownFiles': unknownFiles,
      'distribution': distribution,
      'dominantBitrate': dominantBitrate,
    };
  }

  Future<Map<String, dynamic>> inspectCurrentEditionDownloadPlan() async {
    final everyAyahFolder = _everyAyahFolders[edition];

    if (everyAyahFolder != null) {
      // Derive display bitrate from folder name (e.g. "Alafasy_128kbps" → 128).
      final bitrateMatch = RegExp(r'_(\d+)kbps$').firstMatch(everyAyahFolder);
      final bitrate = int.tryParse(bitrateMatch?.group(1) ?? '') ?? 128;
      final sampleUrl = _buildEveryAyahUrl(1, 1) ?? '';
      return {
        'edition'           : edition,
        'sourceBitrate'     : bitrate,
        'downloadBitrate'   : bitrate,
        'sampleUrl'         : sampleUrl,
        'optimizedSampleUrl': sampleUrl,
        'status'            : 'ok',
        'source'            : 'everyayah.com',
      };
    }

    // Fall back to querying alquran.cloud for non-everyayah editions.
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}${ApiConstants.surahEndpoint}/1/$edition',
      );
      final res = await _client.get(uri);
      if (res.statusCode != 200) {
        return {
          'edition': edition,
          'sourceBitrate': 0,
          'downloadBitrate': 0,
          'status': 'unavailable',
        };
      }

      final decoded = json.decode(res.body) as Map<String, dynamic>;
      final data = decoded['data'] as Map<String, dynamic>;
      final ayahs = (data['ayahs'] as List).cast<Map<String, dynamic>>();
      if (ayahs.isEmpty) {
        return {
          'edition': edition,
          'sourceBitrate': 0,
          'downloadBitrate': 0,
          'status': 'empty',
        };
      }

      final sampleUrl = (ayahs.first['audio'] as String?) ?? '';
      final match = RegExp(r'/audio/(\d+)/').firstMatch(sampleUrl);
      final sourceBitrate = int.tryParse(match?.group(1) ?? '') ?? 0;

      return {
        'edition'         : edition,
        'sourceBitrate'   : sourceBitrate,
        'downloadBitrate' : sourceBitrate,
        'sampleUrl'       : sampleUrl,
        'status'          : 'ok',
        'source'          : 'cdn.islamic.network',
      };
    } catch (_) {
      return {
        'edition': edition,
        'sourceBitrate': 0,
        'downloadBitrate': 0,
        'status': 'error',
      };
    }
  }

  Future<List<String>> _fetchAyahAudioUrls(int surahNumber) async {
    // ── Surah-level editions (mp3quran.net Qira'at) ───────────────────────
    // These servers store one file per surah (001.mp3).  Download that single
    // file and store it as ayah_1.mp3 to represent the whole surah.
    final mp3QuranServer = _mp3QuranServers[edition];
    if (mp3QuranServer != null) {
      final s = surahNumber.toString().padLeft(3, '0');
      return ['$mp3QuranServer$s.mp3'];
    }

    // ── Fast path: build everyayah.com URLs without any API call ──────────
    // cdn.islamic.network returns HTTP 200 + 0 bytes for many 64 kbps files,
    // causing persistent download failures. everyayah.com is reliable.
    final ayahCount = _surahAyahCounts[surahNumber - 1];
    final directFolder = _everyAyahFolders[edition];
    if (directFolder != null) {
      return List.generate(
        ayahCount,
        (i) => _buildEveryAyahUrl(surahNumber, i + 1)!,
      );
    }

    // ── Slow path: alquran.cloud API (editions not on everyayah.com) ──────
    // Use the URL bitrate the API returns — do NOT force 64 kbps because
    // that path is absent for many files on the CDN.
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.surahEndpoint}/$surahNumber/$edition');
    final res = await _client.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Failed to fetch audio URLs for surah $surahNumber');
    }

    final decoded = json.decode(res.body) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>;
    final ayahs = (data['ayahs'] as List).cast<Map<String, dynamic>>();

    final urls = <String>[];
    for (final a in ayahs) {
      final url = a['audio'];
      if (url is String && url.isNotEmpty) {
        urls.add(url); // keep original bitrate
      } else {
        urls.add('');
      }
    }
    return urls;
  }

  /// Download audio for specific surahs only (selective download)
  Future<void> downloadSurahs({
    required List<int> surahNumbers,
    required void Function(OfflineAudioProgress progress) onProgress,
    required bool Function() shouldCancel,
  }) async {
    print('🚀 [Selective Download] Starting download for ${surahNumbers.length} surahs');
    print('📋 [Selective Download] Surahs: $surahNumbers');
    
    await _downloadVerseByVerse(
      onProgress: onProgress,
      shouldCancel: shouldCancel,
      specificSurahs: surahNumbers,
    );
  }

  /// Download surahs with per-surah completion callbacks.
  /// Used by [DownloadManagerCubit] for resumable, state-persisted downloads.
  ///
  /// Downloads each surah's ayahs concurrently (up to [concurrentDownloads]
  /// within a surah), fires [onSurahCompleted] once all ayahs for a surah are
  /// done, then moves to the next surah.
  Future<void> downloadSurahsWithCallbacks({
    required List<int> surahNumbers,
    required void Function(OfflineAudioProgress progress) onProgress,
    required Future<void> Function(int surahNumber) onSurahCompleted,
    required bool Function() shouldCancel,
  }) async {
    const concurrentDownloads = 20;
    final totalSurahs = surahNumbers.length;

    // Compute the exact expected file count for the selected surahs so that
    // the progress percentage reflects ONLY the chosen download scope.
    // Surah-level editions store 1 file per surah; per-ayah editions store
    // one file per ayah.
    final estimatedTotalFiles = _isSurahLevelEdition
        ? surahNumbers.length
        : surahNumbers.fold<int>(0, (sum, sn) => sum + _surahAyahCounts[sn - 1]);
    int globalCompleted = 0;

    // --- Step 1: Pre-count total tasks so we can show a real % early ------
    // We compute this lazily per-surah to avoid waiting for all API calls.

    for (var surahIdx = 0; surahIdx < surahNumbers.length; surahIdx++) {
      if (shouldCancel()) return;

      final surahNumber = surahNumbers[surahIdx];

      // Announce "preparing surah N" while we fetch its URL list.
      onProgress(OfflineAudioProgress.create(
        currentSurah: surahNumber,
        totalSurahs: totalSurahs,
        currentAyah: 0,
        totalAyahs: 0,
        completedFiles: globalCompleted,
        totalFiles: estimatedTotalFiles,
        message: 'Preparing surah $surahNumber…',
      ));

      // Fetch URLs for this surah.
      List<String> urls;
      try {
        urls = await _fetchAyahAudioUrls(surahNumber);
      } catch (e) {
        print('⚠️ [Callbacks] Failed to fetch URLs for surah $surahNumber: $e');
        // Skip this surah on error (don't crash the whole session).
        continue;
      }

      final dir = await _surahDir(surahNumber);
      final tasks = <_DownloadTask>[];

      for (var i = 0; i < urls.length; i++) {
        if (shouldCancel()) return;
        final url = urls[i];
        final ayah = i + 1;
        final file =
            File('${dir.path}${Platform.pathSeparator}ayah_$ayah.mp3');

        if (url.isEmpty) continue;

        // Skip valid existing files (resume support).
        if (file.existsSync() && file.lengthSync() >= _minValidAudioBytes) {
          globalCompleted++;
          continue;
        }

        try {
          file.deleteSync();
        } catch (_) {}

        tasks.add(_DownloadTask(
          surahNumber: surahNumber,
          ayahNumber: ayah,
          url: url,
          file: file,
        ));
      }

      // --- Step 2: Download this surah's tasks in parallel batches ----------
      int surahCompleted = 0;
      final totalAyahs = urls.length;
      int consecutiveNetworkErrors = 0;

      for (var i = 0; i < tasks.length; i += concurrentDownloads) {
        if (shouldCancel()) return;

        final batch = tasks.skip(i).take(concurrentDownloads).toList();

        // Download all files in this batch concurrently.
        final outcomes = await Future.wait(batch.map((task) async {
          if (shouldCancel()) return _DownloadOutcome.cancelled;
          return await _downloadTaskWithRetries(task, shouldCancel: shouldCancel);
        }));

        // Tally results — Dart is single-threaded so this is safe.
        for (final outcome in outcomes) {
          if (outcome == _DownloadOutcome.success) {
            globalCompleted++;
            surahCompleted++;
            consecutiveNetworkErrors = 0;
          } else if (outcome == _DownloadOutcome.networkError) {
            consecutiveNetworkErrors++;
          }
        }

        // Yield to the event loop so Flutter can schedule a frame, then
        // emit exactly ONE progress update per batch.
        await Future.delayed(Duration.zero);
        onProgress(OfflineAudioProgress.create(
          currentSurah: batch.last.surahNumber,
          totalSurahs: totalSurahs,
          currentAyah: batch.last.ayahNumber,
          totalAyahs: totalAyahs,
          completedFiles: globalCompleted,
          totalFiles: estimatedTotalFiles,
          message: 'Surah ${batch.last.surahNumber}…',
        ));

        // If too many consecutive network failures, the connection is lost.
        if (consecutiveNetworkErrors >= 10) {
          throw const DownloadNetworkException(
            'انقطع الاتصال بالإنترنت أثناء التحميل',
          );
        }
      }

      // --- Step 3: Surah is done -------------------------------------------
      // Only checkpoint a surah as completed when ALL expected ayahs are
      // actually on disk. If network dropped mid-surah, leave it in
      // pendingSurahs so it is retried on the next resume.
      final isFullyDone = await isSurahFullyDownloaded(surahNumber);
      if (isFullyDone) {
        await onSurahCompleted(surahNumber);
      }
      print(
          '${isFullyDone ? '✅' : '⚠️'} [Callbacks] Surah $surahNumber '
          '${isFullyDone ? 'fully downloaded' : 'partial – will retry on resume'} '
          '($surahCompleted/${urls.length} new ayahs)');
    }

    // Final progress ping.
    onProgress(OfflineAudioProgress.create(
      currentSurah: totalSurahs,
      totalSurahs: totalSurahs,
      currentAyah: 0,
      totalAyahs: 0,
      completedFiles: globalCompleted,
      totalFiles: estimatedTotalFiles,
      message: 'Download complete!',
    ));
  }

  Future<void> downloadAllQuranAudio({
    required void Function(OfflineAudioProgress progress) onProgress,
    required bool Function() shouldCancel,
  }) async {
    print('🚀 [Offline Audio] Starting optimized verse-by-verse download for edition: $edition');
    print('🔽 [Offline Audio] Using 30 concurrent downloads + 64kbps audio (65% smaller)...');
    
    // Start verse-by-verse download with optimized settings
    await _downloadVerseByVerse(
      onProgress: onProgress,
      shouldCancel: shouldCancel,
    );
  }

  /// Downloads Quran audio verse-by-verse (fallback method)
  Future<void> _downloadVerseByVerse({
    required void Function(OfflineAudioProgress progress) onProgress,
    required bool Function() shouldCancel,
    List<int>? specificSurahs,
  }) async {
    final downloadSurahs = specificSurahs ?? List.generate(114, (i) => i + 1);
    final totalSurahs = downloadSurahs.length;
    
    print('🔽 [Verse-by-Verse] Starting verse-by-verse download...');
    print('📊 [Verse-by-Verse] Downloading ${downloadSurahs.length} surahs');
    const concurrentDownloads = 30; // Increased for better download speed
    print('⚙️ [Verse-by-Verse] Concurrent downloads: $concurrentDownloads');

    // Prepare all download tasks
    final tasks = <_DownloadTask>[];
    int totalAyahsCount = 0;

    // First pass: Fetch all URLs and prepare tasks
    print('📋 [Verse-by-Verse] Step 1: Preparing download list...');
    for (var surah in downloadSurahs) {
      if (shouldCancel()) {
        print('⛔ [Verse-by-Verse] Cancelled during preparation');
        return;
      }

      onProgress(
        OfflineAudioProgress.create(
          currentSurah: surah,
          totalSurahs: totalSurahs,
          currentAyah: 0,
          totalAyahs: 0,
          completedFiles: 0,
          totalFiles: 0,
          message: 'Preparing Surah $surah…',
        ),
      );

      final urls = await _fetchAyahAudioUrls(surah);
      final dir = await _surahDir(surah);

      for (var i = 0; i < urls.length; i++) {
        final url = urls[i];
        final ayah = i + 1;
        final file = File('${dir.path}${Platform.pathSeparator}ayah_$ayah.mp3');

        if (url.isEmpty) continue;

        // Skip only if file looks valid; tiny partial files are treated as broken.
        if (file.existsSync()) {
          final existingBytes = file.lengthSync();
          if (existingBytes >= _minValidAudioBytes) {
            continue;
          }
          try {
            file.deleteSync();
          } catch (_) {}
        }

        tasks.add(_DownloadTask(
          surahNumber: surah,
          ayahNumber: ayah,
          url: url,
          file: file,
        ));
      }
      totalAyahsCount += urls.length;
    }

    print('📊 [Verse-by-Verse] Preparation complete: ${tasks.length} files to download');

    if (shouldCancel()) {
      print('⛔ [Verse-by-Verse] Cancelled before download start');
      return;
    }

    // Second pass: Download in parallel batches
    int successfulCount = 0;
    int processedCount = 0;
    int failedCount = 0;
    var lastLoggedBatch = 0;
    
    print('⬇️ [Verse-by-Verse] Step 2: Starting downloads...');
    for (var i = 0; i < tasks.length; i += concurrentDownloads) {
      if (shouldCancel()) {
        print('⛔ [Verse-by-Verse] Cancelled during download');
        return;
      }

      final batch = tasks.skip(i).take(concurrentDownloads).toList();
      final batchNumber = (i ~/ concurrentDownloads) + 1;
      final totalBatches = (tasks.length / concurrentDownloads).ceil();
      
      if (batchNumber >= lastLoggedBatch + 10 || batchNumber == 1) {
        print('📦 [Verse-by-Verse] Batch $batchNumber/$totalBatches (${successfulCount}/${tasks.length} files successful)');
        lastLoggedBatch = batchNumber;
      }
      
      // Download batch in parallel
      await Future.wait(
        batch.map((task) async {
          if (shouldCancel()) return;

          onProgress(
            OfflineAudioProgress.create(
              currentSurah: task.surahNumber,
              totalSurahs: totalSurahs,
              currentAyah: task.ayahNumber,
              totalAyahs: totalAyahsCount,
              completedFiles: successfulCount,
              totalFiles: tasks.length,
              message: 'Downloading ${processedCount + 1}/${tasks.length}…',
            ),
          );

          final outcome = await _downloadTaskWithRetries(
            task,
            shouldCancel: shouldCancel,
          );

          if (outcome == _DownloadOutcome.success) {
            successfulCount++;
          } else {
            failedCount++;
          }

          processedCount++;
        }),
      );
    }

    print('✅ [Verse-by-Verse] Download complete!');
    print('📊 [Verse-by-Verse] Summary: $successfulCount successful, $failedCount failed');

    // Final progress update
    onProgress(
      OfflineAudioProgress.create(
        currentSurah: totalSurahs,
        totalSurahs: totalSurahs,
        currentAyah: 0,
        totalAyahs: 0,
        completedFiles: successfulCount,
        totalFiles: tasks.length,
        message: failedCount > 0
            ? 'Download complete with $failedCount failed file(s) after retries'
            : 'Download complete! ($successfulCount files)',
      ),
    );
  }

  Future<_DownloadOutcome> _downloadTaskWithRetries(
    _DownloadTask task, {
    required bool Function() shouldCancel,
    int maxAttempts = 3,
  }) async {
    bool lastWasNetworkError = false;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      if (shouldCancel()) return _DownloadOutcome.cancelled;

      try {
        final resp = await _client.get(Uri.parse(task.url));
        lastWasNetworkError = false;
        if (resp.statusCode == 200 && resp.bodyBytes.length >= _minValidAudioBytes) {
          await task.file.writeAsBytes(resp.bodyBytes, flush: true);
          final bitrate = _detectMp3BitrateFromBytes(resp.bodyBytes);
          print(
            '🎵 [Bitrate] Surah ${task.surahNumber}:${task.ayahNumber} '
            '=> ${bitrate != null ? '${bitrate}kbps' : 'unknown'} '
            '(bytes=${resp.bodyBytes.length})',
          );
          return _DownloadOutcome.success;
        }

        print(
          '⚠️ [Verse-by-Verse] Attempt $attempt/$maxAttempts failed '
          'for Surah ${task.surahNumber}:${task.ayahNumber} '
          '(HTTP ${resp.statusCode}, bytes=${resp.bodyBytes.length})',
        );
      } catch (e) {
        lastWasNetworkError = _isNetworkError(e);
        print(
          '❌ [Verse-by-Verse] Attempt $attempt/$maxAttempts error '
          'for Surah ${task.surahNumber}:${task.ayahNumber}: $e',
        );
      }

      try {
        if (task.file.existsSync()) {
          task.file.deleteSync();
        }
      } catch (_) {}

      if (attempt < maxAttempts) {
        await Future.delayed(Duration(milliseconds: 300 * attempt));
      }
    }

    return lastWasNetworkError
        ? _DownloadOutcome.networkError
        : _DownloadOutcome.serverError;
  }

  /// Returns true when the exception looks like a network / DNS failure.
  bool _isNetworkError(Object e) {
    if (e is SocketException) return true;
    if (e is http.ClientException) {
      final msg = e.message.toLowerCase();
      return msg.contains('socketexception') ||
          msg.contains('failed host lookup') ||
          msg.contains('connection refused') ||
          msg.contains('network is unreachable') ||
          msg.contains('errno = 7') ||
          msg.contains('no address associated');
    }
    return false;
  }

  /// Returns the local audio file for an ayah if it exists and is valid.
  /// For surah-level editions (mp3quran.net Qira'at), all ayahs in a surah
  /// are covered by the single surah file stored as ayah_1.mp3.
  /// Never creates directories as a side-effect.
  Future<File?> getLocalAyahAudioFile({
    required int surahNumber,
    required int ayahNumber,
  }) async {
    final base = await getApplicationDocumentsDirectory();
    final sep = Platform.pathSeparator;
    // For surah-level editions, ayah_1.mp3 holds the full surah regardless
    // of which ayah was requested.
    final effectiveAyah = _isSurahLevelEdition ? 1 : ayahNumber;
    final file = File(
      '${base.path}${sep}offline_audio${sep}$edition'
      '${sep}surah_$surahNumber${sep}ayah_$effectiveAyah.mp3',
    );
    if (file.existsSync() && file.lengthSync() >= _minValidAudioBytes) {
      return file;
    }
    return null;
  }
}
