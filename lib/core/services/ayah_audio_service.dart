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

  const AyahAudioSource._({this.localFilePath, this.remoteUri});

  factory AyahAudioSource.local(String path) => AyahAudioSource._(localFilePath: path);

  factory AyahAudioSource.remote(Uri uri) => AyahAudioSource._(remoteUri: uri);

  bool get isLocal => localFilePath != null;
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
};

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

  AyahAudioService(this._client, this._networkInfo, this._offlineAudio);

  String get currentEdition => _offlineAudio.edition;

  int? get currentEditionBitrateKbps => _everyAyahBitratesKbps[currentEdition];

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

    final edition = _offlineAudio.edition;
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
