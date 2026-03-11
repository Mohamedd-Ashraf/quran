import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/mushaf_page_map.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/audio/ayah_audio_cubit.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/services/bookmark_service.dart';
import '../../../../core/settings/app_settings_cubit.dart';
import '../../../../core/utils/arabic_text_style_helper.dart';
import '../bloc/tafsir/tafsir_cubit.dart';
import 'tafsir_screen.dart';
import 'package:qcf_quran/qcf_quran.dart';
import '../widgets/ayah_share_card.dart';
import '../widgets/mushaf_page_view.dart' show IslamicPatternPainter, BorderOrnamentPainter;

// ─── Verse long-press options sheet ───────────────────────────────────────────

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

// ─── Data model ───────────────────────────────────────────────────────────────
class _Verse {
  final String verseKey;
  final int    surah;
  final int    ayah;
  final String text;

  const _Verse({
    required this.verseKey,
    required this.surah,
    required this.ayah,
    required this.text,
  });
}

// ─── Persistent page cache ────────────────────────────────────────────────────
const String _mushafCachePrefix = 'mushaf_page_v1_';

Future<List<_Verse>?> _loadPageFromDiskCache(int page) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString('$_mushafCachePrefix$page');
  if (raw == null || raw.isEmpty) return null;
  try {
    final decoded = jsonDecode(raw) as List;
    return decoded.map((v) {
      final key = v['verseKey'] as String;
      final sp  = key.split(':');
      return _Verse(
        verseKey: key,
        surah:    int.parse(sp[0]),
        ayah:     int.parse(sp[1]),
        text:     (v['text'] as String?) ?? '',
      );
    }).toList();
  } catch (_) {
    return null;
  }
}

Future<void> _savePageToDiskCache(int page, List<_Verse> verses) async {
  final prefs = await SharedPreferences.getInstance();
  final encoded = jsonEncode(
    verses.map((v) => {'verseKey': v.verseKey, 'text': v.text}).toList(),
  );
  await prefs.setString('$_mushafCachePrefix$page', encoded);
}

/// Load verses for [page] from the bundled offline JSON assets (always available).
Future<List<_Verse>> _fetchPageFromBundledAssets(int page) async {
  final surahNumbers = kMushafPageToSurahs[page];
  if (surahNumbers == null || surahNumbers.isEmpty) return [];

  final results = <_Verse>[];
  for (final surahNum in surahNumbers) {
    try {
      final raw = await rootBundle.loadString('assets/offline/surah_$surahNum.json');
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final ayahs = data['ayahs'] as List;
      for (final ayah in ayahs) {
        if ((ayah['page'] as int?) == page) {
          results.add(_Verse(
            verseKey: '$surahNum:${ayah["numberInSurah"]}',
            surah:    surahNum,
            ayah:     ayah['numberInSurah'] as int,
            text:     (ayah['text'] as String?) ?? '',
          ));
        }
      }
    } catch (_) {
      // skip if asset missing
    }
  }
  return results;
}

// ─── Network / cache orchestration ───────────────────────────────────────────
Future<List<_Verse>> _fetchPage(int page) async {
  // 1. Try persistent disk cache first (fastest, works fully offline)
  final cached = await _loadPageFromDiskCache(page);
  if (cached != null && cached.isNotEmpty) return cached;

  // 2. Fall back to bundled offline assets (always available, no internet needed)
  final bundled = await _fetchPageFromBundledAssets(page);
  if (bundled.isNotEmpty) {
    // Persist to disk so next read is instant
    _savePageToDiskCache(page, bundled);
    return bundled;
  }

  // 3. Last resort: fetch from network (requires internet)
  final uri = Uri.parse(
    'https://api.quran.com/api/v4/verses/by_page/$page'
    '?fields=text_uthmani&per_page=50',
  );
  final res = await http.get(uri, headers: const {'Accept': 'application/json'});
  if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');

  final data  = jsonDecode(res.body) as Map<String, dynamic>;
  final vList = data['verses'] as List;

  final verses = vList.map((v) {
    final key  = v['verse_key'] as String;
    final sp   = key.split(':');
    return _Verse(
      verseKey: key,
      surah:    int.parse(sp[0]),
      ayah:     int.parse(sp[1]),
      text:     (v['text_uthmani'] as String?) ?? '',
    );
  }).toList();

  // Save to disk cache
  _savePageToDiskCache(page, verses);
  return verses;
}

// ─── Main screen ──────────────────────────────────────────────────────────────
class MushafPageScreen extends StatefulWidget {
  final int initialPage;
  final int? focusSurahNumber;
  final int? focusAyahNumber;

  /// Optional notifier that mirrors the audio player's collapsed state
  /// so the page content can adapt its bottom padding accordingly.
  final ValueNotifier<bool>? playerCollapsedNotifier;

  const MushafPageScreen({
    super.key,
    this.initialPage = 1,
    this.focusSurahNumber,
    this.focusAyahNumber,
    this.playerCollapsedNotifier,
  });

  @override
  State<MushafPageScreen> createState() => _MushafPageScreenState();
}

class _MushafPageScreenState extends State<MushafPageScreen> {
  late final PageController _pageCtrl;
  int _currentPage = 1;

  final Map<int, List<_Verse>> _cache   = {};
  final Map<int, bool>         _loading = {};
  final Map<int, Object?>      _errors  = {};

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _pageCtrl    = PageController(initialPage: widget.initialPage - 1);
    _load(_currentPage);
    if (_currentPage < 604) _load(_currentPage + 1);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _load(int page) async {
    if (_cache.containsKey(page) || _loading[page] == true) return;
    if (mounted) setState(() => _loading[page] = true);
    try {
      final verses = await _fetchPage(page);
      if (mounted) setState(() => _cache[page] = verses);
    } catch (e) {
      if (mounted) setState(() => _errors[page] = e);
    } finally {
      if (mounted) setState(() => _loading.remove(page));
    }
  }

  void _onPageChanged(int idx) {
    setState(() => _currentPage = idx + 1);
    _load(_currentPage);
    if (_currentPage < 604) _load(_currentPage + 1);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<AppSettingsCubit, bool>(
      (c) => c.state.darkMode);
    final bgColor = isDark ? const Color(0xFF0E1A12) : const Color(0xFFFFF9ED);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        bottom: false,
        child: Container(
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
              Positioned.fill(
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: PageView.builder(
                    controller:    _pageCtrl,
                    itemCount:     604,
                    onPageChanged: _onPageChanged,
                    itemBuilder: (context, idx) {
                      final page = idx + 1;
                      return _MushafPage(
                        page:      page,
                        verses:    _cache[page],
                        isLoading: _loading[page] == true,
                        error:     _errors[page],
                        onRetry:   () => _load(page),
                        trimBeforeSurahNumber:
                            page == widget.initialPage ? widget.focusSurahNumber : null,
                        trimBeforeAyahNumber:
                            page == widget.initialPage ? widget.focusAyahNumber : null,
                        playerCollapsedNotifier: widget.playerCollapsedNotifier,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Single page layout ───────────────────────────────────────────────────────
class _MushafPage extends StatelessWidget {
  final int           page;
  final List<_Verse>? verses;
  final bool          isLoading;
  final Object?       error;
  final VoidCallback  onRetry;
  final int?          trimBeforeSurahNumber;
  final int?          trimBeforeAyahNumber;
  final ValueNotifier<bool>? playerCollapsedNotifier;

  const _MushafPage({
    required this.page,
    required this.verses,
    required this.isLoading,
    required this.error,
    required this.onRetry,
    this.trimBeforeSurahNumber,
    this.trimBeforeAyahNumber,
    this.playerCollapsedNotifier,
  });

  List<_Verse> _effectiveVerses(List<_Verse> source) {
    final surahNumber = trimBeforeSurahNumber;
    if (surahNumber == null) return source;

    final ayahNumber = trimBeforeAyahNumber ?? 1;
    final startIndex = source.indexWhere(
      (verse) =>
          verse.surah == surahNumber &&
          verse.ayah >= ayahNumber,
    );

    if (startIndex <= 0) return source;
    return source.sublist(startIndex);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<AppSettingsCubit, bool>(
      (c) => c.state.darkMode);
    final bgColor = isDark ? const Color(0xFF0E1A12) : const Color(0xFFF5F0E4);
    final visibleVerses = verses == null ? null : _effectiveVerses(verses!);

    if (isLoading || (visibleVerses == null && error == null)) {
      return Container(
        color: bgColor,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 3),
              const SizedBox(height: 14),
              Text('جارٍ تحميل الصفحة $page…',
                style: TextStyle(
                    fontSize: 14,
                    color: isDark ? const Color(0xFF9E9E9E) : AppColors.textSecondary)),
            ],
          ),
        ),
      );
    }

    if (error != null || visibleVerses == null || visibleVerses.isEmpty) {
      return Container(
        color: bgColor,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded,
                  size: 56,
                  color: isDark ? const Color(0xFF6B6B6B) : AppColors.textSecondary),
              const SizedBox(height: 12),
              Text('تعذّر تحميل الصفحة',
                style: TextStyle(
                    fontSize: 14,
                    color: isDark ? const Color(0xFF9E9E9E) : AppColors.textSecondary)),
              const SizedBox(height: 12),
              TextButton.icon(
                icon:  const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        _MushafTopBar(page: page, verses: visibleVerses, isDark: isDark),
        Expanded(
          child: BlocBuilder<AyahAudioCubit, AyahAudioState>(
            builder: (ctx, audioState) {
              final playerVisible =
                  audioState.status != AyahAudioStatus.idle;
              final notifier = playerCollapsedNotifier;
              Widget scrollView(double bottomPad) => SingleChildScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPad),
                child: _PageText(verses: visibleVerses),
              );
              if (notifier != null) {
                return ValueListenableBuilder<bool>(
                  valueListenable: notifier,
                  builder: (ctx, isCollapsed, _) => scrollView(
                    playerVisible ? (isCollapsed ? 8.0 : 220.0) : 8,
                  ),
                );
              }
              return scrollView(playerVisible ? 220.0 : 8);
            },
          ),
        ),
        _MushafFooter(page: page, isDark: isDark),
      ],
    );
  }
}

// ─── Mushaf top bar (matches MushafPageView._buildTopBar style) ──────────────

class _MushafTopBar extends StatelessWidget {
  final int          page;
  final List<_Verse> verses;
  final bool         isDark;

  const _MushafTopBar({
    required this.page,
    required this.verses,
    required this.isDark,
  });

  static const _kJuzNames = [
    'الأول', 'الثاني', 'الثالث', 'الرابع', 'الخامس',
    'السادس', 'السابع', 'الثامن', 'التاسع', 'العاشر',
    'الحادي عشر', 'الثاني عشر', 'الثالث عشر', 'الرابع عشر', 'الخامس عشر',
    'السادس عشر', 'السابع عشر', 'الثامن عشر', 'التاسع عشر', 'العشرون',
    'الحادي والعشرون', 'الثاني والعشرون', 'الثالث والعشرون', 'الرابع والعشرون', 'الخامس والعشرون',
    'السادس والعشرون', 'السابع والعشرون', 'الثامن والعشرون', 'التاسع والعشرون', 'الثلاثون',
  ];

  int get _juz => ((page - 1) ~/ 20).clamp(0, 29) + 1;

  String get _juzName {
    final j = _juz;
    return j >= 1 && j <= 30 ? _kJuzNames[j - 1] : _toArabicNum(j);
  }

  String get _surahLabel {
    if (verses.isEmpty) return '';
    final n = verses.first.surah;
    return n > 0 && n < _kSurahNames.length ? _kSurahNames[n] : '';
  }

  @override
  Widget build(BuildContext context) {
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
          _TopBarPlayButton(verses: verses),
          Text(
            'الجزء $_juzName',
            style: labelStyle,
            textDirection: TextDirection.rtl,
          ),
          Expanded(
            child: Center(
              child: Text(
                '❧',
                style: TextStyle(color: dividerColor, fontSize: 14, height: 1),
              ),
            ),
          ),
          Text(
            _surahLabel,
            style: labelStyle,
            textDirection: TextDirection.rtl,
          ),
          _TopBarBookmarkButton(page: page),
        ],
      ),
    );
  }
}

// ─── Play button for the Mushaf top bar ───────────────────────────────────────

class _TopBarPlayButton extends StatelessWidget {
  final List<_Verse> verses;
  const _TopBarPlayButton({required this.verses});

  @override
  Widget build(BuildContext context) {
    if (verses.isEmpty) {
      return const SizedBox(width: 32, height: 32);
    }
    return BlocBuilder<AyahAudioCubit, AyahAudioState>(
      builder: (context, audioState) {
        final firstSurah  = verses.first.surah;
        final surahVerses = verses.where((v) => v.surah == firstSurah).toList();
        final startAyah   = surahVerses.first.ayah;
        final endAyah     = surahVerses.last.ayah;

        final isPageActive = audioState.surahNumber == firstSurah &&
            audioState.ayahNumber != null &&
            audioState.ayahNumber! >= startAyah &&
            audioState.ayahNumber! <= endAyah;
        final isPagePlaying = isPageActive && audioState.status == AyahAudioStatus.playing;
        final isPagePaused  = isPageActive && audioState.status == AyahAudioStatus.paused;

        return IconButton(
          onPressed: () {
            final cubit = context.read<AyahAudioCubit>();
            if (isPagePlaying) {
              cubit.pause();
            } else if (isPagePaused) {
              cubit.resume();
            } else {
              cubit.playAyahRange(
                surahNumber: firstSurah,
                startAyah:   startAyah,
                endAyah:     endAyah,
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
        );
      },
    );
  }
}

// ─── Bookmark button for the Mushaf top bar ───────────────────────────────────

class _TopBarBookmarkButton extends StatefulWidget {
  final int page;
  const _TopBarBookmarkButton({required this.page});

  @override
  State<_TopBarBookmarkButton> createState() => _TopBarBookmarkButtonState();
}

class _TopBarBookmarkButtonState extends State<_TopBarBookmarkButton> {
  late final BookmarkService _bookmarkService;

  @override
  void initState() {
    super.initState();
    _bookmarkService = di.sl<BookmarkService>();
  }

  @override
  Widget build(BuildContext context) {
    final pageId       = 'mushaf:page:${widget.page}';
    final isBookmarked = _bookmarkService.isBookmarked(pageId);

    return IconButton(
      onPressed: () async {
        if (isBookmarked) {
          await _bookmarkService.removeBookmark(pageId);
        } else {
          await _bookmarkService.addBookmark(
            id:          pageId,
            reference:   pageId,
            arabicText:  'صفحة ${_toArabicNum(widget.page)}',
            surahName:   '',
            surahNumber: 0,
            ayahNumber:  null,
          );
        }
        if (mounted) setState(() {});
      },
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      iconSize: 20,
      icon: Icon(
        isBookmarked ? Icons.bookmark : Icons.bookmark_border,
        color: AppColors.secondary,
        size: 20,
      ),
    );
  }
}

// ─── Mushaf footer (matches MushafPageView._buildDecorativeFooter style) ──────

class _MushafFooter extends StatelessWidget {
  final int  page;
  final bool isDark;
  const _MushafFooter({required this.page, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bottomInset  = MediaQuery.of(context).padding.bottom;
    final dividerColor = isDark
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
                color: isDark ? Colors.white.withValues(alpha: 0.80) : null,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 2),
                child: Text(
                  _toArabicNum(page),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.amiriQuran(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF3D1C00),
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
}

// ─── Continuous page text ─────────────────────────────────────────────────────
// Verses are grouped by surah so a Basmala can be inserted between surahs.
// Long-pressing the ayah text or its circle opens tafsir; tapping plays audio.
// Highlight follows the audio cubit so the active ayah is visually marked.
class _PageText extends StatefulWidget {
  final List<_Verse> verses;
  const _PageText({required this.verses});

  @override
  State<_PageText> createState() => _PageTextState();
}

class _PageTextState extends State<_PageText> {
  final List<GestureRecognizer> _recognizers = [];

  // Tracks the last verse the user's finger touched (pointer-down).
  // Used so a long-press on the text body knows which verse to open.
  _Verse? _lastTouchedVerse;

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  void _openTafsir(_Verse v) {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    final name       = v.surah < _kSurahNames.length ? _kSurahNames[v.surah] : '';
    final bookmarkId = 'surah_${v.surah}_ayah_${v.ayah}';
    _showVerseOptionsSheet(
      context,
      surah:           v.surah,
      verse:           v.ayah,
      surahName:       name,
      arabicText:      v.text,
      bookmarkId:      bookmarkId,
      bookmarkService: di.sl<BookmarkService>(),
      onTafsir: () {
        if (!mounted) return;
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (_) => di.sl<TafsirCubit>(),
            child: TafsirScreen(
              surahNumber:      v.surah,
              ayahNumber:       v.ayah,
              surahName:        name,
              surahEnglishName: '',
              arabicAyahText:   v.text,
            ),
          ),
        ));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AyahAudioCubit>();

    return BlocBuilder<AppSettingsCubit, AppSettingsState>(
      builder: (ctx, settings) {
        return BlocBuilder<AyahAudioCubit, AyahAudioState>(
          builder: (ctx, audioState) {
            final isDark    = settings.darkMode;
            final textColor = isDark
                ? const Color(0xFFE8E8E8)
                : const Color(0xFF1A1A1A);

            final baseStyle = ArabicTextStyleHelper.quranFontStyle(
              fontKey:    settings.quranFont,
              fontSize:   settings.arabicFontSize,
              fontWeight: FontWeight.w500,
              color:      textColor,
              height:     2.2,
            );

            final highlightColor = AppColors.secondary.withValues(alpha: 0.28);

            final playKey = (audioState.hasTarget &&
                    audioState.status != AyahAudioStatus.idle)
                ? '${audioState.surahNumber}:${audioState.ayahNumber}'
                : null;

            // Dispose old recognizers before creating new ones each rebuild.
            for (final r in _recognizers) {
              r.dispose();
            }
            _recognizers.clear();

            // Group verses by surah so Basmala can be inserted between surahs.
            final sections = <_SurahSection>[];
            for (var i = 0; i < widget.verses.length; i++) {
              final v = widget.verses[i];
              if (sections.isEmpty || sections.last.surahNum != v.surah) {
                sections.add(_SurahSection(surahNum: v.surah));
              }
              sections.last.entries.add(_VerseEntry(idx: i, verse: v));
            }

            final children = <Widget>[];
            for (final section in sections) {
              // Show decorative surah header whenever ayah 1 appears.
              if (section.entries.isNotEmpty &&
                  section.entries.first.verse.ayah == 1) {
                children.add(_SurahHeader(
                  surahNum: section.surahNum,
                  isDark: isDark,
                ));
              }
              // Show Basmala before ayah 1 of every surah except Al-Fatiha (1)
              // and At-Tawba (9) which has no Basmala.
              if (section.entries.isNotEmpty &&
                  section.entries.first.verse.ayah == 1 &&
                  section.surahNum != 1 &&
                  section.surahNum != 9) {
                children.add(_Basmala(isDark: isDark));
              }

              // Whether we showed a basmala header for this section.
              // If yes, strip the embedded basmala from verse 1's text.
              final bool hasBasmalaHeader = section.entries.isNotEmpty &&
                  section.entries.first.verse.ayah == 1 &&
                  section.surahNum != 1 &&
                  section.surahNum != 9;

              // All verses in this section flow as a single justified RichText
              // so that text wraps naturally across the full line width —
              // exactly like a real Mushaf page.
              final spans = <InlineSpan>[];
              for (final entry in section.entries) {
                final v        = entry.verse;
                final isActive = '${v.surah}:${v.ayah}' == playKey;

                // Tap on verse text → track touched verse + play.
                final capturedVerse = v;
                final tapRec = TapGestureRecognizer()
                  ..onTapDown = (_) {
                    // Record immediately on finger-down so the wrapping
                    // GestureDetector's onLongPress knows which verse to open.
                    _lastTouchedVerse = capturedVerse;
                  }
                  ..onTap = () {
                    HapticFeedback.selectionClick();
                    cubit.togglePlayAyah(
                        surahNumber: capturedVerse.surah,
                        ayahNumber:  capturedVerse.ayah);
                  };
                _recognizers.add(tapRec);

                final displayText = (hasBasmalaHeader && v.ayah == 1)
                    ? _stripBasmalaPrefix(v.text)
                    : v.text;

                spans.add(TextSpan(
                  text: '$displayText ',
                  style: baseStyle.copyWith(
                    backgroundColor: isActive ? highlightColor : null,
                  ),
                  recognizer: tapRec,
                ));

                // Inline ayah marker — tap to play, long-press for options.
                spans.add(WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _AyahMarker(
                      number:        v.ayah,
                      isDark:        isDark,
                      quranFontSize: settings.arabicFontSize,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        cubit.togglePlayAyah(
                            surahNumber: v.surah, ayahNumber: v.ayah);
                      },
                      onLongPress: () => _openTafsir(v),
                    ),
                  ),
                ));

                // Small space after each marker before the next verse begins.
                spans.add(TextSpan(text: ' ', style: baseStyle));
              }

              // GestureDetector wraps the RichText so that a long-press on
              // the verse *text* (not just the marker circle) also opens the
              // options sheet.  onTapDown on each TextSpan's TapGestureRecognizer
              // fires first (setting _lastTouchedVerse), then the long-press
              // timer wins the gesture arena and calls this handler.
              children.add(GestureDetector(
                onLongPress: () {
                  final verse = _lastTouchedVerse;
                  if (verse != null) {
                    HapticFeedback.mediumImpact();
                    _openTafsir(verse);
                  }
                },
                child: RichText(
                  text: TextSpan(children: spans),
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.justify,
                ),
              ));
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            );
          },
        );
      },
    );
  }
}

// ─── Surah section helpers ────────────────────────────────────────────────────
class _SurahSection {
  final int surahNum;
  final List<_VerseEntry> entries = [];
  _SurahSection({required this.surahNum});
}

class _VerseEntry {
  final int    idx;
  final _Verse verse;
  const _VerseEntry({required this.idx, required this.verse});
}

// ─── Basmala prefix stripper ────────────────────────────────────────────────
// The Uthmani text in the offline JSON (and quran.com API) prepends the Basmala
// to verse 1 of every surah except Al-Fatiha (1) and At-Tawbah (9).
// Strip it to avoid showing it twice alongside the rendered _Basmala widget.

/// Strips the Basmala from the beginning of [text] if present.
///
/// Comparison is done after removing all Arabic diacritics (tashkeel) and
/// normalising Alef-wasla (ٱ → ا), so it is immune to encoding differences
/// across data sources (offline JSON, quran.com API, cached data, etc.).
String _stripBasmalaPrefix(String text) {
  // Basmala in bare consonants only – no diacritics, standard Alef.
  const String kBasmalaBase = 'بسم الله الرحمن الرحيم';

  // Remove all Arabic diacritical marks and normalise Alef-wasla → Alef.
  String normalise(String s) => s
      .replaceAll(
        RegExp(
          r'[\u064B-\u065F\u0670\u06D6-\u06DC\u06DF-\u06E4\u06E7\u06E8\u06EA-\u06ED]',
        ),
        '',
      )
      .replaceAll('\u0671', '\u0627'); // Alef-wasla → Alef

  if (!normalise(text).startsWith(kBasmalaBase)) return text;

  // Walk the *original* text to find the index corresponding to
  // kBasmalaBase.length normalised (non-diacritic) characters.
  int origIdx = 0;
  int normCount = 0;
  final basLen = kBasmalaBase.length;

  while (origIdx < text.length && normCount < basLen) {
    final cp = text.codeUnitAt(origIdx);
    final isDiacritic = (cp >= 0x064B && cp <= 0x065F) ||
        cp == 0x0670 ||
        (cp >= 0x06D6 && cp <= 0x06DC) ||
        (cp >= 0x06DF && cp <= 0x06E4) ||
        cp == 0x06E7 ||
        cp == 0x06E8 ||
        (cp >= 0x06EA && cp <= 0x06ED);
    if (!isDiacritic) normCount++;
    origIdx++;
  }

  // Skip any diacritics attached to the last Basmala consonant (e.g. kasra
  // on مِ in الرَّحِيمِ). The main loop stops after counting the م itself, leaving
  // its trailing harakat at origIdx.
  while (origIdx < text.length) {
    final cp2 = text.codeUnitAt(origIdx);
    final trailing = (cp2 >= 0x064B && cp2 <= 0x065F) ||
        cp2 == 0x0670 ||
        (cp2 >= 0x06D6 && cp2 <= 0x06DC) ||
        (cp2 >= 0x06DF && cp2 <= 0x06E4) ||
        cp2 == 0x06E7 ||
        cp2 == 0x06E8 ||
        (cp2 >= 0x06EA && cp2 <= 0x06ED);
    if (!trailing) break;
    origIdx++;
  }

  return text.substring(origIdx).trimLeft();
}

// ─── Decorative surah header ──────────────────────────────────────────────────
class _SurahHeader extends StatelessWidget {
  final int surahNum;
  final bool isDark;
  const _SurahHeader({required this.surahNum, required this.isDark});

  Widget _darkFrame(int num) {
    const Color nameColor = Color(0xFFE8C46A);
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final bool portrait =
            MediaQuery.of(ctx).orientation == Orientation.portrait;
        final double w =
            portrait ? constraints.maxWidth * 0.95 : constraints.maxWidth * 0.8;
        final double fs =
            portrait ? w * 0.075 : constraints.maxWidth * 0.05;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(
                'assets/mainframe.png',
                package: 'qcf_quran',
                width: w,
                fit: BoxFit.contain,
                color: const Color.fromARGB(255, 43, 63, 48),
                colorBlendMode: BlendMode.color,
              ),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  text: 'surah${num.toString().padLeft(3, '0')}',
                  style: TextStyle(
                    fontFamily: SurahFontHelper.fontFamily,
                    package: 'qcf_quran',
                    color: nameColor,
                    fontSize: fs,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color nameColor =
        isDark ? const Color(0xFFE8C46A) : const Color(0xFF3D2000);
    return HeaderWidget(
      suraNumber: surahNum,
      theme: QcfThemeData(
        headerTextColor: nameColor,
        customHeaderBuilder: isDark ? _darkFrame : null,
      ),
    );
  }
}

// ─── Basmala separator ────────────────────────────────────────────────────────
class _Basmala extends StatelessWidget {
  final bool isDark;
  const _Basmala({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final color = isDark ? const Color(0xFFD4A855) : AppColors.primary;
    // Render the Bismillah using the same QCF_P001 font and glyph sequence
    // as the qcf_quran package so it looks identical to QCF mode.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Text(
        ' \uFC41  \uFC42\uFC43\uFC44',
        textAlign:     TextAlign.center,
        textDirection: TextDirection.rtl,
        style: TextStyle(
          fontFamily: 'QCF_P001',
          package:    'qcf_quran',
          fontSize:   24.0,
          color:      color,
          height:     2.0,
        ),
      ),
    );
  }
}


// ─── Ayah number marker (same visual as mushaf_page_view) ────────────────────
class _AyahMarker extends StatelessWidget {
  final int           number;
  final bool          isDark;
  final double        quranFontSize;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  const _AyahMarker({
    required this.number,
    required this.isDark,
    required this.quranFontSize,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    // Scale the frame and text proportionally with the Quran font size.
    // Base reference is fontSize 18 → frameSize 28.
    final scale     = (quranFontSize / 18.0).clamp(0.7, 2.0);
    final frameSize = 28.0 * scale;
    final numFontSize = number > 99
        ? 8.0  * scale
        : number > 9
            ? 10.0 * scale
            : 12.0 * scale;

    return GestureDetector(
      onTap:       onTap,
      onLongPress: onLongPress,
      child: Stack(
      alignment: Alignment.center,
      children: [
        Image.asset(
          'assets/logo/files/transparent/frame.png',
          width:  frameSize,
          height: frameSize,
          color:  isDark ? Colors.white.withValues(alpha: 0.85) : null,
        ),
        Padding(
          padding: EdgeInsets.only(bottom: frameSize * 0.28),
          child: Text(
            _toArabicNum(number),
            textAlign: TextAlign.center,
            style: GoogleFonts.amiriQuran(
              fontSize:   numFontSize,
              fontWeight: FontWeight.w800,
              color:      isDark ? Colors.white : AppColors.primary,
              height:     1,
            ),
          ),
        ),
      ],
    ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────
String _toArabicNum(int n) {
  const d = ['٠','١','٢','٣','٤','٥','٦','٧','٨','٩'];
  return n.toString().split('').map((c) => d[int.parse(c)]).join();
}

const _kSurahNames = [
  '',
  'الفاتحة','البقرة','آل عمران','النساء','المائدة',
  'الأنعام','الأعراف','الأنفال','التوبة','يونس',
  'هود','يوسف','الرعد','إبراهيم','الحجر',
  'النحل','الإسراء','الكهف','مريم','طه',
  'الأنبياء','الحج','المؤمنون','النور','الفرقان',
  'الشعراء','النمل','القصص','العنكبوت','الروم',
  'لقمان','السجدة','الأحزاب','سبأ','فاطر',
  'يس','الصافات','ص','الزمر','غافر',
  'فصلت','الشورى','الزخرف','الدخان','الجاثية',
  'الأحقاف','محمد','الفتح','الحجرات','ق',
  'الذاريات','الطور','النجم','القمر','الرحمن',
  'الواقعة','الحديد','المجادلة','الحشر','الممتحنة',
  'الصف','الجمعة','المنافقون','التغابن','الطلاق',
  'التحريم','الملك','القلم','الحاقة','المعارج',
  'نوح','الجن','المزمل','المدثر','القيامة',
  'الإنسان','المرسلات','النبأ','النازعات','عبس',
  'التكوير','الانفطار','المطففين','الانشقاق','البروج',
  'الطارق','الأعلى','الغاشية','الفجر','البلد',
  'الشمس','الليل','الضحى','الشرح','التين',
  'العلق','القدر','البينة','الزلزلة','العاديات',
  'القارعة','التكاثر','العصر','الهمزة','الفيل',
  'قريش','الماعون','الكوثر','الكافرون','النصر',
  'المسد','الإخلاص','الفلق','الناس',
];
