import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/audio/ayah_audio_cubit.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/recitation_catalog.dart';
import '../../../../core/services/audio_edition_service.dart';
import '../../../../core/services/offline_audio_service.dart';
import '../../../../core/settings/app_settings_cubit.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/islamic_logo.dart';
import '../../../quran/domain/entities/surah.dart';
import '../../../quran/presentation/bloc/surah/surah_bloc.dart';
import '../../../quran/presentation/bloc/surah/surah_state.dart';
import '../../../quran/presentation/screens/feedback_screen.dart';
import '../../../quran/presentation/screens/offline_tafsir_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qcf_quran_plus/qcf_quran_plus.dart' show getSurahNameArabic;
import '../../../quiz/presentation/screens/quiz_screen.dart';
import '../../../quiz/presentation/widgets/quiz_mode_entry_sheet.dart';
import '../../../../core/services/tutorial_service.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../tutorials/more_tutorial.dart';
import 'hijri_calendar_screen.dart';
import '../../../quran/presentation/screens/mushaf_stress_test_screen.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  bool _tutorialShown = false;

  // Tab index for MoreScreen in the MainNavigator IndexedStack (0=Home,
  // 1=Bookmarks, 2=Wird, 3=More, 4=Settings).
  static const int _tabIndex = 3;

  @override
  void initState() {
    super.initState();
    // Listen for when this tab becomes active instead of triggering at mount
    // time, because IndexedStack mounts all tabs at startup.
    di.sl<TutorialService>().activeTabIndex.addListener(_onTabActivated);
  }

  @override
  void dispose() {
    di.sl<TutorialService>().activeTabIndex.removeListener(_onTabActivated);
    super.dispose();
  }

  void _onTabActivated() {
    if (di.sl<TutorialService>().activeTabIndex.value != _tabIndex) return;
    _tutorialShown = false; // allow retry when tab is revisited
    WidgetsBinding.instance.addPostFrameCallback((_) => _showTutorialIfNeeded());
  }

  void _showTutorialIfNeeded() {
    if (_tutorialShown) return;
    _tutorialShown = true;
    final tutorialService = di.sl<TutorialService>();
    final isArabic = context
        .read<AppSettingsCubit>()
        .state
        .appLanguageCode
        .toLowerCase()
        .startsWith('ar');
    final isDark = context.read<AppSettingsCubit>().state.darkMode;
    MoreTutorial.show(
      context: context,
      tutorialService: tutorialService,
      isArabic: isArabic,
      isDark: isDark,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabicUi = context
        .watch<AppSettingsCubit>()
        .state
        .appLanguageCode
        .toLowerCase()
        .startsWith('ar');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isArabicUi ? 'المزيد' : 'More',
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
      body: Builder(
        builder: (context) {
          return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          // ── App logo card ──────────────────────────────────────────────
          Card(
            margin: const EdgeInsets.only(bottom: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isDark
                    ? AppColors.secondary.withValues(alpha: 0.20)
                    : AppColors.cardBorder.withValues(alpha: 0.5),
                width: 0.8,
              ),
            ),
            clipBehavior: Clip.hardEdge,
            elevation: isDark ? 0 : 2,
            shadowColor: AppColors.primary.withValues(alpha: 0.12),
            child: Column(
              children: [
                // Gradient header strip
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient,
                  ),
                  child: Text(
                    isArabicUi ? 'تطبيق نور الإيمان' : 'Noor Al-Imaan App',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.arefRuqaa(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                // Logo body
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 18,
                    horizontal: 24,
                  ),
                  child: Column(
                    children: [
                      IslamicLogo(size: 80, darkTheme: isDark),
                      const SizedBox(height: 10),
                      Text(
                        isArabicUi ? 'الخدمات الإسلامية' : 'Islamic Services',
                        style: TextStyle(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ── Quran Playlist Banner ──────────────────────────────────────
          BlocBuilder<SurahBloc, SurahState>(
            builder: (context, surahState) {
              if (surahState is! SurahListLoaded)
                return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _QuranPlaylistBanner(
                  isArabicUi: isArabicUi,
                  surahs: surahState.surahs,
                ),
              );
            },
          ),

          // ── Section header ─────────────────────────────────────────────
          AppSectionHeader(
            isArabicUi ? 'الخدمات الإسلامية' : 'Islamic Services',
            Icons.grid_view_rounded,
          ),
          if (SettingsService.enableQuizFeature)
            _NavCard(
              title: isArabicUi ? 'التحدي اليومي' : 'Daily Challenge',
              subtitle: isArabicUi
                  ? 'سؤال ديني يومي مع لوحة المتصدرين'
                  : 'Daily religious question with leaderboard',
              icon: Icons.emoji_events_rounded,
              badge: isArabicUi ? 'جديد' : 'NEW',
              onTap: () {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null || user.isAnonymous) {
                  showQuizModeEntrySheet(
                    context,
                    isArabic: isArabicUi,
                  );
                } else {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const QuizScreen()),
                  );
                }
              },
            ),

          _NavCard(
            key: MoreTutorialKeys.feedbackCard,
            title: isArabicUi ? 'اقتراحات ومشاركات' : 'Feedback & Suggestions',
            subtitle: isArabicUi
                ? 'رأيك يُحسِّن التطبيق — نسخة بيتا'
                : 'Your input improves the app — Beta',
            icon: Icons.feedback_outlined,
            badge: 'BETA',
            onTap: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const FeedbackScreen()));
            },
          ),

          _NavCard(
            title: isArabicUi ? 'تحميل التفسير أوفلاين' : 'Offline Tafsir',
            subtitle: isArabicUi
                ? 'تنزيل وإدارة التفاسير مع استكمال من آخر نقطة'
                : 'Download and manage tafsir with resume support',
            icon: Icons.menu_book_rounded,
            imagePath: 'assets/logo/button icons/Tafsir-icon-mono.png',
            monochromeImage: false,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const OfflineTafsirScreen()),
              );
            },
          ),
          //DO Not delete, may be added back in the future when Ruqyah content is ready
        // _NavCard(
        //     title: isArabicUi ? 'الرقية الشرعية' : 'Ruqyah Shariah',
        //     subtitle: isArabicUi
        //         ? 'آيات الشفاء والحماية من القرآن الكريم'
        //         : 'Quranic verses for healing & protection',
        //     icon: Icons.healing_rounded,
        //     imagePath: 'assets/logo/button icons/Roqia-mono.png',
        //     monochromeImage: false,
        //     onTap: () {
        //       Navigator.of(
        //         context,
        //       ).push(MaterialPageRoute(builder: (_) => const RuqyahScreen()));
        //     },
        //   ),

          _NavCard(
            title: isArabicUi ? 'التقويم الهجري' : 'Hijri Calendar',
            subtitle: isArabicUi
                ? 'التواريخ الإسلامية والمناسبات الدينية'
                : 'Islamic dates & religious occasions',
            icon: Icons.calendar_month_rounded,
            imagePath: 'assetslogo/button icons/calendar.png',

            monochromeImage: false,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const HijriCalendarScreen()),
              );
            },
          ),

          // ── Developer Tools (only visible when flags are enabled) ─────
          if (SettingsService.enableMushafStressTest)
            _NavCard(
              title: isArabicUi ? 'اختبار المصحف' : 'Mushaf Stress Test',
              subtitle: isArabicUi
                  ? 'اختبار رسم صفحات المصحف تلقائياً'
                  : 'Automated rendering test for all pages',
              icon: Icons.speed_rounded,
              badge: 'DEV',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const MushafStressTestScreen(),
                  ),
                );
              },
            ),
        ],
      );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quran Playlist Banner
// ─────────────────────────────────────────────────────────────────────────────

class _QuranPlaylistBanner extends StatefulWidget {
  final bool isArabicUi;
  final List<Surah> surahs;

  const _QuranPlaylistBanner({required this.isArabicUi, required this.surahs});

  @override
  State<_QuranPlaylistBanner> createState() => _QuranPlaylistBannerState();
}

class _QuranPlaylistBannerState extends State<_QuranPlaylistBanner> {
  late final OfflineAudioService _audioService;
  late final AudioEditionService _editionService;
  late Future<List<AudioEdition>> _editionsFuture;

  @override
  void initState() {
    super.initState();
    _audioService = di.sl<OfflineAudioService>();
    _editionService = di.sl<AudioEditionService>();
    _editionsFuture = _editionService.getVerseByVerseAudioEditions();
  }

  void _playAll(BuildContext context) {
    final queue = widget.surahs
        .map((s) => (surahNumber: s.number, numberOfAyahs: s.numberOfAyahs))
        .toList();
    context.read<AyahAudioCubit>().playQueue(queue);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.isArabicUi
              ? 'يتم الآن تشغيل القرآن الكريم كاملاً 🎙'
              : 'Playing the full Holy Quran 🎙',
          textDirection: widget.isArabicUi ? TextDirection.rtl : TextDirection.ltr,
        ),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Future<void> _selectSurahs(BuildContext context) async {
    final selected = await showModalBottomSheet<List<Surah>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _SelectSurahsSheet(surahs: widget.surahs, isArabicUi: widget.isArabicUi),
    );
    if (selected == null || selected.isEmpty) return;
    if (!context.mounted) return;
    final queue = selected
        .map((s) => (surahNumber: s.number, numberOfAyahs: s.numberOfAyahs))
        .toList();
    context.read<AyahAudioCubit>().playQueue(queue);
  }

  Future<void> _showReciterPicker(BuildContext ctx) async {
    final editions = await _editionsFuture;
    if (!mounted) return;
    final isAr = widget.isArabicUi;
    await showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MoreReciterPickerSheet(
        all: editions,
        currentEdition: _audioService.edition,
        isAr: isAr,
        currentSurahNumber: ctx.read<AyahAudioCubit>().state.surahNumber,
        onSelected: (identifier) async {
          await _audioService.setEdition(identifier);
          if (mounted) {
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabicUi = widget.isArabicUi;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: AppColors.primaryGradient,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: isDark ? 0.40 : 0.30),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: 0.45),
          width: 1.2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _IslamicPatternPainter(
                  color: AppColors.secondary.withValues(alpha: 0.10),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.headphones_rounded,
                        color: AppColors.secondary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isArabicUi
                            ? 'استمع للقرآن الكريم'
                            : 'Listen to the Holy Quran',
                        style: GoogleFonts.arefRuqaa(
                          color: AppColors.onPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          letterSpacing: isArabicUi ? 0.5 : 0.3,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.headphones_rounded,
                        color: AppColors.secondary,
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                AppColors.secondary.withValues(alpha: 0.6),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(
                          Icons.star_rounded,
                          color: AppColors.secondary,
                          size: 14,
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.secondary.withValues(alpha: 0.6),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // ── Reciter row ──────────────────────────────────
                  FutureBuilder<List<AudioEdition>>(
                    future: _editionsFuture,
                    builder: (ctx, snap) {
                      final currentId = _audioService.edition;
                      final edition = snap.data
                          ?.where((e) => e.identifier == currentId)
                          .cast<AudioEdition?>()
                          .firstOrNull;
                      final name = edition?.displayNameForAppLanguage(
                              isArabicUi ? 'ar' : 'en') ??
                          currentId;
                      return GestureDetector(
                        onTap: () => _showReciterPicker(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.secondary.withValues(alpha: 0.35),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.mic_rounded,
                                color: AppColors.secondary,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  name,
                                  style: GoogleFonts.arefRuqaa(
                                    color: AppColors.onPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary.withValues(
                                      alpha: 0.25),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isArabicUi ? 'تغيير' : 'Change',
                                  style: const TextStyle(
                                    color: AppColors.secondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _BannerButton(
                          label: isArabicUi
                              ? 'تشغيل القرآن كاملاً'
                              : 'Play Full Quran',
                          icon: Icons.play_circle_fill_rounded,
                          filled: true,
                          onPressed: () => _playAll(context),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _BannerButton(
                          label: isArabicUi ? 'اختر سوراً' : 'Select Surahs',
                          icon: Icons.playlist_add_check_rounded,
                          filled: false,
                          onPressed: () => _selectSurahs(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// More Screen Reciter Picker Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _MoreReciterPickerSheet extends StatefulWidget {
  final List<AudioEdition> all;
  final String currentEdition;
  final bool isAr;
  final int? currentSurahNumber;
  final Future<void> Function(String identifier) onSelected;

  const _MoreReciterPickerSheet({
    required this.all,
    required this.currentEdition,
    required this.isAr,
    this.currentSurahNumber,
    required this.onSelected,
  });

  @override
  State<_MoreReciterPickerSheet> createState() =>
      _MoreReciterPickerSheetState();
}

class _MoreReciterPickerSheetState extends State<_MoreReciterPickerSheet> {
  late String _selected;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _langFilter = 'all';

  static bool _isQiraat(AudioEdition e) =>
      RecitationCatalog.isQiraatEdition(
        identifier: e.identifier,
        name: e.name,
        englishName: e.englishName,
      );

  static bool _isSurahLevelOnly(AudioEdition e) =>
      RecitationCatalog.isSurahLevelOnlyEdition(e.identifier);

  @override
  void initState() {
    super.initState();
    _selected = widget.currentEdition;
    final sel = widget.all
        .where((e) => e.identifier == widget.currentEdition)
        .cast<AudioEdition?>()
        .firstOrNull;
    if (sel != null && _isQiraat(sel)) _langFilter = 'qiraat';
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AudioEdition> _applyFilter(List<AudioEdition> src) {
    List<AudioEdition> list;
    if (_langFilter == 'qiraat') {
      list = src.where(_isQiraat).toList();
    } else if (_langFilter == 'ar') {
      list = src.where((e) => e.language == 'ar').toList();
    } else if (_langFilter == 'other') {
      list = src.where((e) => e.language != 'ar').toList();
    } else {
      list = src;
    }
    if (_query.isEmpty) return list;
    final q = _query;
    return list.where((e) {
      final name = e
          .displayNameForAppLanguage(widget.isAr ? 'ar' : 'en')
          .toLowerCase();
      return name.contains(q) || e.identifier.toLowerCase().contains(q);
    }).toList();
  }

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: color.withValues(alpha: 0.12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

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
    final filtered = _applyFilter(all);

    Widget buildTile(AudioEdition e) {
      final name = e.displayNameForAppLanguage(widget.isAr ? 'ar' : 'en');
      final isSelected = e.identifier == _selected;
      final isAvailableForCurrentSurah =
          widget.currentSurahNumber == null ||
          RecitationCatalog.isSurahAvailableForEdition(
            e.identifier,
            widget.currentSurahNumber!,
          );
      final qiraahLabel = RecitationCatalog.majorQiraahLabelForEditionId(
        e.identifier,
        isArabic: widget.isAr,
      );
      final qiraahColor = RecitationCatalog.majorQiraahColorForEditionId(
        e.identifier,
      );
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Material(
          color:
              isSelected ? accent.withValues(alpha: 0.10) : surfaceColor,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: !isAvailableForCurrentSurah
                ? null
                : () async {
                    setState(() => _selected = e.identifier);
                    await widget.onSelected(e.identifier);
                    if (context.mounted) Navigator.of(context).pop();
                  },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: isSelected ? accent : textColor,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        if (qiraahLabel != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: _badge(qiraahLabel, qiraahColor),
                          ),
                        if (!isAvailableForCurrentSurah)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: _badge(
                              widget.isAr
                                  ? 'غير متاح لهذه السورة'
                                  : 'Unavailable for this surah',
                              Colors.red,
                            ),
                          ),
                        if (RecitationCatalog.isTimedEdition(e.identifier))
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _badge(
                                  widget.isAr ? 'آية بآية ✦' : 'Per-ayah ✦',
                                  AppColors.primaryLight,
                                ),
                                const SizedBox(width: 4),
                                _badge(
                                  widget.isAr ? 'توقيتات ⏱' : 'Timed ⏱',
                                  Colors.blueAccent,
                                ),
                              ],
                            ),
                          )
                        else if (_isSurahLevelOnly(e))
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: _badge(
                              widget.isAr ? 'سورة كاملة' : 'Full surah',
                              accent,
                            ),
                          )
                        else if (RecitationCatalog.isWarshEdition(e.identifier))
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: _badge(
                              widget.isAr ? 'آية بآية' : 'Per-ayah',
                              AppColors.primaryLight,
                            ),
                          ),
                      ],
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
        ),
      );
    }

    Widget buildSectionHeader(String label, IconData icon) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
          child: Row(
            children: [
              Icon(icon, size: 13, color: subtleColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: subtleColor,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        );

    Widget buildFilterChip(
        String label, String filterKey) {
      final selected = _langFilter == filterKey;
      return GestureDetector(
        onTap: () => setState(() => _langFilter = filterKey),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? accent : surfaceColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? accent : accent.withValues(alpha: 0.18),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? Colors.white : textColor,
            ),
          ),
        ),
      );
    }

    final showCategorized = _query.isEmpty &&
        (_langFilter == 'all' || _langFilter == 'ar');

    return SafeArea(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
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
              // Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
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
                      widget.isAr ? 'اختر القارئ' : 'Choose Reciter',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${all.length} ${widget.isAr ? 'قارئ' : 'reciters'}',
                      style: TextStyle(fontSize: 12, color: subtleColor),
                    ),
                  ],
                ),
              ),
              // Search
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(fontSize: 13, color: textColor),
                  decoration: InputDecoration(
                    hintText: widget.isAr ? 'ابحث عن قارئ…' : 'Search reciter…',
                    hintStyle: TextStyle(fontSize: 13, color: subtleColor),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: subtleColor, size: 20),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.close_rounded,
                                size: 18, color: subtleColor),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    filled: true,
                    fillColor: surfaceColor,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
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
              // Filter chips
              SizedBox(
                height: 36,
                child: ListView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  scrollDirection: Axis.horizontal,
                  children: [
                    buildFilterChip(widget.isAr ? 'الكل' : 'All', 'all'),
                    const SizedBox(width: 6),
                    buildFilterChip(
                        widget.isAr ? 'القراءات ✦' : "Qira'at ✦", 'qiraat'),
                    const SizedBox(width: 6),
                    buildFilterChip(
                        widget.isAr ? 'العربية' : 'Arabic', 'ar'),
                    const SizedBox(width: 6),
                    buildFilterChip(
                        widget.isAr ? 'أخرى' : 'Other', 'other'),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.04),
              ),
              // Qira'at info banner
              if (_langFilter == 'qiraat')
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 8, 12, 2),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: accent.withValues(alpha: 0.08),
                    border:
                        Border.all(color: accent.withValues(alpha: 0.18)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 15, color: accent),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          widget.isAr
                              ? 'القراءات المعلَّمة بـ ⏱ تشتغل آية بآية. القراءات المعلَّمة بـ "سورة كاملة" تتطلب تحميل الملف أولاً.'
                              : 'Recitations marked ⏱ play per-ayah. Those marked "Full surah" require downloading first.',
                          style: TextStyle(
                            fontSize: 11,
                            color: accent.withValues(alpha: 0.90),
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              // List
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.50,
                ),
                child: filtered.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          widget.isAr ? 'لا توجد نتائج' : 'No results',
                          style: TextStyle(color: subtleColor),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : showCategorized
                        ? ListView(
                            padding: const EdgeInsets.only(top: 4, bottom: 8),
                            children: [
                              if (filtered
                                  .where((e) => !_isQiraat(e))
                                  .isNotEmpty) ...[
                                buildSectionHeader(
                                  widget.isAr
                                      ? 'القراء (حفص عن عاصم)'
                                      : 'Reciters (Hafs)',
                                  Icons.record_voice_over_rounded,
                                ),
                                ...filtered
                                    .where((e) => !_isQiraat(e))
                                    .map(buildTile),
                              ],
                              if (filtered
                                  .where(_isQiraat)
                                  .isNotEmpty) ...[
                                buildSectionHeader(
                                  widget.isAr
                                      ? 'القراءات والروايات ✦'
                                      : "Qira'at & Recitations ✦",
                                  Icons.auto_stories_rounded,
                                ),
                                ...filtered
                                    .where(_isQiraat)
                                    .map(buildTile),
                              ],
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 4),
                            itemBuilder: (ctx, i) => buildTile(filtered[i]),
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

// ─────────────────────────────────────────────────────────────────────────────
// Banner Button
// ─────────────────────────────────────────────────────────────────────────────

class _BannerButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onPressed;

  const _BannerButton({
    required this.label,
    required this.icon,
    required this.filled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.secondary;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: filled ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: accent.withValues(alpha: filled ? 0 : 0.6),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: filled ? Colors.white : accent,
              size: 15,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: filled ? Colors.white : accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Select Surahs Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _SelectSurahsSheet extends StatefulWidget {
  final List<Surah> surahs;
  final bool isArabicUi;

  const _SelectSurahsSheet({required this.surahs, required this.isArabicUi});

  @override
  State<_SelectSurahsSheet> createState() => _SelectSurahsSheetState();
}

class _SelectSurahsSheetState extends State<_SelectSurahsSheet> {
  final Set<int> _selected = {};
  String _query = '';

  List<Surah> get _filtered {
    if (_query.trim().isEmpty) return widget.surahs;
    final q = _query.trim().toLowerCase();
    return widget.surahs.where((s) {
      return s.name.contains(q) ||
          s.englishName.toLowerCase().contains(q) ||
          '${s.number}' == q;
    }).toList();
  }

  void _toggleAll() {
    setState(() {
      if (_selected.length == widget.surahs.length) {
        _selected.clear();
      } else {
        _selected.addAll(widget.surahs.map((s) => s.number));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filtered;
    final isAr = widget.isArabicUi;
    final selectedCount = _selected.length;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.playlist_add_check_rounded,
                      color: AppColors.secondary,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isAr ? 'اختر السور للتشغيل' : 'Select Surahs to Play',
                        style: const TextStyle(
                          color: AppColors.onPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _toggleAll,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        backgroundColor: AppColors.secondary.withValues(
                          alpha: 0.2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        _selected.length == widget.surahs.length
                            ? (isAr ? 'إلغاء الكل' : 'Deselect All')
                            : (isAr ? 'اختر الكل' : 'Select All'),
                        style: const TextStyle(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Search
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: TextField(
                  textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                  decoration: InputDecoration(
                    hintText: isAr ? 'ابحث عن سورة…' : 'Search surah…',
                    hintStyle: TextStyle(
                      color: isDark
                          ? const Color(0xFF8A9BAB)
                          : AppColors.textSecondary,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.primary,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? AppColors.darkCard
                        : AppColors.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: AppColors.secondary.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              // List
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          isAr ? 'لا توجد نتائج' : 'No results',
                          style: TextStyle(
                            color: isDark
                                ? const Color(0xFF8A9BAB)
                                : AppColors.textSecondary,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) {
                          final surah = filtered[i];
                          final isChecked = _selected.contains(surah.number);
                          return _SurahCheckTile(
                            surah: surah,
                            isArabicUi: isAr,
                            isChecked: isChecked,
                            isDark: isDark,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selected.add(surah.number);
                                } else {
                                  _selected.remove(surah.number);
                                }
                              });
                            },
                          );
                        },
                      ),
              ),
              // Bottom bar
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: Row(
                    children: [
                      if (selectedCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '$selectedCount ${isAr ? 'سورة' : 'Surah'}',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      if (selectedCount > 0) const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: selectedCount == 0
                              ? null
                              : () {
                                  final orderedSelected = widget.surahs
                                      .where(
                                        (s) => _selected.contains(s.number),
                                      )
                                      .toList();
                                  Navigator.of(context).pop(orderedSelected);
                                },
                          icon: const Icon(Icons.play_arrow_rounded, size: 20),
                          label: Text(
                            selectedCount == 0
                                ? (isAr
                                      ? 'اختر سورة أولاً'
                                      : 'Select a surah first')
                                : (isAr
                                      ? 'تشغيل $selectedCount ${selectedCount == 1 ? 'سورة' : 'سور'}'
                                      : 'Play $selectedCount ${selectedCount == 1 ? 'Surah' : 'Surahs'}'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.onPrimary,
                            disabledBackgroundColor: AppColors.primary
                                .withValues(alpha: 0.3),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SurahCheckTile extends StatelessWidget {
  final Surah surah;
  final bool isArabicUi;
  final bool isChecked;
  final bool isDark;
  final ValueChanged<bool?> onChanged;

  const _SurahCheckTile({
    required this.surah,
    required this.isArabicUi,
    required this.isChecked,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isChecked
            ? AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.08)
            : (isDark ? AppColors.darkCard : AppColors.surfaceVariant),
        border: Border.all(
          color: isChecked
              ? AppColors.primary.withValues(alpha: 0.5)
              : AppColors.secondary.withValues(alpha: 0.15),
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: () => onChanged(!isChecked),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            textDirection: isArabicUi ? TextDirection.rtl : TextDirection.ltr,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    '${surah.number}',
                    style: const TextStyle(
                      color: AppColors.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: isArabicUi
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    // Surah name - Arabic calligraphic style
                    Text(
                      isArabicUi
                          ? getSurahNameArabic(surah.number)
                          : surah.englishName,
                      textDirection: isArabicUi
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      locale: isArabicUi ? const Locale('ar') : null,
                      style: isArabicUi
                          ? GoogleFonts.arefRuqaa(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppColors.onPrimary
                                  : AppColors.textPrimary,
                            )
                          : TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: isDark
                                  ? AppColors.onPrimary
                                  : AppColors.textPrimary,
                            ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${surah.numberOfAyahs} ${isArabicUi ? 'آية' : 'ayahs'}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? const Color(0xFF8A9BAB)
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isChecked ? AppColors.primary : Colors.transparent,
                  border: Border.all(
                    color: isChecked
                        ? AppColors.primary
                        : AppColors.secondary.withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
                child: isChecked
                    ? const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: Colors.white,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IslamicPatternPainter extends CustomPainter {
  final Color color;

  _IslamicPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const spacing = 40.0;
    for (double x = 0; x < size.width + spacing; x += spacing) {
      for (double y = 0; y < size.height + spacing; y += spacing) {
        _drawStar(canvas, Offset(x, y), 12, paint);
      }
    }
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    const points = 8;
    const angle = (3.14159 * 2) / points;
    for (int i = 0; i < points; i++) {
      final x = center.dx + radius * math.cos(angle * i - 3.14159 / 2);
      final y = center.dy + radius * math.sin(angle * i - 3.14159 / 2);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────

class _NavCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String? imagePath;
  final bool monochromeImage;
  final VoidCallback onTap;
  final String? badge;

  const _NavCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.imagePath,
    this.monochromeImage = false,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: isDark ? 0 : 1,
      shadowColor: AppColors.primary.withValues(alpha: 0.10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark
              ? AppColors.darkBorder.withValues(alpha: 0.5)
              : AppColors.cardBorder.withValues(alpha: 0.5),
          width: 0.8,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(
                        alpha: isDark ? 0.25 : 0.20,
                      ),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: imagePath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Transform.scale(
                          scale: 1.35,
                          child: Image.asset(
                            imagePath!,
                            width: 50,
                            height: 50,
                            fit: BoxFit.contain,
                            color: monochromeImage ? Colors.white : null,
                            colorBlendMode:
                                monochromeImage ? BlendMode.srcATop : null,
                            errorBuilder: (context, error, stackTrace) =>
                                Icon(icon, color: Colors.white, size: 24),
                          ),
                        ),
                      )
                    : Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: isDark
                                      ? AppColors.darkTextPrimary
                                      : null,
                                ),
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: AppColors.secondary.withValues(
                                    alpha: 0.30),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              badge!,
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.secondary
                                    : AppColors.accent,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark
                    ? AppColors.secondary.withValues(alpha: 0.45)
                    : AppColors.primary.withValues(alpha: 0.35),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
