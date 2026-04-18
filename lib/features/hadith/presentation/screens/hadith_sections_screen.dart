import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/settings/app_settings_cubit.dart';
import '../../data/models/hadith_category_info.dart';
import '../../data/models/remote_hadith.dart';
import '../../data/repositories/hadith_repository.dart';
import '../cubit/hadith_sections_cubit.dart';
import '../cubit/hadith_sections_state.dart';
import '../widgets/hadith_skeleton.dart';
import 'hadith_list_screen.dart';

class HadithSectionsScreen extends StatelessWidget {
  final HadithCategoryInfo book;

  const HadithSectionsScreen({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HadithSectionsCubit(
        repository: context.read<HadithRepository>(),
      )..load(),
      child: _SectionsView(book: book),
    );
  }
}

class _SectionsView extends StatelessWidget {
  final HadithCategoryInfo book;
  const _SectionsView({required this.book});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = context
        .watch<AppSettingsCubit>()
        .state
        .appLanguageCode
        .toLowerCase()
        .startsWith('ar');
    final catColor = book.color;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── AppBar ──
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            stretch: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              BlocBuilder<HadithSectionsCubit, HadithSectionsState>(
                builder: (context, state) {
                  if (state.status != HadithSectionsStatus.loaded) {
                    return const SizedBox.shrink();
                  }
                  return IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                    tooltip: isArabic ? 'تحديث' : 'Refresh',
                    onPressed: () =>
                        context.read<HadithSectionsCubit>().refresh(),
                  );
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Text(
                book.titleAr,
                style: const TextStyle(
                  fontFamily: 'Amiri',
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
              background: _SectionsHeaderBackground(
                book: book,
                catColor: catColor,
              ),
            ),
          ),

          // ── Firestore indicator ──
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: catColor.withValues(alpha: isDark ? 0.18 : 0.09),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: catColor.withValues(alpha: 0.3), width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_done_outlined,
                      size: 14, color: catColor),
                  const SizedBox(width: 6),
                  Text(
                    isArabic
                        ? 'يُحمَّل من الإنترنت • يُحفظ تلقائيًا للاستخدام بدون إنترنت'
                        : 'Loaded from Internet • Auto-saved for offline use',
                    style: TextStyle(
                        fontSize: 12,
                        color: catColor,
                        fontFamily: 'Amiri'),
                  ),
                ],
              ),
            ),
          ),

          // ── Sections list ──
          BlocBuilder<HadithSectionsCubit, HadithSectionsState>(
            builder: (context, state) {
              if (state.status == HadithSectionsStatus.initial ||
                  (state.status == HadithSectionsStatus.loading &&
                      state.sections.isEmpty)) {
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  sliver: HadithListSkeleton(isDark: isDark),
                );
              }

              if (state.status == HadithSectionsStatus.error &&
                  state.sections.isEmpty) {
                return SliverFillRemaining(
                  child: HadithErrorWidget(
                    message: state.errorMessage ?? '',
                    isArabic: true,
                    onRetry: () =>
                        context.read<HadithSectionsCubit>().retry(),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _SectionTile(
                      section: state.sections[index],
                      bookInfo: book,
                      isDark: isDark,
                      isArabic: isArabic,
                      catColor: catColor,
                      index: index,
                    ),
                    childCount: state.sections.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────

class _SectionTile extends StatelessWidget {
  final RemoteSection section;
  final HadithCategoryInfo bookInfo;
  final bool isDark;
  final bool isArabic;
  final Color catColor;
  final int index;

  const _SectionTile({
    required this.section,
    required this.bookInfo,
    required this.isDark,
    required this.isArabic,
    required this.catColor,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = isArabic
        ? section.nameAr
        : (section.name.isNotEmpty ? section.name : 'Section ${section.sectionNumber}');
    final hasCount = section.count > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => OnlineHadithListScreen(
                bookInfo: bookInfo,
                remoteSection: section,
              ),
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: isDark
                  ? const Color(0xFF1A2634)
                  : Colors.white,
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : catColor.withValues(alpha: 0.18),
              ),
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: catColor.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
            ),
            child: Row(
              children: [
                // Colored accent left bar
                Container(
                  width: 4,
                  height: 62,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                    ),
                    color: (index % 4 == 0)
                        ? catColor
                        : (index % 4 == 1)
                            ? catColor.withValues(alpha: 0.6)
                            : (index % 4 == 2)
                                ? catColor.withValues(alpha: 0.4)
                                : catColor.withValues(alpha: 0.2),
                  ),
                ),
                const SizedBox(width: 12),
                // Section number badge
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${section.sectionNumber}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: catColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Section name + count
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: TextStyle(
                          fontFamily: isArabic ? 'Amiri' : null,
                          fontSize: isArabic ? 15 : 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                        textDirection:
                            isArabic ? TextDirection.rtl : TextDirection.ltr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        hasCount ? '${section.count} ${isArabic ? 'حديث' : 'hadith'}' : (isArabic ? 'صحيح البخاري' : 'Sahih Bukhari'),
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Amiri',
                          color: isDark
                              ? Colors.white54
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isArabic
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                  color: isDark
                      ? Colors.white38
                      : catColor.withValues(alpha: 0.45),
                  size: 20,
                ),
                const SizedBox(width: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────

class _SectionsHeaderBackground extends StatelessWidget {
  final HadithCategoryInfo book;
  final Color catColor;

  const _SectionsHeaderBackground({
    required this.book,
    required this.catColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            catColor,
            catColor.withValues(alpha: 0.7),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Stack(
        children: [
          // Decorative icon
          Positioned(
            right: -20,
            top: -20,
            child: Icon(
              Icons.auto_stories_rounded,
              size: 180,
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          Positioned(
            left: 20,
            bottom: 50,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.public_rounded, size: 13, color: Colors.white),
                  SizedBox(width: 5),
                  Text(
                    'CDN API',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontFamily: 'Amiri',
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
