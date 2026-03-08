import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qcf_quran_lite/qcf_quran_lite.dart' hide Surah;

import '../../../../core/audio/ayah_audio_cubit.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/surah_names.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/services/bookmark_service.dart';
import '../../../../core/settings/app_settings_cubit.dart';
import '../../domain/entities/surah.dart';
import '../bloc/tafsir/tafsir_cubit.dart';
import '../screens/tafsir_screen.dart';
import 'islamic_audio_player.dart';

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
  final ValueNotifier<List<HighlightVerse>> _highlightsNotifier =
      ValueNotifier([]);

  late PageController _pageController;
  late final BookmarkService _bookmarkService;

  late AnimationController _highlightAnimationController;

  // 1-based mushaf page currently visible – tracked via onPageChanged.
  int _currentPage = 1;

  // Mirrors the audio player's collapsed state so the page content
  // can shrink/grow to stay visible above the player.
  final ValueNotifier<bool> _playerCollapsed = ValueNotifier(true);

  // Navigation highlight (jumps to ayah) – separate from audio highlight.
  HighlightVerse? _navHighlight;

  // Audio highlight – updated by BlocListener whenever the cubit changes.
  HighlightVerse? _audioHighlight;

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
    _currentPage = startPage;
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

  // ── Long-press → Tafsir ────────────────────────────────────────────────────

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

  /// Long press → open tafsir for the tapped ayah.
  void _onLongPress(int surah, int verse, LongPressStartDetails _) async {
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
    // ignore: use_build_context_synchronously
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => di.sl<TafsirCubit>(),
          child: TafsirScreen(
            surahNumber: surah,
            ayahNumber: verse,
            surahName: SurahNames.getArabicName(surah),
            surahEnglishName: SurahNames.getEnglishName(surah),
            arabicAyahText: arabicText,
          ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsCubit>().state;
    final isDark = settings.darkMode;
    final isAr = widget.isArabicUi;

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
        appBar: AppBar(
          title: Text(
            isAr ? widget.surah.name : widget.surah.englishName,
            style: GoogleFonts.amiriQuran(
                fontSize: 20, fontWeight: FontWeight.w700),
          ),
          centerTitle: true,
          actions: [
            // Bookmark + Play for the current page
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPageBookmarkButton(_currentPage),
                _buildPagePlayButton(_currentPage),
              ],
            ),
          ],
        ),
        body: Container(
          color: bgColor,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: IslamicPatternPainter(color: AppColors.primary),
                ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: BorderOrnamentPainter(color: AppColors.primary),
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
                  child: QuranPageView(
                  pageController: _pageController,
                  scaffoldKey: _scaffoldKey,
                  highlightsNotifier: _highlightsNotifier,
                  onTap: _onTap,
                  onLongPress: _onLongPress,
                  pageBackgroundColor: Colors.transparent,
                  onPageChanged: (pageNum) {
                    if (mounted) setState(() => _currentPage = pageNum);
                  },
                  // Only pass color – not fontSize. The QCF FittedBox
                  // scales every line to fill the page width uniformly;
                  // overriding fontSize here would produce inconsistent
                  // word/character sizes between lines.
                  ayahStyle: TextStyle(color: textColor),
                  basmallahBuilder: (context, surahNumber) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                    child: Text(
                      'بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ',
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: GoogleFonts.amiriQuran(
                        fontSize: 26,
                        color: textColor,
                        height: 2.0,
                      ),
                    ),
                  ),
                  topBar: _buildTopBar(isDark),
                  bottomBar: _buildDecorativeFooter(
                      _currentPage, isDarkMode: isDark),
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
    );
  }

  // ── AppBar action buttons ──────────────────────────────────────────────────

  Widget _buildPageBookmarkButton(int pageNumber) {
    final pageId = '${widget.surahNumber}:page:$pageNumber';

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
                surahName: widget.surah.name,
                surahNumber: widget.surahNumber,
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
          icon: Icon(
            _bookmarkService.isBookmarked(pageId)
                ? Icons.bookmark
                : Icons.bookmark_border,
            color: AppColors.secondary,
            size: 28,
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
          icon: Icon(
            isPagePlaying ? Icons.pause_circle : Icons.play_circle,
            color: (isPagePlaying || isPagePaused)
                ? AppColors.secondary
                : Colors.white54,
            size: 28,
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

  Widget _buildTopBar(bool isDark) {
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: dividerColor, width: 0.8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'الجزء ${_juzName(_juzForPage(_currentPage))}',
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
            _pageLabel(_currentPage),
            style: labelStyle,
            textDirection: TextDirection.rtl,
          ),
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
          height: 36,
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: dividerColor, width: 0.8)),
          ),
          alignment: Alignment.center,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(
                'assets/logo/files/transparent/label.png',
                height: 28,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.80)
                    : null,
              ),
              Text(
                _toArabicNumerals(pageNumber),
                textAlign: TextAlign.center,
                style: GoogleFonts.amiriQuran(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDarkMode ? Colors.white : const Color(0xFF3D1C00),
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

    // Double-line border
    canvas.drawRect(
        Rect.fromLTWH(margin, margin, size.width - margin * 2, size.height - margin * 2),
        outerPaint);
    canvas.drawRect(
        Rect.fromLTWH(innerMargin, innerMargin, size.width - innerMargin * 2,
            size.height - innerMargin * 2),
        innerPaint);

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
