import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../../../core/constants/mushaf_page_map.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/audio/ayah_audio_cubit.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/services/audio_edition_service.dart';
import '../../../../core/services/bookmark_service.dart';
import '../../../../core/services/offline_audio_service.dart';
import '../../../../core/services/tutorial_service.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../core/settings/app_settings_cubit.dart';
import '../../../../core/utils/arabic_text_style_helper.dart';
import '../../../../core/utils/tajweed_parser.dart';
import '../bloc/tafsir/tafsir_cubit.dart';
import 'tafsir_screen.dart';
import 'package:qcf_quran/qcf_quran.dart';
import '../tutorials/mushaf_tutorial.dart';
import '../widgets/ayah_share_card.dart';
import '../widgets/mushaf_page_view.dart'
    show IslamicPatternPainter, BorderOrnamentPainter;

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
                  style: GoogleFonts.cairo(
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

// ─── Data model ───────────────────────────────────────────────────────────────
class _Verse {
  final String verseKey;
  final int surah;
  final int ayah;
  final String text;

  const _Verse({
    required this.verseKey,
    required this.surah,
    required this.ayah,
    required this.text,
  });
}

// ─── Persistent page cache ────────────────────────────────────────────────────
const String _mushafCachePrefix = 'mushaf_page_v2_';

Future<List<_Verse>?> _loadPageFromDiskCache(int page) async {
  final cached = _mushafPageSessionCache[page];
  if (cached == null || cached.isEmpty) return null;
  return List<_Verse>.from(cached);
}

Future<void> _savePageToDiskCache(int page, List<_Verse> verses) async {
  // Keep only session cache in memory to avoid bloating SharedPreferences.
  _mushafPageSessionCache[page] = List<_Verse>.from(verses);
}

final Map<int, List<_Verse>> _mushafPageSessionCache = <int, List<_Verse>>{};

/// Load verses for [page] from the bundled offline JSON assets (always available).
Future<List<_Verse>> _fetchPageFromBundledAssets(int page) async {
  final pageData = getPageData(page);
  final surahNumbers = pageData.map((e) => (e as Map)['surah'] as int).toSet();
  if (surahNumbers.isEmpty) return [];

  final results = <_Verse>[];
  for (final surahNum in surahNumbers) {
    try {
      final raw = await rootBundle.loadString(
        'assets/offline/surah_$surahNum.json',
      );
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final ayahs = data['ayahs'] as List;
      for (final ayah in ayahs) {
        final ayahNum = ayah['numberInSurah'] as int;
        bool inRange = false;
        for (final r in pageData) {
          final bounds = r as Map;
          if (bounds['surah'] == surahNum &&
              ayahNum >= (bounds['start'] as int) &&
              ayahNum <= (bounds['end'] as int)) {
            inRange = true;
            break;
          }
        }
        if (inRange) {
          results.add(
            _Verse(
              verseKey: '$surahNum:${ayah["numberInSurah"]}',
              surah: surahNum,
              ayah: ayah['numberInSurah'] as int,
              text: (ayah['text'] as String?) ?? '',
            ),
          );
        }
      }
    } catch (_) {
      // skip if asset missing
    }
  }

  // Sort the results so they appear in correct Mushaf order (Surah -> Ayah)
  results.sort((a, b) {
    if (a.surah != b.surah) return a.surah.compareTo(b.surah);
    return a.ayah.compareTo(b.ayah);
  });

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
  final res = await http.get(
    uri,
    headers: const {'Accept': 'application/json'},
  );
  if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');

  final data = jsonDecode(res.body) as Map<String, dynamic>;
  final vList = data['verses'] as List;
  final pageData = getPageData(page);

  final verses = <_Verse>[];
  for (final v in vList) {
    final key = v['verse_key'] as String;
    final sp = key.split(':');
    final surahNum = int.parse(sp[0]);
    final ayahNum = int.parse(sp[1]);

    bool inRange = false;
    for (final r in pageData) {
      final bounds = r as Map;
      if (bounds['surah'] == surahNum &&
          ayahNum >= (bounds['start'] as int) &&
          ayahNum <= (bounds['end'] as int)) {
        inRange = true;
        break;
      }
    }

    if (inRange) {
      verses.add(
        _Verse(
          verseKey: key,
          surah: surahNum,
          ayah: ayahNum,
          text: (v['text_uthmani'] as String?) ?? '',
        ),
      );
    }
  }

  // Save to disk cache
  _savePageToDiskCache(page, verses);
  return verses;
}

// ─── Tajweed page data (fetched on-demand from alquran.cloud) ────────────────
// Keyed by page number. Each entry maps "surah:ayah" → tajweed-marked text.
final Map<int, Map<String, String>> _tajweedPageCache = {};
final Map<int, bool> _tajweedPageLoading = {};

/// Fetches tajweed-annotated text for all ayahs on [page] from alquran.cloud.
/// Returns a map of "surah:ayah" → tajweed text, or `null` on failure.
Future<Map<String, String>?> _fetchTajweedPage(int page) async {
  // Return from cache if available.
  if (_tajweedPageCache.containsKey(page)) return _tajweedPageCache[page];
  // Prevent duplicate requests
  if (_tajweedPageLoading[page] == true) return null;
  _tajweedPageLoading[page] = true;

  try {
    final uri = Uri.parse(
      'https://api.alquran.cloud/v1/page/$page/quran-tajweed',
    );
    final res = await http.get(uri, headers: const {'Accept': 'application/json'});
    if (res.statusCode != 200) return null;

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>?;
    if (data == null) return null;

    final ayahs = data['ayahs'] as List?;
    if (ayahs == null) return null;

    final result = <String, String>{};
    for (final a in ayahs) {
      final surahInfo = a['surah'] as Map<String, dynamic>?;
      final surahNum = surahInfo?['number'] as int? ?? 0;
      final ayahNum = a['numberInSurah'] as int? ?? 0;
      final text = a['text'] as String? ?? '';
      if (surahNum > 0 && ayahNum > 0 && text.isNotEmpty) {
        result['$surahNum:$ayahNum'] = text;
      }
    }

    _tajweedPageCache[page] = result;
    return result;
  } catch (_) {
    return null;
  } finally {
    _tajweedPageLoading.remove(page);
  }
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
  bool _tutorialShown = false;
  bool _tajweedMode = false;

  final Map<int, List<_Verse>> _cache = {};
  final Map<int, bool> _loading = {};
  final Map<int, Object?> _errors = {};

  // Tajweed text overlays keyed by page → { "surah:ayah": tajweedText }
  final Map<int, Map<String, String>> _tajweedCache = {};
  final Map<int, bool> _tajweedLoading = {};

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _pageCtrl = PageController(initialPage: widget.initialPage - 1);
    _load(_currentPage);
    if (_currentPage < 604) _load(_currentPage + 1);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showTutorialIfNeeded();
    });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _showTutorialIfNeeded() {
    if (_tutorialShown || !mounted) return;
    final svc = di.sl<TutorialService>();
    if (svc.isTutorialComplete(TutorialService.mushafScreen)) return;
    _tutorialShown = true;
    final settings = context.read<AppSettingsCubit>().state;
    final isArabic = settings.appLanguageCode.toLowerCase().startsWith('ar');
    MushafTutorial.show(
      context: context,
      tutorialService: svc,
      isArabic: isArabic,
      isDark: settings.darkMode,
    );
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

  /// Fetches tajweed overlay for a given page (if not cached yet).
  Future<void> _loadTajweed(int page) async {
    if (_tajweedCache.containsKey(page) || _tajweedLoading[page] == true) return;
    if (mounted) setState(() => _tajweedLoading[page] = true);
    try {
      final data = await _fetchTajweedPage(page);
      if (data != null && mounted) {
        setState(() => _tajweedCache[page] = data);
      }
    } catch (_) {
      // Silently fail — we'll show plain text as fallback
    } finally {
      if (mounted) setState(() => _tajweedLoading.remove(page));
    }
  }

  /// Toggles tajweed colouring on/off. Triggers background fetch if needed.
  void _toggleTajweed() {
    setState(() => _tajweedMode = !_tajweedMode);
    if (_tajweedMode) {
      _loadTajweed(_currentPage);
      if (_currentPage < 604) _loadTajweed(_currentPage + 1);
    }
  }

  void _onPageChanged(int idx) {
    setState(() => _currentPage = idx + 1);
    _load(_currentPage);
    if (_currentPage < 604) _load(_currentPage + 1);
    if (_tajweedMode) {
      _loadTajweed(_currentPage);
      if (_currentPage < 604) _loadTajweed(_currentPage + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<AppSettingsCubit, bool>(
      (c) => c.state.darkMode,
    );
    final bgColor = isDark ? const Color(0xFF0E1A12) : const Color(0xFFFFF9ED);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: bgColor,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
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
                    controller: _pageCtrl,
                    itemCount: 604,
                    onPageChanged: _onPageChanged,
                    itemBuilder: (context, idx) {
                      final page = idx + 1;
                      return _MushafPage(
                        page: page,
                        verses: _cache[page],
                        isLoading: _loading[page] == true,
                        error: _errors[page],
                        onRetry: () => _load(page),
                        isInitialPage: page == widget.initialPage,
                        focusSurahNumber: page == widget.initialPage
                            ? widget.focusSurahNumber
                            : null,
                        focusAyahNumber: page == widget.initialPage
                            ? widget.focusAyahNumber
                            : null,
                        playerCollapsedNotifier: widget.playerCollapsedNotifier,
                        tajweedMode: _tajweedMode,
                        tajweedTexts: _tajweedCache[page],
                        tajweedLoading: _tajweedLoading[page] == true,
                        onToggleTajweed: _toggleTajweed,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

// ─── Single page layout ───────────────────────────────────────────────────────
class _MushafPage extends StatelessWidget {
  final int page;
  final List<_Verse>? verses;
  final bool isLoading;
  final Object? error;
  final VoidCallback onRetry;
  final bool isInitialPage;
  final int? focusSurahNumber;
  final int? focusAyahNumber;
  final ValueNotifier<bool>? playerCollapsedNotifier;
  final bool tajweedMode;
  final Map<String, String>? tajweedTexts;
  final bool tajweedLoading;
  final VoidCallback onToggleTajweed;

  const _MushafPage({
    required this.page,
    required this.verses,
    required this.isLoading,
    required this.error,
    required this.onRetry,
    this.isInitialPage = false,
    this.focusSurahNumber,
    this.focusAyahNumber,
    this.playerCollapsedNotifier,
    this.tajweedMode = false,
    this.tajweedTexts,
    this.tajweedLoading = false,
    required this.onToggleTajweed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<AppSettingsCubit, bool>(
      (c) => c.state.darkMode,
    );
    final bgColor = isDark ? const Color(0xFF0E1A12) : const Color(0xFFF5F0E4);
    final visibleVerses = verses;

    if (isLoading || (visibleVerses == null && error == null)) {
      return Container(
        color: bgColor,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 3,
              ),
              const SizedBox(height: 14),
              Text(
                'جارٍ تحميل الصفحة $page…',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? const Color(0xFF9E9E9E)
                      : AppColors.textSecondary,
                ),
              ),
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
              Icon(
                Icons.wifi_off_rounded,
                size: 56,
                color: isDark
                    ? const Color(0xFF6B6B6B)
                    : AppColors.textSecondary,
              ),
              const SizedBox(height: 12),
              Text(
                'تعذّر تحميل الصفحة',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? const Color(0xFF9E9E9E)
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                icon: const Icon(Icons.refresh_rounded),
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
        _MushafTopBar(
          page: page,
          verses: visibleVerses,
          isDark: isDark,
          attachKeys: isInitialPage,
          tajweedMode: tajweedMode,
          onToggleTajweed: onToggleTajweed,
        ),
        Expanded(
          key: isInitialPage ? MushafTutorialKeys.quranPage : null,
          child: BlocBuilder<AyahAudioCubit, AyahAudioState>(
            builder: (ctx, audioState) {
              final playerVisible = audioState.status != AyahAudioStatus.idle;
              final notifier = playerCollapsedNotifier;
              Widget scrollView(double bottomPad) => SingleChildScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPad),
                child: _PageText(
                  verses: visibleVerses,
                  page: page,
                  focusSurahNumber: focusSurahNumber,
                  focusAyahNumber: focusAyahNumber,
                  tajweedMode: tajweedMode,
                  tajweedTexts: tajweedTexts,
                  tajweedLoading: tajweedLoading,
                ),
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
        _MushafFooter(
          key: isInitialPage ? MushafTutorialKeys.pageFooter : null,
          page: page,
          isDark: isDark,
        ),
      ],
    );
  }
}

// ─── Mushaf top bar (matches MushafPageView._buildTopBar style) ──────────────

class _MushafTopBar extends StatelessWidget {
  final int page;
  final List<_Verse> verses;
  final bool isDark;
  final bool attachKeys;
  final bool tajweedMode;
  final VoidCallback onToggleTajweed;

  const _MushafTopBar({
    required this.page,
    required this.verses,
    required this.isDark,
    this.attachKeys = false,
    this.tajweedMode = false,
    required this.onToggleTajweed,
  });

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
    final labelStyle = GoogleFonts.cairo(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: textColor,
    );

    return Container(
      key: attachKeys ? MushafTutorialKeys.topBar : null,
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: dividerColor, width: 0.8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _TopBarPlayButton(
            verses: verses,
            tutorialKey: attachKeys ? MushafTutorialKeys.playButton : null,
          ),
          _TopBarRecitationSettingsButton(isDark: isDark),
          _TajweedToggleButton(
            isActive: tajweedMode,
            isDark: isDark,
            onToggle: onToggleTajweed,
          ),
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
          _TopBarBookmarkButton(
            page: page,
            tutorialKey: attachKeys ? MushafTutorialKeys.bookmarkButton : null,
          ),
        ],
      ),
    );
  }
}

// ─── Play button for the Mushaf top bar ───────────────────────────────────────

class _TopBarPlayButton extends StatelessWidget {
  final List<_Verse> verses;
  final Key? tutorialKey;
  const _TopBarPlayButton({required this.verses, this.tutorialKey});

  @override
  Widget build(BuildContext context) {
    if (verses.isEmpty) {
      return const SizedBox(width: 32, height: 32);
    }
    return BlocBuilder<AyahAudioCubit, AyahAudioState>(
      builder: (context, audioState) {
        final firstSurah = verses.first.surah;
        final surahVerses = verses.where((v) => v.surah == firstSurah).toList();
        final startAyah = surahVerses.first.ayah;
        final endAyah = surahVerses.last.ayah;

        final isPageActive =
            audioState.surahNumber == firstSurah &&
            audioState.ayahNumber != null &&
            audioState.ayahNumber! >= startAyah &&
            audioState.ayahNumber! <= endAyah;
        final isPagePlaying =
            isPageActive && audioState.status == AyahAudioStatus.playing;
        final isPagePaused =
            isPageActive && audioState.status == AyahAudioStatus.paused;

        return IconButton(
          key: tutorialKey,
          onPressed: () {
            final cubit = context.read<AyahAudioCubit>();
            if (isPagePlaying) {
              cubit.pause();
            } else if (isPagePaused) {
              cubit.resume();
            } else {
              cubit.playAyahRange(
                surahNumber: firstSurah,
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
        );
      },
    );
  }
}

// ─── Bookmark button for the Mushaf top bar ───────────────────────────────────

// ─── Tajweed toggle button ────────────────────────────────────────────────────

class _TajweedToggleButton extends StatelessWidget {
  final bool isActive;
  final bool isDark;
  final VoidCallback onToggle;

  const _TajweedToggleButton({
    required this.isActive,
    required this.isDark,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    // Hide button if tajweed feature flag is disabled (compile-time gate)
    if (!SettingsService.enableTajweedFeature) return const SizedBox.shrink();

    final activeColor = isDark
        ? const Color(0xFF69F0AE)
        : const Color(0xFF169200);
    final inactiveColor = isDark
        ? Colors.white.withValues(alpha: 0.45)
        : AppColors.primary.withValues(alpha: 0.45);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Toggle button
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            onToggle();
          },
          onLongPress: () {
            HapticFeedback.mediumImpact();
            _showTajweedLegend(context, isDark);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: isActive
                  ? activeColor.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isActive ? activeColor : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.palette_rounded,
                  size: 15,
                  color: isActive ? activeColor : inactiveColor,
                ),
                const SizedBox(width: 2),
                Text(
                  'تجويد',
                  style: GoogleFonts.cairo(
                    fontSize: 9,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive ? activeColor : inactiveColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Tajweed legend bottom sheet ──────────────────────────────────────────────

void _showTajweedLegend(BuildContext context, bool isDark) {
  final colorMap = isDark ? kTajweedColorsDark : kTajweedColorsLight;
  final bg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
  final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
  final dividerColor = isDark
      ? Colors.white.withValues(alpha: 0.12)
      : Colors.black.withValues(alpha: 0.08);

  showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    backgroundColor: bg,
    builder: (ctx) {
      return SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Title
                Text(
                  'دليل ألوان التجويد',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'اضغط مطولاً على زر التجويد لعرض هذا الدليل',
                  style: GoogleFonts.cairo(
                    fontSize: 10,
                    color: textColor.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 12),
                Divider(color: dividerColor, height: 1),
                const SizedBox(height: 8),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: kLegendRules.map((rule) {
                        final color = colorMap[rule]!;
                        final name = kTajweedRuleNamesAr[rule] ?? '';
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  name,
                                  style: GoogleFonts.cairo(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _TopBarBookmarkButton extends StatefulWidget {
  final int page;
  final Key? tutorialKey;
  const _TopBarBookmarkButton({required this.page, this.tutorialKey});

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
    final surahNumbers = kMushafPageToSurahs[widget.page];
    final actualSurahNumber = surahNumbers != null && surahNumbers.isNotEmpty
        ? surahNumbers.first
        : 1;
    final actualSurahName =
        actualSurahNumber >= 1 && actualSurahNumber <= _kSurahNames.length
        ? _kSurahNames[actualSurahNumber - 1]
        : '';
    final pageId = '$actualSurahNumber:page:${widget.page}';
    final isBookmarked = _bookmarkService.isBookmarked(pageId);

    return IconButton(
      onPressed: () async {
        if (isBookmarked) {
          await _bookmarkService.removeBookmark(pageId);
        } else {
          await _bookmarkService.addBookmark(
            id: pageId,
            reference: pageId,
            arabicText: 'صفحة ${_toArabicNum(widget.page)}',
            surahName: actualSurahName,
            surahNumber: actualSurahNumber,
            ayahNumber: null,
            pageNumber: widget.page,
          );
        }
        if (mounted) setState(() {});
      },
      key: widget.tutorialKey,
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

// ─── Recitation settings button for the Mushaf top bar ───────────────────────

class _TopBarRecitationSettingsButton extends StatelessWidget {
  final bool isDark;
  const _TopBarRecitationSettingsButton({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final color = isDark
        ? Colors.white.withValues(alpha: 0.65)
        : AppColors.primary.withValues(alpha: 0.55);
    return IconButton(
      onPressed: () => _showRecitationSettingsSheet(context),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 32),
      iconSize: 18,
      icon: Icon(Icons.tune_rounded, color: color, size: 18),
      tooltip: 'إعدادات التلاوة',
    );
  }
}

/// Opens the recitation settings bottom sheet.
void _showRecitationSettingsSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BlocProvider.value(
      value: context.read<AppSettingsCubit>(),
      child: const _RecitationSettingsSheet(),
    ),
  );
}

class _RecitationSettingsSheet extends StatelessWidget {
  const _RecitationSettingsSheet();

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
        final titleStyle = GoogleFonts.cairo(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: textColor,
        );
        final labelStyle = GoogleFonts.cairo(
          fontSize: 14,
          color: textColor,
        );
        final noteStyle = GoogleFonts.cairo(
          fontSize: 11,
          color: subTextColor,
        );

        return SafeArea(
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Container(
              decoration: BoxDecoration(
                color: bg,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
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
                  // Title
                  Text('إعدادات التلاوة', style: titleStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Divider(color: dividerColor, height: 1),
                  const SizedBox(height: 12),

                  // ── القارئ ────────────────────────────────────────────────
                  _RsReciterRow(labelStyle: labelStyle, subTextColor: subTextColor),
                  const SizedBox(height: 12),
                  Divider(color: dividerColor, height: 1),
                  const SizedBox(height: 12),

                  // ── تلاوة كلمة بكلمة (معطلة في هذا المصحف) ───────────────
                  Opacity(
                    opacity: 0.45,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('تلاوة كلمة بكلمة', style: labelStyle),
                              Text(
                                'يتطلب تفعيل عرض المصحف الشريف',
                                style: noteStyle,
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: false,
                          onChanged: null,
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
                  ),
                  const SizedBox(height: 12),
                  Divider(color: dividerColor, height: 1),
                  const SizedBox(height: 12),

                  // ── تكملة التلاوة ─────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Text('تكملة التلاوة عند الضغط', style: labelStyle),
                      ),
                      Switch(
                        value: settings.mushafContinueTilawa,
                        onChanged: (v) =>
                            ctx.read<AppSettingsCubit>().setMushafContinueTilawa(v),
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
                          label: Text('إلى نهاية الصفحة',
                              style: GoogleFonts.cairo(fontSize: 12)),
                        ),
                        ButtonSegment(
                          value: 'surah',
                          label: Text('إلى نهاية السورة',
                              style: GoogleFonts.cairo(fontSize: 12)),
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
                              ? AppColors.primary.withValues(alpha: isDark ? 0.30 : 0.12)
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

/// Reciter row inside the recitation settings sheet — shows the current
/// reciter's name and an inline "تغيير" button that opens the full picker.
class _RsReciterRow extends StatefulWidget {
  final TextStyle labelStyle;
  final Color subTextColor;
  const _RsReciterRow({required this.labelStyle, required this.subTextColor});

  @override
  State<_RsReciterRow> createState() => _RsReciterRowState();
}

class _RsReciterRowState extends State<_RsReciterRow> {
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

  Future<void> _showPicker() async {
    final editions = await _editionsFuture;
    if (!mounted) return;
    final currentEdition = _offlineAudio.edition;
    final settings = context.read<AppSettingsCubit>().state;
    final isAr = settings.appLanguageCode.toLowerCase().startsWith('ar');
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MushafReciterPickerSheet(
        all: editions,
        currentEdition: currentEdition,
        isAr: isAr,
        onSelected: (identifier) async {
          await _offlineAudio.setEdition(identifier);
          if (mounted) {
            try {
              context.read<AyahAudioCubit>().stop();
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
    return FutureBuilder<List<AudioEdition>>(
      future: _editionsFuture,
      builder: (ctx, snap) {
        final currentId = _offlineAudio.edition;
        final edition = snap.data
            ?.where((e) => e.identifier == currentId)
            .cast<AudioEdition?>()
            .firstOrNull;
        final settings = ctx.read<AppSettingsCubit>().state;
        final isAr = settings.appLanguageCode.toLowerCase().startsWith('ar');
        final name = edition?.displayNameForAppLanguage(isAr ? 'ar' : 'en') ??
            currentId;
        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('القارئ', style: widget.labelStyle),
                  Text(name,
                      style: widget.labelStyle.copyWith(
                        color: widget.subTextColor,
                        fontSize: 12,
                      )),
                ],
              ),
            ),
            TextButton(
              onPressed: _showPicker,
              child: Text(
                'تغيير',
                style: GoogleFonts.cairo(
                  color: AppColors.secondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A compact reciter picker for the Mushaf settings sheet.
class _MushafReciterPickerSheet extends StatefulWidget {
  final List<AudioEdition> all;
  final String currentEdition;
  final bool isAr;
  final Future<void> Function(String identifier) onSelected;

  const _MushafReciterPickerSheet({
    required this.all,
    required this.currentEdition,
    required this.isAr,
    required this.onSelected,
  });

  @override
  State<_MushafReciterPickerSheet> createState() =>
      _MushafReciterPickerSheetState();
}

class _MushafReciterPickerSheetState
    extends State<_MushafReciterPickerSheet> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentEdition;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);

    // Arabic reciters first, others after.
    final arReciters = widget.all.where((e) => e.language == 'ar').toList();
    final others = widget.all.where((e) => e.language != 'ar').toList();
    final ordered = [...arReciters, ...others];

    return SafeArea(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
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
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  'اختر القارئ',
                  style: GoogleFonts.cairo(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
              const Divider(height: 1),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.55,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: ordered.length,
                  itemBuilder: (ctx, i) {
                    final e = ordered[i];
                    final name = e.displayNameForAppLanguage(
                        widget.isAr ? 'ar' : 'en');
                    final isSelected = e.identifier == _selected;
                    return ListTile(
                      title: Text(
                        name,
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          color: isSelected
                              ? AppColors.secondary
                              : textColor,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_rounded,
                              color: AppColors.secondary, size: 18)
                          : null,
                      onTap: () async {
                        setState(() => _selected = e.identifier);
                        await widget.onSelected(e.identifier);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Mushaf footer (matches MushafPageView._buildDecorativeFooter style) ──────

class _MushafFooter extends StatelessWidget {
  final int page;
  final bool isDark;
  const _MushafFooter({super.key, required this.page, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
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
                  style: GoogleFonts.cairo(
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
  final int page;
  final int? focusSurahNumber;
  final int? focusAyahNumber;
  final bool tajweedMode;
  final Map<String, String>? tajweedTexts;
  final bool tajweedLoading;

  const _PageText({
    required this.verses,
    required this.page,
    this.focusSurahNumber,
    this.focusAyahNumber,
    this.tajweedMode = false,
    this.tajweedTexts,
    this.tajweedLoading = false,
  });

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

  /// Play a single ayah or a range based on the continue-recitation setting.
  void _playVerse(
    AyahAudioCubit cubit,
    AppSettingsState settings,
    int surahNumber,
    int ayahNumber,
  ) {
    if (settings.mushafContinueTilawa) {
      if (settings.mushafContinueScope == 'surah') {
        final idx = surahNumber - 1;
        final totalAyahs =
            idx >= 0 && idx < _kSurahAyahCounts.length
                ? _kSurahAyahCounts[idx]
                : ayahNumber;
        cubit.playAyahRange(
          surahNumber: surahNumber,
          startAyah: ayahNumber,
          endAyah: totalAyahs,
        );
      } else {
        // 'page' scope: to end of same surah on this page
        final sameOnPage = widget.verses
            .where((vv) => vv.surah == surahNumber)
            .toList();
        final endAyah = sameOnPage.isNotEmpty
            ? sameOnPage.last.ayah
            : ayahNumber;
        cubit.playAyahRange(
          surahNumber: surahNumber,
          startAyah: ayahNumber,
          endAyah: endAyah,
        );
      }
    } else {
      cubit.togglePlayAyah(
        surahNumber: surahNumber,
        ayahNumber: ayahNumber,
      );
    }
  }

  void _openTafsir(_Verse v) {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    final name = v.surah < _kSurahNames.length ? _kSurahNames[v.surah] : '';
    final bookmarkId = 'surah_${v.surah}_ayah_${v.ayah}';
    _showVerseOptionsSheet(
      context,
      surah: v.surah,
      verse: v.ayah,
      surahName: name,
      arabicText: v.text,
      bookmarkId: bookmarkId,
      bookmarkService: di.sl<BookmarkService>(),
      onTafsir: () {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BlocProvider(
              create: (_) => di.sl<TafsirCubit>(),
              child: TafsirScreen(
                surahNumber: v.surah,
                ayahNumber: v.ayah,
                surahName: name,
                surahEnglishName: '',
                arabicAyahText: v.text,
              ),
            ),
          ),
        );
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
            final isDark = settings.darkMode;
            final textColor = isDark
                ? const Color(0xFFE8E8E8)
                : const Color(0xFF1A1A1A);

            final baseStyle = ArabicTextStyleHelper.quranFontStyle(
              fontKey: settings.quranFont,
              fontSize: settings.arabicFontSize,
              fontWeight: FontWeight.w500,
              color: textColor,
              height: 2.2,
            );

            final highlightColor = AppColors.secondary.withValues(alpha: 0.28);

            final playKey =
                (audioState.hasTarget &&
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

            // Show a subtle tajweed loading indicator when data is being fetched.
            if (widget.tajweedMode && widget.tajweedLoading) {
              children.add(
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 12, height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: isDark
                              ? const Color(0xFF69F0AE)
                              : const Color(0xFF169200),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'جارٍ تحميل ألوان التجويد…',
                        style: GoogleFonts.cairo(
                          fontSize: 10,
                          color: isDark
                              ? const Color(0xFF69F0AE).withValues(alpha: 0.7)
                              : const Color(0xFF169200).withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            for (final section in sections) {
              // Show decorative surah header whenever ayah 1 appears.
              if (section.entries.isNotEmpty &&
                  section.entries.first.verse.ayah == 1) {
                children.add(
                  _SurahHeader(surahNum: section.surahNum, isDark: isDark),
                );
              }
              // Show Basmala before ayah 1 of every surah except Al-Fatiha (1)
              // and At-Tawba (9) which has no Basmala.
              if (section.entries.isNotEmpty &&
                  section.entries.first.verse.ayah == 1 &&
                  section.surahNum != 1 &&
                  section.surahNum != 9) {
                children.add(_Basmala(
                  isDark: isDark,
                  quranFont: settings.quranFont,
                  useQcfFont: settings.useQcfFont,
                  page: widget.page,
                ));
              }

              // Whether we showed a basmala header for this section.
              // If yes, strip the embedded basmala from verse 1's text.
              final bool hasBasmalaHeader =
                  section.entries.isNotEmpty &&
                  section.entries.first.verse.ayah == 1 &&
                  section.surahNum != 1 &&
                  section.surahNum != 9;

              // All verses in this section flow as a single justified RichText
              // so that text wraps naturally across the full line width —
              // exactly like a real Mushaf page.
              final spans = <InlineSpan>[];
              for (final entry in section.entries) {
                final v = entry.verse;
                final isActive = '${v.surah}:${v.ayah}' == playKey;
                final isBookmarkFocus =
                    widget.focusAyahNumber != null &&
                    v.surah == widget.focusSurahNumber &&
                    v.ayah == widget.focusAyahNumber;

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
                    _playVerse(cubit, settings, capturedVerse.surah, capturedVerse.ayah);
                  };
                _recognizers.add(tapRec);

                final displayText = (hasBasmalaHeader && v.ayah == 1)
                    ? _stripBasmalaPrefix(v.text)
                    : v.text;

                // Determine if tajweed coloured rendering applies to this verse.
                String? tajweedRaw;
                if (widget.tajweedMode && widget.tajweedTexts != null) {
                  tajweedRaw = widget.tajweedTexts!['${v.surah}:${v.ayah}'];
                }
                final bool useTajweed = tajweedRaw != null &&
                    tajweedRaw.isNotEmpty &&
                    hasTajweedMarkers(tajweedRaw);

                final bgColor = isActive
                    ? highlightColor
                    : isBookmarkFocus
                    ? const Color(0xFFFFD700).withValues(alpha: 0.30)
                    : null;

                if (useTajweed) {
                  // Tajweed mode: render each segment with its rule colour.
                  final rawText = tajweedRaw;
                  final tajweedDisplay = (hasBasmalaHeader && v.ayah == 1)
                      ? _stripBasmalaPrefix(rawText)
                      : rawText;
                  final tajweedSpans = buildTajweedSpans(
                    text: '$tajweedDisplay ',
                    baseStyle: baseStyle.copyWith(backgroundColor: bgColor),
                    isDark: isDark,
                  );
                  spans.add(
                    TextSpan(
                      children: tajweedSpans,
                      recognizer: tapRec,
                    ),
                  );
                } else {
                  // Normal rendering (or tajweed data not yet loaded).
                  spans.add(
                    TextSpan(
                      text: '$displayText ',
                      style: baseStyle.copyWith(backgroundColor: bgColor),
                      recognizer: tapRec,
                    ),
                  );
                }

                // Inline ayah marker — tap to play, long-press for options.
                spans.add(
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _AyahMarker(
                        number: v.ayah,
                        isDark: isDark,
                        quranFontSize: settings.arabicFontSize,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _playVerse(cubit, settings, v.surah, v.ayah);
                        },
                        onLongPress: () => _openTafsir(v),
                      ),
                    ),
                  ),
                );

                // Small space after each marker before the next verse begins.
                spans.add(TextSpan(text: ' ', style: baseStyle));
              }

              // GestureDetector wraps the RichText so that a long-press on
              // the verse *text* (not just the marker circle) also opens the
              // options sheet.  onTapDown on each TextSpan's TapGestureRecognizer
              // fires first (setting _lastTouchedVerse), then the long-press
              // timer wins the gesture arena and calls this handler.
              children.add(
                GestureDetector(
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
                ),
              );
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
  final int idx;
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
    final isDiacritic =
        (cp >= 0x064B && cp <= 0x065F) ||
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
    final trailing =
        (cp2 >= 0x064B && cp2 <= 0x065F) ||
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
        final double w = portrait
            ? constraints.maxWidth * 0.95
            : constraints.maxWidth * 0.8;
        final double fs = portrait ? w * 0.075 : constraints.maxWidth * 0.05;
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
    final Color nameColor = isDark
        ? const Color(0xFFE8C46A)
        : const Color(0xFF3D2000);
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
  final String quranFont;
  final bool useQcfFont;
  final int page;
  const _Basmala({
    required this.isDark,
    required this.quranFont,
    required this.useQcfFont,
    required this.page,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDark ? const Color(0xFFD4A855) : AppColors.primary;
    if (useQcfFont) {
      // Use exact same font-size as QCF page so Basmala matches verse glyphs.
      final fontSize = getFontSize(page, context);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Text(
          ' \uFC41  \uFC42\uFC43\uFC44',
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontFamily: 'QCF_P001',
            package: 'qcf_quran',
            fontSize: fontSize,
            color: color,
            height: 2.0,
          ),
        ),
      );
    }
    // Regular Arabic font — matches the ayah text font the user selected.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Text(
        '\u0628\u0650\u0633\u0652\u0645\u0650 \u0671\u0644\u0644\u0651\u064e\u0647\u0650 \u0671\u0644\u0631\u0651\u064e\u062d\u0652\u0645\u064e\u0670\u0646\u0650 \u0671\u0644\u0631\u0651\u064e\u062d\u0650\u064a\u0645\u0650',
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        style: ArabicTextStyleHelper.quranFontStyle(
          fontKey: quranFont,
          fontSize: 22.0,
          color: color,
          height: 2.0,
        ),
      ),
    );
  }
}

// ─── Ayah number marker (same visual as mushaf_page_view) ────────────────────
class _AyahMarker extends StatelessWidget {
  final int number;
  final bool isDark;
  final double quranFontSize;
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
    final scale = (quranFontSize / 18.0).clamp(0.7, 2.0);
    final frameSize = 28.0 * scale;
    final numFontSize = number > 99
        ? 8.0 * scale
        : number > 9
        ? 10.0 * scale
        : 12.0 * scale;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            'assets/logo/files/transparent/frame.png',
            width: frameSize,
            height: frameSize,
            color: isDark ? Colors.white.withValues(alpha: 0.85) : null,
          ),
          Padding(
            padding: EdgeInsets.only(bottom: frameSize * 0.28),
            child: Text(
              _toArabicNum(number),
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: numFontSize,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppColors.primary,
                height: 1,
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
  const d = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  return n.toString().split('').map((c) => d[int.parse(c)]).join();
}

/// Ayah counts per surah (index 0 = surah 1).
const List<int> _kSurahAyahCounts = [
   7, 286, 200, 176, 120, 165, 206,  75, 129, 109, // 1-10
 123, 111,  43,  52,  99, 128, 111, 110,  98, 135, // 11-20
 112,  78, 118,  64,  77, 227,  93,  88,  69,  60, // 21-30
  34,  30,  73,  54,  45,  83, 182,  88,  75,  85, // 31-40
  54,  53,  89,  59,  37,  35,  38,  29,  18,  45, // 41-50
  60,  49,  62,  55,  78,  96,  29,  22,  24,  13, // 51-60
  14,  11,  11,  18,  12,  12,  30,  52,  52,  44, // 61-70
  28,  28,  20,  56,  40,  31,  50,  40,  46,  42, // 71-80
  29,  19,  36,  25,  22,  17,  19,  26,  30,  20, // 81-90
  15,  21,  11,   8,   8,  19,   5,   8,   8,  11, // 91-100
  11,   8,   3,   9,   5,   4,   7,   3,   6,   3, // 101-110
   5,   4,   5,   6,                               // 111-114
];

const _kSurahNames = [
  '',
  'الفاتحة',
  'البقرة',
  'آل عمران',
  'النساء',
  'المائدة',
  'الأنعام',
  'الأعراف',
  'الأنفال',
  'التوبة',
  'يونس',
  'هود',
  'يوسف',
  'الرعد',
  'إبراهيم',
  'الحجر',
  'النحل',
  'الإسراء',
  'الكهف',
  'مريم',
  'طه',
  'الأنبياء',
  'الحج',
  'المؤمنون',
  'النور',
  'الفرقان',
  'الشعراء',
  'النمل',
  'القصص',
  'العنكبوت',
  'الروم',
  'لقمان',
  'السجدة',
  'الأحزاب',
  'سبأ',
  'فاطر',
  'يس',
  'الصافات',
  'ص',
  'الزمر',
  'غافر',
  'فصلت',
  'الشورى',
  'الزخرف',
  'الدخان',
  'الجاثية',
  'الأحقاف',
  'محمد',
  'الفتح',
  'الحجرات',
  'ق',
  'الذاريات',
  'الطور',
  'النجم',
  'القمر',
  'الرحمن',
  'الواقعة',
  'الحديد',
  'المجادلة',
  'الحشر',
  'الممتحنة',
  'الصف',
  'الجمعة',
  'المنافقون',
  'التغابن',
  'الطلاق',
  'التحريم',
  'الملك',
  'القلم',
  'الحاقة',
  'المعارج',
  'نوح',
  'الجن',
  'المزمل',
  'المدثر',
  'القيامة',
  'الإنسان',
  'المرسلات',
  'النبأ',
  'النازعات',
  'عبس',
  'التكوير',
  'الانفطار',
  'المطففين',
  'الانشقاق',
  'البروج',
  'الطارق',
  'الأعلى',
  'الغاشية',
  'الفجر',
  'البلد',
  'الشمس',
  'الليل',
  'الضحى',
  'الشرح',
  'التين',
  'العلق',
  'القدر',
  'البينة',
  'الزلزلة',
  'العاديات',
  'القارعة',
  'التكاثر',
  'العصر',
  'الهمزة',
  'الفيل',
  'قريش',
  'الماعون',
  'الكوثر',
  'الكافرون',
  'النصر',
  'المسد',
  'الإخلاص',
  'الفلق',
  'الناس',
];
