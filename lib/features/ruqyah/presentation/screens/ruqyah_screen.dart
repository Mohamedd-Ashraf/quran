import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qcf_quran_plus/qcf_quran_plus.dart'
    show
        getPageNumber,
        QcfFontLoader;
import '../../../../core/audio/ayah_audio_cubit.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/settings/app_settings_cubit.dart';
import '../../data/ruqyah_data.dart';
import '../widgets/qcf_verses_widget.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Ruqyah Screen
// ─────────────────────────────────────────────────────────────────────────────

class RuqyahScreen extends StatelessWidget {
  const RuqyahScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isArabicUi = context
        .watch<AppSettingsCubit>()
        .state
        .appLanguageCode
        .toLowerCase()
        .startsWith('ar');

    return Scaffold(
      body: _RuqyahBody(isArabicUi: isArabicUi),
      floatingActionButton: _PlayAllFab(isArabicUi: isArabicUi),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Play-All FAB
// ─────────────────────────────────────────────────────────────────────────────

class _PlayAllFab extends StatelessWidget {
  final bool isArabicUi;
  const _PlayAllFab({required this.isArabicUi});

  void _playAll(BuildContext context) {
    final List<AyahAudioQueueItem> queueItems =
        RuqyahData.sections.map<AyahAudioQueueItem>((section) {
      final audio = section.audio;
      if (audio.type == RuqyahAudioType.fullSurah) {
        return AyahAudioQueueItem.fullSurah(
          surahNumber: audio.surahNumber,
          numberOfAyahs: audio.numberOfAyahs!,
        );
      }
      return AyahAudioQueueItem.ayahRange(
        surahNumber: audio.surahNumber,
        startAyah: audio.startAyah!,
        endAyah: audio.endAyah!,
      );
    }).toList(growable: false);

    context.read<AyahAudioCubit>().playStructuredQueue(queueItems);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isArabicUi ? 'يتم الآن تشغيل الرقية الشرعية كاملة 🌟' : 'Playing full Ruqyah 🌟',
          textDirection: isArabicUi ? TextDirection.rtl : TextDirection.ltr,
        ),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 90),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AyahAudioCubit, AyahAudioState>(
      builder: (context, audioState) {
        final isActive = audioState.status != AyahAudioStatus.idle &&
            audioState.status != AyahAudioStatus.error;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          child: Material(
            elevation: 8,
            shadowColor: AppColors.primary.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(28),
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: isActive
                  ? () => context.read<AyahAudioCubit>().stop()
                  : () => _playAll(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isActive ? Icons.stop_rounded : Icons.play_circle_filled_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isActive
                          ? (isArabicUi ? 'إيقاف التشغيل' : 'Stop')
                          : (isArabicUi ? 'تشغيل الرقية كاملة' : 'Play Full Ruqyah'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Body
// ─────────────────────────────────────────────────────────────────────────────

class _RuqyahBody extends StatefulWidget {
  final bool isArabicUi;
  const _RuqyahBody({required this.isArabicUi});

  @override
  State<_RuqyahBody> createState() => _RuqyahBodyState();
}

class _RuqyahBodyState extends State<_RuqyahBody> {
  static const _expandedHeight = 280.0;
  late final ScrollController _scroll;
  bool _isCollapsed = false;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController()..addListener(_onScroll);
  }

  void _onScroll() {
    final collapsed =
        _scroll.hasClients && _scroll.offset > (_expandedHeight - kToolbarHeight - 16);
    if (collapsed != _isCollapsed) setState(() => _isCollapsed = collapsed);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: _scroll,
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── Immersive hero app bar ────────────────────────────────────────────
        _RuqyahSliverAppBar(isArabicUi: widget.isArabicUi, isCollapsed: _isCollapsed),

        // ── Quranic quote strip ───────────────────────────────────────────────
        SliverToBoxAdapter(child: _QuoteStrip(isArabicUi: widget.isArabicUi)),

        // ── Article-based guidance ───────────────────────────────────────────
        SliverToBoxAdapter(
          child: _RuqyahGuideCard(isArabicUi: widget.isArabicUi),
        ),

     

        // ── Section label ─────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 22,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.secondary, AppColors.gradientStart],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  widget.isArabicUi ? 'الآيات والسور' : 'Verses & Surahs',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.25),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Section cards ─────────────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverList.builder(
            itemCount: RuqyahData.sections.length,
            itemBuilder: (context, index) => _RuqyahCard(
              section: RuqyahData.sections[index],
              isArabicUi: widget.isArabicUi,
              index: index,
            ),
          ),
        ),
   // ── Sunnah supplications section ────────────────────────────────────
        SliverToBoxAdapter(
          child: _SunnahSupplicationsCard(isArabicUi: widget.isArabicUi),
        ),
        // ── Bottom note ───────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
            child: _DisclaimerNote(isArabicUi: widget.isArabicUi),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Immersive SliverAppBar with Roqia hero image
// ─────────────────────────────────────────────────────────────────────────────

class _RuqyahSliverAppBar extends StatelessWidget {
  final bool isArabicUi;
  final bool isCollapsed;
  const _RuqyahSliverAppBar({required this.isArabicUi, required this.isCollapsed});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      stretch: true,
      backgroundColor: AppColors.gradientStart,
      iconTheme: const IconThemeData(color: Colors.white),
      // Title only visible when the image is fully collapsed
      title: AnimatedOpacity(
        opacity: isCollapsed ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Text(
          isArabicUi ? 'الرقية الشرعية' : 'Ruqyah Shariah',
          style: const TextStyle(
            fontFamily: 'Amiri',
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      centerTitle: true,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Hero image
            Image.asset(
              'assets/logo/button icons/Roqia.png',
              fit: BoxFit.cover,
            ),
            // Dark gradient overlay for legibility
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: isDark ? 0.55 : 0.30),
                    AppColors.gradientStart.withValues(alpha: 0.80),
                    AppColors.gradientStart,
                  ],
                  stops: const [0.0, 0.65, 1.0],
                ),
              ),
            ),
            // Decorative star pattern
            Positioned.fill(
              child: CustomPaint(
                painter: _StarPatternPainter(
                  color: AppColors.secondary.withValues(alpha: 0.08),
                ),
              ),
            ),
            // Title text at bottom of expanded area — fades out when collapsing
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: AnimatedOpacity(
                opacity: isCollapsed ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'الرقية الشرعية',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: 'Amiri',
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: AppColors.secondary,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isArabicUi
                        ? 'آيات الشفاء والحماية من القرآن الكريم'
                        : 'Quranic verses for healing & protection',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              ),
            ),
          ],
        ),
        collapseMode: CollapseMode.parallax,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quranic quote strip — uses QCF font for authentic Quran rendering
// ─────────────────────────────────────────────────────────────────────────────

class _QuoteStrip extends StatefulWidget {
  final bool isArabicUi;
  const _QuoteStrip({required this.isArabicUi});

  @override
  State<_QuoteStrip> createState() => _QuoteStripState();
}

class _QuoteStripState extends State<_QuoteStrip> {
  bool _fontLoaded = false;
  late final int _pageNumber;

  // Al-Isra 17:82 — the healing verse
  static const int _surahNumber = 17;
  static const int _verseNumber = 82;

  @override
  void initState() {
    super.initState();
    _pageNumber = getPageNumber(_surahNumber, _verseNumber);
    _loadFont();
  }

  void _loadFont() {
    if (QcfFontLoader.isFontLoaded(_pageNumber)) {
      _fontLoaded = true;
      return;
    }
    QcfFontLoader.ensureFontLoaded(_pageNumber).then((_) {
      if (mounted) setState(() => _fontLoaded = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? AppColors.secondary.withValues(alpha: 0.95)
        : AppColors.primary;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkCard
            : const Color(0xFFF0F9F4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: isDark ? 0.25 : 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: isDark ? 0.06 : 0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          if (_fontLoaded)
            QcfVersesWidget(
              surahNumber: _surahNumber,
              firstVerse: _verseNumber,
              lastVerse: _verseNumber,
              textColor: textColor,
              verseNumberColor: textColor,
              fontSize: 24,
              verseHeight: 1.85,
              textAlign: TextAlign.center,
              isDark: isDark,
            )
          else
            // Fallback while font loads
            Text(
              '﴿ وَنُنَزِّلُ مِنَ ٱلْقُرْءَانِ مَا هُوَ شِفَآءٌ وَرَحْمَةٌ لِّلْمُؤْمِنِينَ ﴾',
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: 'Amiri',
                fontSize: 17,
                height: 1.9,
                color: textColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          const SizedBox(height: 6),
          Text(
            widget.isArabicUi ? '— سورة الإسراء: ٨٢' : '— Surah Al-Isra 17:82',
            style: TextStyle(
              fontSize: 11,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.45)
                  : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _RuqyahGuideCard extends StatelessWidget {
  final bool isArabicUi;
  const _RuqyahGuideCard({required this.isArabicUi});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFD8E2EA) : AppColors.textSecondary;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121A22) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppColors.darkBorder.withValues(alpha: 0.45)
              : AppColors.cardBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.14 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isArabicUi
                      ? 'الرقية الشرعية من القرآن والسنة'
                      : 'Ruqyah from Quran and Sunnah',
                  style: TextStyle(
                    fontFamily: isArabicUi ? 'Amiri' : null,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFFF3F5F7) : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _GuideLine(
            text: isArabicUi
                ? 'الأصل فيها القرآن الكريم والأذكار النبوية الصحيحة، مع التوكل على الله وحده.'
                : 'It is based on the Quran and authentic Prophetic supplications, with reliance upon Allah alone.',
            color: textColor,
          ),
          _GuideLine(
            text: isArabicUi
                ? 'الأفضل أن يرقي المسلم نفسه، كما ثبت عن النبي ﷺ في الصحيحين.'
                : 'It is best for a Muslim to recite ruqyah for himself, as established from the Prophet.',
            color: textColor,
          ),
          _GuideLine(
            text: isArabicUi
                ? 'لا بأس بالرقى ما لم يكن فيها شرك، وتكون بأسماء الله أو كلامه أو الدعاء المشروع.'
                : 'Ruqyah is permissible so long as it contains no shirk and uses lawful supplication.',
            color: textColor,
          ),
          _GuideLine(
            text: isArabicUi
                ? 'قبل الرقية: التوبة، والمحافظة على الصلاة، والتدبر، واليقين بأن الشفاء من الله.'
                : 'Before ruqyah: repent, keep the prayers, reflect, and be certain that healing is from Allah.',
            color: textColor,
          ),
        ],
      ),
    );
  }
}

class _GuideLine extends StatelessWidget {
  final String text;
  final Color color;

  const _GuideLine({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.secondary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                color: color,
                fontSize: 12.5,
                height: 1.6,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SunnahSupplicationsCard extends StatelessWidget {
  final bool isArabicUi;
  const _SunnahSupplicationsCard({required this.isArabicUi});

  static const List<({String duaAr, String sourceAr, String duaEn})> _duas = [
    
    (
      duaAr: 'أذهبِ البأسَ ربَّ الناسِ، اشفِ وأنتَ الشافي، لا شفاءَ إلا شفاؤك، شفاءً لا يُغادرُ سَقَمًا.',
      sourceAr: 'رواه البخاري',
      duaEn: 'Remove the harm, Lord of mankind, heal and You are the Healer...'
    ),
    (
      duaAr: 'أعوذُ بكلماتِ اللهِ التامَّةِ، من كلِّ شيطانٍ وهامَّةٍ، ومن كلِّ عينٍ لامَّةٍ.',
      sourceAr: 'رواه البخاري',
      duaEn: 'I seek refuge in the perfect words of Allah from every devil...'
    ),
    (
      duaAr: 'أعوذُ بكلماتِ اللهِ التامَّاتِ من شرِّ ما خلق.',
      sourceAr: 'صححه الألباني',
      duaEn: 'I seek refuge in the perfect words of Allah from the evil of what He created.'
    ),
    (
      duaAr: 'باسمِ اللهِ أرقيكَ، من كلِّ شيءٍ يُؤذيكَ، من شرِّ كلِّ نفسٍ أو عينِ حاسدٍ، اللهُ يشفيكَ.',
      sourceAr: 'رواه مسلم',
      duaEn: 'In the name of Allah, I perform ruqyah for you from everything harming you...'
    ),
    (
      duaAr: 'باسمِ اللهِ يُبريك، ومن كلِّ داءٍ يشفيكَ، ومن شرِّ حاسدٍ إذا حسد، وشرِّ كلِّ ذي عينٍ.',
      sourceAr: 'رواه مسلم',
      duaEn: 'In the name of Allah, may He cure you, and from every disease...'
    ),
    (
      duaAr: 'بسمِ اللهِ أعوذُ بعزَّةِ اللهِ وقدرتِهِ من شرِّ ما أجدُ وأُحاذر.',
      sourceAr: 'صححه الألباني',
      duaEn: 'In the name of Allah, I seek refuge in Allah’s might and power...'
    ),
    (
      duaAr: 'اللهمَّ فاطرَ السماواتِ والأرضِ، عالمَ الغيبِ والشهادةِ، لا إلهَ إلا أنتَ... أعوذُ بك من شرِّ نفسي ومن شرِّ الشيطانِ وشِركِه.',
      sourceAr: 'صححه الألباني',
      duaEn: 'O Allah, Creator of the heavens and earth, Knower of the unseen...'
    ),
    (
      duaAr: 'اللهمَّ عافِني في بدني، اللهمَّ عافِني في سمعي، اللهمَّ عافِني في بصري، لا إلهَ إلا أنت.',
      sourceAr: 'صححه الألباني',
      duaEn: 'O Allah, grant me wellness in my body, hearing, and sight...'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 2),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101824) : const Color(0xFFF7FBFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppColors.darkBorder.withValues(alpha: 0.5)
              : const Color(0xFFDCE8F3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_stories_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isArabicUi
                      ? 'الرقية من السنة النبوية (أدعية مأثورة)'
                      : 'Ruqyah from the Prophetic Sunnah',
                  style: TextStyle(
                    fontFamily: isArabicUi ? 'Amiri' : null,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFFF3F5F7) : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isArabicUi
                ? 'كان للنبي ﷺ أدعية مميزة جدًا تستخدم في الرقية الشرعية للتحصين والحفظ والحماية والشفاء أيضًا، ومن أبرز هذه الأدعية:'
                : 'The Prophet had distinctive supplications used in ruqyah for protection, preservation, and healing. Among the most important are:',
            textDirection: isArabicUi ? TextDirection.rtl : TextDirection.ltr,
            style: TextStyle(
              fontSize: 12.8,
              height: 1.7,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFD4DFEA) : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          ..._duas.map(
            (d) => _HadithDuaItem(
              dua: isArabicUi ? d.duaAr : d.duaEn,
              source: d.sourceAr,
              isDark: isDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isArabicUi
                ? 'قال النبي ﷺ: «لا بأسَ بالرُّقى ما لم يكن فيه شرك». '
                    'تُقرأ الأدعية بيقينٍ وتوكلٍ على الله مع الأخذ بالأسباب.'
                : 'The Prophet said: “There is no harm in ruqyah so long as it contains no shirk.”',
            textDirection: isArabicUi ? TextDirection.rtl : TextDirection.ltr,
            style: TextStyle(
              fontSize: 12,
              height: 1.6,
              color: isDark
                  ? const Color(0xFFB7C5D4)
                  : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HadithDuaItem extends StatelessWidget {
  final String dua;
  final String source;
  final bool isDark;

  const _HadithDuaItem({
    required this.dua,
    required this.source,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Icon(
              Icons.check_circle_rounded,
              size: 14,
              color: AppColors.secondary.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              textDirection: TextDirection.rtl,
              text: TextSpan(
                style: TextStyle(
                  color: isDark ? const Color(0xFFE0E8EF) : AppColors.textPrimary,
                  fontSize: 13,
                  height: 1.6,
                  fontFamily: 'Amiri',
                ),
                children: [
                  TextSpan(text: dua),
                  TextSpan(
                    text: '  [$source]',
                    style: TextStyle(
                      color: isDark ? const Color(0xFF90A8BC) : AppColors.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ruqyah Section Card (expandable) — creative numbered tile style
// ─────────────────────────────────────────────────────────────────────────────

class _RuqyahCard extends StatefulWidget {
  final RuqyahSection section;
  final bool isArabicUi;
  final int index;

  const _RuqyahCard({
    required this.section,
    required this.isArabicUi,
    required this.index,
  });

  @override
  State<_RuqyahCard> createState() => _RuqyahCardState();
}

class _RuqyahCardState extends State<_RuqyahCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _expandAnimation;
  bool _expanded = false;

  // Arabic ordinal numerals
  static const _arabicNumerals = ['١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩', '١٠'];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  void _playSectionAudio(BuildContext context) {
    HapticFeedback.selectionClick();
    final audio = widget.section.audio;
    final cubit = context.read<AyahAudioCubit>();
    final currentState = cubit.state;

    if (_isCurrentSection(currentState)) {
      if (currentState.status == AyahAudioStatus.playing) {
        cubit.pause();
        return;
      }
      if (currentState.status == AyahAudioStatus.paused) {
        cubit.resume();
        return;
      }
    }

    if (audio.type == RuqyahAudioType.fullSurah) {
      cubit.playSurah(
        surahNumber: audio.surahNumber,
        numberOfAyahs: audio.numberOfAyahs!,
      );
    } else {
      cubit.playAyahRange(
        surahNumber: audio.surahNumber,
        startAyah: audio.startAyah!,
        endAyah: audio.endAyah!,
      );
    }
  }

  bool _isCurrentSection(AyahAudioState state) {
    final audio = widget.section.audio;
    if (state.surahNumber != audio.surahNumber) return false;
    if (state.status == AyahAudioStatus.idle) return false;
    if (audio.type == RuqyahAudioType.fullSurah) {
      return state.surahNumber == audio.surahNumber;
    }
    return state.ayahNumber != null &&
        state.ayahNumber! >= audio.startAyah! &&
        state.ayahNumber! <= audio.endAyah!;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = widget.isArabicUi;
    final numeral = widget.index < _arabicNumerals.length
        ? _arabicNumerals[widget.index]
        : '${widget.index + 1}';

    return BlocBuilder<AyahAudioCubit, AyahAudioState>(
      builder: (context, audioState) {
        final isCurrent = _isCurrentSection(audioState);
        final isPlaying = isCurrent && audioState.status == AyahAudioStatus.playing;
        final isBuffering = isCurrent && audioState.status == AyahAudioStatus.buffering;
        final isPaused = isCurrent && audioState.status == AyahAudioStatus.paused;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: isCurrent
                ? (isDark
                    ? AppColors.primary.withValues(alpha: 0.18)
                    : AppColors.primary.withValues(alpha: 0.04))
                : (isDark ? AppColors.darkCard : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isCurrent
                  ? AppColors.secondary.withValues(alpha: 0.65)
                  : (isDark
                      ? AppColors.darkBorder.withValues(alpha: 0.4)
                      : const Color(0xFFE6EDE9)),
              width: isCurrent ? 1.6 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isCurrent
                    ? AppColors.secondary.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: isDark ? 0.08 : 0.04),
                blurRadius: isCurrent ? 16 : 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: [
                // ── Active indicator bar ──────────────────────────────────
                if (isPlaying || isBuffering)
                  LinearProgressIndicator(
                    backgroundColor: AppColors.secondary.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
                    minHeight: 3,
                  ),

                // ── Main row ──────────────────────────────────────────────
                InkWell(
                  onTap: _toggle,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // ── Number badge ──────────────────────────────
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            gradient: isCurrent
                                ? const LinearGradient(
                                    colors: [AppColors.secondary, Color(0xFFB8962E)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : LinearGradient(
                                    colors: [
                                      AppColors.primary.withValues(alpha: isDark ? 0.3 : 0.10),
                                      AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.06),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              numeral,
                              style: TextStyle(
                                fontFamily: 'Amiri',
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: isCurrent
                                    ? Colors.white
                                    : AppColors.primary.withValues(alpha: isDark ? 0.8 : 0.9),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // ── Title + benefit ───────────────────────────
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isAr ? widget.section.titleAr : widget.section.titleEn,
                                style: TextStyle(
                                  fontSize: isAr ? 15.5 : 14.5,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: isAr ? 'Amiri' : null,
                                  color: isCurrent
                                      ? AppColors.secondary
                                      : (isDark
                                          ? const Color(0xFFE8DCC8)
                                          : AppColors.textPrimary),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                isAr ? widget.section.benefitAr : widget.section.benefitEn,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark
                                      ? const Color(0xFF8A9BAB)
                                      : AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // ── Play + chevron ────────────────────────────
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _PlayButton(
                              isPlaying: isPlaying,
                              isBuffering: isBuffering,
                              isPaused: isPaused,
                              onPressed: () => _playSectionAudio(context),
                            ),
                            const SizedBox(height: 4),
                            AnimatedRotation(
                              turns: _expanded ? 0.5 : 0,
                              duration: const Duration(milliseconds: 300),
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: AppColors.primary.withValues(alpha: 0.45),
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Expanded content ──────────────────────────────────────
                SizeTransition(
                  sizeFactor: _expandAnimation,
                  child: _ExpandedContent(
                    section: widget.section,
                    isArabicUi: isAr,
                    isDark: isDark,
                    isPlaying: isPlaying,
                    isBuffering: isBuffering,
                    isPaused: isPaused,
                    onPlay: () => _playSectionAudio(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Play Button
// ─────────────────────────────────────────────────────────────────────────────

class _PlayButton extends StatelessWidget {
  final bool isPlaying;
  final bool isBuffering;
  final bool isPaused;
  final VoidCallback onPressed;

  const _PlayButton({
    required this.isPlaying,
    required this.isBuffering,
    required this.isPaused,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isPlaying || isBuffering
                ? [
                    AppColors.secondary.withValues(alpha: 0.9),
                    AppColors.secondary,
                  ]
                : isPaused
                    ? [
                        AppColors.gradientStart.withValues(alpha: 0.65),
                        AppColors.gradientEnd.withValues(alpha: 0.75),
                      ]
                    : [
                        AppColors.gradientStart,
                        AppColors.gradientEnd,
                      ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (isPlaying || isBuffering
                          ? AppColors.secondary
                          : AppColors.primary)
                      .withValues(alpha: isPaused ? 0.18 : 0.32),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: isBuffering
            ? const Padding(
                padding: EdgeInsets.all(11),
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.onPrimary),
                ),
              )
            : Icon(
                isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 26,
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Expanded Content
// ─────────────────────────────────────────────────────────────────────────────

class _ExpandedContent extends StatefulWidget {
  final RuqyahSection section;
  final bool isArabicUi;
  final bool isDark;
  final bool isPlaying;
  final bool isBuffering;
  final bool isPaused;
  final VoidCallback onPlay;

  const _ExpandedContent({
    required this.section,
    required this.isArabicUi,
    required this.isDark,
    required this.isPlaying,
    required this.isBuffering,
    required this.isPaused,
    required this.onPlay,
  });

  @override
  State<_ExpandedContent> createState() => _ExpandedContentState();
}

class _ExpandedContentState extends State<_ExpandedContent> {
  bool _showTranslation = false;
  bool _qcfFontsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadQcfFonts();
  }

  void _loadQcfFonts() {
    final audio = widget.section.audio;
    final firstVerse =
        audio.type == RuqyahAudioType.fullSurah ? 1 : audio.startAyah!;
    final lastVerse = audio.type == RuqyahAudioType.fullSurah
        ? audio.numberOfAyahs!
        : audio.endAyah!;

    final pages = <int>{};
    for (int v = firstVerse; v <= lastVerse; v++) {
      try {
        pages.add(getPageNumber(audio.surahNumber, v));
      } catch (_) {}
    }

    if (pages.isEmpty) {
      _qcfFontsLoaded = true;
      return;
    }

    // Check if all fonts are already loaded
    if (pages.every(QcfFontLoader.isFontLoaded)) {
      _qcfFontsLoaded = true;
      return;
    }

    // Load all fonts
    Future.wait(pages.map(QcfFontLoader.ensureFontLoaded)).then((_) {
      if (mounted) setState(() => _qcfFontsLoaded = true);
    });
  }

  Widget _buildVerseContent(bool isDark) {
    final audio = widget.section.audio;
    final surahNumber = audio.surahNumber;
    final firstVerse =
        audio.type == RuqyahAudioType.fullSurah ? 1 : audio.startAyah!;
    final lastVerse = audio.type == RuqyahAudioType.fullSurah
        ? audio.numberOfAyahs!
        : audio.endAyah!;

    final textColor = isDark ? const Color(0xFFF5F0E6) : const Color(0xFF1A1A1A);
    final verseNumberColor = isDark ? AppColors.secondary : AppColors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // QCF Verses rendering (Mushaf drawing style)
        QcfVersesWidget(
          surahNumber: surahNumber,
          firstVerse: firstVerse,
          lastVerse: lastVerse,
          textColor: textColor,
          verseNumberColor: verseNumberColor,
          fontSize: 28,
          verseHeight: 2.0,
          textAlign: TextAlign.center,
          isDark: isDark,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final isAr = widget.isArabicUi;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark
                ? AppColors.darkBorder.withValues(alpha: 0.4)
                : AppColors.cardBorder,
            width: 1,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Quranic verse rendering with QCF fonts ─────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF11161C) : const Color(0xFFFFFDF8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF33414D)
                        : const Color(0xFFD0CAD0),
                    width: 1.2,
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: _qcfFontsLoaded
                    ? _buildVerseContent(isDark)
                    : const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Translation toggle ───────────────────────────────────────
            GestureDetector(
              onTap: () => setState(() => _showTranslation = !_showTranslation),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _showTranslation
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: AppColors.primary.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isAr
                          ? (_showTranslation
                              ? 'إخفاء الترجمة'
                              : 'عرض الترجمة')
                          : (_showTranslation
                              ? 'Hide translation'
                              : 'Show translation'),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary.withValues(alpha: 0.65),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Translation block ────────────────────────────────────────
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurface.withValues(alpha: 0.8)
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.divider.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    widget.section.translationEn,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.7,
                      color: isDark
                          ? const Color(0xFFBAC8D3)
                          : AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
              crossFadeState: _showTranslation
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 220),
            ),

            const SizedBox(height: 14),

            // ── Play button row ──────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: widget.onPlay,
                    icon: Icon(
                      widget.isPlaying
                          ? Icons.pause_rounded
                          : widget.isBuffering
                              ? Icons.hourglass_top_rounded
                              : widget.isPaused
                                  ? Icons.play_circle_filled_rounded
                                  : Icons.play_circle_outline_rounded,
                      size: 18,
                    ),
                    label: Text(
                      isAr
                          ? (widget.isPlaying
                              ? 'إيقاف مؤقت'
                              : widget.isBuffering
                                  ? 'جارٍ التحميل…'
                                  : widget.isPaused
                                      ? 'استئناف'
                                      : 'استمع للتلاوة')
                          : (widget.isPlaying
                              ? 'Pause'
                              : widget.isBuffering
                                  ? 'Loading…'
                                  : widget.isPaused
                                      ? 'Resume'
                                      : 'Play Recitation'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.isPlaying
                          ? AppColors.secondary
                          : widget.isPaused
                              ? AppColors.primary.withValues(alpha: 0.72)
                              : AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Disclaimer Note
// ─────────────────────────────────────────────────────────────────────────────

class _DisclaimerNote extends StatelessWidget {
  final bool isArabicUi;
  const _DisclaimerNote({required this.isArabicUi});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.secondary.withValues(alpha: 0.07)
            : AppColors.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              color: AppColors.secondary.withValues(alpha: 0.8), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isArabicUi
                  ? 'الرقية الشرعية جائزة إذا كانت بالقرآن الكريم أو السنة الصحيحة أو الدعاء المشروع،'
                    ' مع التوكل على الله، واعتقاد أن الشفاء بيده وحده.'
                    ' والأفضل أن يرقي المسلم نفسه، ويستعين بأهل العلم عند الحاجة.'
                  : 'Ruqyah is a Quranic healing by Allah\'s permission. '
                    'It is permissible when based on the Quran, authentic Sunnah, or lawful supplication, '
                    'with reliance upon Allah alone. Consulting qualified scholars is recommended when needed.',
              textDirection:
                  isArabicUi ? TextDirection.rtl : TextDirection.ltr,
              style: TextStyle(
                fontSize: 11.5,
                color: isDark
                    ? AppColors.secondary.withValues(alpha: 0.75)
                    : AppColors.secondary.withValues(alpha: 0.85),
                height: 1.6,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom painter — star/geometric pattern
// ─────────────────────────────────────────────────────────────────────────────

class _StarPatternPainter extends CustomPainter {
  final Color color;
  _StarPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    const double spacing = 56;
    const double starSize = 12;

    for (double x = -spacing / 2; x < size.width + spacing; x += spacing) {
      for (double y = -spacing / 2; y < size.height + spacing; y += spacing) {
        _drawStar(canvas, paint, Offset(x, y), starSize);
      }
    }
  }

  void _drawStar(Canvas canvas, Paint paint, Offset center, double size) {
    final path = Path();
    const int points = 8;
    final double outerR = size;
    final double innerR = size * 0.45;

    for (int i = 0; i < points * 2; i++) {
      final angle = (i * math.pi / points) - math.pi / 2;
      final r = i.isEven ? outerR : innerR;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_StarPatternPainter old) => old.color != color;
}