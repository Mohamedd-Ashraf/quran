import 'dart:io';
import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pages bundled inside the APK — 9 pages covering key surah openings.
///
/// Strategy:
///   • Al-Fatiha + Al-Baqarah opening (1-4)
///   • Al-Imran opening (50)
///   • An-Nisa opening (77)
///   • Al-Maidah opening (106)
///   • Al-An'am opening (128)
///   • Al-A'raf opening (151)
///
/// All remaining 595 pages are downloaded online via QcfFontDownloadService.
class _BundledPages {
  static const Set<int> pages = {
    1, 2, 3, 4,
    50,
    77,
    106,
    128,
    151,
  };

  static bool isBundled(int page) => pages.contains(page);
}

/// Downloads all remaining QCF tajweed fonts by fetching the official pub.dev
/// package archive (`qcf_quran_plus-0.0.7.tar.gz`), extracting each font ZIP
/// from the tarball, and persisting the ZIP files to the same disk path that
/// [QcfFontLoader] checks first.
///
/// Fonts are stored as compressed ZIP files (~104KB each) instead of extracted
/// TTF files (~269KB each), saving ~100MB of disk space across 595 pages.
///
/// Resume support (correct implementation):
///   • Archive stored in **app documents dir** (survives app restarts + OS cleanup).
///   • HTTP Range request sends `bytes=N-` to skip already-downloaded bytes.
///   • File opened in **append mode** — new bytes are added after existing ones,
///     not overwriting them.
///   • Archive is deleted only after successful full extraction.
class QcfFontDownloadService {
  QcfFontDownloadService._();

  static const String _prefKey = 'qcf_fonts_fully_downloaded';
  static const int _totalPages = 604;

  static const String _archiveUrl =
      'https://pub.dev/api/archives/qcf_quran_plus-0.0.7.tar.gz';

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 10),
      followRedirects: true,
      maxRedirects: 5,
    ),
  );

  // ── Public API ─────────────────────────────────────────────────────────────

  static Future<bool> isFullyDownloaded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefKey) == true) {
      final dir = await _getFontDirectory();
      int count = 0;
      for (int i = 1; i <= _totalPages; i++) {
        if (_BundledPages.isBundled(i)) { count++; continue; }
        if (_hasFont(dir, i)) count++;
      }
      if (count == _totalPages) return true;
      await prefs.remove(_prefKey);
      return false;
    }
    return false;
  }

  static Future<bool> isPageAvailable(int pageNumber) async {
    if (_BundledPages.isBundled(pageNumber)) return true;
    final dir = await _getFontDirectory();
    return _hasFont(dir, pageNumber);
  }

  static Future<int> pendingDownloadCount() async {
    final dir = await _getFontDirectory();
    int pending = 0;
    for (int i = 1; i <= _totalPages; i++) {
      if (_BundledPages.isBundled(i)) continue;
      if (!_hasFont(dir, i)) pending++;
    }
    return pending;
  }

  /// Downloads and extracts all non-bundled fonts.
  ///
  /// Fonts are saved as ZIP files (~104KB) instead of extracted TTF (~269KB),
  /// saving ~100MB of disk space across 595 pages.
  ///
  /// [onProgress]   0.0→0.6 download phase, 0.6→1.0 extraction phase.
  /// [onPhase]      Arabic phase label.
  /// [onPageDone]   called after each newly-saved font.
  /// [skipExisting] skip pages already on disk (resume after partial extraction).
  static Future<bool> downloadAll({
    void Function(double progress)? onProgress,
    void Function(String phase)? onPhase,
    void Function(int page)? onPageDone,
    CancelToken? cancelToken,
    bool skipExisting = false,
  }) async {
    final fontDir  = await _getFontDirectory();
    final archive  = await _getArchiveFile();

    try {
      // ── Phase 1: Download archive with proper resume support ───────────
      onPhase?.call('جارٍ تحميل ملف الخطوط…');

      final existingBytes = archive.existsSync() ? archive.lengthSync() : 0;
      final remoteSize    = await _getRemoteFileSize();

      if (remoteSize != null && existingBytes >= remoteSize) {
        debugPrint('QcfFontDownloadService: archive already complete ($existingBytes bytes)');
        onProgress?.call(0.6);
      } else if (existingBytes > 0 && remoteSize != null && existingBytes < remoteSize) {
        debugPrint(
          'QcfFontDownloadService: resuming from $existingBytes / $remoteSize bytes',
        );
        await _downloadRange(
          url: _archiveUrl,
          file: archive,
          from: existingBytes,
          remoteTotal: remoteSize,
          cancelToken: cancelToken,
          onProgress: (p) => onProgress?.call(p * 0.6),
        );
      } else {
        if (existingBytes > 0) await archive.delete();
        await _downloadFull(
          url: _archiveUrl,
          file: archive,
          cancelToken: cancelToken,
          onProgress: (p) => onProgress?.call(p * 0.6),
        );
      }

      if (cancelToken?.isCancelled == true) return false;

      // ── Phase 2: Extract ZIP files from tar.gz and save to disk ───────
      onPhase?.call('جارٍ استخراج الخطوط…');
      onProgress?.call(0.6);

      final archiveBytes = await archive.readAsBytes();
      final tarBytes     = GZipDecoder().decodeBytes(archiveBytes);
      final tar          = TarDecoder().decodeBytes(tarBytes);

      final pattern = RegExp(r'qcf_tajweed/(QCF4_tajweed_(\d{3}))\.zip$');
      final entries = tar.files.where((f) => pattern.hasMatch(f.name)).toList();

      int processed = 0;
      for (final entry in entries) {
        if (cancelToken?.isCancelled == true) break;

        final match    = pattern.firstMatch(entry.name)!;
        final fontName = match.group(1)!;
        final pageNum  = int.parse(match.group(2)!);

        if (!_BundledPages.isBundled(pageNum)) {
          final zipFile = File('${fontDir.path}/$fontName.zip');
          final ttfFile = File('${fontDir.path}/$fontName.ttf');

          // Skip if already present (either new ZIP format or legacy TTF format).
          if (skipExisting &&
              ((zipFile.existsSync() && zipFile.lengthSync() > 500) ||
               (ttfFile.existsSync() && ttfFile.lengthSync() > 1000))) {
            processed++;
            onProgress?.call(0.6 + processed / entries.length * 0.4);
            continue;
          }

          try {
            // Save raw ZIP bytes — no decompression needed at download time.
            // QcfFontLoader will decompress to memory when the page is rendered.
            final zipBytes = Uint8List.fromList(entry.content as List<int>);
            await zipFile.writeAsBytes(zipBytes, flush: true);
            onPageDone?.call(pageNum);
          } catch (e) {
            debugPrint('QcfFontDownloadService: skip page $pageNum – $e');
          }
        }

        processed++;
        onProgress?.call(0.6 + processed / entries.length * 0.4);
      }

      final remaining = await pendingDownloadCount();
      if (remaining == 0) {
        await _markComplete();
        try { if (archive.existsSync()) await archive.delete(); } catch (_) {}
      }
      onProgress?.call(1.0);
      return remaining == 0;
    } catch (e) {
      debugPrint('QcfFontDownloadService: download failed – $e');
      return false;
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Returns true if a font for [page] exists on disk in either format:
  /// - New format: `$fontName.zip` (~104KB compressed)
  /// - Legacy format: `$fontName.ttf` (~269KB uncompressed, backward compat)
  static bool _hasFont(Directory dir, int page) {
    final fontName = _getFontName(page);
    final zipFile  = File('${dir.path}/$fontName.zip');
    if (zipFile.existsSync() && zipFile.lengthSync() > 500) return true;
    final ttfFile  = File('${dir.path}/$fontName.ttf');
    return ttfFile.existsSync() && ttfFile.lengthSync() > 1000;
  }

  /// Full download (no resume): streams response body into [file] (write mode).
  static Future<void> _downloadFull({
    required String url,
    required File file,
    required void Function(double) onProgress,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.get<ResponseBody>(
      url,
      cancelToken: cancelToken,
      options: Options(responseType: ResponseType.stream),
    );
    final body       = response.data!;
    final total      = int.tryParse(
      response.headers.value(Headers.contentLengthHeader) ?? '',
    ) ?? 0;
    final sink       = file.openWrite(mode: FileMode.write);
    int received     = 0;
    await for (final chunk in body.stream) {
      if (cancelToken?.isCancelled == true) break;
      sink.add(chunk);
      received += chunk.length;
      if (total > 0) onProgress(received / total);
    }
    await sink.flush();
    await sink.close();
  }

  /// Resume download: sends Range header and **appends** response to [file].
  static Future<void> _downloadRange({
    required String url,
    required File file,
    required int from,
    required int remoteTotal,
    required void Function(double) onProgress,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.get<ResponseBody>(
      url,
      cancelToken: cancelToken,
      options: Options(
        responseType: ResponseType.stream,
        headers: {'Range': 'bytes=$from-'},
        validateStatus: (s) => s != null && (s == 206 || s == 200),
      ),
    );
    final body   = response.data!;
    final sink   = file.openWrite(mode: FileMode.append);
    int received = from;
    await for (final chunk in body.stream) {
      if (cancelToken?.isCancelled == true) break;
      sink.add(chunk);
      received += chunk.length;
      onProgress(received / remoteTotal);
    }
    await sink.flush();
    await sink.close();
  }

  /// HTTP HEAD to get Content-Length. Returns null if unsupported.
  static Future<int?> _getRemoteFileSize() async {
    try {
      final response = await _dio.head<void>(
        _archiveUrl,
        options: Options(
          followRedirects: true,
          validateStatus: (s) => s != null && s < 400,
        ),
      );
      final cl = response.headers.value(Headers.contentLengthHeader);
      if (cl != null) return int.tryParse(cl);
    } catch (_) {}
    return null;
  }

  static Future<Directory> _getFontDirectory() async {
    final appDir  = await getApplicationDocumentsDirectory();
    final fontDir = Directory('${appDir.path}/qcf_fonts');
    if (!fontDir.existsSync()) fontDir.createSync(recursive: true);
    return fontDir;
  }

  /// Archive stored in app documents dir (persists across restarts).
  static Future<File> _getArchiveFile() async {
    final appDir = await getApplicationDocumentsDirectory();
    return File('${appDir.path}/qcf_fonts_pkg.tar.gz');
  }

  static String _getFontName(int page) =>
      'QCF4_tajweed_${page.toString().padLeft(3, '0')}';

  static Future<void> _markComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
  }
}
