import 'dart:io';
import 'dart:isolate';
import 'package:flutter/services.dart';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';

/// Defines how fonts are stored and loaded
enum FontStorageMode {
  /// Stores extracted fonts permanently on disk (best performance)
  permanentDisk,

  /// Keeps fonts only in RAM (no storage usage, slower startup)
  memoryOnly,
}

class QcfFontLoader {
  /// Prevent duplicate loading for same page
  static final Map<int, Future<void>> _loadingTasks = {};

  /// Tracks already loaded fonts in engine
  static final Set<int> _loadedPages = {};

  /// Current storage mode
  static FontStorageMode _currentMode = FontStorageMode.permanentDisk;

  /// Total Quran pages
  static const int totalPages = 604;

  /// Pages loaded on startup for fast UX

  /// ================= INITIALIZATION =================
  /// Initializes fonts with fast startup strategy:
  /// - Loads only first pages immediately
  /// - Loads remaining fonts in background
  /// ================= INITIALIZATION =================
  static Future<void> setupFontsAtStartup({
    required Function(double progress) onProgress,
    FontStorageMode mode = FontStorageMode.permanentDisk,
  }) async {
    _currentMode = mode;

    Directory? fontDir;
    if (_currentMode == FontStorageMode.permanentDisk) {
      fontDir = await _getFontDirectory();
    }

    int existingFontsCount = 0;
    if (fontDir != null) {
      for (int i = 1; i <= totalPages; i++) {
        final fontName = _getFontName(i);
        // Count both new ZIP format and legacy TTF format.
        final zipFile = File('${fontDir.path}/$fontName.zip');
        final ttfFile = File('${fontDir.path}/$fontName.ttf');
        if ((zipFile.existsSync() && zipFile.lengthSync() > 500) ||
            (ttfFile.existsSync() && ttfFile.lengthSync() > 1000)) {
          existingFontsCount++;
        }
      }
    }

    if (existingFontsCount == totalPages) {
      const int batchSize = 50;

      for (int i = 1; i <= totalPages; i += batchSize) {
        int end = (i + batchSize - 1 < totalPages)
            ? i + batchSize - 1
            : totalPages;

        List<Future<void>> batchTasks = [];
        for (int j = i; j <= end; j++) {
          batchTasks.add(ensureFontLoaded(j));
        }

        await Future.wait(batchTasks);
        onProgress(end / totalPages);
      }
    } else {
      for (int i = 1; i <= totalPages; i++) {
        await ensureFontLoaded(i);
        onProgress(i / totalPages);
      }
    }
  }

  /// ================= STORAGE =================
  /// Returns directory where fonts are stored
  static Future<Directory> _getFontDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final fontDir = Directory('${dir.path}/qcf_fonts');

    if (!fontDir.existsSync()) {
      fontDir.createSync(recursive: true);
    }
    return fontDir;
  }

  /// ================= PUBLIC METHODS =================
  /// Ensures font is loaded once (safe for multiple calls)
  static Future<void> ensureFontLoaded(int pageNumber) {
    if (_loadedPages.contains(pageNumber)) return Future.value();

    if (_loadingTasks.containsKey(pageNumber)) {
      return _loadingTasks[pageNumber]!;
    }

    final task = _loadFontInternal(pageNumber);

    _loadingTasks[pageNumber] = task;

    task
        .then((_) {
          _loadedPages.add(pageNumber);
        })
        .whenComplete(() {
          _loadingTasks.remove(pageNumber);
        });

    return task;
  }

  /// Checks if font is already loaded
  static bool isFontLoaded(int pageNumber) {
    return _loadedPages.contains(pageNumber);
  }

  /// ================= SMART PRELOADING =================
  /// Preloads nearby pages for smooth scrolling
  static Future<void> preloadPages(int currentPage, {int radius = 5}) async {
    List<int> pages = [];

    for (int i = 0; i <= radius; i++) {
      if (i == 0) {
        pages.add(currentPage);
      } else {
        int next = currentPage + i;
        int prev = currentPage - i;

        if (next <= totalPages) {
          pages.add(next);
        }
        if (prev >= 1) {
          pages.add(prev);
        }
      }
    }

    for (int page in pages) {
      if (_loadedPages.contains(page) || _loadingTasks.containsKey(page))
        continue;

      await ensureFontLoaded(page);

      /// Small delay for smoother scrolling
      await Future.delayed(const Duration(milliseconds: 16));
    }
  }

  /// ================= CORE LOADING =================
  /// Loads font — checks disk (ZIP then TTF) then falls back to bundled asset.
  ///
  /// Priority order (permanentDisk mode):
  ///   1. ZIP on disk  (~104KB, new format) → decompress in Isolate to memory
  ///   2. TTF on disk  (~269KB, legacy format) → read directly (backward compat)
  ///   3. ZIP in assets (bundled pages only) → decompress + write TTF to disk
  static Future<void> _loadFontInternal(int pageNumber) async {
    final fontName = _getFontName(pageNumber);
    Uint8List? fontBytes;

    if (_currentMode == FontStorageMode.permanentDisk) {
      final fontDir = await _getFontDirectory();

      // Case 1: ZIP on disk (new compressed format — ~104KB each).
      final zipFile = File('${fontDir.path}/$fontName.zip');
      if (zipFile.existsSync() && zipFile.lengthSync() > 500) {
        try {
          final zipBytes = await zipFile.readAsBytes();
          fontBytes = await Isolate.run(() => _extractFont(zipBytes));
        } catch (_) {
          // ZIP corrupt or unreadable — fall through to TTF check.
        }
      }

      // Case 2: TTF on disk (legacy uncompressed format — backward compat).
      if (fontBytes == null) {
        final ttfFile = File('${fontDir.path}/$fontName.ttf');
        if (ttfFile.existsSync() && ttfFile.lengthSync() > 1000) {
          fontBytes = await ttfFile.readAsBytes();
        }
      }

      // Case 3: Neither on disk — load ZIP from bundled assets (9 bundled pages).
      // Writes TTF to disk so subsequent launches read from disk (Case 2).
      if (fontBytes == null) {
        final assetZipBytes = await _loadZip(fontName);
        final ttfFile = File('${fontDir.path}/$fontName.ttf');
        fontBytes = await Isolate.run(() {
          final extracted = _extractFont(assetZipBytes);
          ttfFile.parent.createSync(recursive: true);
          ttfFile.writeAsBytesSync(extracted, flush: true);
          return extracted;
        });
      }
    } else {
      /// Memory-only mode: extract directly from bundled asset
      final zipBytes = await _loadZip(fontName);
      fontBytes = await Isolate.run(() => _extractFont(zipBytes));
    }

    /// Register font dynamically in Flutter engine
    final loader = FontLoader(fontName);
    loader.addFont(Future.value(ByteData.view(fontBytes!.buffer)));
    await loader.load();
  }

  /// ================= HELPERS =================
  /// Ensures font file exists on disk (background preparation)
  static Future<void> _prepareFontFileIfNeeded(
      int page, Directory? dir) async {
    if (_currentMode != FontStorageMode.permanentDisk) return;

    final fontName = _getFontName(page);

    // Already present as ZIP (new format) — nothing to do.
    final zipFile = File('${dir!.path}/$fontName.zip');
    if (zipFile.existsSync() && zipFile.lengthSync() > 500) return;

    // Already present as TTF (legacy format) — nothing to do.
    final ttfFile = File('${dir.path}/$fontName.ttf');
    if (ttfFile.existsSync() && ttfFile.lengthSync() > 1000) return;

    // Fall back to bundled asset ZIP.
    final assetZipBytes = await _loadZip(fontName);
    final extracted = await Isolate.run(() => _extractFont(assetZipBytes));
    await ttfFile.writeAsBytes(extracted, flush: true);
  }

  /// Loads zipped font from assets
  static Future<Uint8List> _loadZip(String fontName) async {
    final data = await rootBundle.load(
      'packages/qcf_quran_plus/assets/fonts/qcf_tajweed/$fontName.zip',
    );
    return data.buffer.asUint8List();
  }

  /// Generates font name based on page number
  static String _getFontName(int page) {
    return 'QCF4_tajweed_${page.toString().padLeft(3, '0')}';
  }

  /// Extracts TTF font from ZIP archive
  static Uint8List _extractFont(Uint8List zipBytes) {
    final archive = ZipDecoder().decodeBytes(zipBytes);
    for (final file in archive) {
      if (file.name.endsWith('.ttf')) {
        return Uint8List.fromList(file.content as List<int>);
      }
    }
    throw Exception("Font not found in archive");
  }
}
