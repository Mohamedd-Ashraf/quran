import 'dart:convert';
import 'dart:io';

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
  'ar.alafasy': 'Alafasy_128kbps',
  'ar.abdurrahmaansudais': 'Abdurrahmaan_As-Sudais_192kbps',
  'ar.husary': 'Husary_128kbps',
  'ar.husarymujawwad': 'Husary_Mujawwad_128kbps',
  'ar.minshawi': 'Minshawy_Murattal_128kbps',
  'ar.minshawimujawwad': 'Minshawy_Mujawwad_128kbps',
  'ar.muhammadayyoub': 'Muhammad_Ayyoub_128kbps',
  'ar.muhammadjibreel': 'muhammad_jibreel_128kbps',
  'ar.saoodshuraym': 'Saood_ash-Shuraym_128kbps',
  'ar.shaatree': 'Abu_Bakr_Ash-Shaatree_128kbps',
  'ar.parhizgar': 'Parhizgar_48kbps',
  // ─── قراء مضافون يدوياً ───────────────────────────────────────────────────
  'ar.alijaber': 'Ali_Jaber_64kbps',                    // علي عبد الله جابر
};

const Map<String, int> _everyAyahBitratesKbps = {
  'ar.alafasy': 128,
  'ar.abdurrahmaansudais': 192,
  'ar.husary': 128,
  'ar.husarymujawwad': 128,
  'ar.minshawi': 128,
  'ar.minshawimujawwad': 128,
  'ar.muhammadayyoub': 128,
  'ar.muhammadjibreel': 128,
  'ar.saoodshuraym': 128,
  'ar.shaatree': 128,
  'ar.parhizgar': 48,
  'ar.alijaber': 64,
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
      for (final source in sources) {
        int byteCount = 0;
        if (source.isLocal) {
          final file = File(source.localFilePath!);
          byteCount = file.lengthSync();
          await sink.addStream(file.openRead());
        } else {
          final request = http.Request('GET', source.remoteUri!);
          final response = await _client.send(request);
          if (response.statusCode != 200) {
            throw Exception('Failed to download surah segment');
          }
          await for (final chunk in response.stream) {
            byteCount += chunk.length;
            sink.add(chunk);
          }
        }

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
}
