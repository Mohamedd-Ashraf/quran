import 'dart:convert';

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
import '../../../islamic/presentation/screens/hijri_calendar_screen.dart';
import '../../../hadith/presentation/screens/hadith_categories_screen.dart';
import 'search_screen.dart';
import '../../../../core/services/tutorial_service.dart';
import '../tutorials/home_tutorial.dart';
import '../../../../core/utils/hijri_utils.dart' as hijri;

// Cached at file scope — avoids triggering loadFontIfNecessary on every build,
// which causes unhandled rejections with google_fonts ≥6.2 in Flutter.
final TextStyle _cachedAmiri      = GoogleFonts.amiri();
final TextStyle _cachedAmiriQuran = GoogleFonts.amiriQuran();
final TextStyle _cachedArefRuqaa  = GoogleFonts.arefRuqaa();

/// Remove Arabic diacritical marks (تشكيل) from text.
String _removeDiacriticsHelper(String text) {
  const diacritics = [
    '\u064B', // Fathatan
    '\u064C', // Dammatan
    '\u064D', // Kasratan
    '\u064E', // Fatha
    '\u064F', // Damma
    '\u0650', // Kasra
    '\u0651', // Shadda
    '\u0652', // Sukun
    '\u0653', // Maddah
    '\u0654', // Hamza above
    '\u0655', // Hamza below
    '\u0656', // Subscript alef
    '\u0657', // Inverted damma
    '\u0658', // Mark noon ghunna
    '\u0670', // Superscript alef
  ];
  String result = text;
  for (final diacritic in diacritics) {
    result = result.replaceAll(diacritic, '');
  }
  return result;
}

/// Converts an integer to Arabic-Indic numeral string (٠١٢٣٤٥٦٧٨٩).
String _toArabicNumStr(int n) {
  const d = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  return n.toString().split('').map((c) {
    final digit = int.tryParse(c);
    return digit != null ? d[digit] : c;
  }).join();
}

/// Converts all ASCII digits in a string to Arabic-Indic.
String _arabicizeDigits(String s) {
  const d = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  return s.split('').map((c) {
    final digit = int.tryParse(c);
    return digit != null ? d[digit] : c;
  }).join();
}

/// Surah number style with classical Amiri font.
TextStyle _surahNumberStyle(BuildContext context) {
  return _cachedAmiri.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.onPrimary,
  );
}

/// Builds a RichText for details line with Amiri font on numbers.
Widget _buildDetailsLineWithAmiriNumbers(
  String detailsLine,
  BuildContext context, {
  bool isRtl = false,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final baseStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
    color: isDark ? AppColors.darkTextSecondary : null,
  );
  final amiriStyle = _cachedAmiri.copyWith(
    fontWeight: FontWeight.w700,
  ).copyWith(
    fontSize: baseStyle?.fontSize,
    color: baseStyle?.color,
    height: baseStyle?.height,
  );
  final dotStyle = baseStyle?.copyWith(
    color: isDark
        ? AppColors.secondary.withValues(alpha: 0.45)
        : AppColors.primary.withValues(alpha: 0.35),
    fontSize: 10,
  );

  final spans = <InlineSpan>[];
  final chars = detailsLine.split('');

  for (final char in chars) {
    // Check if character is Arabic-Indic digit (٠-٩)
    final isArabicDigit = char.codeUnitAt(0) >= 0x0660 && char.codeUnitAt(0) <= 0x0669;
    final isDot = char == '•';
    spans.add(
      TextSpan(
        text: char,
        style: isDot ? dotStyle : (isArabicDigit ? amiriStyle : baseStyle),
      ),
    );
  }

  return RichText(
    text: TextSpan(children: spans),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    textAlign: isRtl ? TextAlign.right : TextAlign.left,
    textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
  );
}

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
    return '${_toArabicNumStr(count)} آية';
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
        title: Builder(
          builder: (ctx) {
            final offset = ctx.watch<AppSettingsCubit>().state.hijriDateOffset;
            final hDate = hijri.todayHijri(offset);
            final dateStr = hijri.formatHijriDate(
              hDate[0],
              hDate[1],
              hDate[2],
              isAr: isArabicUi,
            );
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isArabicUi ? 'نور الإيمان' : 'Noor Al-Imaan',
                  style: Theme.of(ctx).appBarTheme.titleTextStyle,
                ),
                const SizedBox(height: 1),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.secondary.withValues(alpha: 0.85),
                  ),
                ),
              ],
            );
          },
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
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _tryShowTutorial(),
            );
          }
        },
        builder: (context, state) {
          if (state is SurahLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is SurahListLoaded) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PrayerTimesScreen(),
                      ),
                    ),
                    child: NextPrayerCountdown(
                      key: HomeTutorialKeys.prayerCountdown,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _ContinueReadingCard(
                    isArabicUi: isArabicUi,
                    surahs: state.surahs,
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 4),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    key: HomeTutorialKeys.categoriesSection,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: _QuickAccessBar(
                      isArabicUi: isArabicUi,
                      batteryUnrestricted: _batteryUnrestricted,
                      onBatteryCheck: _checkBatteryStatus,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                    child: Row(
                      children: [
                        Text(
                          isArabicUi ? 'قائمة السور' : 'Surah List',
                          style: _cachedArefRuqaa.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color.fromARGB(255, 241, 202, 61) : AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        
                        Expanded(
                          child: Container(
                            height: 2.5,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isDark
                                    ? [
                                        const Color.fromARGB(255, 241, 202, 61).withValues(alpha: 0.5),
                                        const Color.fromARGB(255, 255, 223, 100),
                                        // const Color.fromARGB(255, 241, 202, 61).withValues(alpha: 0.4),
                                      ]
                                    : [
                                        AppColors.primary.withValues(alpha: 0.5),
                                        AppColors.primary.withValues(alpha: 0.7),
                                        // AppColors.primary.withValues(alpha: 0.3),
                                      ],
                              ),
                            ),
                          ),
                        ),
                        const Spacer(flex: 7),

                        Text(
                          isArabicUi ? '١١٤ سورة' : '114 Surahs',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFFF0D060) : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final surah = state.surahs[index];
                      _ensureJuzLabel(surah.number);
                      final juzLabel = _juzLabelBySurahNumber[surah.number];

                      // Prepare display name without diacritics
                      final nameDisplay = isArabicUi ? _removeDiacriticsHelper(surah.name) : surah.englishName;

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
                                ? _arabicizeDigits(juzLabel.replaceFirst('Juz', 'الجزء'))
                                : juzLabel);
                      final detailsParts = <String>[
                        revelation,
                        ayahs,
                        if (juz != null) juz,
                      ];
                      final detailsLine = detailsParts.join(' • ');

                      return Card(
                        key: index == 0
                            ? HomeTutorialKeys.firstSurahCard
                            : null,
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: isDark ? 0 : 1,
                        shadowColor: isDark
                            ? Colors.transparent
                            : AppColors.primary.withValues(alpha: 0.12),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppDesignSystem.borderRadiusLg,
                          side: BorderSide(
                            color: isDark
                                ? AppColors.darkBorder.withValues(alpha: 0.5)
                                : AppColors.cardBorder.withValues(alpha: 0.6),
                            width: 0.8,
                          ),
                        ),
                        child: InkWell(
                          onTap: () {
                            di.sl<SettingsService>().setLastReadPosition(
                              surahNumber: surah.number,
                              surahNameAr: surah.name,
                              surahNameEn: surah.englishName,
                            );
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SurahDetailScreen(
                                  surahNumber: surah.number,
                                  surahName: nameDisplay,
                                ),
                              ),
                            );
                          },
                          borderRadius: AppDesignSystem.borderRadiusLg,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
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
                                      color: AppColors.secondary.withValues(
                                        alpha: 0.4,
                                      ),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(
                                          alpha: isDark ? 0.3 : 0.2,
                                        ),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      isArabicUi ? _toArabicNumStr(surah.number) : '${surah.number}',
                                      style: isArabicUi
                                          ? _surahNumberStyle(context)
                                          : Theme.of(context)
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
                                        nameDisplay,
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
                                            ? _cachedAmiriQuran.copyWith(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w700,
                                                height: 1.6050,
                                                color: Theme.of(
                                                  context,
                                                ).textTheme.titleMedium?.color,
                                              )
                                            : Theme.of(
                                                context,
                                              ).textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 16,
                                              ),
                                      ),
                                      const SizedBox(height: 4),
                                      _buildDetailsLineWithAmiriNumbers(
                                        detailsLine,
                                        context,
                                        isRtl: isArabicUi,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Play button
                                Material(
                                  key: index == 0
                                      ? HomeTutorialKeys.firstPlayButton
                                      : null,
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius:
                                        BorderRadius.circular(100),
                                    onTap: () {
                                      context
                                          .read<AyahAudioCubit>()
                                          .togglePlaySurah(
                                            surahNumber: surah.number,
                                            numberOfAyahs: surah.numberOfAyahs,
                                          );
                                    },
                                    child: Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: 0.08),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Tooltip(
                                        message: isArabicUi
                                            ? 'تشغيل السورة كاملة'
                                            : 'Play full surah',
                                        child: Icon(
                                          Icons.play_arrow_rounded,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          size: 24,
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

// ─────────────────────────────────────────────────────────────────────────────
// Continue Reading Card
// ─────────────────────────────────────────────────────────────────────────────

class _ContinueReadingCard extends StatelessWidget {
  final bool isArabicUi;
  final List<dynamic> surahs;

  const _ContinueReadingCard({required this.isArabicUi, required this.surahs});

  @override
  Widget build(BuildContext context) {
    final settings = di.sl<SettingsService>();
    final surahNumber = settings.getLastReadSurahNumber();
    if (surahNumber == null) return const SizedBox.shrink();

    final nameAr = settings.getLastReadSurahNameAr() ?? '';
    final nameEn = settings.getLastReadSurahNameEn() ?? '';
    final name = isArabicUi ? nameAr : nameEn;
    if (name.isEmpty) return const SizedBox.shrink();

    final lastAyah = settings.getLastReadAyah();

    // Find ayah count for this surah for progress bar
    int? totalAyahs;
    try {
      final match = surahs.firstWhere(
        (s) => (s.number as int) == surahNumber,
        orElse: () => null,
      );
      if (match != null) totalAyahs = match.numberOfAyahs as int?;
    } catch (_) {}

    final surahProgress = surahNumber / 114.0;
    final ayahProgress =
        (lastAyah != null && totalAyahs != null && totalAyahs > 0)
        ? (lastAyah / totalAyahs).clamp(0.0, 1.0)
        : null;
    final progressValue = ayahProgress ?? surahProgress;

    // Sub-label: show ayah info if available, else surah count
    final String subLabel = lastAyah != null
        ? (isArabicUi ? 'آية ${_toArabicNumStr(lastAyah)}' : 'Verse $lastAyah')
        : (isArabicUi
              ? 'السورة ${_toArabicNumStr(surahNumber)} من ١١٤'
              : 'Surah $surahNumber of 114');

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SurahDetailScreen(
                  surahNumber: surahNumber,
                  surahName: name,
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        AppColors.primary.withValues(alpha: 0.18),
                        AppColors.primary.withValues(alpha: 0.08),
                      ]
                    : [
                        const Color(0xFFF0F7F3),
                        const Color(0xFFFAF8F5),
                      ],
              ),
              border: Border.all(
                color: isDark
                    ? const Color(0xFFD4AF37).withValues(alpha: 0.30)
                    : AppColors.primary.withValues(alpha: 0.15),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.2)
                      : AppColors.primary.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFFD4AF37).withValues(alpha: 0.15)
                            : AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFFD4AF37).withValues(alpha: 0.25)
                              : AppColors.primary.withValues(alpha: 0.18),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.menu_book_rounded,
                        color: isDark ? const Color(0xFFD4AF37) : AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: isArabicUi
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          Text(
                            isArabicUi ? 'متابعة القراءة' : 'Continue Reading',
                            style: TextStyle(
                              color: isDark
                                  ? const Color(0xFFD4AF37).withValues(alpha: 0.75)
                                  : AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                            textAlign: isArabicUi ? TextAlign.end : TextAlign.start,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isArabicUi ? _removeDiacriticsHelper(name) : name,
                            style: _cachedArefRuqaa.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: isDark ? const Color(0xFFF0D060) : AppColors.primary,
                              height: 1.35,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: isArabicUi ? TextAlign.end : TextAlign.start,
                            textDirection: isArabicUi
                                ? TextDirection.rtl
                                : TextDirection.ltr,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subLabel,
                            style: TextStyle(
                              color: isDark
                                  ? const Color(0xFFD4AF37).withValues(alpha: 0.60)
                                  : AppColors.primary.withValues(alpha: 0.60),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: isArabicUi ? TextAlign.end : TextAlign.start,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: isDark
                          ? const Color(0xFFD4AF37).withValues(alpha: 0.45)
                          : AppColors.primary.withValues(alpha: 0.35),
                      size: 22,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: progressValue,
                    minHeight: 5,
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : AppColors.primary.withValues(alpha: 0.10),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDark
                          ? const Color(0xFFD4AF37).withValues(alpha: 0.70)
                          : AppColors.primary.withValues(alpha: 0.70),
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
// Quick Access Bar (replaces the old 3×3 _CategoriesSection)
// ─────────────────────────────────────────────────────────────────────────────

class _QuickAccessBar extends StatelessWidget {
  final bool isArabicUi;
  final bool batteryUnrestricted;
  final VoidCallback onBatteryCheck;

  const _QuickAccessBar({
    required this.isArabicUi,
    this.batteryUnrestricted = true,
    required this.onBatteryCheck,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkSurface : AppColors.surface;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              const SizedBox(width: 4),
              _QuickAccessItem(
                label: isArabicUi ? 'الأذكار' : 'Adhkar',
                imagePath: 'assets/logo/button icons/praying.png',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdhkarCategoriesScreen()),
                ),
              ),
              _QuickAccessItem(
                label: isArabicUi ? 'الأذان' : 'Adhan',
                imagePath: 'assets/logo/button icons/nabawi-mosque.png',
                imagePadding: 3,
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdhanSettingsScreen()),
                  );
                  onBatteryCheck();
                },
              ),
              _QuickAccessItem(
                label: isArabicUi ? 'الإذاعة' : 'Radio',
                imagePath: 'assets/logo/button icons/radio.png',
                imagePadding: 3,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const QuranRadioScreen()),
                ),
              ),
              _QuickAccessItem(
                label: isArabicUi ? 'الأحاديث' : 'Hadiths',
                imagePath: 'assets/logo/button icons/hadith.png',
                imagePadding: 3,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HadithCategoriesScreen()),
                ),
              ),
              _QuickAccessItem(
                label: isArabicUi ? 'القبلة' : 'Qibla',
                imagePath: 'assets/logo/button icons/qibla.png',
                imagePadding: 0,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const QiblahScreen()),
                ),
              ),
              _QuickAccessItem(
                label: isArabicUi ? 'التقويم' : 'Hijri',
                icon: Icons.calendar_month_rounded,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HijriCalendarScreen()),
                ),
              ),
              _QuickAccessItem(
                label: isArabicUi ? 'الأجزاء' : 'Juz',
                imagePath: 'assets/logo/button icons/quran.png',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const JuzListScreen()),
                ),
              ),
              _QuickAccessItem(
                label: isArabicUi ? 'الصوت' : 'Audio',
                imagePath: 'assets/logo/button icons/microphone.png',
                imagePadding: 2,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const OfflineAudioScreen()),
                ),
              ),
              _QuickAccessItem(
                label: isArabicUi ? 'المزيد' : 'More',
                icon: Icons.grid_view_rounded,
                onTap: () => _showServicesSheet(
                  context,
                  isArabicUi: isArabicUi,
                  batteryUnrestricted: batteryUnrestricted,
                  onBatteryCheck: onBatteryCheck,
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
        // Left-side fade — extends fully to screen edge
        Positioned(
          left: -80,
          top: 0,
          bottom: 0,
          child: IgnorePointer(
            child: Container(
              width: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  stops: const [0.0, 0.40, 1.0],
                  colors: [
                    const Color.fromARGB(0, 1, 109, 46),
                    bgColor.withValues(alpha: 0.60),
                    bgColor.withValues(alpha: 0.90),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static void _showServicesSheet(
    BuildContext context, {
    required bool isArabicUi,
    required bool batteryUnrestricted,
    required VoidCallback onBatteryCheck,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.7,
        expand: false,
        builder: (sheetCtx, scrollController) => Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.secondary.withValues(alpha: 0.40)
                        : AppColors.secondary.withValues(alpha: 0.50),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              // Title
              Center(
                child: Text(
                  isArabicUi ? 'الأقسام' : 'Sections',
                  style: _cachedArefRuqaa.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.secondary : AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // Decorative gold line
              Center(
                child: Container(
                  width: 36,
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: AppColors.goldGradient,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              // 3×3 grid of all categories
              LayoutBuilder(
                builder: (ctx, constraints) {
                  const gap = 12.0;
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
                          label: isArabicUi ? 'مواقيت الصلاة' : 'Prayer Times',
                          imagePath: 'assets/logo/button icons/moon.png',
                          onTap: () {
                            Navigator.of(sheetCtx).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const PrayerTimesScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      wrap(
                        _CategoryTile(
                          label: isArabicUi ? 'الأذكار والأدعية' : 'Adhkar',
                          imagePath: 'assets/logo/button icons/praying.png',
                          onTap: () {
                            Navigator.of(sheetCtx).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AdhkarCategoriesScreen(),
                              ),
                            );
                          },
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
                            Navigator.of(sheetCtx).pop();
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
                          imagePath: 'assets/logo/button icons/microphone.png',
                          imagePadding: 2,
                          onTap: () {
                            Navigator.of(sheetCtx).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const OfflineAudioScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      wrap(
                        _CategoryTile(
                          label: isArabicUi ? 'الأجزاء' : 'Juz',
                          imagePath: 'assets/logo/button icons/quran.png',
                          onTap: () {
                            Navigator.of(sheetCtx).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const JuzListScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      wrap(
                        _CategoryTile(
                          label: isArabicUi ? 'القبلة' : 'Qibla',
                          imagePath: 'assets/logo/button icons/qibla.png',
                          imagePadding: 0,
                          onTap: () {
                            Navigator.of(sheetCtx).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const QiblahScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      wrap(
                        _CategoryTile(
                          label: isArabicUi ? 'السبحة' : 'Tasbeeh',
                          imagePath: 'assets/logo/button icons/beads.png',
                          imagePadding: 3,
                          onTap: () {
                            Navigator.of(sheetCtx).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const TasbeehScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      wrap(
                        _CategoryTile(
                          label: isArabicUi ? 'الإذاعة' : 'Radio',
                          imagePath: 'assets/logo/button icons/radio.png',
                          imagePadding: 3,
                          onTap: () {
                            Navigator.of(sheetCtx).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const QuranRadioScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      wrap(
                        _CategoryTile(
                          label: isArabicUi ? 'الأحاديث النبوية' : 'Hadiths',
                          imagePath: 'assets/logo/button icons/hadith.png',
                          imagePadding: 3,
                          onTap: () {
                            Navigator.of(sheetCtx).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const HadithCategoriesScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick Access Item (compact circular icon + label)
// ─────────────────────────────────────────────────────────────────────────────

class _QuickAccessItem extends StatefulWidget {
  final String label;
  final String? imagePath;
  final IconData? icon;
  final VoidCallback onTap;
  final double imagePadding;

  const _QuickAccessItem({
    required this.label,
    required this.onTap,
    this.imagePath,
    this.icon,
    this.imagePadding = 4,
  });

  @override
  State<_QuickAccessItem> createState() => _QuickAccessItemState();
}

class _QuickAccessItemState extends State<_QuickAccessItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: 72,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _pressed ? 0.87 : 1.0,
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 90),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.40),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(
                        alpha: _pressed ? 0.06 : (isDark ? 0.25 : 0.18),
                      ),
                      blurRadius: _pressed ? 3 : 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: widget.icon != null
                    ? Icon(widget.icon, color: AppColors.onPrimary, size: 22)
                    : Padding(
                        padding: EdgeInsets.all(widget.imagePadding),
                        child: Image.asset(
                          widget.imagePath!,
                          fit: BoxFit.contain,
                        ),
                      ),
              ),
              const SizedBox(height: 7),
              Text(
                widget.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark
                      ? const Color(0xFFE8E0D0)
                      : AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 10.5,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Category Tile (used inside the services bottom sheet)
// ─────────────────────────────────────────────────────────────────────────────

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
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 0.5,
        ),
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
