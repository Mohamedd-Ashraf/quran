import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/settings/app_settings_cubit.dart';
import '../../../../core/theme/app_design_system.dart';
import '../../data/models/hadith_item.dart';
import '../../data/repositories/hadith_repository.dart';
import '../cubit/hadith_cubit.dart';
import '../cubit/hadith_detail_cubit.dart';
import '../cubit/hadith_detail_state.dart';
import '../cubit/hadith_state.dart';
import '../widgets/hadith_skeleton.dart';

class HadithDetailScreen extends StatelessWidget {
  final String hadithId;
  final String? categoryId;
  final String categoryTitle;
  final int? sortOrder;

  const HadithDetailScreen({
    super.key,
    required this.hadithId,
    this.categoryId,
    required this.categoryTitle,
    this.sortOrder,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => HadithDetailCubit(
        repository: context.read<HadithRepository>(),
        hadithId: hadithId,
        categoryId: categoryId,
        currentSortOrder: sortOrder,
      )..load(),
      child: _HadithDetailView(categoryTitle: categoryTitle),
    );
  }
}

class _HadithDetailView extends StatefulWidget {
  final String categoryTitle;

  const _HadithDetailView({required this.categoryTitle});

  @override
  State<_HadithDetailView> createState() => _HadithDetailViewState();
}

class _HadithDetailViewState extends State<_HadithDetailView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final GlobalKey _shareCardKey = GlobalKey();
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
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

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'تفاصيل الحديث' : 'Hadith Details'),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        actions: [
          BlocBuilder<HadithDetailCubit, HadithDetailState>(
            builder: (context, detailState) {
              if (detailState.hadith == null) return const SizedBox.shrink();
              return BlocBuilder<HadithCubit, HadithState>(
                builder: (context, state) {
                  final isBookmarked = state.isBookmarked(
                    detailState.hadith!.id,
                  );
                  return IconButton(
                    icon: Icon(
                      isBookmarked
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      color: isBookmarked ? AppColors.secondary : Colors.white,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      context.read<HadithCubit>().toggleBookmark(
                        detailState.hadith!.id,
                      );
                    },
                  );
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: _isSharing ? null : () => _shareAsImage(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.secondary,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          tabs: [
            Tab(text: isArabic ? 'الحديث' : 'Hadith'),
            Tab(text: isArabic ? 'التحقيق' : 'Verification'),
            Tab(text: isArabic ? 'السند' : 'Chain'),
          ],
        ),
      ),
      body: BlocBuilder<HadithDetailCubit, HadithDetailState>(
        builder: (context, state) {
          if (state.status == HadithDetailStatus.loading ||
              state.status == HadithDetailStatus.initial) {
            return HadithDetailSkeleton(isDark: isDark);
          }
          if (state.status == HadithDetailStatus.error ||
              state.hadith == null) {
            return HadithErrorWidget(
              message: state.errorMessage ?? '',
              isArabic: isArabic,
              onRetry: () => context.read<HadithDetailCubit>().retry(),
            );
          }
          final hadith = state.hadith!;
          return TabBarView(
            controller: _tabController,
            children: [
              _HadithTab(
                hadith: hadith,
                isArabic: isArabic,
                isDark: isDark,
                shareCardKey: _shareCardKey,
              ),
              _VerificationTab(
                hadith: hadith,
                isArabic: isArabic,
                isDark: isDark,
              ),
              _SanadTab(hadith: hadith, isArabic: isArabic, isDark: isDark),
            ],
          );
        },
      ),
    );
  }

  Future<void> _shareAsImage(BuildContext context) async {
    final detailState = context.read<HadithDetailCubit>().state;
    if (detailState.hadith == null) return;
    final hadith = detailState.hadith!;

    setState(() => _isSharing = true);

    try {
      // Switch to hadith tab before capturing
      _tabController.animateTo(0);
      await Future.delayed(const Duration(milliseconds: 300));

      final boundary =
          _shareCardKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        setState(() => _isSharing = false);
        return;
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        setState(() => _isSharing = false);
        return;
      }

      final bytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/hadith_${hadith.id}_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes);

      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: hadith.reference),
      );
    } catch (e) {
      if (context.mounted) {
        final isArabic = context
            .read<AppSettingsCubit>()
            .state
            .appLanguageCode
            .toLowerCase()
            .startsWith('ar');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isArabic ? 'فشل في المشاركة' : 'Failed to share'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Tab 1: Hadith Text
// ═══════════════════════════════════════════════════════════════════════════════

class _HadithTab extends StatefulWidget {
  final HadithItem hadith;
  final bool isArabic;
  final bool isDark;
  final GlobalKey shareCardKey;

  const _HadithTab({
    required this.hadith,
    required this.isArabic,
    required this.isDark,
    required this.shareCardKey,
  });

  @override
  State<_HadithTab> createState() => _HadithTabState();
}

class _HadithTabState extends State<_HadithTab> {
  bool _showFullIsnad = false;

  @override
  Widget build(BuildContext context) {
    final hadith = widget.hadith;
    final isArabic = widget.isArabic;
    final isDark = widget.isDark;
    final hasIsnad = !hadith.isOffline && hadith.sanad.trim().isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: RepaintBoundary(
        key: widget.shareCardKey,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.surface,
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusLg),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.cardBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with bismillah
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppDesignSystem.radiusLg),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'بسم الله الرحمن الرحيم',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Amiri',
                        fontSize: 18,
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isArabic ? hadith.topicAr : hadith.topicEn,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Toggle: show full isnad (only for online hadiths that have a sanad)
              if (hasIsnad)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _showFullIsnad = !_showFullIsnad),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _showFullIsnad
                            ? AppColors.primary.withValues(alpha: 0.08)
                            : (isDark
                                  ? AppColors.darkCard
                                  : AppColors.primary.withValues(alpha: 0.03)),
                        borderRadius: BorderRadius.circular(
                          AppDesignSystem.radiusSm,
                        ),
                        border: Border.all(
                          color: _showFullIsnad
                              ? AppColors.primary.withValues(alpha: 0.35)
                              : (isDark
                                    ? AppColors.darkBorder
                                    : AppColors.primary.withValues(alpha: 0.12)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.account_tree_rounded,
                            size: 17,
                            color: _showFullIsnad
                                ? AppColors.primary
                                : (isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.textSecondary),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isArabic
                                  ? (_showFullIsnad
                                        ? 'إخفاء السند'
                                        : 'عرض الحديث بالسند كاملاً')
                                  : (_showFullIsnad
                                        ? 'Hide Isnad'
                                        : 'Show Full Hadith with Isnad'),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _showFullIsnad
                                    ? AppColors.primary
                                    : (isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.textSecondary),
                              ),
                            ),
                          ),
                          Icon(
                            _showFullIsnad
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                            size: 20,
                            color: _showFullIsnad
                                ? AppColors.primary
                                : (isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── Full isnad (sanad) section — shown when toggled on
              if (hasIsnad && _showFullIsnad)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkCard
                          : AppColors.primary.withValues(alpha: 0.025),
                      borderRadius: BorderRadius.circular(
                        AppDesignSystem.radiusSm,
                      ),
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.primary.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Label
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              isArabic ? 'الإسناد' : 'Isnad',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                                color: AppColors.primary.withValues(alpha: 0.55),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.link_rounded,
                              size: 13,
                              color: AppColors.primary.withValues(alpha: 0.45),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Sanad text — muted color, tashkeel dimmed
                        _arabicRichText(
                          hadith.sanad,
                          baseStyle: TextStyle(
                            fontFamily: 'Amiri',
                            fontSize: 16,
                            height: 2.0,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ── Divider between isnad and matn when expanded
              if (hasIsnad && _showFullIsnad)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: AppColors.secondary.withValues(alpha: 0.35),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.arrow_downward_rounded,
                              size: 13,
                              color: AppColors.secondary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isArabic ? 'المتن' : 'Matn',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: AppColors.secondary.withValues(alpha: 0.35),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Matn label
              Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  (hasIsnad && _showFullIsnad) ? 8 : 24,
                  20,
                  8,
                ),
                child: Text(
                  hadith.isOffline ? 'قال رسول الله ﷺ:' : 'نص الحديث:',
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: 'Amiri',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _showFullIsnad ? AppColors.secondary : AppColors.primary,
                  ),
                ),
              ),

              // ── Matn text — highlighted with golden border when full isnad shown
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _showFullIsnad
                        ? AppColors.secondary.withValues(alpha: 0.07)
                        : AppColors.primary.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(
                      AppDesignSystem.radiusMd,
                    ),
                    border: Border.all(
                      color: _showFullIsnad
                          ? AppColors.secondary.withValues(alpha: 0.45)
                          : AppColors.primary.withValues(alpha: 0.1),
                      width: _showFullIsnad ? 1.5 : 1.0,
                    ),
                    boxShadow: _showFullIsnad
                        ? [
                            BoxShadow(
                              color: AppColors.secondary.withValues(alpha: 0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    '« ${hadith.arabicText} »',
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: 'Amiri',
                      fontSize: 20,
                      height: 2.0,
                      fontWeight:
                          _showFullIsnad ? FontWeight.w700 : FontWeight.normal,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),

              // Explanation if available
              if (hadith.explanation != null) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(
                        AppDesignSystem.radiusSm,
                      ),
                      border: Border.all(
                        color: AppColors.secondary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.lightbulb_outline_rounded,
                              size: 16,
                              color: AppColors.secondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isArabic ? 'شرح الحديث' : 'Explanation',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: AppColors.secondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          hadith.explanation!,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.7,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Reference bar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkCard
                      : AppColors.primary.withValues(alpha: 0.04),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(AppDesignSystem.radiusLg),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.menu_book_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hadith.reference,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    Text(
                      isArabic ? 'تطبيق نور الإيمان' : 'Noor Al-Imaan App',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Tab 2: Verification (تحقيق)
// ═══════════════════════════════════════════════════════════════════════════════

class _VerificationTab extends StatelessWidget {
  final HadithItem hadith;
  final bool isArabic;
  final bool isDark;

  const _VerificationTab({
    required this.hadith,
    required this.isArabic,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Authentication Status Card
          _AuthStatusCard(hadith: hadith, isArabic: isArabic, isDark: isDark),
          const SizedBox(height: 16),

          // Details
          _InfoCard(
            icon: Icons.verified_user_rounded,
            title: isArabic ? 'درجة الحديث' : 'Hadith Grading',
            content: isArabic ? hadith.grade.labelAr : hadith.grade.labelEn,
            color: _gradeColor(hadith.grade),
            isArabic: isArabic,
            isDark: isDark,
          ),
          _InfoCard(
            icon: Icons.school_rounded,
            title: isArabic ? 'المُحَقِّق / المُخَرِّج' : 'Graded By',
            content: hadith.gradedBy,
            color: AppColors.info,
            isArabic: isArabic,
            isDark: isDark,
          ),
          _InfoCard(
            icon: Icons.library_books_rounded,
            title: isArabic ? 'المصدر' : 'Source',
            content: hadith.reference,
            color: AppColors.primary,
            isArabic: isArabic,
            isDark: isDark,
          ),
          _InfoCard(
            icon: Icons.book_rounded,
            title: isArabic ? 'الكتاب والباب' : 'Book & Chapter',
            content: hadith.bookReference,
            color: AppColors.tertiary,
            isArabic: isArabic,
            isDark: isDark,
          ),
          _InfoCard(
            icon: Icons.person_rounded,
            title: isArabic ? 'الراوي' : 'Narrator',
            content: hadith.narrator,
            color: AppColors.secondary,
            isArabic: isArabic,
            isDark: isDark,
          ),

          const SizedBox(height: 16),

          // Methodology note
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
              border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: AppColors.info,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isArabic ? 'منهجية التحقيق' : 'Verification Methodology',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.info,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  isArabic
                      ? '• جميع الأحاديث مأخوذة من الكتب الستة المعتمدة عند أهل السنة والجماعة.\n'
                            '• التصحيح والتضعيف بناءً على أحكام الأئمة المحدثين كالبخاري ومسلم والترمذي والألباني.\n'
                            '• الأسانيد مذكورة كاملة كما وردت في المصادر الأصلية.\n'
                            '• لا يتم إدراج أي حديث ضعيف أو موضوع.'
                      : '• All hadiths are from the six canonical books accepted by Ahl al-Sunnah.\n'
                            '• Authentication is based on the rulings of the master hadith scholars like Bukhari, Muslim, Tirmidhi, and Al-Albani.\n'
                            '• Full chains of narration (isnad) are provided as found in the original sources.\n'
                            '• No weak or fabricated hadiths are included.',
                  textDirection: isArabic
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.8,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _gradeColor(HadithGrade grade) {
    switch (grade) {
      case HadithGrade.sahih:
        return AppColors.success;
      case HadithGrade.hasan:
        return AppColors.info;
      case HadithGrade.muttafaqAlayh:
        return const Color(0xFF6A1B9A);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Authentication Status Card
// ─────────────────────────────────────────────────────────────────────────────

class _AuthStatusCard extends StatelessWidget {
  final HadithItem hadith;
  final bool isArabic;
  final bool isDark;

  const _AuthStatusCard({
    required this.hadith,
    required this.isArabic,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final Color statusColor;
    final IconData statusIcon;
    final String statusText;
    final String statusDescription;

    switch (hadith.grade) {
      case HadithGrade.sahih:
        statusColor = AppColors.success;
        statusIcon = Icons.verified_rounded;
        statusText = isArabic ? 'حديث صحيح' : 'Authentic Hadith';
        statusDescription = isArabic
            ? 'اتصل سنده بنقل العدل الضابط عن مثله إلى منتهاه، من غير شذوذ ولا علة'
            : 'Its chain is connected through reliable and precise narrators without irregularity or hidden defect';
      case HadithGrade.hasan:
        statusColor = AppColors.info;
        statusIcon = Icons.check_circle_rounded;
        statusText = isArabic ? 'حديث حسن' : 'Good Hadith';
        statusDescription = isArabic
            ? 'كالصحيح إلا أن في رواته من هو خفيف الضبط، وهو حجة يُعمل به'
            : 'Like Sahih except that it has a narrator with slightly lesser precision. It is still a proof to act upon';
      case HadithGrade.muttafaqAlayh:
        statusColor = const Color(0xFF6A1B9A);
        statusIcon = Icons.workspace_premium_rounded;
        statusText = isArabic ? 'متفق عليه' : 'Agreed Upon';
        statusDescription = isArabic
            ? 'رواه الإمامان البخاري ومسلم في صحيحيهما، وهو أعلى درجات الصحة'
            : 'Narrated by both Imam Bukhari and Imam Muslim, the highest degree of authenticity';
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusLg),
        border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 2),
      ),
      child: Column(
        children: [
          // Status header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppDesignSystem.radiusLg - 2),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.4),
                      width: 2,
                    ),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 32),
                ),
                const SizedBox(height: 12),
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    fontFamily: 'Amiri',
                  ),
                ),
              ],
            ),
          ),
          // Description
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              statusDescription,
              textAlign: TextAlign.center,
              textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
              style: TextStyle(
                fontSize: 14,
                height: 1.7,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info Card
// ─────────────────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;
  final Color color;
  final bool isArabic;
  final bool isDark;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.content,
    required this.color,
    required this.isArabic,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    content,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Tab 3: Sanad (Chain of Narration)
// ═══════════════════════════════════════════════════════════════════════════════

/// Renders Arabic [text] as a [RichText] with tashkeel (diacritics) displayed
/// in a muted colour (38 % opacity of the base colour) so base letters stand out.
RichText _arabicRichText(String text, {required TextStyle baseStyle}) {
  final baseColor = baseStyle.color ?? Colors.black;
  final tashkeelColor = baseColor.withValues(alpha: 0.38);
  final tkRegex = RegExp(
    '[\u064B-\u065F\u0610-\u061A\u0670\u06D6-\u06DC\u06DF-\u06E4\u06E7\u06E8\u06EA-\u06ED]',
  );
  final spans = <TextSpan>[];
  int prev = 0;
  for (final m in tkRegex.allMatches(text)) {
    if (m.start > prev) {
      spans.add(TextSpan(text: text.substring(prev, m.start)));
    }
    spans.add(TextSpan(text: m[0], style: TextStyle(color: tashkeelColor)));
    prev = m.end;
  }
  if (prev < text.length) spans.add(TextSpan(text: text.substring(prev)));
  return RichText(
    textDirection: TextDirection.rtl,
    text: TextSpan(style: baseStyle, children: spans),
  );
}

class _SanadTab extends StatelessWidget {
  final HadithItem hadith;
  final bool isArabic;
  final bool isDark;

  const _SanadTab({
    required this.hadith,
    required this.isArabic,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    // Parse the sanad into individual narrators
    final narrators = _parseSanad(hadith.sanad);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sanad header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusLg),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.account_tree_rounded,
                  color: Colors.white,
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  isArabic ? 'سلسلة السند' : 'Chain of Narration',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    fontFamily: 'Amiri',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isArabic
                      ? 'سلسلة الرواة من المصنف إلى النبي ﷺ'
                      : 'Chain of narrators from the compiler to the Prophet ﷺ',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Full sanad text
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkCard
                  : AppColors.primary.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
              border: Border.all(
                color: isDark
                    ? AppColors.darkBorder
                    : AppColors.primary.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.format_quote_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isArabic ? 'السند الكامل' : 'Full Isnad',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  hadith.sanad,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: 'Amiri',
                    fontSize: 16,
                    height: 2.0,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Visual chain
          Text(
            isArabic ? 'سلسلة الرواة' : 'Narrator Chain',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          // Chain visualization
          ...List.generate(narrators.length, (index) {
            final isLast = index == narrators.length - 1;
            return _ChainLink(
              narrator: narrators[index],
              isFirst: index == 0,
              isLast: isLast,
              index: index,
              total: narrators.length,
              isDark: isDark,
            );
          }),

          // The Prophet ﷺ at the end
          _ProphetNode(isArabic: isArabic, isDark: isDark),

          const SizedBox(height: 20),

          // Sanad terminology
          _SanadTerminology(isArabic: isArabic, isDark: isDark),
        ],
      ),
    );
  }

  List<String> _parseSanad(String sanad) {
    // Diacritic-tolerant pattern: after each keyword letter allow any number of
    // tashkeel characters so it matches both plain (offline) and fully-vowelled
    // (online/Firestore) text without stripping diacritics from the original.
    const t = r'[\u064B-\u065F\u0610-\u061A\u0670]*';
    String kw(String word) =>
        word.split('').map((c) => RegExp.escape(c) + t).join();

    // Build the split pattern (highest-priority variant first):
    //   • (قال )?(حدثنا|أخبرنا) — optionally preceded by قال and comma/space
    //   • ، عن  — only when preceded by comma to avoid mid-word matches
    final pattern = RegExp(
      '(?:[،,]$t[ \\t]*)?' // optional leading comma+space
      '(?:${kw('قال')}$t[ \\t]+)?' // optional قال
      '(?:${kw('حدثنا')}|${kw('أخبرنا')})'
      '|'
      '[،,]$t[ \\t]*${kw('عن')}$t(?=[ \\t])', // ، عن (comma required)
    );

    final matches = pattern.allMatches(sanad).toList();
    if (matches.isEmpty) return [sanad];

    String clean(String s) =>
        s.trim().replaceAll(RegExp(r'^[،,\s]+|[،,\s]+$'), '');

    final parts = <String>[];

    final before = clean(sanad.substring(0, matches.first.start));
    if (before.length > 3) parts.add(before);

    for (var i = 0; i < matches.length - 1; i++) {
      final seg = clean(sanad.substring(matches[i].end, matches[i + 1].start));
      if (seg.length > 3) parts.add(seg);
    }

    final after = clean(sanad.substring(matches.last.end));
    if (after.length > 3) parts.add(after);

    return parts.isEmpty ? [sanad] : parts;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chain Link Widget
// ─────────────────────────────────────────────────────────────────────────────

class _ChainLink extends StatelessWidget {
  final String narrator;
  final bool isFirst;
  final bool isLast;
  final int index;
  final int total;
  final bool isDark;

  const _ChainLink({
    required this.narrator,
    required this.isFirst,
    required this.isLast,
    required this.index,
    required this.total,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    // Determine role label
    String role;
    if (isFirst) {
      role = 'المصنف';
    } else if (isLast) {
      role = 'الصحابي';
    } else {
      role = 'الراوي $index';
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Vertical connecting line
          SizedBox(
            width: 40,
            child: Column(
              children: [
                // Top line
                if (!isFirst)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                // Dot
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: isFirst || isLast
                        ? AppColors.primary
                        : AppColors.primary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 2),
                  ),
                  child: isFirst || isLast
                      ? const Icon(Icons.circle, size: 6, color: Colors.white)
                      : null,
                ),
                // Bottom line
                Expanded(
                  child: Container(
                    width: 2,
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Narrator card
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkCard
                    : (isFirst || isLast
                          ? AppColors.primary.withValues(alpha: 0.05)
                          : AppColors.surface),
                borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm),
                border: Border.all(
                  color: isFirst || isLast
                      ? AppColors.primary.withValues(alpha: 0.2)
                      : (isDark ? AppColors.darkBorder : AppColors.cardBorder),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    role,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  _arabicRichText(
                    narrator,
                    baseStyle: TextStyle(
                      fontFamily: 'Amiri',
                      fontSize: 14,
                      fontWeight: isFirst || isLast
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
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

// ─────────────────────────────────────────────────────────────────────────────
// Prophet Node
// ─────────────────────────────────────────────────────────────────────────────

class _ProphetNode extends StatelessWidget {
  final bool isArabic;
  final bool isDark;

  const _ProphetNode({required this.isArabic, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Column(
            children: [
              Container(
                width: 2,
                height: 12,
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.star_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.mosque_rounded,
                  color: AppColors.secondary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  isArabic ? 'رسول الله ﷺ' : 'The Messenger of Allah ﷺ',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    fontFamily: 'Amiri',
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.mosque_rounded,
                  color: AppColors.secondary,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sanad Terminology
// ─────────────────────────────────────────────────────────────────────────────

class _SanadTerminology extends StatelessWidget {
  final bool isArabic;
  final bool isDark;

  const _SanadTerminology({required this.isArabic, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final terms = isArabic
        ? [
            ('حدثنا', 'صيغة تحمل وسماع مباشر من الشيخ'),
            ('أخبرنا', 'صيغة قراءة على الشيخ'),
            ('عن', 'صيغة عنعنة، تحتمل السماع'),
            ('سمعت', 'صيغة سماع صريح'),
          ]
        : [
            ('Haddathana', 'Direct hearing from the teacher'),
            ('Akhbarana', 'Reading to the teacher'),
            ("'An", 'Possible hearing (An\'ana)'),
            ('Sami\'tu', 'Explicit hearing'),
          ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.school_rounded, size: 18, color: AppColors.secondary),
              const SizedBox(width: 8),
              Text(
                isArabic ? 'مصطلحات السند' : 'Chain Terminology',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...terms.map(
            (term) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      term.$1,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: AppColors.primary,
                        fontFamily: isArabic ? 'Amiri' : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      term.$2,
                      textDirection: isArabic
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                      ),
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
