import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../bloc/surah/surah_bloc.dart';
import '../bloc/surah/surah_event.dart';
import '../bloc/surah/surah_state.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_design_system.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/services/settings_service.dart';
import '../../../../core/settings/app_settings_cubit.dart';
import '../../../../core/audio/ayah_audio_cubit.dart';
import '../../../../core/widgets/islamic_logo.dart';
import '../../../islamic/presentation/screens/adhan_settings_screen.dart';
import '../../../islamic/presentation/screens/prayer_times_screen.dart';
import '../../../adhkar/presentation/screens/adhkar_categories_screen.dart';
import '../../../adhkar/presentation/screens/tasbeeh_screen.dart';
import 'offline_audio_screen.dart';
import 'quran_radio_screen.dart';
import 'juz_list_screen.dart';
import '../../../islamic/presentation/widgets/next_prayer_countdown.dart';
import 'package:noor_al_imaan/features/quran/presentation/screens/surah_detail_screen.dart';
import '../../../islamic/presentation/screens/qiblah_screen.dart';
import '../../../hadith/presentation/screens/hadith_categories_screen.dart';
import 'search_screen.dart';
import '../../../../core/services/tutorial_service.dart';
import '../tutorials/home_tutorial.dart';
import '../../../../core/utils/hijri_utils.dart' as hijri;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  static const MethodChannel _adhanChannel = MethodChannel(
    'quraan/adhan_player',
  );

  final Map<int, String> _juzLabelBySurahNumber = {};
  final Set<int> _loadingJuzForSurah = {};
  bool _batteryUnrestricted = true; // default true = no warning until checked
  bool _tutorialShown = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSurahs();
    _checkBatteryStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkBatteryStatus();
    }
  }

  Future<void> _checkBatteryStatus() async {
    try {
      final disabled =
          await _adhanChannel.invokeMethod<bool>(
            'isBatteryOptimizationDisabled',
          ) ??
          false;
      if (mounted) setState(() => _batteryUnrestricted = disabled);
    } catch (_) {
      // Not Android or channel unavailable — assume unrestricted
      if (mounted) setState(() => _batteryUnrestricted = true);
    }
  }

  void _loadSurahs() {
    final currentState = context.read<SurahBloc>().state;
    // Only load if we don't have the list or if we have an error/detail state
    if (currentState is! SurahListLoaded) {
      context.read<SurahBloc>().add(GetAllSurahsEvent());
    }
  }

  void reload() {
    context.read<SurahBloc>().add(GetAllSurahsEvent());
  }

  void showTutorial() {
    _tutorialShown = false;
    _tryShowTutorial();
  }

  void _tryShowTutorial() {
    if (_tutorialShown) return;
    final tutorialService = di.sl<TutorialService>();
    if (tutorialService.isTutorialComplete(TutorialService.homeScreen)) return;
    _tutorialShown = true;
    final isArabic = context
        .read<AppSettingsCubit>()
        .state
        .appLanguageCode
        .toLowerCase()
        .startsWith('ar');
    final isDark = context.read<AppSettingsCubit>().state.darkMode;
    HomeTutorial.show(
      context: context,
      tutorialService: tutorialService,
      isArabic: isArabic,
      isDark: isDark,
    );
  }

  String _revelationLabel(String revelationType, {required bool isArabicUi}) {
    final value = revelationType.toLowerCase().trim();
    if (!isArabicUi) {
      return value.startsWith('med') ? 'Medinan' : 'Meccan';
    }
    return value.startsWith('med') ? 'مدنية' : 'مكية';
  }

  String _ayahCountLabel(int count, {required bool isArabicUi}) {
    if (!isArabicUi) return '$count Ayahs';
    // Keep it simple; Arabic pluralization can be refined later.
    return '$count آية';
  }

  Future<void> _ensureJuzLabel(int surahNumber) async {
    if (_juzLabelBySurahNumber.containsKey(surahNumber)) return;
    if (_loadingJuzForSurah.contains(surahNumber)) return;
    _loadingJuzForSurah.add(surahNumber);

    try {
      final jsonString = await rootBundle.loadString(
        'assets/offline/surah_$surahNumber.json',
      );
      final decoded = jsonDecode(jsonString);
      final ayahs = (decoded is Map<String, dynamic>)
          ? (decoded['ayahs'] as List?)
          : null;

      int? firstJuz;
      int? lastJuz;
      if (ayahs != null && ayahs.isNotEmpty) {
        final first = ayahs.first;
        final last = ayahs.last;
        if (first is Map) {
          final v = first['juz'];
          if (v is int) firstJuz = v;
        }
        if (last is Map) {
          final v = last['juz'];
          if (v is int) lastJuz = v;
        }
      }

      if (firstJuz != null) {
        final label = (lastJuz != null && lastJuz != firstJuz)
            ? 'Juz $firstJuz-$lastJuz'
            : 'Juz $firstJuz';
        _juzLabelBySurahNumber[surahNumber] = label;
        if (mounted) setState(() {});
      }
    } catch (_) {
      // Ignore; juz will simply not show.
    } finally {
      _loadingJuzForSurah.remove(surahNumber);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final isArabicUi = context
        .watch<AppSettingsCubit>()
        .state
        .appLanguageCode
        .toLowerCase()
        .startsWith('ar');
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: IslamicLogo(
            size: 32,
            darkTheme: context.watch<AppSettingsCubit>().state.darkMode,
          ),
        ),
        title: Builder(builder: (ctx) {
          final offset = ctx
              .watch<AppSettingsCubit>()
              .state
              .hijriDateOffset;
          final hDate = hijri.todayHijri(offset);
          final dateStr = hijri.formatHijriDate(
            hDate[0], hDate[1], hDate[2],
            isAr: isArabicUi,
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isArabicUi ? 'نور الإيمان' : 'Noor Al-Imaan',
                // style: const TextStyle(
                //   color: Colors.white,
                //   fontWeight: FontWeight.bold,
                //   fontSize: 18,
                //   fontFamily: GoogleFonts.amiriQuran().fon,
                // ),
                style: GoogleFonts.arefRuqaa(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                dateStr,
                // style: const TextStyle(
                //   color: Colors.white70,
                //   fontSize: 11,
                // ),
                style: GoogleFonts.arefRuqaa(
                  fontSize: 11,
                  color: Colors.white70,
                ),
              ),
            ],
          );
        }),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        actions: [
          // Search button
          _AppBarActionButton(
            key: HomeTutorialKeys.searchButton,
            icon: Icons.search_rounded,
            tooltip: isArabicUi ? 'بحث' : 'Search',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SearchScreen()),
            ),
          ),
          // Dark mode toggle
          _AppBarActionButton(
            key: HomeTutorialKeys.darkModeButton,
            icon: context.watch<AppSettingsCubit>().state.darkMode
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded,
            tooltip: isArabicUi
                ? (context.watch<AppSettingsCubit>().state.darkMode
                      ? 'الوضع الفاتح'
                      : 'الوضع الداكن')
                : (context.watch<AppSettingsCubit>().state.darkMode
                      ? 'Light Mode'
                      : 'Dark Mode'),
            onPressed: () {
              final cubit = context.read<AppSettingsCubit>();
              cubit.setDarkMode(!cubit.state.darkMode);
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: BlocConsumer<SurahBloc, SurahState>(
        // listener fires once per state transition — safe place for side effects.
        listener: (context, state) {
          if (state is SurahListLoaded) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _tryShowTutorial());
          }
        },
        builder: (context, state) {
          if (state is SurahLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is SurahListLoaded) {
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: NextPrayerCountdown(key: HomeTutorialKeys.prayerCountdown)),
                SliverToBoxAdapter(
                  child: Padding(
                    key: HomeTutorialKeys.categoriesSection,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: _CategoriesSection(
                      isArabicUi: isArabicUi,
                      batteryUnrestricted: _batteryUnrestricted,
                      onBatteryCheck: _checkBatteryStatus,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final surah = state.surahs[index];
                      _ensureJuzLabel(surah.number);
                      final juzLabel = _juzLabelBySurahNumber[surah.number];

                      final revelation = _revelationLabel(
                        surah.revelationType,
                        isArabicUi: isArabicUi,
                      );
                      final ayahs = _ayahCountLabel(
                        surah.numberOfAyahs,
                        isArabicUi: isArabicUi,
                      );
                      final juz = juzLabel == null
                          ? null
                          : (isArabicUi
                                ? juzLabel.replaceFirst('Juz', 'الجزء')
                                : juzLabel);
                      final detailsParts = <String>[
                        revelation,
                        ayahs,
                        if (juz != null) juz,
                      ];
                      final detailsLine = detailsParts.join(' • ');

                      return Card(
                        key: index == 0 ? HomeTutorialKeys.firstSurahCard : null,
                        margin: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SurahDetailScreen(
                                    surahNumber: surah.number,
                                    surahName: isArabicUi
                                        ? surah.name
                                        : surah.englishName,
                                  ),
                                ),
                              );
                            },
                            borderRadius: AppDesignSystem.borderRadiusLg,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              child: Row(
                                textDirection: isArabicUi
                                    ? TextDirection.rtl
                                    : TextDirection.ltr,
                                children: [
                                  // Surah number badge
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      gradient: AppColors.primaryGradient,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.secondary.withValues(alpha: 0.4),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${surah.number}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              color: AppColors.onPrimary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: isArabicUi
                                          ? CrossAxisAlignment.end
                                          : CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isArabicUi
                                              ? surah.name
                                              : surah.englishName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: isArabicUi
                                              ? TextAlign.right
                                              : TextAlign.left,
                                          textDirection: isArabicUi
                                              ? TextDirection.rtl
                                              : TextDirection.ltr,
                                          locale: isArabicUi
                                              ? const Locale('ar')
                                              : null,
                                          strutStyle: isArabicUi
                                              ? const StrutStyle(
                                                  height: 1.6,
                                                  forceStrutHeight: true,
                                                )
                                              : null,
                                          style: isArabicUi
                                              ? GoogleFonts.amiriQuran (
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w700,
                                                  height: 1.6050,
                                                  color: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium
                                                      ?.color,
                                                )
                                              : Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 16,
                                                    ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          detailsLine,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: isArabicUi
                                              ? TextAlign.right
                                              : TextAlign.left,
                                          textDirection: isArabicUi
                                              ? TextDirection.rtl
                                              : TextDirection.ltr,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Play button
                                  Material(
                                    key: index == 0 ? HomeTutorialKeys.firstPlayButton : null,
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: AppDesignSystem.borderRadiusMd,
                                      onTap: () {
                                        context
                                            .read<AyahAudioCubit>()
                                            .togglePlaySurah(
                                              surahNumber: surah.number,
                                              numberOfAyahs:
                                                  surah.numberOfAyahs,
                                            );
                                      },
                                      child: Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                          borderRadius: AppDesignSystem.borderRadiusMd,
                                        ),
                                        child: Tooltip(
                                          message: isArabicUi
                                              ? 'تشغيل السورة كاملة'
                                              : 'Play full surah',
                                          child: Icon(
                                            Icons.play_arrow_rounded,
                                            color: Theme.of(context).colorScheme.primary,
                                            size: 22,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      );
                    }, childCount: state.surahs.length),
                  ),
                ),
              ],
            );
          } else if (state is SurahError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text(
                    state.message,
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      context.read<SurahBloc>().add(GetAllSurahsEvent());
                    },
                    icon: const Icon(Icons.refresh),
                    label: Text(isArabicUi ? 'إعادة المحاولة' : 'Retry'),
                  ),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _CategoriesSection extends StatelessWidget {
  final bool isArabicUi;
  final bool batteryUnrestricted;
  final VoidCallback onBatteryCheck;

  const _CategoriesSection({
    required this.isArabicUi,
    this.batteryUnrestricted = true,
    required this.onBatteryCheck,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: isDark ? 0.35 : 0.28),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: isDark ? 0.14 : 0.09),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Islamic pattern background
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: CustomPaint(
                painter: _IslamicPatternPainter(
                  color: isDark
                      ? AppColors.secondary.withValues(alpha: 0.04)
                      : AppColors.primary.withValues(alpha: 0.04),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [AppColors.darkCard, AppColors.darkSurface]
                    : [const Color(0xFFFBF9F6), const Color(0xFFF5EFE6)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 1.0,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.secondary.withValues(alpha: 0.0),
                              AppColors.secondary.withValues(
                                alpha: isDark ? 0.45 : 0.32,
                              ),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(
                              alpha: isDark ? 0.65 : 0.45,
                            ),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isArabicUi ? 'الأقسام' : 'Sections',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? AppColors.secondary
                                    : AppColors.primary,
                                letterSpacing: 1.5,
                              ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(
                              alpha: isDark ? 0.65 : 0.45,
                            ),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        height: 1.0,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.secondary.withValues(
                                alpha: isDark ? 0.45 : 0.32,
                              ),
                              AppColors.secondary.withValues(alpha: 0.0),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    const gap = 10.0;
                    final w = (constraints.maxWidth - gap * 2) / 3;
                    Widget wrap(Widget child) => SizedBox(
                      width: w,
                      child: AspectRatio(aspectRatio: 0.90, child: child),
                    );
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      alignment: WrapAlignment.center,
                      children: [
                        wrap(
                          _CategoryTile(
                            label: isArabicUi
                                ? 'مواقيت الصلاة'
                                : 'Prayer Times',
                            imagePath: 'assets/logo/button icons/moon.png',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const PrayerTimesScreen(),
                              ),
                            ),
                          ),
                        ),
                        wrap(
                          _CategoryTile(
                            label: isArabicUi ? 'الأذكار والأدعية' : 'Adhkar',
                            imagePath: 'assets/logo/button icons/praying.png',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AdhkarCategoriesScreen(),
                              ),
                            ),
                          ),
                        ),
                        wrap(
                          _CategoryTile(
                            label: isArabicUi ? 'الأذان' : 'Adhan',
                            imagePath:
                                'assets/logo/button icons/nabawi-mosque.png',
                            imagePadding: 3,
                            showDisabledBadge:
                                !di
                                    .sl<SettingsService>()
                                    .getAdhanNotificationsEnabled() ||
                                !batteryUnrestricted,
                            disabledTooltip:
                                !di
                                    .sl<SettingsService>()
                                    .getAdhanNotificationsEnabled()
                                ? (isArabicUi
                                      ? 'الأذان معطَّل'
                                      : 'Adhan disabled')
                                : (isArabicUi
                                      ? 'لضمان سماع الأذان افتح إعدادات البطارية'
                                      : 'Open battery settings for reliable Adhan'),
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const AdhanSettingsScreen(),
                                ),
                              );
                              onBatteryCheck();
                            },
                          ),
                        ),
                        wrap(
                          _CategoryTile(
                            label: isArabicUi ? 'الصوت' : 'Audio',
                            imagePath:
                                'assets/logo/button icons/microphone.png',
                            imagePadding: 2,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const OfflineAudioScreen(),
                              ),
                            ),
                          ),
                        ),
                        wrap(
                          _CategoryTile(
                            label: isArabicUi ? 'الأجزاء' : 'Juz',
                            imagePath: 'assets/logo/button icons/quran.png',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const JuzListScreen(),
                              ),
                            ),
                          ),
                        ),
                        wrap(
                          _CategoryTile(
                            label: isArabicUi ? 'القبلة' : 'Qibla',
                            imagePath: 'assets/logo/button icons/qibla.png',
                            imagePadding: 0,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const QiblahScreen(),
                              ),
                            ),
                          ),
                        ),
                        wrap(
                          _CategoryTile(
                            label: isArabicUi ? 'السبحة' : 'Tasbeeh',
                            imagePath: 'assets/logo/button icons/beads.png',
                            imagePadding: 3,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const TasbeehScreen(),
                              ),
                            ),
                          ),
                        ),
                        wrap(
                          _CategoryTile(
                            label: isArabicUi ? 'الإذاعة' : 'Radio',
                            imagePath: 'assets/logo/button icons/radio.png',
                            imagePadding: 3,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const QuranRadioScreen(),
                              ),
                            ),
                          ),
                        ),
                        wrap(
                          _CategoryTile(
                            label: isArabicUi ? 'الأحاديث النبوية' : 'Hadiths',
                            imagePath: 'assets/logo/button icons/hadith.png',
                            imagePadding: 3,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const HadithCategoriesScreen(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Islamic geometric pattern painter
// ─────────────────────────────────────────────────────────────────────────────

class _IslamicPatternPainter extends CustomPainter {
  final Color color;

  _IslamicPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final spacing = 40.0;

    // Draw star pattern
    for (double x = 0; x < size.width + spacing; x += spacing) {
      for (double y = 0; y < size.height + spacing; y += spacing) {
        _drawStar(canvas, Offset(x, y), 12, paint);
      }
    }
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    final points = 8;
    final angle = (3.14159 * 2) / points;

    for (int i = 0; i < points; i++) {
      final x = center.dx + radius * cos(angle * i - 3.14159 / 2);
      final y = center.dy + radius * sin(angle * i - 3.14159 / 2);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  double cos(double angle) => math.cos(angle);
  double sin(double angle) => math.sin(angle);

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CategoryTile extends StatelessWidget {
  final String label;
  final String? imagePath;
  final IconData? iconData;
  final VoidCallback onTap;
  final double imagePadding;
  final bool showDisabledBadge;
  final String? disabledTooltip;

  const _CategoryTile({
    required this.label,
    required this.onTap,
    this.imagePath,
    this.iconData,
    this.imagePadding = 4,
    this.showDisabledBadge = false,
    this.disabledTooltip,
  }) : assert(
         imagePath != null || iconData != null,
         'Provide imagePath or iconData',
       );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: AppColors.secondary.withValues(alpha: 0.10),
        highlightColor: AppColors.secondary.withValues(alpha: 0.05),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: isDark ? AppColors.darkCard : Colors.white,
            border: Border.all(
              color: AppColors.secondary.withValues(
                alpha: isDark ? 0.20 : 0.15,
              ),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.secondary.withValues(
                  alpha: isDark ? 0.08 : 0.10,
                ),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                // Thin gold top accent strip
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.secondary.withValues(
                          alpha: isDark ? 0.55 : 0.40,
                        ),
                        AppColors.goldGradientEnd.withValues(
                          alpha: isDark ? 0.75 : 0.60,
                        ),
                        AppColors.secondary.withValues(
                          alpha: isDark ? 0.55 : 0.40,
                        ),
                      ],
                    ),
                  ),
                ),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 10,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon circle with green gradient
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.secondary.withValues(
                                alpha: 0.50,
                              ),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(
                                  alpha: 0.22,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (iconData != null)
                                Icon(
                                  iconData,
                                  color: AppColors.onPrimary,
                                  size: 30,
                                )
                              else
                                Padding(
                                  padding: EdgeInsets.all(imagePadding),
                                  child: Image.asset(
                                    imagePath!,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              if (showDisabledBadge)
                                Positioned(
                                  top: 1,
                                  right: 1,
                                  child: Tooltip(
                                    message: disabledTooltip ?? '',
                                    child: Container(
                                      width: 11,
                                      height: 11,
                                      decoration: BoxDecoration(
                                        color: Colors.orange,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.orange.withValues(
                                              alpha: 0.6,
                                            ),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Label
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: TextStyle(
                              color: isDark
                                  ? const Color(0xFFE8E0D0)
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
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

// ─────────────────────────────────────────────────────────────────────────────
// Shared AppBar action button
// ─────────────────────────────────────────────────────────────────────────────

class _AppBarActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _AppBarActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: AppDesignSystem.borderRadiusMd,
      ),
      child: IconButton(
        icon: Icon(icon, color: AppColors.onPrimary, size: 20),
        tooltip: tooltip,
        onPressed: onPressed,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      ),
    );
  }
}