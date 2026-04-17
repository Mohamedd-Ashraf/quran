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
          knownTotalSize: remoteSize,
        );
      }

      if (cancelToken?.isCancelled == true) return false;

      // ── Phase 2: Extract ZIP files from tar.gz and save to disk ───────
      onPhase?.call('جارٍ استخراج الخطوط…');
      onProgress?.call(0.6);

      // Offload CPU-intensive decode + file I/O to a separate isolate so the
      // UI thread stays responsive during the extraction phase.
      final writtenPages = await compute(
        _extractArchiveIsolate,
        [archive.path, fontDir.path, _BundledPages.pages.toList(), skipExisting],
      );

      // Notify caller for each newly-written font so it can register the font
      // in the Flutter engine immediately.
      for (final page in writtenPages) {
        onPageDone?.call(page);
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

  /// Full download: tries 4 parallel Range connections for maximum throughput,
  /// then falls back to a single sequential stream on any error.
  static Future<void> _downloadFull({
    required String url,
    required File file,
    required void Function(double) onProgress,
    CancelToken? cancelToken,
    int? knownTotalSize,
  }) async {
    if (knownTotalSize != null && knownTotalSize > 0) {
      try {
        await _downloadParallel(
          url: url,
          file: file,
          totalSize: knownTotalSize,
          onProgress: onProgress,
          cancelToken: cancelToken,
        );
        return;
      } catch (e) {
        debugPrint(
          'QcfFontDownloadService: parallel failed ($e), retrying sequential',
        );
        try {
          if (file.existsSync()) await file.delete();
        } catch (_) {}
      }
    }

    // Sequential fallback (also used when knownTotalSize is null).
    final response = await _dio.get<ResponseBody>(
      url,
      cancelToken: cancelToken,
      options: Options(responseType: ResponseType.stream),
    );
    final body   = response.data!;
    final total  = int.tryParse(
      response.headers.value(Headers.contentLengthHeader) ?? '',
    ) ?? 0;
    final sink   = file.openWrite(mode: FileMode.write);
    int received = 0;
    await for (final chunk in body.stream) {
      if (cancelToken?.isCancelled == true) break;
      sink.add(chunk);
      received += chunk.length;
      if (total > 0) onProgress(received / total);
    }
    await sink.flush();
    await sink.close();
  }

  /// Downloads [totalSize] bytes using [numConnections] parallel HTTP Range
  /// requests, then concatenates the chunks into [file].
  static Future<void> _downloadParallel({
    required String url,
    required File file,
    required int totalSize,
    required void Function(double) onProgress,
    CancelToken? cancelToken,
    int numConnections = 4,
  }) async {
    final tempDir   = await getTemporaryDirectory();
    final chunkSize = (totalSize / numConnections).ceil();
    final received  = List<int>.filled(numConnections, 0);
    final chunks    = List.generate(
      numConnections,
      (i) => File('${tempDir.path}/qcf_dl_chunk_$i.tmp'),
    );

    try {
      await Future.wait(
        List.generate(numConnections, (i) async {
          final from = i * chunkSize;
          final to   = (i == numConnections - 1) ? totalSize - 1 : from + chunkSize - 1;
          if (from > totalSize - 1) return;

          final res = await _dio.get<ResponseBody>(
            url,
            cancelToken: cancelToken,
            options: Options(
              responseType: ResponseType.stream,
              headers: {'Range': 'bytes=$from-$to'},
              validateStatus: (s) => s == 206,
            ),
          );

          final sink = chunks[i].openWrite(mode: FileMode.write);
          await for (final chunk in res.data!.stream) {
            if (cancelToken?.isCancelled == true) break;
            sink.add(chunk);
            received[i] += chunk.length;
            onProgress(received.fold(0, (a, b) => a + b) / totalSize);
          }
          await sink.flush();
          await sink.close();
        }),
      );

      if (cancelToken?.isCancelled == true) return;

      // Concatenate all chunk files into the target file.
      final outSink = file.openWrite(mode: FileMode.write);
      for (final chunk in chunks) {
        if (chunk.existsSync()) outSink.add(await chunk.readAsBytes());
      }
      await outSink.flush();
      await outSink.close();
    } finally {
      // Always clean up temp chunk files.
      for (final chunk in chunks) {
        try {
          if (chunk.existsSync()) await chunk.delete();
        } catch (_) {}
      }
    }
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

// ── Top-level isolate entry point ─────────────────────────────────────────────

/// Runs inside a [compute] isolate: decodes the tar.gz archive and writes each
/// font ZIP to disk, returning the list of page numbers that were newly saved.
///
/// Must be a top-level function (not a static method) for [compute] to accept it.
///
/// Params (positional list for [SendPort] compatibility):
///   [0] String    archivePath  — path to `qcf_fonts_pkg.tar.gz`
///   [1] String    fontDirPath  — target directory for font ZIP files
///   [2] List<int> bundledPages — pages bundled in the APK (skip these)
///   [3] bool      skipExisting — skip pages whose ZIP is already on disk
List<int> _extractArchiveIsolate(List<Object> params) {
  final archivePath  = params[0] as String;
  final fontDirPath  = params[1] as String;
  final bundledPages = Set<int>.from(params[2] as List<dynamic>);
  final skipExist    = params[3] as bool;

  final archiveBytes = File(archivePath).readAsBytesSync();
  final tarBytes     = GZipDecoder().decodeBytes(archiveBytes);
  final tar          = TarDecoder().decodeBytes(tarBytes);

  final pattern = RegExp(r'qcf_tajweed/(QCF4_tajweed_(\d{3}))\.zip$');
  final written = <int>[];

  for (final entry in tar.files) {
    final match = pattern.firstMatch(entry.name);
    if (match == null) continue;

    final fontName = match.group(1)!;
    final pageNum  = int.parse(match.group(2)!);

    if (bundledPages.contains(pageNum)) continue;

    final zipFile = File('$fontDirPath/$fontName.zip');
    final ttfFile = File('$fontDirPath/$fontName.ttf');

    if (skipExist &&
        ((zipFile.existsSync() && zipFile.lengthSync() > 500) ||
         (ttfFile.existsSync() && ttfFile.lengthSync() > 1000))) {
      continue;
    }

    try {
      zipFile.writeAsBytesSync(Uint8List.fromList(entry.content as List<int>));
      written.add(pageNum);
    } catch (_) {}
  }

  return written;
}
