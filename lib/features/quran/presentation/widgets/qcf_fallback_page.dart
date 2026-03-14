// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io' show HttpClient;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qcf_quran/qcf_quran.dart';

import '../../../../core/audio/ayah_audio_cubit.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/mushaf_page_map.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/services/bookmark_service.dart';
import '../../../../core/settings/app_settings_cubit.dart';
import '../../../../core/utils/arabic_text_style_helper.dart';
import '../bloc/tafsir/tafsir_cubit.dart';
import '../screens/tafsir_screen.dart';
import '../widgets/ayah_share_card.dart';

// ─── Configuration ─────────────────────────────────────────────────────────

/// Master switch for the QCF fallback renderer.
///
/// `true`  → Pages listed in [kQcfProblematicPages] render with the regular
///           Arabic text font instead of QCF glyphs, eliminating the overflow
///           / clipping bug that exists in those pages.
/// `false` → All pages render with QCF as normal. Set this to `false` when
///           you want to compare QCF vs fallback, or after you've verified a
///           proper QCF calibration fix covers all affected pages.
const bool kEnableQcfFallback = true;

/// Set of page numbers whose QCF font glyphs overflow their container.
///
/// These pages were omitted from the qcf_quran package's per-page font-size
/// calibration table, so they receive the default 23.1 px size even though
/// their glyph data was designed for a slightly smaller size. On a reference-
/// width (≈393 dp) phone the lines overflow and get clipped symmetrically on
/// both edges.
///
/// **To add or remove a page:** just edit the set literal below. No other
/// code change is needed; [QcfFallbackPage] is automatically used for every
/// page number present here (when [kEnableQcfFallback] is `true`).
const Set<int> kQcfProblematicPages = {
  377,
  387,
  498,
  504,
  510,
  523,
  530,
  535,
  555,
  579,
  591,
};

// ─── Internal data model ───────────────────────────────────────────────────

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

// ─── Disk cache (shares key-space with MushafPageScreen) ───────────────────

const String _kCachePrefix = 'qcf_fallback_page_v2_';

// The Uthmani text in the offline JSON (and quran.com API) prepends the Basmala
// to verse 1 of every surah except Al-Fatiha (1) and At-Tawbah (9).
// Strip it to avoid showing it twice alongside the QCF decorative header.

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

Future<List<_Verse>?> _loadFromCache(int page) async {
  try {
    final cached = _pageTextSessionCache[page];
    if (cached == null || cached.isEmpty) return null;
    return List<_Verse>.from(cached);
  } catch (_) {
    return null;
  }
}

Future<void> _saveToCache(int page, List<_Verse> verses) async {
  try {
    // Keep only a lightweight in-memory cache for this app session.
    // Writing full-page Quran text to SharedPreferences causes file bloat and
    // can trigger OOM on Android while codec serializes values.
    _pageTextSessionCache[page] = List<_Verse>.from(verses);
  } catch (_) {}
}

final Map<int, List<_Verse>> _pageTextSessionCache = <int, List<_Verse>>{};

Future<List<_Verse>> _loadFromBundledAssets(int page) async {
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
    } catch (_) {}
  }
  // Sort the results so they appear in correct Mushaf order (Surah -> Ayah)
  results.sort((a, b) {
    if (a.surah != b.surah) return a.surah.compareTo(b.surah);
    return a.ayah.compareTo(b.ayah);
  });
  return results;
}

Future<List<_Verse>> _fetchPage(int page) async {
  // 1. Disk cache (fastest, fully offline)
  final cached = await _loadFromCache(page);
  if (cached != null && cached.isNotEmpty) return cached;

  // 2. Bundled offline assets (always available, no internet needed)
  final bundled = await _loadFromBundledAssets(page);
  if (bundled.isNotEmpty) {
    _saveToCache(page, bundled);
    return bundled;
  }

  // 3. Network last resort
  try {
    final client = HttpClient();
    final request = await client.getUrl(
      Uri.parse(
        'https://api.quran.com/api/v4/verses/by_page/$page'
        '?fields=text_uthmani&per_page=50',
      ),
    );
    request.headers.set('Accept', 'application/json');
    final response = await request.close();
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    final body = await response.transform(const Utf8Decoder()).join();
    final data = jsonDecode(body) as Map<String, dynamic>;
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

    // In rare cases quran.com might disagree on page bounds such that an ayah is missing.
    // If it happens, we still save and return what we got.
    _saveToCache(page, verses);
    return verses;
  } catch (e) {
    throw Exception('Failed to load page $page: $e');
  }
}

// ─── Public widget ─────────────────────────────────────────────────────────

/// Renders a single Quran page using the regular Arabic text font instead of
/// QCF glyphs. This is immune to the QCF calibration overflow bug.
///
/// Appearance and interactions (long-press options, bookmark, tafsir, audio)
/// match the standard MushafPageScreen experience.
class QcfFallbackPage extends StatefulWidget {
  final int pageNumber;

  const QcfFallbackPage({super.key, required this.pageNumber});

  @override
  State<QcfFallbackPage> createState() => _QcfFallbackPageState();
}

class _QcfFallbackPageState extends State<QcfFallbackPage> {
  List<_Verse>? _verses;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(QcfFallbackPage old) {
    super.didUpdateWidget(old);
    if (old.pageNumber != widget.pageNumber) {
      setState(() {
        _verses = null;
        _loading = true;
        _error = null;
      });
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final verses = await _fetchPage(widget.pageNumber);
      if (mounted) {
        setState(() {
          _verses = verses;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<AppSettingsCubit, bool>(
      (c) => c.state.darkMode,
    );
    final bgColor = isDark ? const Color(0xFF0E1A12) : const Color(0xFFF5F0E4);

    if (_loading) {
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
                'جارٍ تحميل الصفحة ${widget.pageNumber}…',
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

    final verses = _verses;
    if (_error != null || verses == null || verses.isEmpty) {
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
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  _load();
                },
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        _FbTopBar(page: widget.pageNumber, verses: verses, isDark: isDark),
        Expanded(
          child: BlocBuilder<AyahAudioCubit, AyahAudioState>(
            builder: (ctx, audioState) {
              final playerVisible = audioState.status != AyahAudioStatus.idle;
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  playerVisible ? 220.0 : 8,
                ),
                child: _FbPageText(verses: verses),
              );
            },
          ),
        ),
        _FbFooter(page: widget.pageNumber, isDark: isDark),
      ],
    );
  }
}

// ─── Top bar ───────────────────────────────────────────────────────────────

class _FbTopBar extends StatelessWidget {
  final int page;
  final List<_Verse> verses;
  final bool isDark;

  const _FbTopBar({
    required this.page,
    required this.verses,
    required this.isDark,
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

  String get _juzLabel {
    final j = _juz;
    return j >= 1 && j <= 30 ? 'الجزء ${_kJuzNames[j - 1]}' : 'الجزء $j';
  }

  String get _surahLabel {
    if (verses.isEmpty) return '';
    final n = verses.first.surah;
    return n >= 1 && n <= _kSurahNames.length ? _kSurahNames[n - 1] : '';
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
        children: [
          _FbPlayButton(page: page, verses: verses),
          Expanded(
            child: Text(
              _juzLabel,
              style: labelStyle,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _surahLabel,
              style: labelStyle,
              textAlign: TextAlign.left,
              textDirection: TextDirection.rtl,
            ),
          ),
          _FbBookmarkButton(page: page),
        ],
      ),
    );
  }
}

// ─── Play button ───────────────────────────────────────────────────────────

class _FbPlayButton extends StatelessWidget {
  final int page;
  final List<_Verse> verses;
  const _FbPlayButton({required this.page, required this.verses});

  @override
  Widget build(BuildContext context) {
    if (verses.isEmpty) return const SizedBox(width: 32, height: 32);
    return BlocBuilder<AyahAudioCubit, AyahAudioState>(
      builder: (ctx, audioState) {
        final firstSurah = verses.first.surah;
        final sv = verses.where((v) => v.surah == firstSurah).toList();
        final startAyah = sv.first.ayah;
        final endAyah = sv.last.ayah;
        final isActive =
            audioState.surahNumber == firstSurah &&
            audioState.ayahNumber != null &&
            audioState.ayahNumber! >= startAyah &&
            audioState.ayahNumber! <= endAyah;
        final isPlaying =
            isActive && audioState.status == AyahAudioStatus.playing;
        final isPaused =
            isActive && audioState.status == AyahAudioStatus.paused;
        return IconButton(
          onPressed: () {
            final cubit = ctx.read<AyahAudioCubit>();
            if (isPlaying) {
              cubit.pause();
            } else if (isPaused) {
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
            isPlaying ? Icons.pause_circle : Icons.play_circle,
            color: (isPlaying || isPaused)
                ? AppColors.secondary
                : AppColors.primary.withValues(alpha: 0.6),
            size: 20,
          ),
        );
      },
    );
  }
}

// ─── Bookmark button ───────────────────────────────────────────────────────

class _FbBookmarkButton extends StatefulWidget {
  final int page;
  const _FbBookmarkButton({required this.page});

  @override
  State<_FbBookmarkButton> createState() => _FbBookmarkButtonState();
}

class _FbBookmarkButtonState extends State<_FbBookmarkButton> {
  late final BookmarkService _bm;

  @override
  void initState() {
    super.initState();
    _bm = di.sl<BookmarkService>();
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
    final isBookmarked = _bm.isBookmarked(pageId);
    return IconButton(
      onPressed: () async {
        if (isBookmarked) {
          await _bm.removeBookmark(pageId);
        } else {
          await _bm.addBookmark(
            id: pageId,
            reference: pageId,
            arabicText: 'صفحة ${widget.page}',
            surahName: actualSurahName,
            surahNumber: actualSurahNumber,
            ayahNumber: null,
            pageNumber: widget.page,
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

// ─── Footer ────────────────────────────────────────────────────────────────

class _FbFooter extends StatelessWidget {
  final int page;
  final bool isDark;
  const _FbFooter({required this.page, required this.isDark});

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

// ─── Page text ─────────────────────────────────────────────────────────────

class _SurahSection {
  final int surahNum;
  final List<_Verse> verses = [];
  _SurahSection(this.surahNum);
}

class _FbPageText extends StatefulWidget {
  final List<_Verse> verses;
  const _FbPageText({required this.verses});

  @override
  State<_FbPageText> createState() => _FbPageTextState();
}

class _FbPageTextState extends State<_FbPageText> {
  final List<GestureRecognizer> _recognizers = [];
  _Verse? _lastTouched;

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  void _openOptions(_Verse v) {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    final name = v.surah >= 1 && v.surah <= _kSurahNames.length
        ? _kSurahNames[v.surah - 1]
        : '';
    final bookmarkId = 'surah_${v.surah}_ayah_${v.ayah}';
    _showFbVerseOptionsSheet(
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

            for (final r in _recognizers) {
              r.dispose();
            }
            _recognizers.clear();

            // Group by surah
            final sections = <_SurahSection>[];
            for (final v in widget.verses) {
              if (sections.isEmpty || sections.last.surahNum != v.surah) {
                sections.add(_SurahSection(v.surah));
              }
              sections.last.verses.add(v);
            }

            final children = <Widget>[];
            for (final section in sections) {
              if (section.verses.isNotEmpty &&
                  section.verses.first.ayah == 1 &&
                  section.surahNum != 1 &&
                  section.surahNum != 9) {
                children.add(
                  _FbSurahHeader(surahNum: section.surahNum, isDark: isDark),
                );
              }

              // Whether we showed a basmala header for this section.
              // If yes, strip the embedded basmala from verse 1's text.
              final bool hasBasmalaHeader =
                  section.verses.isNotEmpty &&
                  section.verses.first.ayah == 1 &&
                  section.surahNum != 1 &&
                  section.surahNum != 9;

              final spans = <InlineSpan>[];
              final sectionFirstVerse = section.verses.first;

              for (final v in section.verses) {
                final isHighlighted = playKey == v.verseKey;
                // onTapDown fires immediately on pointer-down (before the
                // gesture arena resolves) — so _lastTouched is always set
                // by the time GestureDetector.onLongPress fires below.
                final tap = TapGestureRecognizer()
                  ..onTapDown = (_) {
                    _lastTouched = v;
                  }
                  ..onTap = () {
                    final cubit = ctx.read<AyahAudioCubit>();
                    if (audioState.surahNumber == v.surah &&
                        audioState.ayahNumber == v.ayah &&
                        audioState.status == AyahAudioStatus.playing) {
                      cubit.pause();
                    } else {
                      cubit.playAyah(surahNumber: v.surah, ayahNumber: v.ayah);
                    }
                  };
                _recognizers.add(tap);

                // QCF verse-number glyph from the page's own font family
                final verseNumGlyph = getVerseNumberQCF(v.surah, v.ayah);
                final versePage = getPageNumber(v.surah, v.ayah);
                final versePageFont =
                    'QCF_P${versePage.toString().padLeft(3, '0')}';
                final verseNumColor = isHighlighted
                    ? AppColors.secondary
                    : (isDark ? const Color(0xFFC8A84B) : AppColors.primary);

                final displayText = (hasBasmalaHeader && v.ayah == 1)
                    ? _stripBasmalaPrefix(v.text)
                    : v.text;

                spans.add(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: displayText,
                        recognizer: tap,
                        style: baseStyle.copyWith(
                          backgroundColor: isHighlighted
                              ? highlightColor
                              : Colors.transparent,
                        ),
                      ),
                      TextSpan(
                        text: verseNumGlyph,
                        style: TextStyle(
                          fontFamily: versePageFont,
                          package: 'qcf_quran',
                          fontSize: baseStyle.fontSize,
                          color: verseNumColor,
                          height: baseStyle.height,
                        ),
                      ),
                      const TextSpan(text: ' '),
                    ],
                  ),
                );
              }

              // Long-press is handled at section level so it works even when
              // the finger lands between words. GestureDetector adds a
              // LongPressGestureRecognizer that competes in the arena with
              // each TextSpan's TapGestureRecognizer; for long presses the
              // tap recognizer times out and this one wins.
              children.add(
                GestureDetector(
                  onLongPress: () {
                    _openOptions(_lastTouched ?? sectionFirstVerse);
                  },
                  child: Text.rich(
                    TextSpan(children: spans),
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.justify,
                    style: baseStyle,
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

// ─── Surah header ──────────────────────────────────────────────────────────

/// Decorative QCF surah header using [HeaderWidget] from the qcf_quran package.
///
/// Light mode: [HeaderWidget] renders natively with [QcfThemeData.headerTextColor].
/// Dark mode: [QcfThemeData.customHeaderBuilder] overrides the rendering so the
/// decorative mainframe image is colour-blended to match the dark background
/// while preserving all ornamental detail.
/// The QCF basmala glyph (QCF_P001) is shown below for all surahs except 9.
class _FbSurahHeader extends StatelessWidget {
  final int surahNum;
  final bool isDark;

  const _FbSurahHeader({required this.surahNum, required this.isDark});

  // Used as QcfThemeData.customHeaderBuilder in dark mode.
  // Receives the surah number from HeaderWidget and returns a tinted frame.
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
                // Tint the cream frame to dark-green so ornamental borders and
                // flower patterns stay legible on a dark background.
                color: const Color.fromARGB(255, 43, 63, 48),
                colorBlendMode: BlendMode.color,
              ),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  text: 'surah${num.toString().padLeft(3, '0')}',
                  style: const TextStyle(
                    fontFamily: SurahFontHelper.fontFamily,
                    package: 'qcf_quran',
                    fontSize: 0, // overridden below via fontSize on style
                    color: nameColor,
                  ).copyWith(fontSize: fs),
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
    final Color basmalaColor = isDark
        ? const Color(0xFFD4AF37)
        : AppColors.primary.withValues(alpha: 0.9);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // QCF decorative surah-name frame
        HeaderWidget(
          suraNumber: surahNum,
          theme: QcfThemeData(
            headerTextColor: nameColor,
            // Dark mode needs custom rendering to tint the image.
            customHeaderBuilder: isDark ? _darkFrame : null,
          ),
        ),
        // QCF basmala glyph
        if (surahNum != 9)
          Text.rich(
            TextSpan(
              text: ' ﱁ  ﱂﱃﱄ',
              style: TextStyle(
                fontFamily: 'QCF_P001',
                package: 'qcf_quran',
                fontSize: 18,
                color: basmalaColor,
              ),
            ),
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
          ),
      ],
    );
  }
}

// ─── Verse options sheet ───────────────────────────────────────────────────

void _showFbVerseOptionsSheet(
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
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
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

// ─── Helpers ───────────────────────────────────────────────────────────────

String _toArabicNum(int n) {
  const digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  return n.toString().split('').map((d) {
    final i = int.tryParse(d);
    return i != null ? digits[i] : d;
  }).join();
}

const List<String> _kSurahNames = [
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
