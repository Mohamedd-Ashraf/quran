import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

  OfflineAudioService(this._prefs, this._client);

  bool get enabled => _prefs.getBool(_keyEnabled) ?? false;

  Future<void> setEnabled(bool value) async {
    await _prefs.setBool(_keyEnabled, value);
  }

  /// Default: verse-by-verse Mishary Alafasy.
  String get edition => _prefs.getString(_keyEdition) ?? 'ar.alafasy';

  Future<void> setEdition(String value) async {
    await _prefs.setString(_keyEdition, value);
  }

  Future<Directory> _audioRootDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final root = Directory('${dir.path}${Platform.pathSeparator}offline_audio${Platform.pathSeparator}$edition');
    if (!root.existsSync()) {
      root.createSync(recursive: true);
    }
    return root;
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

  /// Get list of downloaded surahs
  Future<List<int>> getDownloadedSurahs() async {
    final root = await _audioRootDir();
    if (!root.existsSync()) return [];

    final downloaded = <int>[];
    for (int i = 1; i <= 114; i++) {
      final dir = await _surahDir(i);
      if (dir.existsSync()) {
        final files = dir.listSync().where((e) => e is File && e.path.endsWith('.mp3')).toList();
        if (files.isNotEmpty) {
          downloaded.add(i);
        }
      }
    }
    return downloaded;
  }

  /// Get download statistics
  Future<Map<String, dynamic>> getDownloadStatistics() async {
    final root = await _audioRootDir();
    if (!root.existsSync()) {
      return {
        'downloadedFiles': 0,
        'totalFiles': 6236,
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
      'totalFiles': 6236,
      'downloadedSurahs': downloadedSurahs.length,
      'totalSurahs': 114,
      'totalSizeMB': totalSize / 1048576,
      'percentage': (fileCount / 6236) * 100,
    };
  }

  Future<List<String>> _fetchAyahAudioUrls(int surahNumber) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.surahEndpoint}/$surahNumber/$edition');
    final res = await _client.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Failed to fetch audio URLs');
    }

    final decoded = json.decode(res.body) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>;
    final ayahs = (data['ayahs'] as List).cast<Map<String, dynamic>>();

    final urls = <String>[];
    for (final a in ayahs) {
      final url = a['audio'];
      if (url is String && url.isNotEmpty) {
        // Use 64kbps instead of 128kbps (65% smaller files)
        final optimizedUrl = url.replaceAll('/128/', '/64/');
        urls.add(optimizedUrl);
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

        // Skip if already downloaded
        if (file.existsSync() && file.lengthSync() > 0) {
          continue;
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
    int completedCount = 0;
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
        print('📦 [Verse-by-Verse] Batch $batchNumber/$totalBatches (${completedCount}/${tasks.length} files completed)');
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
              completedFiles: completedCount,
              totalFiles: tasks.length,
              message: 'Downloading ${completedCount + 1}/${tasks.length}…',
            ),
          );

          try {
            final resp = await _client.get(Uri.parse(task.url));
            if (resp.statusCode == 200) {
              await task.file.writeAsBytes(resp.bodyBytes, flush: true);
            } else {
              print('⚠️ [Verse-by-Verse] Failed HTTP ${resp.statusCode} for Surah ${task.surahNumber}:${task.ayahNumber}');
              failedCount++;
            }
          } catch (e) {
            print('❌ [Verse-by-Verse] Error downloading Surah ${task.surahNumber}:${task.ayahNumber}: $e');
            failedCount++;
          }

          completedCount++;
        }),
      );
    }

    print('✅ [Verse-by-Verse] Download complete!');
    print('📊 [Verse-by-Verse] Summary: $completedCount successful, $failedCount failed');

    // Final progress update
    onProgress(
      OfflineAudioProgress.create(
        currentSurah: totalSurahs,
        totalSurahs: totalSurahs,
        currentAyah: 0,
        totalAyahs: 0,
        completedFiles: completedCount,
        totalFiles: tasks.length,
        message: 'Download complete! ($completedCount files)',
      ),
    );
  }

  Future<File?> getLocalAyahAudioFile({
    required int surahNumber,
    required int ayahNumber,
  }) async {
    final dir = await _surahDir(surahNumber);
    final file = File('${dir.path}${Platform.pathSeparator}ayah_$ayahNumber.mp3');
    if (file.existsSync() && file.lengthSync() > 0) {
      return file;
    }
    return null;
  }
}
