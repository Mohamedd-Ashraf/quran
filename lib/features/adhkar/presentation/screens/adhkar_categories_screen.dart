import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/settings/app_settings_cubit.dart';
import '../../data/adhkar_data.dart';
import '../../data/models/adhkar_category.dart';
import '../cubit/adhkar_progress_cubit.dart';
import 'adhkar_list_screen.dart';

class AdhkarCategoriesScreen extends StatelessWidget {
  const AdhkarCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isArabicUi = context
        .watch<AppSettingsCubit>()
        .state
        .appLanguageCode
        .toLowerCase()
        .startsWith('ar');

    final categories = AdhkarData.categories;

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
            child: _HeaderBanner(isArabicUi: isArabicUi),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.62,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _CategoryCard(
                  category: categories[index],
                  isArabicUi: isArabicUi,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AdhkarListScreen(
                          category: categories[index],
                        ),
                      ),
                    );
                  },
                ),
                childCount: categories.length,
              ),
            ),
          ),
        ],
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

// ─── Category Card ────────────────────────────────────────────────────────────
class _CategoryCard extends StatelessWidget {
  final AdhkarCategory category;
  final bool isArabicUi;
  final VoidCallback onTap;

  const _CategoryCard({
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
              // Icon container
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
              // Title
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
              // Count chip + progress
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
                              ? '${category.count} أذكار'
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
                          '$completedCount/${category.count}',
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