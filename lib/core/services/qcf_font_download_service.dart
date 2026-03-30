import 'dart:io';
import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Smart selection of pages bundled inside the APK (local fork of qcf_quran_plus).
///
/// Strategy — 66 pages covering:
///   • Al-Fatiha + Al-Baqarah opening (1-4)
///   • Juz boundary pages (22, 62, 81, 100 … 281) — one page per Juz 2–15
///   • Ayat al-Kursi area (42-44)
///   • Al-Baqarah last verses (49-50)
///   • Al-Kahf full (293-297)
///   • Yasin full (440-444)
///   • Al-Rahman (531-533), Al-Waqiah (534-536)
///   • Al-Hashr last 3 verses (548-549)
///   • Al-Mulk (562-564)
///   • Full Juz Amma (582-604)
class _BundledPages {
  static const Set<int> pages = {
    // Al-Fatiha + Al-Baqarah opening
    1, 2, 3, 4,
    // Juz 2 midpoint (Al-Baqarah cont.)
    22,
    // Ayat al-Kursi (Al-Baqarah 255+)
    42, 43, 44,
    // Al-Baqarah last 2 ayahs (285-286)
    49, 50,
    // Juz boundary pages (one per juz, 4–15)
    62, 81, 100, 121, 141, 161, 181, 201, 221, 241, 261, 281,
    // Al-Kahf (important for Fridays)
    293, 294, 295, 296, 297,
    // Yasin
    440, 441, 442, 443, 444,
    // Al-Rahman
    531, 532, 533,
    // Al-Waqiah
    534, 535, 536,
    // Al-Hashr last verses
    548, 549,
    // Al-Mulk
    562, 563, 564,
    // Full Juz Amma
    582, 583, 584, 585, 586, 587, 588, 589, 590, 591, 592,
    593, 594, 595, 596, 597, 598, 599, 600, 601, 602, 603, 604,
  };

  static bool isBundled(int page) => pages.contains(page);
}

/// Downloads all remaining QCF tajweed fonts by fetching the official pub.dev
/// package archive (`qcf_quran_plus-0.0.7.tar.gz`), extracting each font ZIP
/// from the tarball, and persisting the TTF files to the same disk path that
/// [QcfFontLoader] checks first — so it uses cached files on all future launches.
///
/// No external hosting is required; pub.dev is used as the CDN.
class QcfFontDownloadService {
  QcfFontDownloadService._();

  static const String _prefKey = 'qcf_fonts_fully_downloaded';
  static const int _totalPages = 604;

  /// Official pub.dev archive for qcf_quran_plus 0.0.7.
  static const String _archiveUrl =
      'https://pub.dev/api/archives/qcf_quran_plus-0.0.7.tar.gz';

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 5),
      followRedirects: true,
      maxRedirects: 5,
    ),
  );

  // ── Public API ─────────────────────────────────────────────────────────────

  /// [true] when all 604 fonts are available (bundled or previously downloaded).
  static Future<bool> isFullyDownloaded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefKey) == true) {
      // Double-check disk in case storage was cleared after install.
      final dir = await _getFontDirectory();
      int count = 0;
      for (int i = 1; i <= _totalPages; i++) {
        if (_BundledPages.isBundled(i)) {
          count++;
          continue;
        }
        final file = File('${dir.path}/${_getFontName(i)}.ttf');
        if (file.existsSync() && file.lengthSync() > 1000) count++;
      }
      if (count == _totalPages) return true;
      // Storage was cleared — reset flag and re-download.
      await prefs.remove(_prefKey);
      return false;
    }
    return false;
  }

  /// [true] if the font for [pageNumber] is bundled or already on disk.
  static Future<bool> isPageAvailable(int pageNumber) async {
    if (_BundledPages.isBundled(pageNumber)) return true;
    final dir = await _getFontDirectory();
    final file = File('${dir.path}/${_getFontName(pageNumber)}.ttf');
    return file.existsSync() && file.lengthSync() > 1000;
  }

  /// How many non-bundled pages still need downloading.
  static Future<int> pendingDownloadCount() async {
    final dir = await _getFontDirectory();
    int pending = 0;
    for (int i = 1; i <= _totalPages; i++) {
      if (_BundledPages.isBundled(i)) continue;
      final file = File('${dir.path}/${_getFontName(i)}.ttf');
      if (!file.existsSync() || file.lengthSync() <= 1000) pending++;
    }
    return pending;
  }

  /// Downloads the pub.dev package archive and extracts all non-bundled fonts.
  ///
  /// [onProgress]   — 0.0 → 0.6 during HTTP download, 0.6 → 1.0 during extraction.
  /// [onPhase]      — called with a human-readable Arabic phase label.
  /// [onPageDone]   — called after each **newly** extracted page font is saved.
  /// [skipExisting] — when true, pages already on disk are skipped (enables resume).
  ///
  /// Returns [true] on full success.
  static Future<bool> downloadAll({
    void Function(double progress)? onProgress,
    void Function(String phase)? onPhase,
    void Function(int page)? onPageDone,
    CancelToken? cancelToken,
    bool skipExisting = false,
  }) async {
    final fontDir = await _getFontDirectory();
    final tmpDir = await getTemporaryDirectory();
    final archiveFile = File('${tmpDir.path}/qcf_fonts_pkg.tar.gz');

    try {
      // ── Phase 1: Download archive ──────────────────────────────────────
      onPhase?.call('جارٍ تحميل ملف الخطوط…');
      await _dio.download(
        _archiveUrl,
        archiveFile.path,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) onProgress?.call(received / total * 0.6);
        },
      );

      // ── Phase 2: Extract fonts from tar.gz ────────────────────────────
      onPhase?.call('جارٍ استخراج الخطوط…');
      onProgress?.call(0.6);

      final archiveBytes = await archiveFile.readAsBytes();
      final tarBytes = GZipDecoder().decodeBytes(archiveBytes);
      final archive = TarDecoder().decodeBytes(tarBytes);

      final fontPattern =
          RegExp(r'qcf_tajweed/(QCF4_tajweed_(\d{3}))\.zip$');
      final fontEntries =
          archive.files.where((f) => fontPattern.hasMatch(f.name)).toList();

      int processed = 0;
      for (final entry in fontEntries) {
        if (cancelToken?.isCancelled == true) break;

        final match = fontPattern.firstMatch(entry.name)!;
        final fontName = match.group(1)!;
        final pageNum = int.parse(match.group(2)!);

        if (!_BundledPages.isBundled(pageNum)) {
          // Skip pages already on disk when resume mode is enabled.
          final ttfFile = File('${fontDir.path}/$fontName.ttf');
          if (skipExisting &&
              ttfFile.existsSync() &&
              ttfFile.lengthSync() > 1000) {
            // Page already downloaded — count in progress but don't callback.
            processed++;
            onProgress?.call(0.6 + processed / fontEntries.length * 0.4);
            continue;
          }

          try {
            final zipBytes =
                Uint8List.fromList(entry.content as List<int>);
            final ttfBytes = await compute(_extractFont, zipBytes);
            await ttfFile.writeAsBytes(ttfBytes, flush: true);
            onPageDone?.call(pageNum);
          } catch (e) {
            debugPrint('QcfFontDownloadService: skip page $pageNum – $e');
          }
        }

        processed++;
        onProgress?.call(0.6 + processed / fontEntries.length * 0.4);
      }

      final remaining = await pendingDownloadCount();
      if (remaining == 0) {
        await _markComplete();
      }
      onProgress?.call(1.0);
      return remaining == 0;
    } catch (e) {
      debugPrint('QcfFontDownloadService: download failed – $e');
      return false;
    } finally {
      try {
        if (archiveFile.existsSync()) await archiveFile.delete();
      } catch (_) {}
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  static Future<Directory> _getFontDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final fontDir = Directory('${appDir.path}/qcf_fonts');
    if (!fontDir.existsSync()) fontDir.createSync(recursive: true);
    return fontDir;
  }

  static String _getFontName(int page) =>
      'QCF4_tajweed_${page.toString().padLeft(3, '0')}';

  static Uint8List _extractFont(Uint8List zipBytes) {
    final archive = ZipDecoder().decodeBytes(zipBytes);
    for (final file in archive) {
      if (file.name.endsWith('.ttf')) {
        return Uint8List.fromList(file.content as List<int>);
      }
    }
    throw Exception('QcfFontDownloadService: TTF not found in ZIP');
  }

  static Future<void> _markComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
  }
}
