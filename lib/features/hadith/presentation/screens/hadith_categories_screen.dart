import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/settings/app_settings_cubit.dart';
import '../../data/models/hadith_category_info.dart';
import '../../data/repositories/hadith_repository.dart';
import 'hadith_list_screen.dart';
import 'hadith_search_screen.dart';
import 'hadith_sections_screen.dart';

class HadithCategoriesScreen extends StatefulWidget {
  const HadithCategoriesScreen({super.key});

  @override
  State<HadithCategoriesScreen> createState() => _HadithCategoriesScreenState();
}

class _HadithCategoriesScreenState extends State<HadithCategoriesScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  List<HadithCategoryInfo> _categories = [];
  int _totalHadiths = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final repo = context.read<HadithRepository>();
    final categories = await repo.getCategories();
    final total = await repo.getTotalCount();
    if (mounted) {
      setState(() {
        _categories = categories;
        _totalHadiths = total;
        _loaded = true;
      });
      _animCtrl.forward();
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
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
    final categories = _categories;
    final totalHadiths = _totalHadiths;

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        body: _loaded
            ? CustomScrollView(
                slivers: [
                  // ── Gradient AppBar ──
                  SliverAppBar(
                    expandedHeight: 220,
                    pinned: true,
                    stretch: true,
                    leading: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(
                          Icons.search_rounded,
                          color: Colors.white,
                        ),
                        tooltip: isArabic
                            ? 'بحث في الأحاديث'
                            : 'Search hadiths',
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const HadithSearchScreen(),
                          ),
                        ),
                      ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      centerTitle: true,
                      title: Text(
                        isArabic ? 'الأحاديث النبوية' : 'Prophetic Hadiths',
                        style: const TextStyle(
                          fontFamily: 'Amiri',
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                      background: _HeaderBackground(
                        isArabic: isArabic,
                        totalHadiths: totalHadiths,
                        totalCategories: categories.length,
                      ),
                    ),
                  ),

                  // ── Section Label: Curated ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
                      child: Row(
                        children: [
                          _GlowDot(color: AppColors.primary),
                          const SizedBox(width: 10),
                          Text(
                            isArabic ? 'مختارات الأحاديث' : 'Curated Hadiths',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              height: 1.5,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primary.withValues(alpha: 0.35),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Offline Category Cards ──
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final cat = categories[index];
                        return AnimatedBuilder(
                          animation: _animCtrl,
                          builder: (context, child) {
                            final delay = index * 0.10;
                            final t = Curves.easeOutCubic.transform(
                              (_animCtrl.value - delay).clamp(0.0, 1.0),
                            );
                            return Transform.translate(
                              offset: Offset(0, 30 * (1 - t)),
                              child: Opacity(opacity: t, child: child),
                            );
                          },
                          child: _CategoryCard(
                            category: cat,
                            index: index,
                            isArabic: isArabic,
                            isDark: isDark,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => HadithListScreen(category: cat),
                              ),
                            ),
                          ),
                        );
                      }, childCount: categories.length),
                    ),
                  ),

                  // ── Section Label: Major books ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
                      child: Row(
                        children: [
                          _GlowDot(color: AppColors.info),
                          const SizedBox(width: 10),
                          Text(
                            isArabic ? 'كتب الحديث الكبرى' : 'Major Hadith Books',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : AppColors.info,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.info.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: AppColors.info.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.wifi_rounded,
                                    size: 11, color: AppColors.info),
                                SizedBox(width: 3),
                                Text(
                                  'أونلاين',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.info,
                                    fontFamily: 'Amiri',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              height: 1.5,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.info.withValues(alpha: 0.35),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Online Book Cards ──
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final book = HadithCategoryInfo.allOnline[index];
                        return AnimatedBuilder(
                          animation: _animCtrl,
                          builder: (context, child) {
                            final delay =
                                (categories.length + index) * 0.10;
                            final t = Curves.easeOutCubic.transform(
                              (_animCtrl.value - delay).clamp(0.0, 1.0),
                            );
                            return Transform.translate(
                              offset: Offset(0, 30 * (1 - t)),
                              child: Opacity(opacity: t, child: child),
                            );
                          },
                          child: _CategoryCard(
                            category: book,
                            index: categories.length + index,
                            isArabic: isArabic,
                            isDark: isDark,
                            showOnlineBadge: true,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    HadithSectionsScreen(book: book),
                              ),
                            ),
                          ),
                        );
                      },
                          childCount: HadithCategoryInfo.allOnline.length),
                    ),
                  ),
                ],
              )
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
//  Header Background with decorative elements
// ╚═══════════════════════════════════════════════════════════════════════════╝

class _HeaderBackground extends StatelessWidget {
  final bool isArabic;
  final int totalHadiths;
  final int totalCategories;

  const _HeaderBackground({
    required this.isArabic,
    required this.totalHadiths,
    required this.totalCategories,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Gradient base
        Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        // Geometric pattern
        Positioned.fill(
          child: CustomPaint(
            painter: _GeometricPatternPainter(
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
        ),
        // Decorative glow circles
        Positioned(
          top: -30,
          right: -20,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.secondary.withValues(alpha: 0.12),
            ),
          ),
        ),
        Positioned(
          bottom: 60,
          left: -40,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
        ),
        // Central icon + subtitles
        Positioned.fill(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Book icon with decorative ring
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.secondary.withValues(alpha: 0.5),
                        width: 2,
                      ),
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      color: AppColors.secondary,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isArabic
                        ? 'أحاديث صحيحة مُحققة'
                        : 'Verified Authentic Hadiths',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Stats row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _StatChip(
                        icon: Icons.library_books_rounded,
                        label: '$totalHadiths',
                        sub: isArabic ? 'حديث' : 'hadiths',
                      ),
                      Container(
                        width: 1,
                        height: 22,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                      _StatChip(
                        icon: Icons.category_rounded,
                        label: '$totalCategories',
                        sub: isArabic ? 'أبواب' : 'categories',
                      ),
                    ],
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

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;

  const _StatChip({required this.icon, required this.label, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.secondary, size: 16),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          sub,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
//  Glow Dot
// ╚═══════════════════════════════════════════════════════════════════════════╝

class _GlowDot extends StatelessWidget {
  final Color color;
  const _GlowDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

// ╔═══════════════════════════════════════════════════════════════════════════╗
//  Category Card — creative glassmorphism card
// ╚═══════════════════════════════════════════════════════════════════════════╝

class _CategoryCard extends StatelessWidget {
  final HadithCategoryInfo category;
  final int index;
  final bool isArabic;
  final bool isDark;
  final VoidCallback onTap;
  final bool showOnlineBadge;

  const _CategoryCard({
    required this.category,
    required this.index,
    required this.isArabic,
    required this.isDark,
    required this.onTap,
    this.showOnlineBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final catColor = category.color;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white,
              border: Border.all(
                color: catColor.withValues(alpha: isDark ? 0.3 : 0.15),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: catColor.withValues(alpha: isDark ? 0.08 : 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Decorative corner accent
                Positioned(
                  top: 0,
                  right: isArabic ? null : 0,
                  left: isArabic ? 0 : null,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.only(
                        topRight: isArabic
                            ? Radius.zero
                            : const Radius.circular(16),
                        topLeft: isArabic
                            ? const Radius.circular(16)
                            : Radius.zero,
                        bottomLeft: isArabic
                            ? Radius.zero
                            : const Radius.circular(40),
                        bottomRight: isArabic
                            ? const Radius.circular(40)
                            : Radius.zero,
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          catColor.withValues(alpha: 0.15),
                          catColor.withValues(alpha: 0.02),
                        ],
                      ),
                    ),
                  ),
                ),
                // Main content
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      // Icon container with gradient
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              catColor.withValues(alpha: 0.18),
                              catColor.withValues(alpha: 0.06),
                            ],
                          ),
                          border: Border.all(
                            color: catColor.withValues(alpha: 0.25),
                            width: 1.2,
                          ),
                        ),
                        child: Icon(category.icon, color: catColor, size: 24),
                      ),
                      const SizedBox(width: 14),
                      // Texts
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isArabic ? category.titleAr : category.titleEn,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: isDark ? Colors.white : Colors.black87,
                                fontFamily: isArabic ? 'Amiri' : null,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isArabic
                                  ? category.subtitleAr
                                  : category.subtitleEn,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Count badge or online badge
                      if (showOnlineBadge)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.info.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppColors.info.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.wifi_rounded,
                                  size: 11, color: AppColors.info),
                              SizedBox(width: 3),
                              Text(
                                'أونلاين',
                                style: TextStyle(
                                  color: AppColors.info,
                                  fontSize: 10,
                                  fontFamily: 'Amiri',
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: catColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${category.count}',
                            style: TextStyle(
                              color: catColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      const SizedBox(width: 4),
                      Icon(
                        isArabic
                            ? Icons.chevron_left_rounded
                            : Icons.chevron_right_rounded,
                        color: catColor.withValues(alpha: 0.5),
                        size: 22,
                      ),
                    ],
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

// ╔═══════════════════════════════════════════════════════════════════════════╗
//  Geometric Pattern Painter — Islamic-inspired repeating 8-point stars
// ╚═══════════════════════════════════════════════════════════════════════════╝

class _GeometricPatternPainter extends CustomPainter {
  final Color color;
  _GeometricPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    const spacing = 36.0;
    const r = 10.0;
    for (double x = 0; x < size.width + spacing; x += spacing) {
      for (double y = 0; y < size.height + spacing; y += spacing) {
        final cx = x;
        final cy = y;
        // Draw 8-point star
        final path = Path();
        for (int i = 0; i < 8; i++) {
          final angle = i * math.pi / 4;
          final ox = cx + r * math.cos(angle);
          final oy = cy + r * math.sin(angle);
          if (i == 0) {
            path.moveTo(ox, oy);
          } else {
            path.lineTo(ox, oy);
          }
        }
        path.close();
        canvas.drawPath(path, paint);
        // Inner diamond
        canvas.drawCircle(Offset(cx, cy), 3, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
