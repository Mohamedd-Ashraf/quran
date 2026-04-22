import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/settings/app_settings_cubit.dart';
import '../../../../core/theme/app_design_system.dart';
import '../../../../core/utils/number_style_utils.dart';
import '../../data/models/hadith_category_info.dart';
import '../../data/models/hadith_item.dart';
import '../../data/models/hadith_list_item.dart';
import '../../data/models/remote_hadith.dart';
import '../../data/repositories/hadith_repository.dart';
import '../cubit/hadith_cubit.dart';
import '../cubit/hadith_list_cubit.dart';
import '../cubit/hadith_list_state.dart';
import '../cubit/hadith_state.dart';
import '../widgets/hadith_skeleton.dart';
import 'hadith_detail_screen.dart';

// ─── Offline category list ────────────────────────────────────────────────────

class HadithListScreen extends StatelessWidget {
  final HadithCategoryInfo category;

  const HadithListScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => HadithListCubit(
        repository: context.read<HadithRepository>(),
        categoryId: category.id,
      )..loadInitial(),
      child: _HadithListView(category: category),
    );
  }
}

// ─── Online (Firestore/Bukhari) section list ──────────────────────────────────

/// Wrapper for browsing a specific Bukhari section from the CDN API.
class OnlineHadithListScreen extends StatelessWidget {
  final HadithCategoryInfo bookInfo;
  final RemoteSection remoteSection;

  const OnlineHadithListScreen({
    super.key,
    required this.bookInfo,
    required this.remoteSection,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => HadithListCubit(
        repository: context.read<HadithRepository>(),
        categoryId: bookInfo.id,
        remoteSection: remoteSection,
      )..loadInitial(),
      child: _HadithListView(
        category: bookInfo,
        sectionTitle: remoteSection.nameAr,
      ),
    );
  }
}

class _HadithListView extends StatefulWidget {
  final HadithCategoryInfo category;
  final String? sectionTitle;
  const _HadithListView({required this.category, this.sectionTitle});

  @override
  State<_HadithListView> createState() => _HadithListViewState();
}

class _HadithListViewState extends State<_HadithListView> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isNearBottom) {
      context.read<HadithListCubit>().loadMore();
    }
  }

  bool get _isNearBottom {
    if (!_scrollController.hasClients) return false;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    return currentScroll >= (maxScroll - 200);
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = context
        .watch<AppSettingsCubit>()
        .state
        .appLanguageCode
        .toLowerCase()
        .startsWith('ar');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final catColor = widget.category.color;

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        body: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverAppBar(
              expandedHeight: 190,
              pinned: true,
              stretch: true,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
              flexibleSpace: FlexibleSpaceBar(
                centerTitle: true,
                titlePadding: const EdgeInsets.only(bottom: 16),
                title: Text(
                  widget.sectionTitle?.isNotEmpty == true
                      ? widget.sectionTitle!
                      : (isArabic
                          ? widget.category.titleAr
                          : widget.category.titleEn),
                  style: Theme.of(context).appBarTheme.titleTextStyle?.copyWith(fontSize: 16),
                ),
                background: _ListHeaderBackground(
                  category: widget.category,
                  isArabic: isArabic,
                  catColor: catColor,
                ),
              ),
            ),
            BlocBuilder<HadithListCubit, HadithListState>(
              builder: (context, state) {
                // Initial loading — show skeleton
                if (state.status == HadithListStatus.initial ||
                    (state.status == HadithListStatus.loading &&
                        state.items.isEmpty)) {
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    sliver: HadithListSkeleton(isDark: isDark),
                  );
                }

                // Error on first load
                if (state.status == HadithListStatus.error &&
                    state.items.isEmpty) {
                  return SliverFillRemaining(
                    child: HadithErrorWidget(
                      message: state.errorMessage ?? '',
                      isArabic: isArabic,
                      onRetry: () => context.read<HadithListCubit>().retry(),
                    ),
                  );
                }

                // Loaded items + optional loading-more indicator
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index >= state.items.length) {
                          return const HadithLoadingMore();
                        }
                        final hadith = state.items[index];
                        return _HadithCard(
                          hadith: hadith,
                          index: index,
                          isArabic: isArabic,
                          isDark: isDark,
                          categoryId: widget.category.id,
                          categoryTitle: isArabic
                              ? widget.category.titleAr
                              : widget.category.titleEn,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => HadithDetailScreen(
                                  hadithId: hadith.id,
                                  categoryId: widget.category.id,
                                  categoryTitle: isArabic
                                      ? widget.category.titleAr
                                      : widget.category.titleEn,
                                  sortOrder: hadith.sortOrder,
                                ),
                              ),
                            );
                          },
                        );
                      },
                      childCount:
                          state.items.length + (state.isLoadingMore ? 1 : 0),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Category Header Background
// ─────────────────────────────────────────────────────────────────────────────

class _ListHeaderBackground extends StatelessWidget {
  final HadithCategoryInfo category;
  final bool isArabic;
  final Color catColor;

  const _ListHeaderBackground({
    required this.category,
    required this.isArabic,
    required this.catColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Gradient using category color
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                catColor,
                Color.alphaBlend(
                  Colors.black.withValues(alpha: 0.28),
                  catColor,
                ),
              ],
            ),
          ),
        ),
        // Decorative circles
        Positioned(
          top: -30,
          right: isArabic ? null : -20,
          left: isArabic ? -20 : null,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.07),
            ),
          ),
        ),
        Positioned(
          bottom: 20,
          right: isArabic ? -30 : null,
          left: isArabic ? null : -30,
          child: Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
        ),
        // Icon + subtitle + count badge
        Positioned.fill(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 42),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(category.icon, color: Colors.white, size: 26),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: Text(
                      isArabic ? category.subtitleAr : category.subtitleEn,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      isArabic
                          ? '${localizeNumber(category.count, isArabic: true)} حديث'
                          : '${category.count} Hadiths',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hadith Card
// ─────────────────────────────────────────────────────────────────────────────

class _HadithCard extends StatelessWidget {
  final HadithListItem hadith;
  final int index;
  final bool isArabic;
  final bool isDark;
  final String categoryId;
  final String categoryTitle;
  final VoidCallback onTap;

  const _HadithCard({
    required this.hadith,
    required this.index,
    required this.isArabic,
    required this.isDark,
    required this.categoryId,
    required this.categoryTitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HadithCubit, HadithState>(
      builder: (context, state) {
        final isBookmarked = state.isBookmarked(hadith.id);

        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top bar with number and grade badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Number circle
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Topic
                      Expanded(
                        child: Text(
                          isArabic ? hadith.topicAr : hadith.topicEn,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                        ),
                      ),
                      // Grade badge
                      _GradeBadge(grade: hadith.grade, isArabic: isArabic),
                      const SizedBox(width: 8),
                      // Bookmark button
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          context.read<HadithCubit>().toggleBookmark(hadith.id);
                        },
                        child: Icon(
                          isBookmarked
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          color: isBookmarked
                              ? AppColors.secondary
                              : (isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.textSecondary),
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),
                // Arabic text preview
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Text(
                    hadith.arabicPreview.length >= 150
                        ? '${hadith.arabicPreview}...'
                        : hadith.arabicPreview,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: 'Amiri',
                      fontSize: 16,
                      height: 1.8,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                // Reference & narrator
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_outline_rounded,
                        size: 14,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          hadith.narrator,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        Icons.library_books_outlined,
                        size: 14,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        hadith.reference,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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
// Grade Badge
// ─────────────────────────────────────────────────────────────────────────────

class _GradeBadge extends StatelessWidget {
  final HadithGrade grade;
  final bool isArabic;

  const _GradeBadge({required this.grade, required this.isArabic});

  Color get _badgeColor {
    switch (grade) {
      case HadithGrade.sahih:
        return AppColors.success;
      case HadithGrade.hasan:
        return AppColors.info;
      case HadithGrade.muttafaqAlayh:
        return const Color(0xFF6A1B9A);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _badgeColor.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Text(
        isArabic ? grade.labelAr : grade.labelEn,
        style: TextStyle(
          color: _badgeColor,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
