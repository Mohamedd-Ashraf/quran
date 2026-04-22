import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/settings/app_settings_cubit.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/utils/number_style_utils.dart';
import '../../../../core/services/tutorial_service.dart';
import '../tutorials/adhkar_tutorial.dart';
import '../../data/adhkar_data.dart';
import '../../data/models/adhkar_category.dart';
import '../cubit/adhkar_progress_cubit.dart';
import 'adhkar_list_screen.dart';

class AdhkarCategoriesScreen extends StatefulWidget {
  const AdhkarCategoriesScreen({super.key});

  @override
  State<AdhkarCategoriesScreen> createState() => _AdhkarCategoriesScreenState();
}

class _AdhkarCategoriesScreenState extends State<AdhkarCategoriesScreen> {
  bool _tutorialShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showTutorialIfNeeded());
  }

  void _showTutorialIfNeeded() {
    if (_tutorialShown) return;
    if (!mounted) return;
    _tutorialShown = true;
    final svc = di.sl<TutorialService>();
    if (svc.isTutorialComplete(TutorialService.adhkarScreen)) return;
    final isAr = context
        .read<AppSettingsCubit>()
        .state
        .appLanguageCode
        .toLowerCase()
        .startsWith('ar');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    AdhkarTutorial.show(
      context: context,
      tutorialService: svc,
      isArabic: isAr,
      isDark: isDark,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabicUi = context
        .watch<AppSettingsCubit>()
        .state
        .appLanguageCode
        .toLowerCase()
        .startsWith('ar');

    final categories = AdhkarData.categories;

    final featured = categories.where((c) => c.group == AdhkarGroup.featured).toList();
    final prayer   = categories.where((c) => c.group == AdhkarGroup.prayer).toList();
    final home     = categories.where((c) => c.group == AdhkarGroup.homeTavel).toList();
    final food     = categories.where((c) => c.group == AdhkarGroup.food).toList();
    final health   = categories.where((c) => c.group == AdhkarGroup.health).toList();
    final occasions= categories.where((c) => c.group == AdhkarGroup.occasions).toList();

    void openCategory(AdhkarCategory cat) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AdhkarListScreen(category: cat)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabicUi ? 'الأذكار والأدعية' : 'Adhkar & Duas'),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: AppColors.primaryGradient),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              key: AdhkarTutorialKeys.categoryGrid,
              child: _HeaderBanner(isArabicUi: isArabicUi),
            ),
          ),

          // ── الأذكار اليومية الأساسية ──────────────────────────────
          _SectionHeader(
            icon: Icons.today_rounded,
            titleAr: 'الأذكار اليومية الأساسية',
            titleEn: 'Daily Essentials',
            accentColor: const Color(0xFFD4AF37),
            isArabicUi: isArabicUi,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.62,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _CategoryCard(
                  key: index == 0 ? AdhkarTutorialKeys.morningCard : null,
                  category: featured[index],
                  isArabicUi: isArabicUi,
                  onTap: () => openCategory(featured[index]),
                ),
                childCount: featured.length,
              ),
            ),
          ),

          // ── الطهارة والصلاة ────────────────────────────────────────
          _SectionHeader(
            icon: Icons.mosque_rounded,
            titleAr: 'الطهارة والصلاة',
            titleEn: 'Purification & Prayer',
            accentColor: const Color(0xFF0288D1),
            isArabicUi: isArabicUi,
          ),
          _buildSmallGrid(prayer, isArabicUi, openCategory),

          // ── المنزل والسفر ──────────────────────────────────────────
          _SectionHeader(
            icon: Icons.home_rounded,
            titleAr: 'المنزل والسفر',
            titleEn: 'Home & Travel',
            accentColor: const Color(0xFF1565C0),
            isArabicUi: isArabicUi,
          ),
          _buildSmallGrid(home, isArabicUi, openCategory),

          // ── الطعام والشراب ─────────────────────────────────────────
          _SectionHeader(
            icon: Icons.restaurant_rounded,
            titleAr: 'الطعام والشراب',
            titleEn: 'Food & Drink',
            accentColor: const Color(0xFF8B4513),
            isArabicUi: isArabicUi,
          ),
          _buildSmallGrid(food, isArabicUi, openCategory),

          // ── الصحة والأحوال ─────────────────────────────────────────
          _SectionHeader(
            icon: Icons.favorite_rounded,
            titleAr: 'الصحة والأحوال',
            titleEn: 'Health & Wellbeing',
            accentColor: const Color(0xFFC62828),
            isArabicUi: isArabicUi,
          ),
          _buildSmallGrid(health, isArabicUi, openCategory),

          // ── المناسبات والمجتمع ─────────────────────────────────────
          _SectionHeader(
            icon: Icons.celebration_rounded,
            titleAr: 'المناسبات والمجتمع',
            titleEn: 'Occasions & Society',
            accentColor: const Color(0xFF4527A0),
            isArabicUi: isArabicUi,
          ),
          _buildSmallGrid(occasions, isArabicUi, openCategory),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  SliverPadding _buildSmallGrid(
    List<AdhkarCategory> cats,
    bool isArabicUi,
    void Function(AdhkarCategory) onTap,
  ) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.76,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _SmallCategoryCard(
            category: cats[index],
            isArabicUi: isArabicUi,
            onTap: () => onTap(cats[index]),
          ),
          childCount: cats.length,
        ),
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String titleAr;
  final String titleEn;
  final Color accentColor;
  final bool isArabicUi;

  const _SectionHeader({
    required this.icon,
    required this.titleAr,
    required this.titleEn,
    required this.accentColor,
    required this.isArabicUi,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: isDark
                ? [
                    accentColor.withValues(alpha: 0.18),
                    accentColor.withValues(alpha: 0.06),
                  ]
                : [
                    accentColor.withValues(alpha: 0.12),
                    accentColor.withValues(alpha: 0.03),
                  ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: accentColor.withValues(alpha: isDark ? 0.35 : 0.25),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: isDark ? 0.3 : 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: accentColor, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              isArabicUi ? titleAr : titleEn,
              style: GoogleFonts.amiri(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Header Banner ────────────────────────────────────────────────────────────
class _HeaderBanner extends StatelessWidget {
  final bool isArabicUi;
  const _HeaderBanner({required this.isArabicUi});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1B3A2D), const Color(0xFF0F2018)]
              : [const Color(0xFFE8F5EC), const Color(0xFFF0F9F4)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.volunteer_activism_rounded,
              color: AppColors.onPrimary,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabicUi ? 'حصن المسلم' : 'Fortress of the Muslim',
                  style: GoogleFonts.amiri(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isArabicUi
                      ? 'أذكار وأدعية مأثورة من السنة النبوية'
                      : 'Authentic adhkar & duas from the Sunnah',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
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

// ─── Large Category Card (featured) ──────────────────────────────────────────
class _CategoryCard extends StatelessWidget {
  final AdhkarCategory category;
  final bool isArabicUi;
  final VoidCallback onTap;

  const _CategoryCard({
    super.key,
    required this.category,
    required this.isArabicUi,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = category.color;
    final progressState = context.watch<AdhkarProgressCubit>().state;
    final completedCount = category.items
        .where((item) =>
            progressState.countFor(category.id, item.id) >= item.repeatCount)
        .length;
    final isFullyDone = completedCount == category.count;
    final progress =
        category.count > 0 ? completedCount / category.count : 0.0;
    final progressColor = isFullyDone ? AppColors.success : color;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isFullyDone
              ? AppColors.success.withValues(alpha: 0.5)
              : color.withValues(alpha: isDark ? 0.4 : 0.25),
          width: isFullyDone ? 2 : 1.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: progressColor.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(category.icon, color: progressColor, size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                isArabicUi ? category.titleAr : category.titleEn,
                style: GoogleFonts.amiri(
                  fontSize: isArabicUi ? 16 : 14,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.9)
                      : AppColors.textPrimary,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                isArabicUi ? category.subtitleAr : category.subtitleEn,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.25,
                      fontSize: 10.5,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: progressColor
                              .withValues(alpha: isDark ? 0.25 : 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                              isArabicUi
                                ? '${localizeNumber(category.count, isArabic: true)} أذكار'
                                : '${category.count} items',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: progressColor,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (completedCount > 0)
                        Text(
                          isArabicUi
                              ? '${localizeNumber(completedCount, isArabic: true)}/${localizeNumber(category.count, isArabic: true)}'
                              : '$completedCount/${category.count}',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: progressColor,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor:
                          color.withValues(alpha: isDark ? 0.15 : 0.1),
                      valueColor:
                          AlwaysStoppedAnimation<Color>(progressColor),
                      minHeight: 5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Small Category Card (groups) ────────────────────────────────────────────
class _SmallCategoryCard extends StatelessWidget {
  final AdhkarCategory category;
  final bool isArabicUi;
  final VoidCallback onTap;

  const _SmallCategoryCard({
    required this.category,
    required this.isArabicUi,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = category.color;
    final progressState = context.watch<AdhkarProgressCubit>().state;
    final completedCount = category.items
        .where((item) =>
            progressState.countFor(category.id, item.id) >= item.repeatCount)
        .length;
    final isFullyDone = completedCount == category.count && category.count > 0;
    final progress = category.count > 0 ? completedCount / category.count : 0.0;
    final progressColor = isFullyDone ? AppColors.success : color;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isFullyDone
              ? AppColors.success.withValues(alpha: 0.5)
              : color.withValues(alpha: isDark ? 0.35 : 0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 4),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: progressColor.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(category.icon, color: progressColor, size: 19),
              ),
              const SizedBox(height: 8),
              Text(
                isArabicUi ? category.titleAr : category.titleEn,
                textAlign: TextAlign.center,
                style: GoogleFonts.amiri(
                  fontSize: isArabicUi ? 13 : 11.5,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.88)
                      : AppColors.textPrimary,
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              // count badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: progressColor.withValues(alpha: isDark ? 0.22 : 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  isArabicUi
                      ? '${localizeNumber(category.count, isArabic: true)} ذكر'
                      : '${category.count}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: progressColor,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor:
                      color.withValues(alpha: isDark ? 0.15 : 0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  minHeight: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
