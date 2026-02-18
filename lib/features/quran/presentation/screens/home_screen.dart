import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../bloc/surah/surah_bloc.dart';
import '../bloc/surah/surah_event.dart';
import '../bloc/surah/surah_state.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/settings/app_settings_cubit.dart';
import '../../../../core/audio/ayah_audio_cubit.dart';
import '../../../islamic/presentation/screens/duaa_screen.dart';
import '../../../islamic/presentation/screens/prayer_times_screen.dart';
import '../../../islamic/presentation/screens/qiblah_screen.dart';
import 'surah_detail_screen.dart';
import 'offline_audio_screen.dart';
import 'settings_screen.dart';
import 'juz_list_screen.dart';
import '../widgets/islamic_audio_player.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  final Map<int, String> _juzLabelBySurahNumber = {};
  final Set<int> _loadingJuzForSurah = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadSurahs();
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
        title: Text(isArabicUi ? 'القرآن الكريم' : 'Quran'),
        centerTitle: true,
        actions: [
          // Dark mode toggle
          IconButton(
            icon: Icon(
              context.watch<AppSettingsCubit>().state.darkMode
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
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
        ],
      ),
      body: BlocBuilder<SurahBloc, SurahState>(
        builder: (context, state) {
          if (state is SurahLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is SurahListLoaded) {
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: _CategoriesSection(isArabicUi: isArabicUi),
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

                      final useUthmaniScript = context
                          .watch<AppSettingsCubit>()
                          .state
                          .useUthmaniScript;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
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
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${surah.number}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
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
                                            ? GoogleFonts.amiriQuran(
                                                fontSize: 22,
                                                fontWeight: FontWeight.w700,
                                                height: 1.6,
                                                color: Theme.of(
                                                  context,
                                                ).textTheme.titleMedium?.color,
                                              )
                                            : Theme.of(
                                                context,
                                              ).textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                      ),
                                      const SizedBox(height: 6),
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
                                if (useUthmaniScript) ...[
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: Icon(
                                      Icons.play_circle_outline,
                                      color: AppColors.primary,
                                    ),
                                    tooltip: isArabicUi
                                        ? 'تشغيل السورة كاملة'
                                        : 'Play full surah',
                                    onPressed: () {
                                      context
                                          .read<AyahAudioCubit>()
                                          .togglePlaySurah(
                                            surahNumber: surah.number,
                                            numberOfAyahs: surah.numberOfAyahs,
                                          );
                                    },
                                  ),
                                ],
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
      bottomNavigationBar: IslamicAudioPlayer(isArabicUi: isArabicUi),
    );
  }
}

class _CategoriesSection extends StatelessWidget {
  final bool isArabicUi;

  const _CategoriesSection({required this.isArabicUi});

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800);

    return Column(
      crossAxisAlignment: isArabicUi
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(isArabicUi ? 'الأقسام' : 'Categories', style: titleStyle),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _CategoryTile(
              label: isArabicUi ? 'مواقيت الصلاة' : 'Prayer Times',
              icon: Icons.schedule,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PrayerTimesScreen()),
                );
              },
            ),
            _CategoryTile(
              label: isArabicUi ? 'القبلة' : 'Qiblah',
              icon: Icons.explore,
              onTap: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const QiblahScreen()));
              },
            ),
            _CategoryTile(
              label: isArabicUi ? 'الأدعية' : 'Duaa',
              icon: Icons.menu_book,
              onTap: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const DuaaScreen()));
              },
            ),
            _CategoryTile(
              label: isArabicUi ? 'الصوت' : 'Audio',
              icon: Icons.headphones,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const OfflineAudioScreen()),
                );
              },
            ),
            _CategoryTile(
              label: isArabicUi ? 'الإعدادات' : 'Settings',
              icon: Icons.settings,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
            _CategoryTile(
              label: isArabicUi ? 'الأجزاء' : 'Juz',
              icon: Icons.menu_book_outlined,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const JuzListScreen()),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          isArabicUi
              ? 'يمكنك الوصول للسور من خلال الأجزاء أو من القائمة أدناه.'
              : 'Access Surahs through Juz or the list below.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          textAlign: isArabicUi ? TextAlign.right : TextAlign.left,
        ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Theme.of(context).cardColor,
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
