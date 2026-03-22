import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/settings/app_settings_cubit.dart';
import '../../data/models/adhkar_category.dart';
import '../../data/models/adhkar_item.dart';
import '../cubit/adhkar_progress_cubit.dart';

class AdhkarListScreen extends StatelessWidget {
  final AdhkarCategory category;

  const AdhkarListScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsCubit>().state;
    final isArabicUi =
        settings.appLanguageCode.toLowerCase().startsWith('ar');
    final showTranslation = settings.showTranslation;
    final progressState = context.watch<AdhkarProgressCubit>().state;
    final cubit = context.read<AdhkarProgressCubit>();
    final color = category.color;

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabicUi ? category.titleAr : category.titleEn),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: isArabicUi ? 'إعادة تعيين الكل' : 'Reset all',
            onPressed: () => cubit.resetCategory(category.id),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemCount: category.items.length,
        itemBuilder: (context, index) {
          final item = category.items[index];
          final count = progressState.countFor(category.id, item.id);
          final isDone = count >= item.repeatCount;

          return _AdhkarCard(
            item: item,
            count: count,
            isDone: isDone,
            isArabicUi: isArabicUi,
            showTranslation: showTranslation,
            categoryColor: color,
            index: index,
            onTap: () {
              HapticFeedback.lightImpact();
              cubit.increment(category.id, item.id, item.repeatCount);
            },
            onReset: () {
              HapticFeedback.mediumImpact();
              cubit.resetItem(category.id, item.id);
            },
            onIncrement5: () {
              HapticFeedback.lightImpact();
              cubit.incrementBy(category.id, item.id, item.repeatCount, 5);
            },
            onIncrement10: () {
              HapticFeedback.lightImpact();
              cubit.incrementBy(category.id, item.id, item.repeatCount, 10);
            },
            onMarkDone: () {
              HapticFeedback.heavyImpact();
              cubit.markDone(category.id, item.id, item.repeatCount);
            },
          );
        },
      ),
    );
  }
}

// ─── Adhkar Card ──────────────────────────────────────────────────────────────
class _AdhkarCard extends StatelessWidget {
  final AdhkarItem item;
  final int count;
  final bool isDone;
  final bool isArabicUi;
  final bool showTranslation;
  final Color categoryColor;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onReset;
  final VoidCallback onIncrement5;
  final VoidCallback onIncrement10;
  final VoidCallback onMarkDone;

  const _AdhkarCard({
    required this.item,
    required this.count,
    required this.isDone,
    required this.isArabicUi,
    required this.showTranslation,
    required this.categoryColor,
    required this.index,
    required this.onTap,
    required this.onReset,
    required this.onIncrement5,
    required this.onIncrement10,
    required this.onMarkDone,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDone
        ? (isDark
            ? const Color(0xFF1B3A2D)
            : const Color(0xFFE8F5EC))
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Card(
        color: cardColor,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: isDone
                ? AppColors.primary.withValues(alpha: 0.5)
                : AppColors.cardBorder,
            width: isDone ? 2 : 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── Top bar with index + done badge ─────────────────────
            Container(
              decoration: BoxDecoration(
                color: categoryColor.withValues(alpha: isDark ? 0.25 : 0.1),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: isDark ? 0.4 : 0.2),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: categoryColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (isDone)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded,
                              size: 14,
                              color: AppColors.success),
                          const SizedBox(width: 4),
                          Text(
                            isArabicUi ? 'تمّ' : 'Done',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // ─── Arabic text ──────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Text(
                item.arabicText,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: GoogleFonts.amiri(
                  fontSize: 22,
                  height: 1.9,
                  fontWeight: FontWeight.w600,
                  color: isDone
                      ? AppColors.primary
                      : (isDark
                          ? const Color(0xFFE8DCC8)
                          : AppColors.arabicText),
                ),
              ),
            ),

            // ─── Translation (shown only when setting is enabled) ────
            if (showTranslation)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Text(
                  item.translationEn,
                  textAlign: isArabicUi ? TextAlign.right : TextAlign.left,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                        height: 1.6,
                        fontStyle: FontStyle.italic,
                      ),
                ),
              ),

            // ─── Virtue (if any) ──────────────────────────────────────
            if (item.virtue != null) ...[
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: isDark ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.star_rounded,
                        size: 15, color: AppColors.secondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.virtue!,
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.right,
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: isDark
                              ? const Color(0xFFD4AF37)
                              : AppColors.accent,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const Divider(height: 1),

            // ─── Reference row ────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(14, 8, 14, item.repeatCount > 1 ? 4 : 12),
              child: Row(
                children: [
                  Icon(Icons.bookmark_rounded,
                      size: 13,
                      color: AppColors.textSecondary.withValues(alpha: 0.7)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item.reference,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            color: AppColors.textSecondary.withValues(alpha: 0.8),
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (item.repeatCount == 1) ...[  
                    const SizedBox(width: 8),
                    _CounterWidget(
                      count: count,
                      maxCount: item.repeatCount,
                      isDone: isDone,
                      categoryColor: categoryColor,
                      isArabicUi: isArabicUi,
                      onTap: onTap,
                      onReset: onReset,
                      onIncrement5: onIncrement5,
                      onIncrement10: onIncrement10,
                      onMarkDone: onMarkDone,
                    ),
                  ],
                ],
              ),
            ),

            // ─── Counter row (multi-repeat items only) ────────────────
            if (item.repeatCount > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                child: _CounterWidget(
                  count: count,
                  maxCount: item.repeatCount,
                  isDone: isDone,
                  categoryColor: categoryColor,
                  isArabicUi: isArabicUi,
                  onTap: onTap,
                  onReset: onReset,
                  onIncrement5: onIncrement5,
                  onIncrement10: onIncrement10,
                  onMarkDone: onMarkDone,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Counter Widget ────────────────────────────────────────────────────────────
class _CounterWidget extends StatelessWidget {
  final int count;
  final int maxCount;
  final bool isDone;
  final Color categoryColor;
  final bool isArabicUi;
  final VoidCallback onTap;
  final VoidCallback onReset;
  final VoidCallback onIncrement5;
  final VoidCallback onIncrement10;
  final VoidCallback onMarkDone;

  const _CounterWidget({
    required this.count,
    required this.maxCount,
    required this.isDone,
    required this.categoryColor,
    required this.isArabicUi,
    required this.onTap,
    required this.onReset,
    required this.onIncrement5,
    required this.onIncrement10,
    required this.onMarkDone,
  });

  @override
  Widget build(BuildContext context) {
    if (maxCount == 1) {
      // For single-repeat items, show a simple done button
      return Tooltip(
        message: isDone
            ? (isArabicUi
                ? 'اضغط لإلغاء التعليم وإعادة الذِكر'
                : 'Tap to unmark and repeat')
            : (isArabicUi
                ? 'اضغط لتعليم الذِكر كمقروء'
                : 'Tap to mark as recited'),
        preferBelow: false,
        child: GestureDetector(
          onTap: isDone ? onReset : onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: isDone
                  ? AppColors.success.withValues(alpha: 0.15)
                  : categoryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDone
                    ? AppColors.success.withValues(alpha: 0.5)
                    : categoryColor.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isDone
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 15,
                  color: isDone ? AppColors.success : categoryColor,
                ),
                const SizedBox(width: 5),
                Text(
                  isDone
                      ? (isArabicUi ? 'تمّ' : 'Done')
                      : (isArabicUi ? 'قرأت' : 'Mark'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDone ? AppColors.success : categoryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Multi-repeat counter – 2-row layout: big tap area + action strip
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Row 1: full-width main counter button ─────────────────────
        GestureDetector(
          onTap: isDone ? null : onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              gradient: isDone
                  ? null
                  : LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        categoryColor.withValues(alpha: 0.85),
                        categoryColor,
                      ],
                    ),
              color: isDone ? AppColors.success.withValues(alpha: 0.12) : null,
              borderRadius: BorderRadius.circular(16),
              border: isDone
                  ? Border.all(
                      color: AppColors.success.withValues(alpha: 0.5),
                      width: 1.5)
                  : null,
              boxShadow: isDone
                  ? null
                  : [
                      BoxShadow(
                        color: categoryColor.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isDone) ...[
                  Icon(Icons.check_circle_rounded,
                      size: 20, color: AppColors.success),
                  const SizedBox(width: 8),
                  Text(
                    '$maxCount / $maxCount',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.success,
                    ),
                  ),
                ] else ...[
                  const Icon(Icons.add_rounded, size: 20, color: Colors.white),
                  const SizedBox(width: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$count / $maxCount',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        // ── Row 2: action strip (+5 / +10 / اكتمل / ↺) ───────────────
        Row(
          children: [
            // Reset
            IntrinsicWidth(
              child: _ActionChip(
                icon: Icons.refresh_rounded,
                label: isArabicUi ? 'إعادة' : 'Reset',
                color: AppColors.error,
                onTap: onReset,
              ),
            ),
            const SizedBox(width: 6),

            // +5
            if (!isDone && maxCount >= 5) ...[
              Expanded(
                child: _ActionChip(
                  label: '+5',
                  color: categoryColor,
                  onTap: onIncrement5,
                ),
              ),
              const SizedBox(width: 6),
            ],

            // +10
            if (!isDone && maxCount >= 10) ...[
              Expanded(
                child: _ActionChip(
                  label: '+10',
                  color: categoryColor,
                  onTap: onIncrement10,
                ),
              ),
              const SizedBox(width: 6),
            ],

            // اكتمل
            if (!isDone)
              Expanded(
                child: _ActionChip(
                  icon: Icons.done_all_rounded,
                  label: isArabicUi ? 'اكتمل' : 'Done',
                  color: AppColors.success,
                  onTap: onMarkDone,
                  tooltip: isArabicUi
                      ? 'أتممت العدد بالمسبحة أو غيرها'
                      : 'Mark as fully done (external counter)',
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ─── Action Chip button ───────────────────────────────────────────────────────
class _ActionChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final IconData? icon;
  final String? tooltip;

  const _ActionChip({
    required this.label,
    required this.color,
    required this.onTap,
    this.icon,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    Widget chip = GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, preferBelow: false, child: chip);
    }
    return chip;
  }
}
