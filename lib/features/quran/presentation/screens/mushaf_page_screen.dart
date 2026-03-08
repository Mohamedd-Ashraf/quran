import 'dart:async';
import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../../../core/constants/app_colors.dart';
import '../../../../core/audio/ayah_audio_cubit.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/settings/app_settings_cubit.dart';
import '../../../../core/utils/arabic_text_style_helper.dart';
import '../bloc/tafsir/tafsir_cubit.dart';
import 'tafsir_screen.dart';

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

// ─── Network ──────────────────────────────────────────────────────────────────
Future<List<_Verse>> _fetchPage(int page) async {
  final uri = Uri.parse(
    'https://api.quran.com/api/v4/verses/by_page/$page'
    '?fields=text_uthmani&per_page=50',
  );
  final res = await http.get(uri, headers: const {'Accept': 'application/json'});
  if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');

  final data  = jsonDecode(res.body) as Map<String, dynamic>;
  final vList = data['verses'] as List;

  return vList.map((v) {
    final key  = v['verse_key'] as String;
    final sp   = key.split(':');
    return _Verse(
      verseKey: key,
      surah:    int.parse(sp[0]),
      ayah:     int.parse(sp[1]),
      text:     (v['text_uthmani'] as String?) ?? '',
    );
  }).toList();
}

// ─── Main screen ──────────────────────────────────────────────────────────────
class MushafPageScreen extends StatefulWidget {
  final int initialPage;

  /// Optional notifier that mirrors the audio player's collapsed state
  /// so the page content can adapt its bottom padding accordingly.
  final ValueNotifier<bool>? playerCollapsedNotifier;

  const MushafPageScreen({
    super.key,
    this.initialPage = 1,
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

  void _showGoToPage() async {
    final ctrl = TextEditingController();
    final page = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('الانتقال إلى صفحة',
          textDirection: TextDirection.rtl,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller:   ctrl,
          keyboardType: TextInputType.number,
          decoration:   const InputDecoration(
            hintText: '1 – 604', border: OutlineInputBorder()),
          autofocus: true,
          onSubmitted: (v) {
            final n = int.tryParse(v);
            if (n != null && n >= 1 && n <= 604) Navigator.pop(ctx, n);
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              final n = int.tryParse(ctrl.text);
              if (n != null && n >= 1 && n <= 604) Navigator.pop(ctx, n);
            },
            child: const Text('انتقال'),
          ),
        ],
      ),
    );
    if (page != null && mounted) _pageCtrl.jumpToPage(page - 1);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<AppSettingsCubit, bool>(
      (c) => c.state.darkMode);
    final bgColor = isDark ? const Color(0xFF0E1A12) : const Color(0xFFF5F0E4);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        title: Text('الصفحة $_currentPage  من  ٦٠٤',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon:     const Icon(Icons.search_rounded),
            tooltip:  'انتقل إلى صفحة',
            onPressed: _showGoToPage,
          ),
        ],
      ),
      body: PageView.builder(
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
            playerCollapsedNotifier: widget.playerCollapsedNotifier,
          );
        },
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
  final ValueNotifier<bool>? playerCollapsedNotifier;

  const _MushafPage({
    required this.page,
    required this.verses,
    required this.isLoading,
    required this.error,
    required this.onRetry,
    this.playerCollapsedNotifier,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<AppSettingsCubit, bool>(
      (c) => c.state.darkMode);
    final bgColor = isDark ? const Color(0xFF0E1A12) : const Color(0xFFF5F0E4);

    if (isLoading || (verses == null && error == null)) {
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

    if (error != null || verses == null || verses!.isEmpty) {
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

    return Container(
      color: bgColor,
      child: Column(
        children: [
          _PageBorder(isTop: true, isDark: isDark),
          _PageHeader(verses: verses!, page: page, isDark: isDark),
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
                  child: _PageText(verses: verses!),
                );
                if (notifier != null) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: notifier,
                    builder: (ctx, isCollapsed, child) => scrollView(
                      // Minimized: player floats over content (no push).
                      // Maximized: push content up so it isn't hidden.
                      playerVisible ? (isCollapsed ? 8.0 : 220.0) : 8,
                    ),
                  );
                }
                return scrollView(playerVisible ? 220.0 : 8);
              },
            ),
          ),
          _PageFooter(page: page, isDark: isDark),
          _PageBorder(isTop: false, isDark: isDark),
        ],
      ),
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
  // One recognizer per ayah – kept alive between builds when the verse list
  // has not changed, properly disposed when the list changes or widget is
  // removed from the tree.
  final List<TapGestureRecognizer> _taps = [];
  List<_Verse>? _builtForVerses;

  // Long-press detection via a timer inside TapGestureRecognizer.
  Timer? _lpTimer;
  bool   _lpHandled = false;

  @override
  void dispose() {
    _lpTimer?.cancel();
    for (final r in _taps) { r.dispose(); }
    super.dispose();
  }

  void _openTafsir(_Verse v) {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    final name = v.surah < _kSurahNames.length ? _kSurahNames[v.surah] : '';
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
  }

  void _rebuildRecognizers(List<_Verse> verses, AyahAudioCubit cubit) {
    _lpTimer?.cancel();
    for (final r in _taps) { r.dispose(); }
    _taps.clear();
    for (final v in verses) {
      _taps.add(
        TapGestureRecognizer()
          ..onTapDown = (_) {
              _lpHandled = false;
              _lpTimer?.cancel();
              _lpTimer = Timer(const Duration(milliseconds: 500), () {
                _lpHandled = true;
                _openTafsir(v);
              });
            }
          ..onTapUp    = (_) { _lpTimer?.cancel(); }
          ..onTapCancel = () {
              _lpTimer?.cancel();
              _lpHandled = false;
            }
          ..onTap = () {
              if (!_lpHandled) {
                HapticFeedback.selectionClick();
                cubit.togglePlayAyah(surahNumber: v.surah, ayahNumber: v.ayah);
              }
              _lpHandled = false;
            },
      );
    }
    _builtForVerses = verses;
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AyahAudioCubit>();
    // Rebuild recognizers only when the verse list reference changes.
    if (!identical(_builtForVerses, widget.verses)) {
      _rebuildRecognizers(widget.verses, cubit);
    }

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

            // Highlight style for the currently playing/paused ayah.
            final highlightStyle = baseStyle.copyWith(
              background: Paint()
                ..color = AppColors.secondary.withValues(alpha: 0.28),
            );

            final playKey = (audioState.hasTarget &&
                    audioState.status != AyahAudioStatus.idle)
                ? '${audioState.surahNumber}:${audioState.ayahNumber}'
                : null;

            // Group verses by surah so we can insert Basmala between surahs.
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
              // Show Basmala before ayah 1 of every surah except Al-Fatiha (1)
              // and At-Tawba (9) which has no Basmala.
              if (section.entries.isNotEmpty &&
                  section.entries.first.verse.ayah == 1 &&
                  section.surahNum != 1 &&
                  section.surahNum != 9) {
                children.add(_Basmala(isDark: isDark));
              }

              final spans = <InlineSpan>[];
              for (final entry in section.entries) {
                final v       = entry.verse;
                final isActive = '${v.surah}:${v.ayah}' == playKey;
                spans.add(TextSpan(
                  text:       '\u200f${v.text}\u200f ',
                  style:      isActive ? highlightStyle : baseStyle,
                  recognizer: _taps[entry.idx],
                ));
                spans.add(WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _AyahMarker(
                      number:      v.ayah,
                      isDark:      isDark,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        cubit.togglePlayAyah(
                            surahNumber: v.surah, ayahNumber: v.ayah);
                      },
                      onLongPress: () => _openTafsir(v),
                    ),
                  ),
                ));
              }

              children.add(Text.rich(
                TextSpan(children: spans),
                textDirection: TextDirection.rtl,
                textAlign:     TextAlign.justify,
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

// ─── Basmala separator ────────────────────────────────────────────────────────
class _Basmala extends StatelessWidget {
  final bool isDark;
  const _Basmala({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Text(
        'بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ',
        textAlign:     TextAlign.center,
        textDirection: TextDirection.rtl,
        style: GoogleFonts.amiriQuran(
          fontSize:   18,
          color:      isDark ? const Color(0xFFD4A855) : AppColors.primary,
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
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  const _AyahMarker({
    required this.number,
    required this.isDark,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    const frameSize    = 28.0;
    final baseFontSize = number > 99 ? 8.0 : (number > 9 ? 10.0 : 12.0);

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
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            _toArabicNum(number),
            textAlign: TextAlign.center,
            style: GoogleFonts.amiriQuran(
              fontSize:   baseFontSize,
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

// ─── Page header ──────────────────────────────────────────────────────────────
class _PageHeader extends StatelessWidget {
  final List<_Verse> verses;
  final int          page;
  final bool         isDark;
  const _PageHeader({
    required this.verses,
    required this.page,
    required this.isDark,
  });

  String _surahName() {
    if (verses.isEmpty) return '';
    final n = verses.first.surah;
    return n < _kSurahNames.length ? _kSurahNames[n] : '';
  }

  int _juz() => ((page - 1) ~/ 20) + 1;

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark ? const Color(0xFF8B6B3A) : const Color(0xFFBB9860);
    final bgColor     = isDark ? const Color(0xFF1A2B1C) : const Color(0xFFF5F0E4);
    final textColor   = isDark ? const Color(0xFFD4A855) : const Color(0xFF6B4B0F);

    return Container(
      margin:  const EdgeInsets.fromLTRB(12, 4, 12, 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border:       Border.all(color: borderColor, width: 0.8),
        borderRadius: BorderRadius.circular(4),
        color:        bgColor,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('الجزء ${_toArabicNum(_juz())}',
            style: GoogleFonts.amiriQuran(
              fontSize: 13, color: textColor,
              fontWeight: FontWeight.bold)),
          Text('سُورَةُ ${_surahName()}',
            style: GoogleFonts.amiriQuran(
              fontSize: 13, color: textColor,
              fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ─── Page footer ──────────────────────────────────────────────────────────────
class _PageFooter extends StatelessWidget {
  final int  page;
  final bool isDark;
  const _PageFooter({required this.page, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? const Color(0xFFD4A855) : const Color(0xFF6B4B0F);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(_toArabicNum(page),
        style: GoogleFonts.amiriQuran(
          fontSize:   16,
          color:      textColor,
          fontWeight: FontWeight.bold)),
    );
  }
}

// ─── Decorative border ────────────────────────────────────────────────────────
class _PageBorder extends StatelessWidget {
  final bool isTop;
  final bool isDark;
  const _PageBorder({required this.isTop, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark ? const Color(0xFF8B6B3A) : const Color(0xFFBB9860);
    return Container(
      height: 22,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border(
          top:    BorderSide(color: borderColor, width: isTop ? 2.5 : 1),
          bottom: BorderSide(color: borderColor, width: isTop ? 1 : 2.5),
          left:   BorderSide(color: borderColor, width: 1),
          right:  BorderSide(color: borderColor, width: 1),
        ),
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
