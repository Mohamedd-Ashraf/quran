// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qcf_quran_plus/qcf_quran_plus.dart'
    show getPageData, getSurahNameArabic, QuranTextStyles;

import '../../../../core/audio/ayah_audio_cubit.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/mushaf_page_map.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/services/audio_edition_service.dart';
import '../../../../core/services/bookmark_service.dart';
import '../../../../core/services/offline_audio_service.dart';
import '../../../../core/settings/app_settings_cubit.dart';
import '../../../../core/utils/arabic_text_style_helper.dart';
import '../../../wird/data/quran_boundaries.dart';
import '../bloc/tafsir/tafsir_cubit.dart';
import '../screens/tafsir_screen.dart';
import '../widgets/ayah_share_card.dart';

// â”€â”€â”€ Internal data model â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

// â”€â”€â”€ Page verse loader â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

// ─── Basmala strip ──────────────────────────────────────────────────────────

/// Strips the leading Basmala from [text] if present.
/// Comparison ignores all diacritics and normalises Alef-wasla → Alef.
String _stripBasmalaPrefix(String text) {
  const String kBase = 'بسم الله الرحمن الرحيم';
  String normalise(String s) => s
      .replaceAll(
        RegExp(
          r'[\u064B-\u065F\u0670\u06D6-\u06DC\u06DF-\u06E4\u06E7\u06E8\u06EA-\u06ED]',
        ),
        '',
      )
      .replaceAll('\u0671', '\u0627');
  if (!normalise(text).startsWith(kBase)) return text;
  int origIdx = 0, normCount = 0;
  while (origIdx < text.length && normCount < kBase.length) {
    final cp = text.codeUnitAt(origIdx);
    final isDiac = (cp >= 0x064B && cp <= 0x065F) || cp == 0x0670 ||
        (cp >= 0x06D6 && cp <= 0x06DC) || (cp >= 0x06DF && cp <= 0x06E4) ||
        cp == 0x06E7 || cp == 0x06E8 || (cp >= 0x06EA && cp <= 0x06ED);
    if (!isDiac) normCount++;
    origIdx++;
  }
  while (origIdx < text.length) {
    final cp2 = text.codeUnitAt(origIdx);
    final trail = (cp2 >= 0x064B && cp2 <= 0x065F) || cp2 == 0x0670 ||
        (cp2 >= 0x06D6 && cp2 <= 0x06DC) || (cp2 >= 0x06DF && cp2 <= 0x06E4) ||
        cp2 == 0x06E7 || cp2 == 0x06E8 || (cp2 >= 0x06EA && cp2 <= 0x06ED);
    if (!trail) break;
    origIdx++;
  }
  return text.substring(origIdx).trimLeft();
}

// ─── Page verse loader ────────────────────────────────────────────────────────

/// In-session cache: navigating back to the same page is instant.
final Map<int, List<_Verse>> _pageTextSessionCache = {};

/// Loads Uthmani Arabic text for all verses on [page] from bundled offline
/// JSON assets (`assets/offline/surah_X.json`).
/// Always offline-capable; returns empty list on any error.
Future<List<_Verse>> _fetchPageVerses(int page) async {
  if (_pageTextSessionCache.containsKey(page)) {
    return _pageTextSessionCache[page]!;
  }
  final List<dynamic> pageData;
  try {
    pageData = getPageData(page);
  } catch (_) {
    return [];
  }
  final surahNums = pageData
      .map((e) => int.parse((e as Map)['surah'].toString()))
      .toSet()
      .toList()
    ..sort();

  final results = <_Verse>[];
  for (final surahNum in surahNums) {
    try {
      final raw =
          await rootBundle.loadString('assets/offline/surah_$surahNum.json');
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final ayahs = data['ayahs'] as List<dynamic>;
      for (final ayah in ayahs) {
        final ayahNum = ayah['numberInSurah'] as int;
        bool inRange = false;
        for (final r in pageData) {
          final bounds = r as Map;
          if (int.parse(bounds['surah'].toString()) == surahNum &&
              ayahNum >= int.parse(bounds['start'].toString()) &&
              ayahNum <= int.parse(bounds['end'].toString())) {
            inRange = true;
            break;
          }
        }
        if (inRange) {
          results.add(_Verse(
            verseKey: '$surahNum:$ayahNum',
            surah: surahNum,
            ayah: ayahNum,
            text: (ayah['text'] as String?) ?? '',
          ));
        }
      }
    } catch (_) {}
  }
  results.sort((a, b) {
    if (a.surah != b.surah) return a.surah.compareTo(b.surah);
    return a.ayah.compareTo(b.ayah);
  });
  _pageTextSessionCache[page] = results;
  return results;
}

// â”€â”€â”€ Public widget â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

/// Renders a single Quran page using Amiri Quran font when the QCF tajweed
/// font for that page has not yet been downloaded.
///
/// Matches the full-featured MushafPageScreen experience:
/// tap to play audio, long-press for options (bookmark / share / tafsir),
/// recitation settings, page bookmark, surah header with basmala.
class QcfFallbackPage extends StatefulWidget {
  final int pageNumber;
  final bool isDarkMode;

  const QcfFallbackPage({
    super.key,
    required this.pageNumber,
    this.isDarkMode = false,
  });

  @override
  State<QcfFallbackPage> createState() => _QcfFallbackPageState();
}

class _QcfFallbackPageState extends State<QcfFallbackPage> {
  List<_Verse> _verses = [];
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
      setState(() { _verses = []; _loading = true; _error = null; });
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final verses = await _fetchPageVerses(widget.pageNumber);
      if (mounted) setState(() { _verses = verses; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bgColor = isDark ? const Color(0xFF0E1A12) : const Color(0xFFF5F0E4);

    if (_loading) {
      return Container(
        color: bgColor,
        child: const Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 3,
          ),
        ),
      );
    }

    if (_error != null || _verses.isEmpty) {
      return Container(color: bgColor);
    }

    return Column(
      children: [
        _FbTopBar(page: widget.pageNumber, verses: _verses, isDark: isDark),
        Expanded(
          child: BlocBuilder<AyahAudioCubit, AyahAudioState>(
            builder: (ctx, audioState) {
              final playerVisible = audioState.status != AyahAudioStatus.idle;
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: EdgeInsets.fromLTRB(
                  16, 8, 16,
                  playerVisible ? 220.0 : 8,
                ),
                child: _FbPageText(
                  verses: _verses,
                  page: widget.pageNumber,
                ),
              );
            },
          ),
        ),
        _FbFooter(page: widget.pageNumber, isDark: isDark),
      ],
    );
  }
}

// â”€â”€â”€ Top bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
    'Ø§Ù„Ø£ÙˆÙ„','Ø§Ù„Ø«Ø§Ù†ÙŠ','Ø§Ù„Ø«Ø§Ù„Ø«','Ø§Ù„Ø±Ø§Ø¨Ø¹','Ø§Ù„Ø®Ø§Ù…Ø³',
    'Ø§Ù„Ø³Ø§Ø¯Ø³','Ø§Ù„Ø³Ø§Ø¨Ø¹','Ø§Ù„Ø«Ø§Ù…Ù†','Ø§Ù„ØªØ§Ø³Ø¹','Ø§Ù„Ø¹Ø§Ø´Ø±',
    'Ø§Ù„Ø­Ø§Ø¯ÙŠ Ø¹Ø´Ø±','Ø§Ù„Ø«Ø§Ù†ÙŠ Ø¹Ø´Ø±','Ø§Ù„Ø«Ø§Ù„Ø« Ø¹Ø´Ø±','Ø§Ù„Ø±Ø§Ø¨Ø¹ Ø¹Ø´Ø±','Ø§Ù„Ø®Ø§Ù…Ø³ Ø¹Ø´Ø±',
    'Ø§Ù„Ø³Ø§Ø¯Ø³ Ø¹Ø´Ø±','Ø§Ù„Ø³Ø§Ø¨Ø¹ Ø¹Ø´Ø±','Ø§Ù„Ø«Ø§Ù…Ù† Ø¹Ø´Ø±','Ø§Ù„ØªØ§Ø³Ø¹ Ø¹Ø´Ø±','Ø§Ù„Ø¹Ø´Ø±ÙˆÙ†',
    'Ø§Ù„Ø­Ø§Ø¯ÙŠ ÙˆØ§Ù„Ø¹Ø´Ø±ÙˆÙ†','Ø§Ù„Ø«Ø§Ù†ÙŠ ÙˆØ§Ù„Ø¹Ø´Ø±ÙˆÙ†','Ø§Ù„Ø«Ø§Ù„Ø« ÙˆØ§Ù„Ø¹Ø´Ø±ÙˆÙ†','Ø§Ù„Ø±Ø§Ø¨Ø¹ ÙˆØ§Ù„Ø¹Ø´Ø±ÙˆÙ†',
    'Ø§Ù„Ø®Ø§Ù…Ø³ ÙˆØ§Ù„Ø¹Ø´Ø±ÙˆÙ†','Ø§Ù„Ø³Ø§Ø¯Ø³ ÙˆØ§Ù„Ø¹Ø´Ø±ÙˆÙ†','Ø§Ù„Ø³Ø§Ø¨Ø¹ ÙˆØ§Ù„Ø¹Ø´Ø±ÙˆÙ†','Ø§Ù„Ø«Ø§Ù…Ù† ÙˆØ§Ù„Ø¹Ø´Ø±ÙˆÙ†',
    'Ø§Ù„ØªØ§Ø³Ø¹ ÙˆØ§Ù„Ø¹Ø´Ø±ÙˆÙ†','Ø§Ù„Ø«Ù„Ø§Ø«ÙˆÙ†',
  ];

  int get _juz => ((page - 1) ~/ 20).clamp(0, 29) + 1;

  String get _juzLabel {
    final j = _juz;
    return j >= 1 && j <= 30 ? 'Ø§Ù„Ø¬Ø²Ø¡ ${_kJuzNames[j - 1]}' : 'Ø§Ù„Ø¬Ø²Ø¡ $j';
  }

  String get _surahLabel {
    if (verses.isEmpty) return '';
    final n = verses.first.surah;
    try { return getSurahNameArabic(n); } catch (_) { return ''; }
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
      fontSize: 12, fontWeight: FontWeight.w700, color: textColor,
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
          _FbRecitationSettingsButton(isDark: isDark),
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

// â”€â”€â”€ Play button â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
        final endAyah   = sv.last.ayah;
        final isActive =
            audioState.surahNumber == firstSurah &&
            audioState.ayahNumber != null &&
            audioState.ayahNumber! >= startAyah &&
            audioState.ayahNumber! <= endAyah;
        final isPlaying = isActive && audioState.status == AyahAudioStatus.playing;
        final isPaused  = isActive && audioState.status == AyahAudioStatus.paused;

        return IconButton(
          onPressed: () {
            final cubit = ctx.read<AyahAudioCubit>();
            if (isPlaying)      cubit.pause();
            else if (isPaused)  cubit.resume();
            else cubit.playAyahRange(
              surahNumber: firstSurah,
              startAyah: startAyah,
              endAyah: endAyah,
            );
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

// â”€â”€â”€ Bookmark button â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
    final actualSurahNumber = (surahNumbers != null && surahNumbers.isNotEmpty)
        ? surahNumbers.first : 1;
    String actualSurahName = '';
    try { actualSurahName = getSurahNameArabic(actualSurahNumber); } catch (_) {}
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
            arabicText: 'ØµÙØ­Ø© ${widget.page}',
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
        color: AppColors.secondary, size: 20,
      ),
    );
  }
}

// â”€â”€â”€ Footer â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
                    fontSize: 14, fontWeight: FontWeight.w700,
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

// â”€â”€â”€ Page text â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _SurahSection {
  final int surahNum;
  final List<_Verse> verses = [];
  _SurahSection(this.surahNum);
}

class _FbPageText extends StatefulWidget {
  final List<_Verse> verses;
  final int page;
  const _FbPageText({required this.verses, required this.page});

  @override
  State<_FbPageText> createState() => _FbPageTextState();
}

class _FbPageTextState extends State<_FbPageText> {
  final List<GestureRecognizer> _recognizers = [];
  _Verse? _lastTouched;

  @override
  void dispose() {
    for (final r in _recognizers) { r.dispose(); }
    super.dispose();
  }

  void _openOptions(_Verse v) {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    String name = '';
    try { name = getSurahNameArabic(v.surah); } catch (_) {}
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

            for (final r in _recognizers) { r.dispose(); }
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
              // Show decorative header only when verse 1 is present, and not
              // for Al-Fatiha (basmala IS verse 1) or At-Tawbah (has no basmala).
              final bool showHeader = section.verses.isNotEmpty &&
                  section.verses.first.ayah == 1 &&
                  section.surahNum != 1 &&
                  section.surahNum != 9;
              if (showHeader) {
                children.add(
                  _FbSurahHeader(surahNum: section.surahNum, isDark: isDark),
                );
              }

              final spans = <InlineSpan>[];
              final sectionFirstVerse = section.verses.first;

              for (final v in section.verses) {
                final isHighlighted = playKey == v.verseKey;

                final tap = TapGestureRecognizer()
                  ..onTapDown = (_) { _lastTouched = v; }
                  ..onTap = () {
                    final cubit = ctx.read<AyahAudioCubit>();
                    if (audioState.surahNumber == v.surah &&
                        audioState.ayahNumber == v.ayah &&
                        (audioState.status == AyahAudioStatus.playing ||
                         audioState.status == AyahAudioStatus.paused)) {
                      if (audioState.status == AyahAudioStatus.playing) {
                        cubit.pause();
                      } else {
                        cubit.resume();
                      }
                      return;
                    }
                    final s = ctx.read<AppSettingsCubit>().state;
                    if (s.mushafContinueTilawa) {
                      if (s.mushafContinueScope == 'surah') {
                        final idx = v.surah - 1;
                        final totalAyahs =
                            (idx >= 0 && idx < kSurahAyahCounts.length)
                                ? kSurahAyahCounts[idx]
                                : v.ayah;
                        cubit.playAyahRange(
                          surahNumber: v.surah,
                          startAyah: v.ayah,
                          endAyah: totalAyahs,
                        );
                      } else {
                        final endAyah = widget.verses
                            .where((vv) => vv.surah == v.surah)
                            .fold<int>(v.ayah, (last, vv) => vv.ayah > last ? vv.ayah : last);
                        cubit.playAyahRange(
                          surahNumber: v.surah,
                          startAyah: v.ayah,
                          endAyah: endAyah,
                        );
                      }
                    } else {
                      cubit.playAyah(surahNumber: v.surah, ayahNumber: v.ayah);
                    }
                  };
                _recognizers.add(tap);

                // Strip basmala from verse 1 when the decorative header shows it.
                final displayText = (showHeader && v.ayah == 1)
                    ? _stripBasmalaPrefix(v.text)
                    : v.text;

                final verseNumColor = isHighlighted
                    ? AppColors.secondary
                    : (isDark
                        ? const Color(0xFFC8A84B)
                        : AppColors.primary);

                spans.add(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$displayText ',
                        recognizer: tap,
                        style: baseStyle.copyWith(
                          backgroundColor: isHighlighted
                              ? highlightColor
                              : Colors.transparent,
                        ),
                      ),
                      // Arabic verse-end marker (U+06DD) + Arabic-Indic numeral
                      TextSpan(
                        text: '\u06DD${_toArabicNum(v.ayah)} ',
                        style: baseStyle.copyWith(
                          color: verseNumColor,
                          fontSize: (baseStyle.fontSize ?? 18) * 0.75,
                          backgroundColor: Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                );
              }

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

// â”€â”€â”€ Surah header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _FbSurahHeader extends StatelessWidget {
  final int surahNum;
  final bool isDark;

  const _FbSurahHeader({required this.surahNum, required this.isDark});

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
        // â”€â”€ Surah ornamental banner (qcf_quran_plus arsura font) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        LayoutBuilder(
          builder: (ctx, constraints) {
            final double w = constraints.maxWidth * 0.9;
            final double fs = w * 0.085;
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              width: double.infinity,
              alignment: Alignment.center,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image(
                    image: const AssetImage(
                      'assets/surah_banner.png',
                      package: 'qcf_quran_plus',
                    ),
                    width: w,
                    fit: BoxFit.contain,
                    color: isDark ? const Color.fromARGB(255, 43, 63, 48) : null,
                    colorBlendMode: isDark ? BlendMode.color : null,
                  ),
                  Text(
                    '$surahNum',
                    style: QuranTextStyles.surahHeaderStyle(
                      color: nameColor,
                      fontSize: fs,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        // â”€â”€ Basmala (QCF4_BSML font, bundled in qcf_quran_plus) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        if (surahNum != 1 && surahNum != 9)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                surahNum == 97 || surahNum == 95
                    ? 'é½ƒð§»“ð¥³é¾Ž'
                    : 'é½ƒð§»“ð¥³ð¥‰‰',
                style: QuranTextStyles.basmallahStyle(
                  fontSize: 22,
                  color: basmalaColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

// â”€â”€â”€ Recitation settings button â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _FbRecitationSettingsButton extends StatelessWidget {
  final bool isDark;
  const _FbRecitationSettingsButton({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final color = isDark
        ? Colors.white.withValues(alpha: 0.65)
        : AppColors.primary.withValues(alpha: 0.55);
    return IconButton(
      onPressed: () {
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => BlocProvider.value(
            value: context.read<AppSettingsCubit>(),
            child: _FbRecitationSettingsSheet(
              isAr: context
                  .read<AppSettingsCubit>()
                  .state
                  .appLanguageCode
                  .toLowerCase()
                  .startsWith('ar'),
            ),
          ),
        );
      },
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 32),
      iconSize: 18,
      icon: Icon(Icons.tune_rounded, color: color, size: 18),
      tooltip: 'Ø¥Ø¹Ø¯Ø§Ø¯Ø§Øª Ø§Ù„ØªÙ„Ø§ÙˆØ©',
    );
  }
}

class _FbRecitationSettingsSheet extends StatefulWidget {
  final bool isAr;
  const _FbRecitationSettingsSheet({required this.isAr});

  @override
  State<_FbRecitationSettingsSheet> createState() =>
      _FbRecitationSettingsSheetState();
}

class _FbRecitationSettingsSheetState
    extends State<_FbRecitationSettingsSheet> {
  late final OfflineAudioService _offlineAudio;
  late final AudioEditionService  _editionService;
  late Future<List<AudioEdition>> _editionsFuture;

  @override
  void initState() {
    super.initState();
    _offlineAudio   = di.sl<OfflineAudioService>();
    _editionService = di.sl<AudioEditionService>();
    _editionsFuture = _editionService.getVerseByVerseAudioEditions();
  }

  Future<void> _showPicker(
    BuildContext ctx,
    List<AudioEdition> all,
    String currentId,
  ) async {
    await showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FbReciterPickerSheet(
        all: all,
        currentEdition: currentId,
        isAr: widget.isAr,
        onSelected: (identifier) async {
          await _offlineAudio.setEdition(identifier);
          if (ctx.mounted) {
            try { ctx.read<AyahAudioCubit>().stop(); } catch (_) {}
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
        final isDark     = settings.darkMode;
        final bg         = isDark ? const Color(0xFF1E1E1E) : Colors.white;
        final textColor  = isDark ? Colors.white : const Color(0xFF1A1A1A);
        final subTextColor = isDark
            ? Colors.white.withValues(alpha: 0.55)
            : Colors.black.withValues(alpha: 0.45);
        final dividerColor = isDark
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.black.withValues(alpha: 0.08);
        final titleStyle = GoogleFonts.amiriQuran(
            fontSize: 15, fontWeight: FontWeight.w700, color: textColor);
        final labelStyle  = GoogleFonts.amiriQuran(fontSize: 14, color: textColor);
        final noteStyle   = GoogleFonts.amiriQuran(fontSize: 11, color: subTextColor);

        return SafeArea(
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Container(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36, height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text('Ø¥Ø¹Ø¯Ø§Ø¯Ø§Øª Ø§Ù„ØªÙ„Ø§ÙˆØ©', style: titleStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Divider(color: dividerColor, height: 1),
                  const SizedBox(height: 12),
                  FutureBuilder<List<AudioEdition>>(
                    future: _editionsFuture,
                    builder: (ctx, snap) {
                      final currentId = _offlineAudio.edition;
                      final edition = snap.data
                          ?.where((e) => e.identifier == currentId)
                          .cast<AudioEdition?>()
                          .firstOrNull;
                      final name = edition?.displayNameForAppLanguage(
                              widget.isAr ? 'ar' : 'en') ?? currentId;
                      return Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Ø§Ù„Ù‚Ø§Ø±Ø¦', style: labelStyle),
                                Text(name, style: labelStyle.copyWith(
                                    color: subTextColor, fontSize: 12)),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: snap.hasData
                                ? () => _showPicker(ctx, snap.data!, _offlineAudio.edition)
                                : null,
                            child: Text('ØªØºÙŠÙŠØ±', style: GoogleFonts.amiriQuran(
                                color: AppColors.secondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Divider(color: dividerColor, height: 1),
                  const SizedBox(height: 12),
                  // â”€â”€ Continue Tilawa â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  Row(
                    children: [
                      Expanded(child: Text('ØªÙƒÙ…Ù„Ø© Ø§Ù„ØªÙ„Ø§ÙˆØ© Ø¹Ù†Ø¯ Ø§Ù„Ø¶ØºØ·', style: labelStyle)),
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
                          label: Text('Ø¥Ù„Ù‰ Ù†Ù‡Ø§ÙŠØ© Ø§Ù„ØµÙØ­Ø©',
                              style: GoogleFonts.amiriQuran(fontSize: 12)),
                        ),
                        ButtonSegment(
                          value: 'surah',
                          label: Text('Ø¥Ù„Ù‰ Ù†Ù‡Ø§ÙŠØ© Ø§Ù„Ø³ÙˆØ±Ø©',
                              style: GoogleFonts.amiriQuran(fontSize: 12)),
                        ),
                      ],
                      selected: {settings.mushafContinueScope},
                      onSelectionChanged: (s) =>
                          ctx.read<AppSettingsCubit>().setMushafContinueScope(s.first),
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
                            BorderSide(color: dividerColor, width: 0.8)),
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

// â”€â”€â”€ Reciter picker sheet â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _FbReciterPickerSheet extends StatefulWidget {
  final List<AudioEdition> all;
  final String currentEdition;
  final bool isAr;
  final Future<void> Function(String) onSelected;

  const _FbReciterPickerSheet({
    required this.all,
    required this.currentEdition,
    required this.isAr,
    required this.onSelected,
  });

  @override
  State<_FbReciterPickerSheet> createState() => _FbReciterPickerSheetState();
}

class _FbReciterPickerSheetState extends State<_FbReciterPickerSheet> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentEdition;
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final bg        = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final all       = [
      ...widget.all.where((e) => e.language == 'ar'),
      ...widget.all.where((e) => e.language != 'ar'),
    ];

    return SafeArea(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.18)
                      : Colors.black.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text('Ø§Ø®ØªØ± Ø§Ù„Ù‚Ø§Ø±Ø¦', style: GoogleFonts.amiriQuran(
                    fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
              ),
              const Divider(height: 1),
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.55),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: all.length,
                  itemBuilder: (ctx, i) {
                    final e = all[i];
                    final name      = e.displayNameForAppLanguage(widget.isAr ? 'ar' : 'en');
                    final isSelected = e.identifier == _selected;
                    return ListTile(
                      title: Text(name, style: GoogleFonts.amiriQuran(
                        fontSize: 13,
                        color: isSelected ? AppColors.secondary : textColor,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                      )),
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

// â”€â”€â”€ Verse options sheet â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300], borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text(
                  '$surahName â€” Ø¢ÙŠØ© $verse',
                  style: GoogleFonts.amiriQuran(
                    fontSize: 16, fontWeight: FontWeight.bold,
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
                      isBookmarked ? 'Ø¥Ø²Ø§Ù„Ø© Ø§Ù„Ø¥Ø´Ø§Ø±Ø©' : 'Ø¥Ø¶Ø§ÙØ© Ø¥Ø´Ø§Ø±Ø©',
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
                leading: const Icon(Icons.share_rounded, color: AppColors.primary),
                title: const Text('Ù…Ø´Ø§Ø±ÙƒØ© Ø§Ù„Ø¢ÙŠØ©', style: TextStyle(fontSize: 15)),
                subtitle: const Text('ØµÙˆØ±Ø© Ø¨Ø®Ø· Ø§Ù„Ù‚Ø±Ø¢Ù† Ø§Ù„ÙƒØ±ÙŠÙ…',
                    style: TextStyle(fontSize: 11)),
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
                leading: const Icon(Icons.menu_book_rounded, color: AppColors.primary),
                title: const Text('Ø§Ù„ØªÙØ³ÙŠØ±', style: TextStyle(fontSize: 15)),
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

// â”€â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

String _toArabicNum(int n) {
  const digits = ['Ù ','Ù¡','Ù¢','Ù£','Ù¤','Ù¥','Ù¦','Ù§','Ù¨','Ù©'];
  return n.toString().split('').map((d) {
    final i = int.tryParse(d);
    return i != null ? digits[i] : d;
  }).join();
}

// Placeholder to satisfy mushaf_page_view.dart's isDarkMode parameter
// (the widget now reads isDark from AppSettingsCubit internally)
// kept for API compatibility
class QcfFallbackPagecompat {}
