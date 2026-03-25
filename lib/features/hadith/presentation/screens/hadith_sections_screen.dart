import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/datasources/hadith_firestore_datasource.dart';
import '../../data/models/hadith_category_info.dart';
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
                    tooltip: 'تحديث',
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
                    'يُحمَّل بالتدريج • يُحفظ تلقائيًا للاستخدام بدون إنترنت',
                    style: TextStyle(
                        fontSize: 12,
                        color: catColor,
                        fontFamily: 'Amiri'),
                  ),
                ],
              ),
            ),
          ),

          // ── Books list ──
          BlocBuilder<HadithSectionsCubit, HadithSectionsState>(
            builder: (context, state) {
              if (state.status == HadithSectionsStatus.initial ||
                  (state.status == HadithSectionsStatus.loading &&
                      state.books.isEmpty)) {
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  sliver: HadithListSkeleton(isDark: isDark),
                );
              }

              if (state.status == HadithSectionsStatus.error &&
                  state.books.isEmpty) {
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
                    (context, index) => _BookTile(
                      book: state.books[index],
                      bookInfo: book,
                      isDark: isDark,
                      catColor: catColor,
                    ),
                    childCount: state.books.length,
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

class _BookTile extends StatelessWidget {
  final BukhariBook book;
  final HadithCategoryInfo bookInfo;
  final bool isDark;
  final Color catColor;

  const _BookTile({
    required this.book,
    required this.bookInfo,
    required this.isDark,
    required this.catColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isDark ? const Color(0xFF1A2E24) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => OnlineHadithListScreen(
                bookInfo: bookInfo,
                bukhariBook: book,
              ),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : catColor.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                // Book number badge
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${book.number}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: catColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Book name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.nameAr.isNotEmpty
                            ? book.nameAr
                            : 'كتاب ${book.number}',
                        style: TextStyle(
                          fontFamily: 'Amiri',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${book.hadithCount} حديث',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.white54
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_left_rounded,
                  color: isDark
                      ? Colors.white38
                      : catColor.withValues(alpha: 0.5),
                ),
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
          // Firestore badge
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
                  Icon(Icons.cloud_done_rounded, size: 13, color: Colors.white),
                  SizedBox(width: 5),
                  Text(
                    'Firestore',
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
