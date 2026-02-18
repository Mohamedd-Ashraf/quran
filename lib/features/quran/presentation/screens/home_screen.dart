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
import '../../../../core/settings/app_settings_cubit.dart';
import '../../../../core/audio/ayah_audio_cubit.dart';
import '../../../islamic/presentation/screens/duaa_screen.dart';
import '../../../islamic/presentation/screens/prayer_times_screen.dart';
import '../../../islamic/presentation/screens/qiblah_screen.dart';
import '../../../islamic/presentation/widgets/next_prayer_countdown.dart';
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
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.gradientStart,
                AppColors.gradientMid,
                AppColors.gradientEnd,
              ],
            ),
          ),
        ),
        actions: [
          // Dark mode toggle
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.secondary.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: IconButton(
              icon: Icon(
                context.watch<AppSettingsCubit>().state.darkMode
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                color: AppColors.onPrimary,
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
                const SliverToBoxAdapter(
                  child: NextPrayerCountdown(),
                ),
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

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 4,
                        shadowColor: AppColors.secondary.withValues(alpha: 0.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: AppColors.secondary.withValues(alpha: 0.15),
                            width: 1,
                          ),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Theme.of(context).cardColor,
                                Theme.of(context).cardColor.withValues(alpha: 0.95),
                              ],
                            ),
                          ),
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
                            borderRadius: BorderRadius.circular(16),
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
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          AppColors.gradientStart,
                                          AppColors.gradientEnd,
                                        ],
                                      ),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.secondary,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.secondary.withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
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
                                              fontSize: 18,
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
                                const SizedBox(width: 8),
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.primary.withValues(alpha: 0.3),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () {
                                        context
                                            .read<AyahAudioCubit>()
                                            .togglePlaySurah(
                                              surahNumber: surah.number,
                                              numberOfAyahs: surah.numberOfAyahs,
                                            );
                                      },
                                      child: Tooltip(
                                        message: isArabicUi
                                            ? 'تشغيل السورة كاملة'
                                            : 'Play full surah',
                                        child: Icon(
                                          Icons.play_arrow_rounded,
                                          color: AppColors.primary,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleStyle = Theme.of(
      context,
    ).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: isDark ? AppColors.secondary : AppColors.primary,
          letterSpacing: 0.5,
        );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: isDark ? 0.3 : 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: isDark ? 0.15 : 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Islamic pattern background
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        AppColors.darkCard,
                        AppColors.darkSurface,
                      ]
                    : [
                        AppColors.surfaceVariant,
                        AppColors.surface,
                      ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: isArabicUi
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
          Row(
            mainAxisAlignment: isArabicUi
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              if (!isArabicUi) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: isDark ? 0.25 : 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.category_rounded,
                    color: isDark ? AppColors.secondary : AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Text(
                isArabicUi ? 'الأقسام' : 'Categories',
                style: titleStyle,
              ),
              if (isArabicUi) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: isDark ? 0.25 : 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.category_rounded,
                    color: isDark ? AppColors.secondary : AppColors.primary,
                    size: 24,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _CategoryTile(
                label: isArabicUi ? 'مواقيت الصلاة' : 'Prayer Times',
                icon: Icons.schedule_rounded,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PrayerTimesScreen()),
                  );
                },
              ),
              _CategoryTile(
                label: isArabicUi ? 'القبلة' : 'Qiblah',
                icon: Icons.explore_rounded,
                onTap: () {
                  Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const QiblahScreen()));
                },
              ),
              _CategoryTile(
                label: isArabicUi ? 'الأدعية' : 'Duaa',
                icon: Icons.menu_book_rounded,
                onTap: () {
                  Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const DuaaScreen()));
                },
              ),
              _CategoryTile(
                label: isArabicUi ? 'الصوت' : 'Audio',
                icon: Icons.headphones_rounded,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const OfflineAudioScreen()),
                  );
                },
              ),
              _CategoryTile(
                label: isArabicUi ? 'الإعدادات' : 'Settings',
                icon: Icons.settings_rounded,
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
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.1),
                width: 1,
              ),
            ),
            child: Text(
              isArabicUi
                  ? 'يمكنك الوصول للسور من خلال الأجزاء أو من القائمة أدناه.'
                  : 'Access Surahs through Juz or the list below.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(
                    color: isDark ? const Color(0xFFB0B0B0) : AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
              textAlign: isArabicUi ? TextAlign.right : TextAlign.left,
            ),
          ),
        ],
            ),
          ),
        ],
      ),
    );
  }
}

// Islamic geometric pattern painter
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
  final IconData icon;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).cardColor,
                Theme.of(context).cardColor.withValues(alpha: 0.9),
              ],
            ),
            border: Border.all(
              color: AppColors.secondary.withValues(alpha: 0.25),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.secondary.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
                children: [
                Flexible(
                  child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.gradientStart,
                      AppColors.gradientMid,
                    ],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                    color: AppColors.secondary,
                    width: 1.5,
                    ),
                    boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: AppColors.onPrimary,
                    size: 22,
                  ),
                  ),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
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
