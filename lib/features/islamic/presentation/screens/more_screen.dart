import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/audio/ayah_audio_cubit.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/settings/app_settings_cubit.dart';
import '../../../../core/widgets/islamic_logo.dart';
import '../../../quran/domain/entities/surah.dart';
import '../../../quran/presentation/bloc/surah/surah_bloc.dart';
import '../../../quran/presentation/bloc/surah/surah_state.dart';
import 'adhan_settings_screen.dart';
import 'duaa_screen.dart';
import 'prayer_times_screen.dart';
import 'qiblah_screen.dart';
import '../../../adhkar/presentation/screens/tasbeeh_screen.dart';
import '../../../quran/presentation/screens/feedback_screen.dart';
import '../../../quran/presentation/screens/offline_tafsir_screen.dart';
import '../../../ruqyah/presentation/screens/ruqyah_screen.dart';
import '../../../hadith/presentation/screens/hadith_categories_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../quiz/presentation/screens/quiz_screen.dart';
import '../../../quiz/presentation/widgets/quiz_sign_in_sheet.dart';
import 'package:qcf_quran/qcf_quran.dart';
import '../../../../core/services/tutorial_service.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../tutorials/more_tutorial.dart';

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
        title: Text(isArabicUi ? 'المزيد' : 'More'),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: AppColors.primaryGradient),
        ),
      ),
      body: Builder(
        builder: (context) {
          return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── App logo card ──────────────────────────────────────────────
          Card(
            margin: const EdgeInsets.only(bottom: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            clipBehavior: Clip.hardEdge,
            elevation: 2,
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
                    isArabicUi ? 'تطبيق القرآن الكريم' : 'Quran Application',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      fontFamily: 'Amiri',
                    ),
                  ),
                ),
                // Logo body
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 22,
                    horizontal: 24,
                  ),
                  child: Column(
                    children: [
                      IslamicLogo(size: 90, darkTheme: isDark),
                      const SizedBox(height: 12),
                      Text(
                        isArabicUi ? 'الخدمات الإسلامية' : 'Islamic Services',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 8, 2, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.22),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.grid_view_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        isArabicUi ? 'الخدمات الإسلامية' : 'Islamic Services',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Divider(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          if (SettingsService.enableQuizFeature)
            _NavCard(
              title: isArabicUi ? 'المسابقة اليومية' : 'Daily Quiz',
              subtitle: isArabicUi
                  ? 'سؤال ديني يومي مع لوحة المتصدرين'
                  : 'Daily religious question with leaderboard',
              icon: Icons.emoji_events_rounded,
              badge: isArabicUi ? 'جديد' : 'NEW',
              onTap: () {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null || user.isAnonymous) {
                  showQuizSignInSheet(
                    context,
                    isArabic: isArabicUi,
                    onAuthenticated: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const QuizScreen()),
                    ),
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
        _NavCard(
            title: isArabicUi ? 'الرقية الشرعية' : 'Ruqyah Shariah',
            subtitle: isArabicUi
                ? 'آيات الشفاء والحماية من القرآن الكريم'
                : 'Quranic verses for healing & protection',
            icon: Icons.healing_rounded,
            imagePath: 'assets/logo/button icons/Roqia-mono.png',
            monochromeImage: false,
            onTap: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const RuqyahScreen()));
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

class _QuranPlaylistBanner extends StatelessWidget {
  final bool isArabicUi;
  final List<Surah> surahs;

  const _QuranPlaylistBanner({required this.isArabicUi, required this.surahs});

  void _playAll(BuildContext context) {
    final queue = surahs
        .map((s) => (surahNumber: s.number, numberOfAyahs: s.numberOfAyahs))
        .toList();
    context.read<AyahAudioCubit>().playQueue(queue);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isArabicUi
              ? 'يتم الآن تشغيل القرآن الكريم كاملاً 🎙'
              : 'Playing the full Holy Quran 🎙',
          textDirection: isArabicUi ? TextDirection.rtl : TextDirection.ltr,
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
          _SelectSurahsSheet(surahs: surahs, isArabicUi: isArabicUi),
    );
    if (selected == null || selected.isEmpty) return;
    if (!context.mounted) return;
    final queue = selected
        .map((s) => (surahNumber: s.number, numberOfAyahs: s.numberOfAyahs))
        .toList();
    context.read<AyahAudioCubit>().playQueue(queue);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: AppColors.primaryGradient,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _IslamicPatternPainter(
                  color: AppColors.secondary.withValues(alpha: 0.12),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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
                        style: TextStyle(
                          color: AppColors.onPrimary,
                          fontWeight: FontWeight.w800,
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
    if (filled) {
      return ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.secondary,
          foregroundColor: AppColors.onBackground,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
      );
    } else {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18, color: AppColors.secondary),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: const TextStyle(
              color: AppColors.onPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          side: const BorderSide(color: AppColors.secondary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    }
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
                    // IMPORTANT: Do not change this back to normal text. The user explicitly requested the specialized Quran font for Arabic Surah names.
                    Text(
                      isArabicUi
                          ? 'surah${surah.number.toString().padLeft(3, '0')}'
                          : surah.englishName,
                      textDirection: isArabicUi
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      locale: isArabicUi ? const Locale('ar') : null,
                      style: isArabicUi
                          ? TextStyle(
                              fontFamily: SurahFontHelper.fontFamily,
                              package: 'qcf_quran',
                              fontSize: 32,
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
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: imagePath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: Image.asset(
                          imagePath!,
                          width: 48,
                          height: 48,
                          fit: BoxFit.contain,
                          color: monochromeImage ? Colors.white : null,
                          colorBlendMode: monochromeImage ? BlendMode.srcATop : null,
                          errorBuilder: (context, error, stackTrace) =>
                              Icon(icon, color: Colors.white, size: 22),
                        ),
                      )
                    : Icon(icon, color: Colors.white, size: 22),
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
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              badge!,
                              style: const TextStyle(
                                color: AppColors.secondary,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}