import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qcf_quran_plus/qcf_quran_plus.dart'
    show QuranPageView, HighlightVerse, getPageNumber, QcfFontLoader;
import 'package:qcf_quran_lite/qcf_quran_lite.dart' show getPageData;
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/services/qcf_font_download_service.dart';
import '../../../../core/services/font_download_manager.dart';
import 'qcf_fallback_page.dart';

import '../../../../core/audio/ayah_audio_cubit.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/surah_names.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/services/audio_edition_service.dart';
import '../../../../core/services/bookmark_service.dart';
import '../../../../core/services/offline_audio_service.dart';
import '../../../../core/services/tutorial_service.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../core/settings/app_settings_cubit.dart';
import '../../../wird/data/quran_boundaries.dart' show kSurahAyahCounts;
import '../../domain/entities/surah.dart';
import '../../../../core/utils/tajweed_parser.dart';
import '../bloc/tafsir/tafsir_cubit.dart';
import '../screens/tafsir_screen.dart';
import '../tutorials/mushaf_tutorial.dart';
import 'ayah_share_card.dart';
import 'islamic_audio_player.dart';
import 'hizb_banner.dart';
import '../../../../core/services/hizb_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Verse long-press options sheet
// ─────────────────────────────────────────────────────────────────────────────

void _showVerseOptionsSheet(
  BuildContext context, {
  required int surah,
  required int verse,
  required String surahName,
  required String arabicText,
  required String bookmarkId,
  required BookmarkService bookmarkService,
  required VoidCallback onTafsir,
}) {
  showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Ayah title
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text(
                  '$surahName — آية $verse',
                  style: GoogleFonts.arefRuqaa(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ),
              const Divider(height: 1),
              // Bookmark
              StatefulBuilder(
                builder: (_, setSt) {
                  final isBookmarked = bookmarkService.isBookmarked(bookmarkId);
                  return ListTile(
                    leading: Icon(
                      isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      isBookmarked ? 'إزالة الإشارة' : 'إضافة إشارة',
                      style: const TextStyle(fontSize: 15),
                    ),
                    onTap: () async {
                      if (isBookmarked) {
                        await bookmarkService.removeBookmark(bookmarkId);
                      } else {
                        await bookmarkService.addBookmark(
                          id: bookmarkId,
                          reference: '$surah:$verse',
                          arabicText: arabicText,
                          surahName: surahName,
                          surahNumber: surah,
                          ayahNumber: verse,
                        );
                      }
                      setSt(() {});
                    },
                  );
                },
              ),
              // Share as image (QCF Mushaf style)
              ListTile(
                leading: const Icon(
                  Icons.share_rounded,
                  color: AppColors.primary,
                ),
                title: const Text(
                  'مشاركة الآية',
                  style: TextStyle(fontSize: 15),
                ),
                subtitle: const Text(
                  'صورة بخط القرآن الكريم',
                  style: TextStyle(fontSize: 11),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  showAyahShareDialog(
                    context: context,
                    surahNumber: surah,
                    initialVerse: verse,
                    surahName: surahName,
                  );
                },
              ),
              // Tafsir
              ListTile(
                leading: const Icon(
                  Icons.menu_book_rounded,
                  color: AppColors.primary,
                ),
                title: const Text('التفسير', style: TextStyle(fontSize: 15)),
                onTap: () {
                  Navigator.pop(ctx);
                  onTafsir();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// MushafPageView
// ─────────────────────────────────────────────────────────────────────────────

class MushafPageView extends StatefulWidget {
  final Surah surah;
  final int? initialPage;
  final bool isArabicUi;
  final int surahNumber;
  final int? initialAyahNumber;

  /// Called when the user taps the next-surah transition button.
  final VoidCallback? onNextSurah;

  /// Called when the user taps the previous-surah transition button.
  final VoidCallback? onPreviousSurah;

  /// Called whenever the visible mushaf page number changes (1-based, 1-604).
  /// Used by the Wird screen to auto-save the reading page position.
  final void Function(int page)? onPageChanged;

  const MushafPageView({
    super.key,
    required this.surah,
    this.initialPage,
    required this.isArabicUi,
    required this.surahNumber,
    this.initialAyahNumber,
    this.onNextSurah,
    this.onPreviousSurah,
    this.onPageChanged,
  });

  @override
  State<MushafPageView> createState() => _MushafPageViewState();
}

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────

class _MushafPageViewState extends State<MushafPageView>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ValueNotifier<List<HighlightVerse>> _highlightsNotifier = ValueNotifier(
    [],
  );

  late PageController _pageController;
  late final BookmarkService _bookmarkService;

  late AnimationController _highlightAnimationController;

  // Mirrors the audio player's collapsed state so the page content
  // can shrink/grow to stay visible above the player.
  final ValueNotifier<bool> _playerCollapsed = ValueNotifier(true);

  // Navigation highlight (jumps to ayah) – separate from audio highlight.
  HighlightVerse? _navHighlight;

  // Audio highlight – updated by BlocListener whenever the cubit changes.
  HighlightVerse? _audioHighlight;

  bool _tutorialShown = false;
  late final int _startPage;

  // ── Tajweed mode ───────────────────────────────────────────────────────────
  late bool _tajweedMode;

  // Tracks the currently visible page number for the top bar / footer.
  late int _currentPageNum;

  // Tracks whether the QCF font for the current page is available on disk.
  bool _currentPageFontAvailable = true;

  // ── Controls visibility (auto-hide after 5 s) ─────────────────────────────
  bool _showControls = true;
  Timer? _hideTimer;

  // ── Hizb notification system ──────────────────────────────────────────────
  final _hizbService = HizbService();
  final _hizbBannerController = HizbBannerController();
  int? _lastShownHizbPage; // Prevent showing same notification twice

  // ── Init / dispose ─────────────────────────────────────────────────────────

  int _getStartPage() {
    if (widget.initialPage != null) return widget.initialPage!;
    try {
      return getPageNumber(widget.surahNumber, widget.initialAyahNumber ?? 1);
    } catch (_) {
      return getPageNumber(widget.surahNumber, 1);
    }
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _bookmarkService = di.sl<BookmarkService>();

    // Restore tajweed mode from persisted settings.
    _tajweedMode = context.read<AppSettingsCubit>().state.tajweedEnabled;

    _highlightAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    final startPage = _getStartPage();
    _startPage = startPage;
    _currentPageNum = startPage;
    _pageController = PageController(initialPage: startPage - 1);

    // Check font availability for the initial page and load from disk if needed.
    _checkAndLoadPageFont(startPage);

    // Listen to background download progress to auto-refresh when a font
    // for the current page finishes downloading.
    FontDownloadManager.instance.addListener(_onFontDownloadProgress);

    if (widget.initialAyahNumber != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _highlightAyah(widget.surahNumber, widget.initialAyahNumber!);
      });
    } else if (widget.initialPage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Highlight the first ayah on the target page.
        try {
          final ranges = getPageData(startPage);
          if (ranges.isNotEmpty) {
            final s = int.parse(ranges.first['surah'].toString());
            final v = int.parse(ranges.first['start'].toString());
            _highlightAyah(s, v);
          }
        } catch (_) {}
      });
    }

    // Tutorial trigger – fires once after the page tree has settled.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showTutorialIfNeeded();
      // Check if initial page starts a Hizb quarter
      _checkAndShowHizbBanner();
    });

    _resetHideTimer();
  }

  @override
  void dispose() {
    _hizbBannerController.dismiss();
    FontDownloadManager.instance.removeListener(_onFontDownloadProgress);
    _hideTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _highlightAnimationController.dispose();
    _pageController.dispose();
    _highlightsNotifier.dispose();
    _playerCollapsed.dispose();
    super.dispose();
  }

  /// Called whenever the background download makes progress.
  /// Only triggers a rebuild if the current page's font just became available.
  void _onFontDownloadProgress() {
    if (!mounted) return;
    final nowLoaded = QcfFontLoader.isFontLoaded(_currentPageNum);
    if (nowLoaded && !_currentPageFontAvailable) {
      setState(() => _currentPageFontAvailable = true);
    }
  }

  /// Checks whether [page]'s font is available on disk and, if so, loads it
  /// into the Flutter engine so [QuranPageView] can render with the QCF font
  /// instead of the fallback — all without requiring a restart.
  void _checkAndLoadPageFont(int page) {
    if (QcfFontLoader.isFontLoaded(page)) {
      if (!_currentPageFontAvailable) {
        setState(() => _currentPageFontAvailable = true);
      }
      return;
    }
    QcfFontDownloadService.isPageAvailable(page).then((onDisk) async {
      if (!mounted) return;
      if (onDisk) {
        // Font file exists on disk — load into engine, then refresh.
        try {
          await QcfFontLoader.ensureFontLoaded(page);
        } catch (_) {}
        if (mounted && _currentPageNum == page) {
          setState(() => _currentPageFontAvailable = true);
        }
      } else {
        // Font not on disk — show the download banner.
        if (mounted && _currentPageNum == page) {
          setState(() => _currentPageFontAvailable = false);
        }
      }
    });
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _onPageTap() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _resetHideTimer();
  }

  void _showTutorialIfNeeded() {
    if (_tutorialShown || !mounted) return;
    final svc = di.sl<TutorialService>();
    if (svc.isTutorialComplete(TutorialService.mushafScreen)) return;
    _tutorialShown = true;
    final settings = context.read<AppSettingsCubit>().state;
    MushafTutorial.show(
      context: context,
      tutorialService: svc,
      isArabic: widget.isArabicUi,
      isDark: settings.darkMode,
    );
  }

  // ── Tajweed helpers ────────────────────────────────────────────────────────

  void _toggleTajweed(int currentPage) {
    final newValue = !_tajweedMode;
    // If enabling tajweed but the current page font isn't loaded, warn user.
    if (newValue && !QcfFontLoader.isFontLoaded(currentPage)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'يجب تحميل خطوط المصحف لعرض ألوان التجويد',
            style: GoogleFonts.cairo(fontSize: 13),
            textDirection: TextDirection.rtl,
          ),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }
    setState(() => _tajweedMode = newValue);
    context.read<AppSettingsCubit>().setTajweedEnabled(newValue);
    if (newValue) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم تفعيل التجويد — اضغط مطولاً على زر التجويد لعرض دليل الألوان',
            style: GoogleFonts.cairo(fontSize: 12),
            textDirection: TextDirection.rtl,
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // ── Font download prompt ───────────────────────────────────────────────────

  /// Starts the background download. The banner widget listens to
  /// [FontDownloadManager] and updates itself automatically.
  void _startFontDownload() {
    FontDownloadManager.instance.startIfNeeded();
  }

  // ── Highlight helpers ──────────────────────────────────────────────────────

  void _updateHighlightsNotifier() {
    final list = <HighlightVerse>[];
    if (_audioHighlight != null) list.add(_audioHighlight!);
    if (_navHighlight != null) list.add(_navHighlight!);
    _highlightsNotifier.value = List.unmodifiable(list);
  }

  void _highlightAyah(int surah, int verse) {
    int page;
    try {
      page = getPageNumber(surah, verse);
    } catch (_) {
      return;
    }
    _navHighlight = HighlightVerse(
      surah: surah,
      verseNumber: verse,
      page: page,
      color: AppColors.secondary,
    );
    _updateHighlightsNotifier();
    _highlightAnimationController.forward(from: 0.0);

    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        _highlightAnimationController.reverse().then((_) {
          if (mounted) {
            _navHighlight = null;
            _updateHighlightsNotifier();
          }
        });
      }
    });
  }

  void _syncAudioHighlights(AyahAudioState state) {
    if (!state.hasTarget || state.status == AyahAudioStatus.idle) {
      if (_audioHighlight != null) {
        _audioHighlight = null;
        _updateHighlightsNotifier();
      }
      return;
    }
    int page;
    try {
      page = getPageNumber(state.surahNumber!, state.ayahNumber!);
    } catch (_) {
      return;
    }
    final color = state.status == AyahAudioStatus.playing
        ? AppColors.secondary
        : AppColors.primary;
    _audioHighlight = HighlightVerse(
      surah: state.surahNumber!,
      verseNumber: state.ayahNumber!,
      page: page,
      color: color,
    );
    _updateHighlightsNotifier();
  }

  void _handleDisplayedPageChanged(int page) {
    widget.onPageChanged?.call(page);
    if (mounted) {
      setState(() {
        _currentPageNum = page;
        // Optimistically assume loaded if already in engine.
        _currentPageFontAvailable = QcfFontLoader.isFontLoaded(page);
        _showControls = true;
      });
      _resetHideTimer();
      // Load from disk if available, or reveal the download banner if not.
      _checkAndLoadPageFont(page);
      // Show Hizb banner if this page starts a new quarter
      _checkAndShowHizbBanner();
    }
  }

  /// Check if current page starts a Hizb quarter and show banner
  void _checkAndShowHizbBanner() {
    final hizbInfo = _hizbService.getHizbInfoForPage(_currentPageNum);
    if (hizbInfo != null) {
      // Show banner if we're on a new Hizb page OR returning to a Hizb page from a non-Hizb page
      if (_lastShownHizbPage != _currentPageNum) {
        _lastShownHizbPage = _currentPageNum;
        _hizbBannerController.show(
          context: context,
          hizbInfo: hizbInfo,
          displayDuration: const Duration(milliseconds: 2500),
        );
      }
    } else {
      // Reset when leaving a Hizb page so banner shows again on return
      _lastShownHizbPage = null;
    }
  }

  void _onAyahTap(int surahNumber, int ayahNumber) {
    final cubit = context.read<AyahAudioCubit>();
    final audioState = cubit.state;
    final settings = context.read<AppSettingsCubit>().state;

    if (audioState.surahNumber == surahNumber &&
        audioState.ayahNumber == ayahNumber &&
        (audioState.status == AyahAudioStatus.playing ||
            audioState.status == AyahAudioStatus.paused)) {
      if (audioState.status == AyahAudioStatus.playing) {
        cubit.pause();
      } else {
        cubit.resume();
      }
      return;
    }

    if (settings.mushafContinueTilawa) {
      if (settings.mushafContinueScope == 'surah') {
        final idx = surahNumber - 1;
        final totalAyahs = idx >= 0 && idx < kSurahAyahCounts.length
            ? kSurahAyahCounts[idx]
            : ayahNumber;
        cubit.playAyahRange(
          surahNumber: surahNumber,
          startAyah: ayahNumber,
          endAyah: totalAyahs,
        );
      } else {
        final List rawRanges;
        try {
          rawRanges = getPageData(_currentPageNum);
        } catch (_) {
          cubit.togglePlayAyah(
            surahNumber: surahNumber,
            ayahNumber: ayahNumber,
          );
          return;
        }
        int endAyah = ayahNumber;
        for (final r in rawRanges) {
          final m = r as Map<dynamic, dynamic>;
          if (int.tryParse(m['surah'].toString()) == surahNumber) {
            endAyah = int.parse(m['end'].toString());
          }
        }
        cubit.playAyahRange(
          surahNumber: surahNumber,
          startAyah: ayahNumber,
          endAyah: endAyah,
        );
      }
    } else {
      cubit.togglePlayAyah(surahNumber: surahNumber, ayahNumber: ayahNumber);
    }
  }

  // ── Long-press → options sheet ────────────────────────────────────────────

  /// Long press → show options sheet (bookmark / share / tafsir).
  void _onLongPress(int surah, int verse) async {
    HapticFeedback.mediumImpact();

    // Load plain Arabic text from the offline asset bundle so the Tafsir
    // screen always receives proper Unicode text (not QCF-encoded glyph IDs).
    String arabicText = '';
    try {
      final raw = await rootBundle.loadString(
        'assets/offline/surah_$surah.json',
      );
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final ayahs = data['ayahs'] as List<dynamic>;
      for (final a in ayahs) {
        if ((a as Map<dynamic, dynamic>)['numberInSurah'] == verse) {
          arabicText = (a['text'] as String?) ?? '';
          break;
        }
      }
    } catch (_) {}

    if (!mounted) return;

    final surahName = SurahNames.getArabicName(surah);
    final surahNameEn = SurahNames.getEnglishName(surah);
    final bookmarkId = 'surah_${surah}_ayah_$verse';
    final capturedText = arabicText;

    // ignore: use_build_context_synchronously
    _showVerseOptionsSheet(
      context,
      surah: surah,
      verse: verse,
      surahName: surahName,
      arabicText: capturedText,
      bookmarkId: bookmarkId,
      bookmarkService: _bookmarkService,
      onTafsir: () {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BlocProvider(
              create: (_) => di.sl<TafsirCubit>(),
              child: TafsirScreen(
                surahNumber: surah,
                ayahNumber: verse,
                surahName: surahName,
                surahEnglishName: surahNameEn,
                arabicAyahText: capturedText,
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsCubit>().state;
    final isDark = settings.darkMode;

    // When the audio player is visible it overlays the bottom of the page.
    // We shrink the QuranPageView's Positioned area by the player's height so
    // the Quran text is never hidden under the player.
    final playerVisible = context.select<AyahAudioCubit, bool>(
      (c) => c.state.status != AyahAudioStatus.idle,
    );
    const double kPlayerHeight = 220.0;
    // kPlayerCollapsedHeight removed — minimized player now floats over content.

    final bgColor = isDark ? const Color(0xFF0E1A12) : const Color(0xFFFDF6E3);
    final textColor = isDark
        ? const Color(0xFFE8E8E8)
        : const Color(0xFF1A1A1A);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: BlocListener<AyahAudioCubit, AyahAudioState>(
        listener: (_, state) => _syncAudioHighlights(state),
        child: Scaffold(
          key: _scaffoldKey,
          body: SafeArea(
            bottom: false,
            top: false,
            child: Container(
              color: bgColor,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: IslamicPatternPainter(
                        color: isDark
                            ? const Color(0xFFC8A84B)
                            : AppColors.primary,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: BorderOrnamentPainter(
                        color: isDark
                            ? const Color(0xFFC8A84B)
                            : AppColors.primary,
                      ),
                    ),
                  ),
                  // ── Quran page – always fills the full body area ──────
                  // Using Positioned.fill guarantees the page occupies the
                  // entire available space regardless of any overlay widgets.
                  // When the audio player is visible, shrink from the bottom
                  // so the page content is never covered by the player.
                  ValueListenableBuilder<bool>(
                    valueListenable: _playerCollapsed,
                    builder: (ctx, isCollapsed, child) => Positioned.fill(
                      // When minimized the pill floats over the content.
                      // Only push content up when the full player is expanded.
                      bottom: playerVisible
                          ? (isCollapsed ? 0.0 : kPlayerHeight)
                          : 0.0,
                      child: GestureDetector(
                        onTap: _onPageTap,
                        behavior: HitTestBehavior.translucent,
                        child: Column(
                          children: [
                            AnimatedOpacity(
                              opacity: _showControls ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 300),
                              child: IgnorePointer(
                                ignoring: !_showControls,
                                child: Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: _buildTopBar(isDark, _currentPageNum),
                                ),
                              ),
                            ),
                            Expanded(
                              key: MushafTutorialKeys.quranPage,
                              child: Stack(
                                children: [
                                  ValueListenableBuilder<List<HighlightVerse>>(
                                    valueListenable: _highlightsNotifier,
                                    builder: (_, highlights, __) => QuranPageView(
                                      pageController: _pageController,
                                      highlights: highlights,
                                      isDarkMode: isDark,
                                      isTajweed: _tajweedMode,
                                      onPageChanged: _handleDisplayedPageChanged,
                                      onAyahTap: _onAyahTap,
                                      onLongPress: (surah, verse, details) =>
                                          _onLongPress(surah, verse),
                                      ayahStyle: TextStyle(color: textColor),
                                      fallbackPageBuilder: (ctx, pageNum) =>
                                          QcfFallbackPage(
                                            pageNumber: pageNum,
                                            isDarkMode: isDark,
                                          ),
                                    ),
                                  ),
                                  // ── Download-fonts banner (only when current page is fallback) ──
                                  if (!_currentPageFontAvailable)
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: _buildDownloadFontsBanner(isDark),
                                    ),
                                ],
                              ),
                            ),
                            AnimatedOpacity(
                              opacity: _showControls ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 300),
                              child: IgnorePointer(
                                ignoring: !_showControls,
                                child: Directionality(
                                  key: MushafTutorialKeys.pageFooter,
                                  textDirection: TextDirection.ltr,
                                  child: _buildDecorativeFooter(
                                    _currentPageNum,
                                    isDarkMode: isDark,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // ── Floating audio player ──────────────────────────────
                  // Positioned at the bottom so it never participates in
                  // layout and never compresses the Quran page above it.
                  // Returns SizedBox.shrink() when audio is idle.
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: IslamicAudioPlayer(
                      isArabicUi: widget.isArabicUi,
                      collapsedNotifier: _playerCollapsed,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageBookmarkButton(int pageNumber, {bool attachKey = false}) {
    // Resolve the actual surah that owns this page, which may differ from
    // widget.surahNumber when the user has navigated across surah boundaries.
    int actualSurahNumber = widget.surahNumber;
    String actualSurahName = widget.surah.name;
    try {
      final ranges = getPageData(pageNumber);
      if (ranges.isNotEmpty) {
        final m = ranges.first as Map<dynamic, dynamic>;
        actualSurahNumber = int.parse(m['surah'].toString());
        actualSurahName = SurahNames.getArabicName(actualSurahNumber);
      }
    } catch (_) {}

    final pageId = '$actualSurahNumber:page:$pageNumber';

    return StatefulBuilder(
      builder: (context, setLocalState) {
        final isBookmarked = _bookmarkService.isBookmarked(pageId);
        return IconButton(
          key: attachKey ? MushafTutorialKeys.bookmarkButton : null,
          onPressed: () {
            final isArabicUi = widget.isArabicUi;
            if (isBookmarked) {
              _bookmarkService.removeBookmark(pageId);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isArabicUi ? 'تم حذف الإشارة' : 'Bookmark removed',
                  ),
                  duration: const Duration(seconds: 1),
                ),
              );
            } else {
              _bookmarkService.addBookmark(
                id: pageId,
                reference: pageId,
                arabicText: 'صفحة $pageNumber',
                surahName: actualSurahName,
                surahNumber: actualSurahNumber,
                ayahNumber: null,
                pageNumber: pageNumber,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isArabicUi ? 'تمت إضافة إشارة' : 'Bookmark added',
                  ),
                  duration: const Duration(seconds: 1),
                ),
              );
            }
            setLocalState(() {});
          },
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
          iconSize: 22,
          icon: Icon(
            _bookmarkService.isBookmarked(pageId)
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            color: _kGoldText,
            size: 22,
          ),
          tooltip: widget.isArabicUi ? 'إشارة مرجعية' : 'Bookmark',
        );
      },
    );
  }

  Widget _buildPagePlayButton(int pageNumber, {bool attachKey = false}) {
    return BlocBuilder<AyahAudioCubit, AyahAudioState>(
      builder: (context, audioState) {
        // Cast to List<dynamic> so firstWhere's orElse type-checks correctly.
        final List rawRanges;
        try {
          rawRanges = getPageData(pageNumber);
        } catch (_) {
          return const SizedBox.shrink();
        }
        if (rawRanges.isEmpty) return const SizedBox.shrink();

        // Prefer the current widget's surah if it's on this page; fall back
        // to the first range. Use a plain loop to avoid firstWhere orElse
        // type issues with the runtime-typed List returned by getPageData().
        Map<dynamic, dynamic>? matched;
        for (final r in rawRanges) {
          final m = r as Map<dynamic, dynamic>;
          if (int.tryParse(m['surah'].toString()) == widget.surahNumber) {
            matched = m;
            break;
          }
        }
        final range = matched ?? (rawRanges.first as Map<dynamic, dynamic>);
        final surahNum = int.parse(range['surah'].toString());
        final startAyah = int.parse(range['start'].toString());
        final endAyah = int.parse(range['end'].toString());

        final isPageActive =
            audioState.surahNumber == surahNum &&
            audioState.ayahNumber != null &&
            audioState.ayahNumber! >= startAyah &&
            audioState.ayahNumber! <= endAyah;
        final isPagePlaying =
            isPageActive && audioState.status == AyahAudioStatus.playing;
        final isPagePaused =
            isPageActive && audioState.status == AyahAudioStatus.paused;

        // Premium golden circle play button
        final isActive = isPagePlaying || isPagePaused;
        return GestureDetector(
          key: attachKey ? MushafTutorialKeys.playButton : null,
          onTap: () {
            if (isPagePlaying) {
              context.read<AyahAudioCubit>().pause();
            } else if (isPagePaused) {
              context.read<AyahAudioCubit>().resume();
            } else {
              context.read<AyahAudioCubit>().playAyahRange(
                surahNumber: surahNum,
                startAyah: startAyah,
                endAyah: endAyah,
              );
            }
          },
          child: Tooltip(
            message: widget.isArabicUi ? 'تشغيل الصفحة' : 'Play page',
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive
                      ? _kGoldText
                      : _kGoldText.withValues(alpha: 0.55),
                  width: 1.5,
                ),
                color: isActive
                    ? _kGoldText.withValues(alpha: 0.12)
                    : Colors.transparent,
              ),
              child: Center(
                child: Icon(
                  isPagePlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: isActive
                      ? _kGoldText
                      : _kGoldText.withValues(alpha: 0.7),
                  size: 20,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecitationSettingsButton(bool isDark) {
    return IconButton(
      onPressed: () => _showMushafRecitationSettings(context),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 36),
      iconSize: 18,
      icon: Icon(
        Icons.tune_rounded,
        color: _kGoldText.withValues(alpha: 0.65),
        size: 18,
      ),
      tooltip: 'إعدادات التلاوة',
    );
  }

  void _showMushafRecitationSettings(BuildContext ctx) {
    showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: ctx.read<AppSettingsCubit>(),
        child: _MushafQcfRecitationSheet(isAr: widget.isArabicUi),
      ),
    );
  }

  // ── Decorative widgets ─────────────────────────────────────────────────────

  // ── Juz approximation (standard 20-page/juz Medina layout) ──────────────
  int _juzForPage(int page) => ((page - 1) ~/ 20).clamp(0, 29) + 1;

  static const _kJuzNames = [
    'الأول',
    'الثاني',
    'الثالث',
    'الرابع',
    'الخامس',
    'السادس',
    'السابع',
    'الثامن',
    'التاسع',
    'العاشر',
    'الحادي عشر',
    'الثاني عشر',
    'الثالث عشر',
    'الرابع عشر',
    'الخامس عشر',
    'السادس عشر',
    'السابع عشر',
    'الثامن عشر',
    'التاسع عشر',
    'العشرون',
    'الحادي والعشرون',
    'الثاني والعشرون',
    'الثالث والعشرون',
    'الرابع والعشرون',
    'الخامس والعشرون',
    'السادس والعشرون',
    'السابع والعشرون',
    'الثامن والعشرون',
    'التاسع والعشرون',
    'الثلاثون',
  ];

  String _juzName(int juz) =>
      juz >= 1 && juz <= 30 ? _kJuzNames[juz - 1] : _toArabicNumerals(juz);

  String _pageLabel(int page) {
    try {
      final ranges = getPageData(page);
      if (ranges.isNotEmpty) {
        final m = ranges.first as Map<dynamic, dynamic>;
        return SurahNames.getArabicName(int.parse(m['surah'].toString()));
      }
    } catch (_) {}
    return widget.surah.name;
  }

  // ── Premium Mushaf color constants ─────────────────────────────────────
  static const _kBarTealLight = Color(0xFF3C9A80);
  static const _kBarTealDark = Color(0xFF2A7F6B);
  static const _kBarTealDarkModeLight = Color(0xFF1A5244);
  static const _kBarTealDarkModeDark = Color(0xFF133D31);
  static const _kGoldText = Color(0xFFEDE3B7);
  static const _kGoldBorder = Color(0xFFE6D9A8);

  Widget _buildTopBar(bool isDark, int pageNumber) {
    final isInitialPage = pageNumber == _startPage;
    final topInset = MediaQuery.of(context).padding.top;

    final gradientStart = isDark ? _kBarTealDarkModeLight : _kBarTealLight;
    final gradientEnd = isDark ? _kBarTealDarkModeDark : _kBarTealDark;
    final goldColor = _kGoldText;
    final goldBorder = _kGoldBorder.withValues(alpha: 0.28);
    final ornamentColor = goldColor.withValues(alpha: 0.50);

    final labelStyle = GoogleFonts.arefRuqaa(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: goldColor,
    );

    return Container(
      key: isInitialPage ? MushafTutorialKeys.topBar : null,
      padding: EdgeInsets.fromLTRB(10, topInset*0.5, 10, 0),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [gradientStart, gradientEnd],
        ),
        border: Border.all(color: goldBorder, width: 0.7),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      foregroundDecoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.5,
          colors: [
            Color(0x1FEDE3B7), // subtle golden centre glow
            Colors.transparent,
          ],
        ),
      ),
      child: SizedBox(
        height: 50,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildPagePlayButton(pageNumber, attachKey: isInitialPage),
            const SizedBox(width: 6),
            _buildRecitationSettingsButton(isDark),
            const SizedBox(width: 8),
            Text(
              'الجزء ${_juzName(_juzForPage(pageNumber))}',
              style: labelStyle,
              textDirection: TextDirection.rtl,
            ),
            Expanded(
              child: Center(
                child: Text(
                  '',
                  style: TextStyle(
                    color: ornamentColor,
                    fontSize: 16,
                    height: 1,
                  ),
                ),
              ),
            ),
            Text(
              _pageLabel(pageNumber),
              style: labelStyle,
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(width: 8),
            _buildTajweedToggle(isDark, pageNumber),
            const SizedBox(width: 4),
            _buildPageBookmarkButton(pageNumber, attachKey: isInitialPage),
          ],
        ),
      ),
    );
  }

  /// Compact banner shown when the current page's QCF font is not yet loaded.
  /// Adapts its content based on the global [FontDownloadManager] state:
  ///   • downloading → live progress bar + percentage
  ///   • error       → error message + retry button
  ///   • idle        → prompt with a download button
  Widget _buildDownloadFontsBanner(bool isDark) {
    final bg = isDark
        ? const Color(0xFF1E2E22).withValues(alpha: 0.97)
        : const Color(0xFFFFF8E1).withValues(alpha: 0.97);
    final borderColor = isDark
        ? const Color(0xFF4CAF50).withValues(alpha: 0.4)
        : AppColors.primary.withValues(alpha: 0.3);

    return ListenableBuilder(
      listenable: FontDownloadManager.instance,
      builder: (context, _) {
        final mgr = FontDownloadManager.instance;
        final textCol =
            isDark ? const Color(0xFFFFE082) : const Color(0xFF7B4F00);
        final accentCol = isDark ? const Color(0xFF4CAF50) : AppColors.primary;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            decoration: BoxDecoration(
              color: bg,
              border: Border(
                top: BorderSide(color: borderColor, width: 0.8),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: mgr.isDownloading
                ? _buildProgressContent(textCol, accentCol, mgr)
                : mgr.hasError
                    ? _buildErrorContent(textCol, accentCol)
                    : _buildIdleContent(textCol, accentCol),
          ),
        );
      },
    );
  }

  /// Banner content while download is running — shows phase + progress bar.
  Widget _buildProgressContent(
      Color textCol, Color accentCol, FontDownloadManager mgr) {
    final percent = (mgr.progress * 100).clamp(0, 100).round();
    final label = mgr.phase.isNotEmpty ? mgr.phase : 'جارٍ تحميل خطوط المصحف…';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: accentCol,
                value: mgr.progress > 0 ? mgr.progress : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.cairo(
                    fontSize: 10,
                    color: textCol,
                    fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              '$percent٪',
              style: GoogleFonts.cairo(
                  fontSize: 10,
                  color: accentCol,
                  fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: mgr.progress > 0 ? mgr.progress : null,
            backgroundColor: accentCol.withValues(alpha: 0.18),
            valueColor: AlwaysStoppedAnimation<Color>(accentCol),
            minHeight: 3,
          ),
        ),
        if (mgr.totalPending > 0 && mgr.pagesDownloaded > 0) ...[
          const SizedBox(height: 3),
          Text(
            '${mgr.pagesDownloaded} / ${mgr.totalPending} صفحة',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
                fontSize: 9, color: textCol.withValues(alpha: 0.7)),
          ),
        ],
      ],
    );
  }

  /// Banner content after a download error.
  Widget _buildErrorContent(Color textCol, Color accentCol) {
    return Row(
      children: [
        Icon(Icons.wifi_off_rounded,
            size: 15, color: Colors.redAccent.shade100),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'فشل التحميل — تحقق من الاتصال',
            style: GoogleFonts.cairo(
                fontSize: 10,
                color: Colors.redAccent.shade100,
                fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: FontDownloadManager.instance.retry,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.redAccent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'إعادة المحاولة',
              style: GoogleFonts.cairo(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  /// Banner content when no download is running yet.
  Widget _buildIdleContent(Color textCol, Color accentCol) {
    return Row(
      children: [
        Icon(Icons.download_for_offline_rounded, size: 16, color: accentCol),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'خطوط المصحف غير مُحمَّلة',
            style: GoogleFonts.cairo(
                fontSize: 10,
                color: textCol,
                fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: _startFontDownload,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: accentCol,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'تحميل',
              style: GoogleFonts.cairo(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTajweedToggle(bool isDark, int pageNumber) {
    if (!SettingsService.enableTajweedFeature) return const SizedBox.shrink();

    final activeColor = const Color(0xFFB8E6C8); // Soft mint — visible on teal
    final inactiveColor = _kGoldText.withValues(alpha: 0.5);
    return GestureDetector(
      onTap: () => _toggleTajweed(pageNumber),
      onLongPress: () => _showTajweedLegend(isDark),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: _tajweedMode
              ? activeColor.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _tajweedMode
                ? activeColor.withValues(alpha: 0.6)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.palette_rounded,
              size: 14,
              color: _tajweedMode ? activeColor : inactiveColor,
            ),
            const SizedBox(width: 3),
            Text(
              'تجويد',
              style: GoogleFonts.arefRuqaa(
                fontSize: 10,
                fontWeight: _tajweedMode ? FontWeight.w700 : FontWeight.w500,
                color: _tajweedMode ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTajweedLegend(bool isDark) {
    final colorMap = isDark ? kTajweedColorsDark : kTajweedColorsLight;
    final bg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final subColor = textColor.withValues(alpha: 0.55);
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);
    final linkColor = isDark ? const Color(0xFF80CBC4) : AppColors.primary;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: bg,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (_, scrollCtrl) => SafeArea(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                children: [
                  // ── Handle ──────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        Text(
                          'دليل ألوان التجويد',
                          style: GoogleFonts.arefRuqaa(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'اضغط مطولاً على زر التجويد لعرض هذا الدليل',
                          style: GoogleFonts.cairo(
                            fontSize: 10,
                            color: subColor,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Divider(color: dividerColor, height: 1),
                      ],
                    ),
                  ),
                  // ── Rules list ──────────────────────────────────────
                  Expanded(
                    child: ListView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      children: [
                        ...kLegendRules.map((rule) {
                          final color = colorMap[rule]!;
                          final name = kTajweedRuleNamesAr[rule] ?? '';
                          final desc = kTajweedRuleDescriptionsAr[rule] ?? '';
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  margin: const EdgeInsets.only(top: 2),
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: GoogleFonts.arefRuqaa(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: textColor,
                                        ),
                                      ),
                                      if (desc.isNotEmpty)
                                        Text(
                                          desc,
                                          style: GoogleFonts.cairo(
                                            fontSize: 10,
                                            color: subColor,
                                            height: 1.45,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        // ── Divider ────────────────────────────────────
                        const SizedBox(height: 6),
                        Divider(color: dividerColor, height: 1),
                        const SizedBox(height: 10),
                        // ── Resource links ─────────────────────────────
                        Text(
                          'تعلّم التجويد',
                          style: GoogleFonts.arefRuqaa(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _TajweedLinkRow(
                          icon: Icons.language_rounded,
                          label: 'دليل ألوان التجويد — alquran.cloud',
                          url: 'https://alquran.cloud/tajweed-guide',
                          color: linkColor,
                          textColor: textColor,
                        ),
                        const SizedBox(height: 6),
                        _TajweedLinkRow(
                          icon: Icons.play_circle_outline_rounded,
                          label: 'دروس التجويد (يوتيوب)',
                          url:
                              'https://www.youtube.com/results?search_query=%D8%AF%D8%B1%D9%88%D8%B3+%D8%A7%D9%84%D8%AA%D8%AC%D9%88%D9%8A%D8%AF+%D9%84%D9%84%D9%85%D8%A8%D8%AA%D8%AF%D8%A6%D9%8A%D9%86',
                          color: const Color(0xFFE53935),
                          textColor: textColor,
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDecorativeFooter(int pageNumber, {required bool isDarkMode}) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    const tealL = Color(0xFF2A7F6B);
    const tealBot = Color(0xFF3C9A80);
    const darkL = Color(0xFF1A5244);
    const darkD = Color(0xFF133D31);
    const borderCol = Color(0xFFE6D9A8);
    const textCol = Color(0xFFF5E6B5);

    final barTop = isDarkMode ? darkD : tealL;
    final barBot = isDarkMode ? darkL : tealBot;
// متعدلش اي حاجة هنا في الويدجت كلها 
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [barTop, barBot],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SizedBox(
        height: 30,
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(
                'assets/logo/files/page_number.png',
                width: 180,
                height: 23,
                color: borderCol,
                colorBlendMode: BlendMode.srcIn,
                fit: BoxFit.fill,
              ),

              Positioned(
                bottom: 5,
                child: Text(
                  _toArabicNumerals(pageNumber),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.arefRuqaa(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: textCol,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Ornament helpers ───────────────────────────────────────────────────────

  String _toArabicNumerals(int number) {
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return number
        .toString()
        .split('')
        .map((d) => int.tryParse(d) != null ? arabicDigits[int.parse(d)] : d)
        .join();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom Painters
// ─────────────────────────────────────────────────────────────────────────────

class IslamicPatternPainter extends CustomPainter {
  final Color color;
  IslamicPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.015)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const patternSize = 40.0;
    for (double x = 0; x < size.width; x += patternSize) {
      for (double y = 0; y < size.height; y += patternSize) {
        final path = Path()
          ..moveTo(x + patternSize / 2, y)
          ..lineTo(x + patternSize, y + patternSize / 2)
          ..lineTo(x + patternSize / 2, y + patternSize)
          ..lineTo(x, y + patternSize / 2)
          ..close();
        canvas.drawPath(path, paint);
        canvas.drawCircle(
          Offset(x + patternSize / 2, y + patternSize / 2),
          patternSize / 4,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class BorderOrnamentPainter extends CustomPainter {
  final Color color;
  BorderOrnamentPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokeColor = color.withValues(alpha: 0.12);
    final outerPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final innerPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    final fillPaint = Paint()
      ..color = strokeColor.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;

    const margin = 9.0;
    const innerMargin = 14.0;

    // Horizontal lines only (top + bottom) — vertical sides removed
    canvas.drawLine(
      Offset(margin, margin),
      Offset(size.width - margin, margin),
      outerPaint,
    );
    canvas.drawLine(
      Offset(margin, size.height - margin),
      Offset(size.width - margin, size.height - margin),
      outerPaint,
    );
    canvas.drawLine(
      Offset(innerMargin, innerMargin),
      Offset(size.width - innerMargin, innerMargin),
      innerPaint,
    );
    canvas.drawLine(
      Offset(innerMargin, size.height - innerMargin),
      Offset(size.width - innerMargin, size.height - innerMargin),
      innerPaint,
    );

    // Medallion ornaments at every corner
    const medallionR = 14.0;
    final corners = [
      Offset(margin, margin),
      Offset(size.width - margin, margin),
      Offset(margin, size.height - margin),
      Offset(size.width - margin, size.height - margin),
    ];
    for (final c in corners) {
      _drawMedallion(canvas, c, medallionR, outerPaint, innerPaint, fillPaint);
    }
  }

  /// Draws a circular medallion with an 8-pointed star — classical Islamic manuscript style.
  void _drawMedallion(
    Canvas canvas,
    Offset center,
    double r,
    Paint outer,
    Paint inner,
    Paint fill,
  ) {
    // Filled background circle
    canvas.drawCircle(center, r, fill);
    // Outer ring
    canvas.drawCircle(center, r, outer);
    // Inner ring
    canvas.drawCircle(center, r * 0.55, inner);

    // 8-pointed star (alternating long/short ray tips)
    final starPath = Path();
    const n = 8;
    for (int i = 0; i < n; i++) {
      final outerAngle = i * math.pi * 2 / n - math.pi / 2;
      final innerAngle = outerAngle + math.pi / n;
      final ox = center.dx + math.cos(outerAngle) * r * 0.85;
      final oy = center.dy + math.sin(outerAngle) * r * 0.85;
      final ix = center.dx + math.cos(innerAngle) * r * 0.42;
      final iy = center.dy + math.sin(innerAngle) * r * 0.42;
      if (i == 0) {
        starPath.moveTo(ox, oy);
      } else {
        starPath.lineTo(ox, oy);
      }
      starPath.lineTo(ix, iy);
    }
    starPath.close();
    canvas.drawPath(starPath, inner);

    // Central dot
    canvas.drawCircle(center, r * 0.18, outer);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Tajweed legend resource link row ────────────────────────────────────────

class _TajweedLinkRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String url;
  final Color color;
  final Color textColor;

  const _TajweedLinkRow({
    required this.icon,
    required this.label,
    required this.url,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.open_in_new_rounded,
              size: 14,
              color: color.withValues(alpha: 0.65),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Recitation settings sheet (QCF Mushaf) ──────────────────────────────────

class _MushafQcfRecitationSheet extends StatefulWidget {
  final bool isAr;
  const _MushafQcfRecitationSheet({required this.isAr});

  @override
  State<_MushafQcfRecitationSheet> createState() =>
      _MushafQcfRecitationSheetState();
}

class _MushafQcfRecitationSheetState extends State<_MushafQcfRecitationSheet> {
  late final OfflineAudioService _offlineAudio;
  late final AudioEditionService _editionService;
  late Future<List<AudioEdition>> _editionsFuture;

  @override
  void initState() {
    super.initState();
    _offlineAudio = di.sl<OfflineAudioService>();
    _editionService = di.sl<AudioEditionService>();
    _editionsFuture = _editionService.getVerseByVerseAudioEditions();
  }

  Future<void> _showReciterPicker(
    BuildContext ctx,
    List<AudioEdition> all,
    String currentEdition,
  ) async {
    await showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QcfReciterPickerSheet(
        all: all,
        currentEdition: currentEdition,
        isAr: widget.isAr,
        onSelected: (identifier) async {
          await _offlineAudio.setEdition(identifier);
          if (ctx.mounted) {
            try {
              ctx.read<AyahAudioCubit>().stop();
            } catch (_) {}
            setState(() {
              _editionsFuture = _editionService.getVerseByVerseAudioEditions();
            });
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppSettingsCubit, AppSettingsState>(
      builder: (ctx, settings) {
        final isDark = settings.darkMode;
        final bg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
        final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
        final subTextColor = isDark
            ? Colors.white.withValues(alpha: 0.55)
            : Colors.black.withValues(alpha: 0.45);
        final dividerColor = isDark
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.black.withValues(alpha: 0.08);
        final titleStyle = GoogleFonts.arefRuqaa(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: textColor,
        );
        final labelStyle = GoogleFonts.arefRuqaa(
          fontSize: 14,
          color: textColor,
        );
        final noteStyle = GoogleFonts.arefRuqaa(
          fontSize: 11,
          color: subTextColor,
        );

        return SafeArea(
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Container(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'إعدادات التلاوة',
                    style: titleStyle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Divider(color: dividerColor, height: 1),
                  const SizedBox(height: 12),

                  // ── القارئ ──────────────────────────────────────────────────
                  FutureBuilder<List<AudioEdition>>(
                    future: _editionsFuture,
                    builder: (ctx, snap) {
                      final currentId = _offlineAudio.edition;
                      final edition = snap.data
                          ?.where((e) => e.identifier == currentId)
                          .cast<AudioEdition?>()
                          .firstOrNull;
                      final name =
                          edition?.displayNameForAppLanguage(
                            widget.isAr ? 'ar' : 'en',
                          ) ??
                          currentId;
                      return Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('القارئ', style: labelStyle),
                                Text(
                                  name,
                                  style: labelStyle.copyWith(
                                    color: subTextColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: snap.hasData
                                ? () => _showReciterPicker(
                                    ctx,
                                    snap.data!,
                                    _offlineAudio.edition,
                                  )
                                : null,
                            child: Text(
                              'تغيير',
                              style: GoogleFonts.arefRuqaa(
                                color: AppColors.secondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Divider(color: dividerColor, height: 1),
                  const SizedBox(height: 12),

                  // ── تلاوة كلمة بكلمة ────────────────────────────────────────
                  Builder(
                    builder: (context) {
                      final wordByWordEnabled =
                          settings.useUthmaniScript && !settings.useQcfFont;
                      return Opacity(
                        opacity: wordByWordEnabled ? 1.0 : 0.45,
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('تلاوة كلمة بكلمة', style: labelStyle),
                                  Text(
                                    wordByWordEnabled
                                        ? 'اضغط على كلمة لتسمعها'
                                        : (settings.useQcfFont
                                              ? 'يتطلب إيقاف رسم المصحف QCF'
                                              : 'يتطلب تفعيل عرض المصحف الشريف'),
                                    style: noteStyle,
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value:
                                  wordByWordEnabled && settings.wordByWordAudio,
                              onChanged: wordByWordEnabled
                                  ? (v) => ctx
                                        .read<AppSettingsCubit>()
                                        .setWordByWordAudio(v)
                                  : null,
                              activeColor: AppColors.secondary,
                              inactiveThumbColor: isDark
                                  ? Colors.white.withValues(alpha: 0.55)
                                  : Colors.grey.shade400,
                              inactiveTrackColor: isDark
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : Colors.grey.shade300,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Divider(color: dividerColor, height: 1),
                  const SizedBox(height: 12),

                  // ── تكملة التلاوة ──────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'تكملة التلاوة عند الضغط',
                          style: labelStyle,
                        ),
                      ),
                      Switch(
                        value: settings.mushafContinueTilawa,
                        onChanged: (v) => ctx
                            .read<AppSettingsCubit>()
                            .setMushafContinueTilawa(v),
                        activeColor: AppColors.secondary,
                        inactiveThumbColor: isDark
                            ? Colors.white.withValues(alpha: 0.55)
                            : Colors.grey.shade400,
                        inactiveTrackColor: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.grey.shade300,
                      ),
                    ],
                  ),
                  if (settings.mushafContinueTilawa) ...[
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: [
                        ButtonSegment(
                          value: 'page',
                          label: Text(
                            'إلى نهاية الصفحة',
                            style: GoogleFonts.arefRuqaa(fontSize: 12),
                          ),
                        ),
                        ButtonSegment(
                          value: 'surah',
                          label: Text(
                            'إلى نهاية السورة',
                            style: GoogleFonts.arefRuqaa(fontSize: 12),
                          ),
                        ),
                      ],
                      selected: {settings.mushafContinueScope},
                      onSelectionChanged: (s) => ctx
                          .read<AppSettingsCubit>()
                          .setMushafContinueScope(s.first),
                      style: ButtonStyle(
                        foregroundColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected)
                              ? (isDark ? Colors.white : AppColors.primary)
                              : textColor.withValues(alpha: 0.65),
                        ),
                        backgroundColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected)
                              ? AppColors.primary.withValues(
                                  alpha: isDark ? 0.30 : 0.12,
                                )
                              : Colors.transparent,
                        ),
                        side: WidgetStateProperty.all(
                          BorderSide(color: dividerColor, width: 0.8),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _QcfReciterPickerSheet extends StatefulWidget {
  final List<AudioEdition> all;
  final String currentEdition;
  final bool isAr;
  final Future<void> Function(String identifier) onSelected;

  const _QcfReciterPickerSheet({
    required this.all,
    required this.currentEdition,
    required this.isAr,
    required this.onSelected,
  });

  @override
  State<_QcfReciterPickerSheet> createState() => _QcfReciterPickerSheetState();
}

class _QcfReciterPickerSheetState extends State<_QcfReciterPickerSheet> {
  late String _selected;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selected = widget.currentEdition;
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final surfaceColor = isDark
        ? const Color(0xFF2C2C2E)
        : const Color(0xFFF5F5F5);
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final subtleColor = isDark
        ? Colors.white.withValues(alpha: 0.40)
        : Colors.black.withValues(alpha: 0.35);
    const accent = AppColors.secondary;

    final arReciters = widget.all.where((e) => e.language == 'ar').toList();
    final others = widget.all.where((e) => e.language != 'ar').toList();
    final all = [...arReciters, ...others];

    final filtered = _query.isEmpty
        ? all
        : all.where((e) {
            final name = e
                .displayNameForAppLanguage(widget.isAr ? 'ar' : 'en')
                .toLowerCase();
            return name.contains(_query);
          }).toList();

    return SafeArea(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.18)
                      : Colors.black.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.record_voice_over_rounded,
                        color: accent,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'اختر القارئ',
                      style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${all.length} قارئ',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: subtleColor,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: TextField(
                  controller: _searchController,
                  textDirection: TextDirection.rtl,
                  style: GoogleFonts.cairo(fontSize: 13, color: textColor),
                  decoration: InputDecoration(
                    hintText: 'ابحث عن قارئ…',
                    hintStyle: GoogleFonts.cairo(
                      fontSize: 13,
                      color: subtleColor,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: subtleColor,
                      size: 20,
                    ),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: subtleColor,
                            ),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    filled: true,
                    fillColor: surfaceColor,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Divider(
                height: 1,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.50,
                ),
                child: filtered.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'لا توجد نتائج',
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            color: subtleColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 4),
                        itemBuilder: (ctx, i) {
                          final e = filtered[i];
                          final name = e.displayNameForAppLanguage(
                            widget.isAr ? 'ar' : 'en',
                          );
                          final isSelected = e.identifier == _selected;
                          return Material(
                            color: isSelected
                                ? accent.withValues(alpha: 0.10)
                                : surfaceColor,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () async {
                                setState(() => _selected = e.identifier);
                                await widget.onSelected(e.identifier);
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 11,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: GoogleFonts.cairo(
                                          fontSize: 13.5,
                                          color: isSelected
                                              ? accent
                                              : textColor,
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Container(
                                        width: 22,
                                        height: 22,
                                        decoration: const BoxDecoration(
                                          color: accent,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.check_rounded,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
