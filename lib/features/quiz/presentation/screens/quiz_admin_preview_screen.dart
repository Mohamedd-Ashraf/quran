import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/datasources/quiz_questions_data.dart';
import '../../data/models/quiz_question_model.dart';

/// Set this to the admin's Firebase UID.
/// Only accounts whose UID matches this value can open the preview.
const String _kAdminUid = 'G0WMPKyBFdf2weY5zJa34t8d0f93';

/// Read-only admin screen for previewing and testing quiz questions.
///
/// - Zero writes to Firestore — safe to browse freely.
/// - Navigate between all 360 questions.
/// - Filter by difficulty.
/// - Jump to any question by ID.
/// - See the correct answer highlighted immediately.
class QuizAdminPreviewScreen extends StatefulWidget {
  const QuizAdminPreviewScreen({super.key});

  /// Returns true if the currently signed-in user is the admin.
  static bool isAdmin() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid != null && uid == _kAdminUid;
  }

  @override
  State<QuizAdminPreviewScreen> createState() =>
      _QuizAdminPreviewScreenState();
}

class _QuizAdminPreviewScreenState extends State<QuizAdminPreviewScreen> {
  // Filtered + full lists
  List<QuizQuestion> _filtered = quizQuestionsPool;
  QuizDifficulty? _selectedDifficulty; // null = all

  int _index = 0; // index into _filtered

  // Jump-to dialog controller
  final _jumpController = TextEditingController();

  @override
  void dispose() {
    _jumpController.dispose();
    super.dispose();
  }

  QuizQuestion get _current => _filtered[_index];

  // ── Filtering ─────────────────────────────────────────────────────────────

  void _setFilter(QuizDifficulty? d) {
    setState(() {
      _selectedDifficulty = d;
      _filtered = d == null
          ? quizQuestionsPool
          : quizQuestionsPool.where((q) => q.difficulty == d).toList();
      _index = 0;
    });
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _prev() {
    if (_index > 0) setState(() => _index--);
  }

  void _next() {
    if (_index < _filtered.length - 1) setState(() => _index++);
  }

  void _jumpTo() async {
    _jumpController.clear();
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAr ? 'الذهاب لسؤال' : 'Go to Question'),
        content: TextField(
          controller: _jumpController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: isAr
                ? 'رقم السؤال (0 – ${_filtered.length - 1})'
                : 'Question number (0 – ${_filtered.length - 1})',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isAr ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(_jumpController.text.trim());
              if (v != null && v >= 0 && v < _filtered.length) {
                setState(() => _index = v);
              }
              Navigator.pop(ctx);
            },
            child: Text(isAr ? 'انتقل' : 'Go'),
          ),
        ],
      ),
    );
  }

  // ── UI helpers ────────────────────────────────────────────────────────────

  Color _diffColor(QuizDifficulty d) {
    switch (d) {
      case QuizDifficulty.easy:
        return AppColors.success;
      case QuizDifficulty.medium:
        return AppColors.warning;
      case QuizDifficulty.hard:
        return AppColors.error;
    }
  }

  String _diffLabel(QuizDifficulty d, [bool isAr = true]) {
    switch (d) {
      case QuizDifficulty.easy:
        return isAr ? 'سهل' : 'Easy';
      case QuizDifficulty.medium:
        return isAr ? 'متوسط' : 'Medium';
      case QuizDifficulty.hard:
        return isAr ? 'صعب' : 'Hard';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final q = _current;
    final diffColor = _diffColor(q.difficulty);

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'معاينة الأسئلة — أدمن' : 'Question Preview — Admin'),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: isAr ? 'انتقل لسؤال' : 'Jump to question',
            onPressed: _jumpTo,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Difficulty filter chips ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: isAr ? 'الكل (${quizQuestionsPool.length})' : 'All (${quizQuestionsPool.length})',
                    selected: _selectedDifficulty == null,
                    color: AppColors.primary,
                    onTap: () => _setFilter(null),
                  ),
                  const SizedBox(width: 8),
                  for (final d in QuizDifficulty.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _FilterChip(
                        label:
                            '${_diffLabel(d, isAr)} (${quizQuestionsPool.where((q) => q.difficulty == d).length})',
                        selected: _selectedDifficulty == d,
                        color: _diffColor(d),
                        onTap: () => _setFilter(d),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Progress indicator ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  '${_index + 1} / ${_filtered.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _filtered.isEmpty
                          ? 0
                          : (_index + 1) / _filtered.length,
                      minHeight: 6,
                      backgroundColor: isDark
                          ? AppColors.darkBorder
                          : Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(diffColor),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // ID badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: diffColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: diffColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    'ID: ${q.id}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: diffColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Question card ────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Difficulty + timer + points row
                  Row(
                    children: [
                      _Badge(
                        label: _diffLabel(q.difficulty, isAr),
                        color: diffColor,
                      ),
                      const SizedBox(width: 8),
                      _Badge(
                        label: '⏱ ${q.timerSeconds}s',
                        color: AppColors.info,
                      ),
                      const SizedBox(width: 8),
                      _Badge(
                        label: isAr ? '+${q.points} نقطة' : '+${q.points} pts',
                        color: AppColors.secondary,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Question text
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Text(
                      q.question,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.6,
                        fontFamily: 'Amiri',
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Options — correct always highlighted immediately
                  ...List.generate(q.options.length, (i) {
                    final isCorrect = i == q.correctIndex;
                    final optLabels = isAr ? ['أ', 'ب', 'ج', 'د'] : ['A', 'B', 'C', 'D'];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(
                        color: isCorrect
                            ? AppColors.success.withValues(alpha: 0.1)
                            : (isDark
                                ? AppColors.darkCard
                                : Colors.white),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isCorrect
                              ? AppColors.success
                              : (isDark
                                  ? AppColors.darkBorder.withValues(alpha: 0.5)
                                  : Colors.grey.withValues(alpha: 0.25)),
                          width: isCorrect ? 2 : 1,
                        ),
                        boxShadow: isCorrect
                            ? [
                                BoxShadow(
                                  color: AppColors.success
                                      .withValues(alpha: 0.18),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        children: [
                          // Letter badge
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isCorrect
                                  ? AppColors.success
                                  : (isDark
                                      ? AppColors.darkBorder
                                      : const Color(0xFFF3F4F5)),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: isCorrect
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 20)
                                : Text(
                                    optLabels[i],
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black54,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              q.options[i],
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isCorrect
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isCorrect ? AppColors.success : null,
                              ),
                            ),
                          ),
                          if (isCorrect)
                            const Icon(Icons.check_circle,
                                color: AppColors.success, size: 20),
                        ],
                      ),
                    );
                  }),

                  // Explanation
                  if (q.explanation != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.info.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lightbulb_outline,
                              color: AppColors.info, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              q.explanation!,
                              style: const TextStyle(
                                  fontSize: 13, height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // ── Bottom navigation ────────────────────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? AppColors.darkBorder
                      : Colors.grey.shade200,
                ),
              ),
            ),
            child: Row(
              children: [
                // Prev
                FilledButton.icon(
                  onPressed: _index > 0 ? _prev : null,
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                  label: Text(isAr ? 'السابق' : 'Previous'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                ),
                const Spacer(),
                // Page counter tap → jump
                GestureDetector(
                  onTap: _jumpTo,
                  child: Text(
                    '${_index + 1} / ${_filtered.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                const Spacer(),
                // Next
                FilledButton.icon(
                  onPressed: _index < _filtered.length - 1 ? _next : null,
                  icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  label: Text(isAr ? 'التالي' : 'Next'),
                  iconAlignment: IconAlignment.end,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: Colors.grey.shade300,
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

// ── Small reusable widgets ─────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
