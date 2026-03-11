import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qcf_quran/qcf_quran.dart';

import '../../../../core/audio/ayah_audio_cubit.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/surah_names.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/services/bookmark_service.dart';
import '../../../../core/settings/app_settings_cubit.dart';
import '../../domain/entities/surah.dart';
import '../bloc/tafsir/tafsir_cubit.dart';
import '../screens/tafsir_screen.dart';
import 'app_qcf_page.dart';
import 'ayah_share_card.dart';
import 'qcf_fallback_page.dart';
import 'islamic_audio_player.dart';

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
                  style: GoogleFonts.amiriQuran(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ),
              const Divider(height: 1),
              // Bookmark
              StatefulBuilder(builder: (_, setSt) {
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
                        id:          bookmarkId,
                        reference:   '$surah:$verse',
                        arabicText:  arabicText,
                        surahName:   surahName,
                        surahNumber: surah,
                        ayahNumber:  verse,
                      );
                    }
                    setSt(() {});
                  },
                );
              }),
              // Share as image (QCF Mushaf style)
              ListTile(
                leading: const Icon(Icons.share_rounded, color: AppColors.primary),
                title: const Text('مشاركة الآية', style: TextStyle(fontSize: 15)),
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
                leading: const Icon(Icons.menu_book_rounded, color: AppColors.primary),
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

  const MushafPageView({
    super.key,
    required this.surah,
    this.initialPage,
    required this.isArabicUi,
    required this.surahNumber,
    this.initialAyahNumber,
    this.onNextSurah,
    this.onPreviousSurah,
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
  final ValueNotifier<List<_HighlightVerse>> _highlightsNotifier =
      ValueNotifier([]);

  late PageController _pageController;
  late final BookmarkService _bookmarkService;

  late AnimationController _highlightAnimationController;

  // Mirrors the audio player's collapsed state so the page content
  // can shrink/grow to stay visible above the player.
  final ValueNotifier<bool> _playerCollapsed = ValueNotifier(true);

  // Navigation highlight (jumps to ayah) – separate from audio highlight.
  _HighlightVerse? _navHighlight;

  // Audio highlight – updated by BlocListener whenever the cubit changes.
  _HighlightVerse? _audioHighlight;

  // Verse that the user's finger is currently pressing (set on pointer-down,
  // before the gesture arena resolves). Used to identify the correct verse
  // when a long-press fires, since QcfPage can't expose both onTap and
  // onLongPress simultaneously on the same TextSpan recognizer.
  int? _tapDownSurah;
  int? _tapDownVerse;

  // ── Init / dispose ─────────────────────────────────────────────────────────

  int _getStartPage() {
    if (widget.initialPage != null) return widget.initialPage!;
    try {
      return getPageNumber(
        widget.surahNumber,
        widget.initialAyahNumber ?? 1,
      );
    } catch (_) {
      return getPageNumber(widget.surahNumber, 1);
    }
  }

  @override
  void initState() {
    super.initState();
    _bookmarkService = di.sl<BookmarkService>();

    _highlightAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    final startPage = _getStartPage();
    _pageController = PageController(initialPage: startPage - 1);

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
  }

  @override
  void dispose() {
    _highlightAnimationController.dispose();
    _pageController.dispose();
    _highlightsNotifier.dispose();
    _playerCollapsed.dispose();
    super.dispose();
  }

  // ── Highlight helpers ──────────────────────────────────────────────────────

  void _updateHighlightsNotifier() {
    final list = <_HighlightVerse>[];
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
    _navHighlight = _HighlightVerse(
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
    _audioHighlight = _HighlightVerse(
      surah: state.surahNumber!,
      verseNumber: state.ayahNumber!,
      page: page,
      color: color,
    );
    _updateHighlightsNotifier();
  }

  // ── Long-press → options sheet ────────────────────────────────────────────

  /// Single tap → play the tapped ayah (or toggle play/pause if already playing).
  void _onTap(int surah, int verse) {
    HapticFeedback.selectionClick();
    final cubit = context.read<AyahAudioCubit>();
    final state = cubit.state;
    if (state.isCurrent(surah, verse)) {
      // Already playing/paused this ayah – toggle.
      if (state.status == AyahAudioStatus.playing) {
        cubit.pause();
      } else if (state.status == AyahAudioStatus.paused) {
        cubit.resume();
      } else {
        cubit.playAyah(surahNumber: surah, ayahNumber: verse);
      }
    } else {
      cubit.playAyah(surahNumber: surah, ayahNumber: verse);
    }
    // Highlight the tapped ayah.
    _highlightAyah(surah, verse);
  }

  /// Long press → show options sheet (bookmark / share / tafsir).
  void _onLongPress(int surah, int verse) async {
    HapticFeedback.mediumImpact();

    // Load plain Arabic text from the offline asset bundle so the Tafsir
    // screen always receives proper Unicode text (not QCF-encoded glyph IDs).
    String arabicText = '';
    try {
      final raw = await rootBundle
          .loadString('assets/offline/surah_$surah.json');
      final data  = jsonDecode(raw) as Map<String, dynamic>;
      final ayahs = data['ayahs'] as List<dynamic>;
      for (final a in ayahs) {
        if ((a as Map<dynamic, dynamic>)['numberInSurah'] == verse) {
          arabicText = (a['text'] as String?) ?? '';
          break;
        }
      }
    } catch (_) {}

    if (!mounted) return;

    final surahName      = SurahNames.getArabicName(surah);
    final surahNameEn    = SurahNames.getEnglishName(surah);
    final bookmarkId     = 'surah_${surah}_ayah_$verse';
    final capturedText   = arabicText;

    // ignore: use_build_context_synchronously
    _showVerseOptionsSheet(
      context,
      surah:           surah,
      verse:           verse,
      surahName:       surahName,
      arabicText:      capturedText,
      bookmarkId:      bookmarkId,
      bookmarkService: _bookmarkService,
      onTafsir: () {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BlocProvider(
              create: (_) => di.sl<TafsirCubit>(),
              child: TafsirScreen(
                surahNumber:      surah,
                ayahNumber:       verse,
                surahName:        surahName,
                surahEnglishName: surahNameEn,
                arabicAyahText:   capturedText,
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

    final bgColor =
        isDark ? const Color(0xFF0E1A12) : const Color(0xFFFFF9ED);
    final textColor =
        isDark ? const Color(0xFFE8E8E8) : const Color(0xFF1A1A1A);

    return BlocListener<AyahAudioCubit, AyahAudioState>(
      listener: (_, state) => _syncAudioHighlights(state),
      child: Scaffold(
        key: _scaffoldKey,
        body: SafeArea(
          bottom: false,
          child: Container(
          color: bgColor,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: IslamicPatternPainter(
                    color: isDark ? const Color(0xFFC8A84B) : AppColors.primary,
                  ),
                ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: BorderOrnamentPainter(
                    color: isDark ? const Color(0xFFC8A84B) : AppColors.primary,
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
                  child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: 604,
                    itemBuilder: (ctx, index) {
                      final pageNum = index + 1;
                      // Use regular-font fallback for pages whose QCF glyph
                      // calibration is known to overflow the container.
                      if (kEnableQcfFallback &&
                          kQcfProblematicPages.contains(pageNum)) {
                        return QcfFallbackPage(
                          key: ValueKey('fb_$pageNum'),
                          pageNumber: pageNum,
                        );
                      }
                      return Column(
                        children: [
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: _buildTopBar(isDark, pageNum),
                          ),
                          Expanded(
                            child: GestureDetector(
                              // Page-level long press → show options sheet for
                              // the verse the user's finger is touching.
                              // _tapDownSurah/_tapDownVerse are set by QcfPage's
                              // onTapDown which fires on pointer-down (before
                              // the gesture arena resolves), so the correct verse
                              // is always known by the time onLongPress fires.
                              onLongPress: () {
                                int? s, v;
                                if (_tapDownSurah != null && _tapDownVerse != null) {
                                  // Primary source: the verse the finger is on.
                                  s = _tapDownSurah;
                                  v = _tapDownVerse;
                                } else if (_audioHighlight != null) {
                                  s = _audioHighlight!.surah;
                                  v = _audioHighlight!.verseNumber;
                                } else if (_navHighlight != null) {
                                  s = _navHighlight!.surah;
                                  v = _navHighlight!.verseNumber;
                                } else {
                                  // Last resort: first verse on the page.
                                  try {
                                    final ranges = getPageData(pageNum);
                                    if (ranges.isNotEmpty) {
                                      final r = ranges.first as Map;
                                      s = int.parse(r['surah'].toString());
                                      v = int.parse(r['start'].toString());
                                    }
                                  } catch (_) {}
                                }
                                if (s != null && v != null) _onLongPress(s, v);
                              },
                              child: ValueListenableBuilder<List<_HighlightVerse>>(
                                valueListenable: _highlightsNotifier,
                                builder: (_, highlights, child) =>
                                    LayoutBuilder(
                                  builder: (lbCtx, constraints) {
                                  // Use the same formula as the reference app
                                  // (flutter_screenutil 1.sp / 1.h):
                                  //   sp = screenWidth  / designWidth
                                  //   h  = screenHeight / designHeight
                                  // Using full MediaQuery dimensions (not
                                  // constraints) intentionally matches the
                                  // reference app and makes the 15-line grid
                                  // fill the visible page naturally.
                                  const double kDesignWidth  = 392.72727272727275;
                                  const double kDesignHeight = 800.7272727272727;
                                    final Size screen = MediaQuery.of(lbCtx).size;
                                  final double effectiveWidth =
                                      constraints.maxWidth.isFinite && constraints.maxWidth > 0
                                          ? constraints.maxWidth
                                          : screen.width;
                                  // ---------- sp / font-size safety explanation ----------
                                  // The qcf_quran package calibrates its page fonts for a
                                  // reference device of ≈393 dp width.  Some pages (e.g.
                                  // 387, 504, 579 …) were accidentally omitted from
                                  // getFontSize()'s special-case list and get the default
                                  // 23.1 px, which is too large – their QCF glyphs were
                                  // designed for a slightly smaller size.  On a 393 dp
                                  // phone sp ≈ 1.0 so capping at 1.0 does nothing; the
                                  // overflow is baked into the font calibration itself.
                                  //
                                  // Fix: add a 20 dp safety margin to the design width
                                  // denominator. This gives sp ≈ 0.952 on a 393 dp phone,
                                  // reducing every font size by ~4.8 %.  Lines that exactly
                                  // filled the container now span ~374 dp and sit centred
                                  // with 9-10 dp breathing room each side – visually
                                  // identical to a printed Mushaf page which also has
                                  // slight margins.  For tablets (≥ 600 dp) getFontSize
                                  // already returns 15 and needs sp > 1, so the margin is
                                  // not applied there.
                                  const double kSafeMargin = 20.0;
                                  final bool isPhone = effectiveWidth < 600;
                                  final double rawSp = effectiveWidth /
                                      (isPhone ? kDesignWidth + kSafeMargin : kDesignWidth);
                                  final double sp = rawSp;
                                  final double h  = screen.height / kDesignHeight;
                                    // Wrap in MediaQuery to neutralise the
                                    // system font-size setting (the user may
                                    // have Samsung font set to Large/Huge).
                                    // Without this, Flutter applies the system
                                    // textScaler to the QCF font, making every
                                    // line wider than the container and
                                    // clipping the first (rightmost) character.
                                    return MediaQuery(
                                      data: MediaQuery.of(lbCtx).copyWith(
                                        textScaler: TextScaler.linear(1.0),
                                      ),
                                      child: AppQcfPage(
                                      pageNumber: pageNum,
                                      sp: sp,
                                      h: h,
                                      theme: QcfThemeData(
                                        verseTextColor: textColor,
                                        pageBackgroundColor: Colors.transparent,
                                        basmalaColor: textColor,
                                        customHeaderBuilder: (surahNum) =>
                                            _buildSurahHeader(surahNum, isDark),
                                      ),
                                      verseBackgroundColor: (surah, verse) {
                                        for (final h in highlights) {
                                          if (h.surah == surah &&
                                              h.verseNumber == verse) {
                                            return h.color
                                                .withValues(alpha: 0.3);
                                          }
                                        }
                                        return null;
                                      },
                                      onTap: _onTap,
                                      onTapDown: (s, v, _) {
                                        _tapDownSurah = s;
                                        _tapDownVerse = v;
                                      },
                                    ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: _buildDecorativeFooter(pageNum,
                                isDarkMode: isDark),
                          ),
                        ],
                      );
                    },
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
    );
  }

  /// Surah header that supports both light and dark modes.
  /// In dark mode the cream banner image is tinted to blend with the dark background.
  Widget _buildSurahHeader(int surahNumber, bool isDark) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final isPortrait =
            MediaQuery.of(ctx).orientation == Orientation.portrait;
        final headerWidth =
            isPortrait ? constraints.maxWidth * 0.95 : constraints.maxWidth * 0.8;
        final fontSize =
            isPortrait ? headerWidth * 0.075 : constraints.maxWidth * 0.05;
        final nameColor =
            isDark ? const Color(0xFFE8C46A) : const Color(0xFF3D2000);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // In dark mode: use BlendMode.color to recolor the cream image
              // with the app's dark-green hue while preserving all ornamental
              // detail (luminance). This keeps the flower patterns and borders
              // clearly visible instead of blending into blackness.
              Image.asset(
                'assets/mainframe.png',
                package: 'qcf_quran',
                width: headerWidth,
                fit: BoxFit.contain,
                color: isDark ? const Color.fromARGB(255, 43, 63, 48) : null,
                colorBlendMode: isDark ? BlendMode.color : null,
              ),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  text: 'surah${surahNumber.toString().padLeft(3, '0')}',
                  style: TextStyle(
                    fontFamily: SurahFontHelper.fontFamily,
                    package: 'qcf_quran',
                    fontSize: fontSize,
                    color: nameColor,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPageBookmarkButton(int pageNumber) {
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
          onPressed: () {
            final isArabicUi = widget.isArabicUi;
            if (isBookmarked) {
              _bookmarkService.removeBookmark(pageId);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                    isArabicUi ? 'تم حذف الإشارة' : 'Bookmark removed'),
                duration: const Duration(seconds: 1),
              ));
            } else {
              _bookmarkService.addBookmark(
                id: pageId,
                reference: pageId,
                arabicText: 'صفحة $pageNumber',
                surahName: actualSurahName,
                surahNumber: actualSurahNumber,
                ayahNumber: null,
              );
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                    isArabicUi ? 'تمت إضافة إشارة' : 'Bookmark added'),
                duration: const Duration(seconds: 1),
              ));
            }
            setLocalState(() {});
          },
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          iconSize: 20,
          icon: Icon(
            _bookmarkService.isBookmarked(pageId)
                ? Icons.bookmark
                : Icons.bookmark_border,
            color: AppColors.secondary,
            size: 20,
          ),
          tooltip: widget.isArabicUi ? 'إشارة مرجعية' : 'Bookmark',
        );
      },
    );
  }

  Widget _buildPagePlayButton(int pageNumber) {
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

        return IconButton(
          onPressed: () {
            final cubit = context.read<AyahAudioCubit>();
            if (isPagePlaying) {
              cubit.pause();
            } else if (isPagePaused) {
              cubit.resume();
            } else {
              cubit.playAyahRange(
                surahNumber: surahNum,
                startAyah: startAyah,
                endAyah: endAyah,
              );
            }
          },
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          iconSize: 20,
          icon: Icon(
            isPagePlaying ? Icons.pause_circle : Icons.play_circle,
            color: (isPagePlaying || isPagePaused)
                ? AppColors.secondary
                : AppColors.primary.withValues(alpha: 0.6),
            size: 20,
          ),
          tooltip: widget.isArabicUi ? 'تشغيل الصفحة' : 'Play page',
        );
      },
    );
  }

  // ── Decorative widgets ─────────────────────────────────────────────────────

  // ── Juz approximation (standard 20-page/juz Medina layout) ──────────────
  int _juzForPage(int page) =>
      ((page - 1) ~/ 20).clamp(0, 29) + 1;

  static const _kJuzNames = [
    'الأول', 'الثاني', 'الثالث', 'الرابع', 'الخامس',
    'السادس', 'السابع', 'الثامن', 'التاسع', 'العاشر',
    'الحادي عشر', 'الثاني عشر', 'الثالث عشر', 'الرابع عشر', 'الخامس عشر',
    'السادس عشر', 'السابع عشر', 'الثامن عشر', 'التاسع عشر', 'العشرون',
    'الحادي والعشرون', 'الثاني والعشرون', 'الثالث والعشرون', 'الرابع والعشرون', 'الخامس والعشرون',
    'السادس والعشرون', 'السابع والعشرون', 'الثامن والعشرون', 'التاسع والعشرون', 'الثلاثون',
  ];

  String _juzName(int juz) =>
      juz >= 1 && juz <= 30 ? _kJuzNames[juz - 1] : _toArabicNumerals(juz);

  String _pageLabel(int page) {
    try {
      final ranges = getPageData(page);
      if (ranges.isNotEmpty) {
        final m = ranges.first as Map<dynamic, dynamic>;
        return SurahNames.getArabicName(
            int.parse(m['surah'].toString()));
      }
    } catch (_) {}
    return widget.surah.name;
  }

  Widget _buildTopBar(bool isDark, int pageNumber) {
    final textColor = isDark
        ? Colors.white.withValues(alpha: 0.88)
        : const Color(0xFF3D1C00);
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.18)
        : const Color(0xFFC8A84B).withValues(alpha: 0.55);
    final labelStyle = GoogleFonts.amiriQuran(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: textColor,
    );
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: dividerColor, width: 0.8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildPagePlayButton(pageNumber),
          Text(
            'الجزء ${_juzName(_juzForPage(pageNumber))}',
            style: labelStyle,
            textDirection: TextDirection.rtl,
          ),
          Expanded(
            child: Center(
              child: Text(
                '❧',
                style: TextStyle(
                    color: dividerColor, fontSize: 14, height: 1),
              ),
            ),
          ),
          Text(
            _pageLabel(pageNumber),
            style: labelStyle,
            textDirection: TextDirection.rtl,
          ),
          _buildPageBookmarkButton(pageNumber),
        ],
      ),
    );
  }

  Widget _buildDecorativeFooter(int pageNumber, {required bool isDarkMode}) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final dividerColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.18)
        : const Color(0xFFC8A84B).withValues(alpha: 0.55);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 24,
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: dividerColor, width: 0.8)),
          ),
          alignment: Alignment.center,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(
                'assets/logo/files/transparent/label.png',
                height: 18,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.80)
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(0,0,0,2)
                ,
                // TODO: consider adding a subtle drop shadow to the text in light mode for better contrast against the decorative background.
                child: Text(
                  _toArabicNumerals(pageNumber),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.amiriQuran(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDarkMode ? Colors.white : const Color(0xFF3D1C00),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (bottomInset > 0) SizedBox(height: bottomInset),
      ],
    );
  }

  // ── Ornament helpers ───────────────────────────────────────────────────────

  String _toArabicNumerals(int number) {
    const arabicDigits = [
      '٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'
    ];
    return number
        .toString()
        .split('')
        .map((d) => int.tryParse(d) != null ? arabicDigits[int.parse(d)] : d)
        .join();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Local verse-highlight model (replaces qcf_quran_lite's HighlightVerse)
// ─────────────────────────────────────────────────────────────────────────────

class _HighlightVerse {
  final int surah;
  final int verseNumber;
  final int page;
  final Color color;

  const _HighlightVerse({
    required this.surah,
    required this.verseNumber,
    required this.page,
    required this.color,
  });
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
      ..color = color.withValues(alpha: 0.03)
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
    final strokeColor = color.withValues(alpha: 0.30);
    final outerPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final innerPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    final fillPaint = Paint()
      ..color = strokeColor.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    const margin = 9.0;
    const innerMargin = 14.0;

    // Horizontal lines only (top + bottom) — vertical sides removed
    canvas.drawLine(Offset(margin, margin), Offset(size.width - margin, margin), outerPaint);
    canvas.drawLine(Offset(margin, size.height - margin), Offset(size.width - margin, size.height - margin), outerPaint);
    canvas.drawLine(Offset(innerMargin, innerMargin), Offset(size.width - innerMargin, innerMargin), innerPaint);
    canvas.drawLine(Offset(innerMargin, size.height - innerMargin), Offset(size.width - innerMargin, size.height - innerMargin), innerPaint);

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
  void _drawMedallion(Canvas canvas, Offset center, double r, Paint outer,
      Paint inner, Paint fill) {
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
