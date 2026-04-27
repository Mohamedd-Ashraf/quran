import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/settings/app_settings_cubit.dart';
import '../../data/models/practice_question.dart';
import '../cubit/practice_cubit.dart';
import '../cubit/practice_state.dart';
import '../widgets/report_question_sheet.dart';

class PracticeQuizScreen extends StatefulWidget {
  final String? category;
  final String? difficulty;
  final bool timerEnabled;
  final int timerSeconds;

  const PracticeQuizScreen({
    super.key,
    required this.category,
    required this.difficulty,
    this.timerEnabled = false,
    this.timerSeconds = 15,
  });

  @override
  State<PracticeQuizScreen> createState() => _PracticeQuizScreenState();
}

class _PracticeQuizScreenState extends State<PracticeQuizScreen>
    with TickerProviderStateMixin {
  // ── Timer ──────────────────────────────────────────────────────────────────
  AnimationController? _timerController;
  int _timerQuestionIndex = -1;

  // ── Option tap scale animations (one per option, max 4) ───────────────────
  final List<AnimationController> _tapControllers = [];
  final List<Animation<double>> _tapAnimations = [];

  // ── Motivation overlay ─────────────────────────────────────────────────────
  bool _showMotivation = false;
  String _motivationText = '';

  // ── Confetti (finish screen) ───────────────────────────────────────────────
  late final ConfettiController _confettiController;
  bool _confettiFired = false;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    // Pre-build 4 tap controllers
    for (var i = 0; i < 4; i++) {
      final ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 120),
      );
      final anim = Tween<double>(begin: 1.0, end: 0.93).animate(
        CurvedAnimation(parent: ctrl, curve: Curves.easeIn),
      );
      _tapControllers.add(ctrl);
      _tapAnimations.add(anim);
    }
  }

  @override
  void dispose() {
    _timerController?.dispose();
    for (final c in _tapControllers) {
      c.dispose();
    }
    _confettiController.dispose();
    super.dispose();
  }

  // ── Timer helpers ──────────────────────────────────────────────────────────

  void _startTimer(int questionIndex) {
    if (!widget.timerEnabled) return;
    if (_timerQuestionIndex == questionIndex) return;
    _timerQuestionIndex = questionIndex;

    _timerController?.dispose();
    _timerController = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.timerSeconds),
    )
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          context.read<PracticeCubit>().timerExpired();
        }
      })
      ..forward();
  }

  void _stopTimer() => _timerController?.stop();

  // ── Option tap animation ───────────────────────────────────────────────────

  Future<void> _animateTap(int index, VoidCallback onDone) async {
    if (index >= _tapControllers.length) {
      onDone();
      return;
    }
    await _tapControllers[index].forward();
    await _tapControllers[index].reverse();
    onDone();
  }

  // ── Motivation overlay ─────────────────────────────────────────────────────

  void _maybeShowMotivation(int streak) {
    if (streak == 0) return;

    String? msg;
    if (streak == 3) msg = '🔥 ثلاثة صح متتالية!';
    if (streak == 5) msg = '⭐ خمسة صح! رائع!';
    if (streak == 10) msg = '🏆 عشرة صح! أنت نجم!';
    if (streak > 10 && streak % 5 == 0) msg = '🚀 $streak متتالي! لا يُصدَّق!';
    if (msg == null) return;

    setState(() {
      _motivationText = msg!;
      _showMotivation = true;
    });

    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _showMotivation = false);
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

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
        title: Text(isArabic ? 'وضع التمرين' : 'Practice Mode'),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.primaryGradient,
          ),
        ),
      ),
      body: BlocConsumer<PracticeCubit, PracticeState>(
        listener: (context, state) {
          if (state is PracticeReady) {
            if (!state.answered) {
              _startTimer(state.currentIndex);
            } else {
              _stopTimer();
              if (state.streak > 0) _maybeShowMotivation(state.streak);
            }
          }
          if (state is PracticeFinished && !_confettiFired) {
            _confettiFired = true;
            _confettiController.play();
          }
        },
        builder: (context, state) {
          Widget body;

          if (state is PracticeInitial || state is PracticeLoading) {
            body = const Center(child: CircularProgressIndicator());
          } else if (state is PracticeEmpty) {
            body = _buildEmpty(context, isArabic: isArabic, isDark: isDark);
          } else if (state is PracticeError) {
            body = _buildError(context, state.message,
                isArabic: isArabic, isDark: isDark);
          } else if (state is PracticeNeedsMore) {
            body = _buildNeedsMore(context, state,
                isArabic: isArabic, isDark: isDark);
          } else if (state is PracticeFinished) {
            body = _buildFinished(context, state,
                isArabic: isArabic, isDark: isDark);
          } else if (state is PracticeDownloading) {
            body = const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('جارٍ تحميل المزيد من الأسئلة...'),
                ],
              ),
            );
          } else if (state is PracticeReady) {
            body = _buildQuestion(context, state,
                isArabic: isArabic, isDark: isDark);
          } else {
            body = const SizedBox.shrink();
          }

          return Stack(
            alignment: Alignment.topCenter,
            children: [
              body,
              // Motivation overlay
              if (_showMotivation)
                Positioned(
                  top: 24,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: AnimatedOpacity(
                      opacity: _showMotivation ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.secondary.withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          _motivationText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              // Confetti
              ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                numberOfParticles: 30,
                gravity: 0.2,
                emissionFrequency: 0.05,
                colors: const [
                  AppColors.primary,
                  AppColors.secondary,
                  AppColors.success,
                  AppColors.warning,
                  Colors.white,
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Question view ──────────────────────────────────────────────────────────

  Widget _buildQuestion(
    BuildContext context,
    PracticeReady state, {
    required bool isArabic,
    required bool isDark,
  }) {
    final cubit = context.read<PracticeCubit>();
    final q = state.currentQuestion;
    final optionLabels =
        isArabic ? ['أ', 'ب', 'ج', 'د'] : ['A', 'B', 'C', 'D'];
    final total = state.questions.length;
    final current = state.currentIndex + 1;
    final progress = current / total;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 130),
          children: [
            // ── Progress bar (question X/N) ─────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: isDark
                          ? AppColors.darkBorder
                          : Colors.grey.withValues(alpha: 0.15),
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.secondary),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Circular timer OR simple counter
                if (widget.timerEnabled &&
                    !state.answered &&
                    _timerController != null)
                  AnimatedBuilder(
                    animation: _timerController!,
                    builder: (context, child) {
                      final remaining = 1.0 - _timerController!.value;
                      final secs =
                          (remaining * widget.timerSeconds).ceil();
                      final timerColor = remaining > 0.5
                          ? AppColors.success
                          : remaining > 0.25
                              ? AppColors.warning
                              : AppColors.error;
                      return SizedBox(
                        width: 44,
                        height: 44,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(
                              size: const Size(44, 44),
                              painter: _CircularTimerPainter(
                                progress: remaining,
                                color: timerColor,
                                bgColor: isDark
                                    ? AppColors.darkBorder
                                    : Colors.grey.withValues(alpha: 0.2),
                              ),
                            ),
                            Text(
                              '$secs',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: timerColor,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                else
                  Text(
                    '$current / $total',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 8),

            // ── Badges row + streak + report ──────────────────────────────────
            Row(
              children: [
                _badge(
                  label: _categoryLabel(q.category.value, isArabic),
                  color: AppColors.primary,
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _badge(
                  label: isArabic ? q.difficulty.labelAr : q.difficulty.value,
                  color: _difficultyColor(q.difficulty.value),
                  isDark: isDark,
                ),
                if (state.streak >= 2) ...[
                  const SizedBox(width: 8),
                  _badge(
                    label: '🔥 ${state.streak}',
                    color: AppColors.warning,
                    isDark: isDark,
                  ),
                ],
                const Spacer(),
                // Score badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_outline,
                          size: 14, color: AppColors.secondary),
                      const SizedBox(width: 4),
                      Text(
                        '${state.correct}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Report button
                GestureDetector(
                  onTap: () => ReportQuestionSheet.show(
                    context,
                    questionId: q.id,
                    questionSnippet: q.question.length > 80
                        ? '${q.question.substring(0, 80)}…'
                        : q.question,
                    questionText: q.question,
                  ),
                  child: Icon(
                    Icons.flag_outlined,
                    size: 20,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Question card ─────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(48),
                  topRight: Radius.circular(48),
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
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
                  height: 1.7,
                  fontFamily: 'Amiri',
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Time's up banner ──────────────────────────────────────────────
            if (state.answered && state.selectedIndex == -1)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    isArabic ? '⏰ انتهى الوقت!' : '⏰ Time\'s up!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),

            // ── Options ───────────────────────────────────────────────────────
            ...List.generate(q.options.length, (i) {
              final isSelected = state.selectedIndex == i;
              final isCorrect = i == q.correctIndex;
              Color? borderColor;
              Color? bgColor;
              Widget? trailingIcon;

              if (state.answered) {
                if (isCorrect) {
                  borderColor = AppColors.success;
                  bgColor = AppColors.success.withValues(alpha: 0.08);
                  trailingIcon = const Icon(Icons.check_circle,
                      color: AppColors.success, size: 20);
                } else if (isSelected && !isCorrect) {
                  borderColor = AppColors.error;
                  bgColor = AppColors.error.withValues(alpha: 0.08);
                  trailingIcon = const Icon(Icons.cancel,
                      color: AppColors.error, size: 20);
                }
              } else if (isSelected) {
                borderColor = AppColors.secondary;
              }

              final optionTile = AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color:
                      bgColor ?? (isDark ? AppColors.darkCard : Colors.white),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: borderColor ??
                        (isDark
                            ? AppColors.darkBorder.withValues(alpha: 0.5)
                            : Colors.grey.withValues(alpha: 0.15)),
                    width: borderColor != null ? 1.5 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (borderColor ?? Colors.black)
                          .withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        q.options[i],
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                              isSelected || (state.answered && isCorrect)
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    trailingIcon ??
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.secondary
                                : (isDark
                                    ? AppColors.darkBorder
                                    : const Color(0xFFF3F4F5)),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: isSelected
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 18)
                                : Text(
                                    optionLabels[i],
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                          ),
                        ),
                  ],
                ),
              );

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: i < _tapAnimations.length
                    ? ScaleTransition(
                        scale: _tapAnimations[i],
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: state.answered
                                ? null
                                : () => _animateTap(i, () {
                                      if (mounted && !state.answered) {
                                        cubit.selectAnswer(i);
                                      }
                                    }),
                            child: optionTile,
                          ),
                        ),
                      )
                    : Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: state.answered
                              ? null
                              : () => cubit.selectAnswer(i),
                          child: optionTile,
                        ),
                      ),
              );
            }),
          ],
        ),

        // ── Sticky bottom button ───────────────────────────────────────────────
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkBackground.withValues(alpha: 0.95)
                  : Colors.white.withValues(alpha: 0.95),
            ),
            child: state.answered
                ? SizedBox(
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: () => cubit.nextQuestion(),
                      icon: Icon(
                        state.isLastQuestion
                            ? Icons.emoji_events_rounded
                            : Icons.arrow_forward_rounded,
                        color: Colors.white,
                      ),
                      label: Text(
                        state.isLastQuestion
                            ? (isArabic ? 'عرض النتائج' : 'Show Results')
                            : (isArabic ? 'السؤال التالي' : 'Next Question'),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: state.isLastQuestion
                            ? AppColors.success
                            : AppColors.primary,
                        shape: const StadiumBorder(),
                        elevation: 6,
                      ),
                    ),
                  )
                : SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: state.selectedIndex != null
                          ? () => cubit.confirmAnswer()
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: state.selectedIndex != null
                            ? AppColors.primary
                            : Colors.grey.shade400,
                        shape: const StadiumBorder(),
                        elevation: state.selectedIndex != null ? 8 : 2,
                      ),
                      child: Text(
                        isArabic ? 'تأكيد الإجابة' : 'Confirm Answer',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  // ── Needs more ─────────────────────────────────────────────────────────────

  Widget _buildNeedsMore(
    BuildContext context,
    PracticeNeedsMore state, {
    required bool isArabic,
    required bool isDark,
  }) {
    final cubit = context.read<PracticeCubit>();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_download_rounded,
                  size: 56, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text(
              isArabic
                  ? 'لقد انتهت الأسئلة، يمكنك تحميل المزيد'
                  : 'No more questions. You can download more.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, height: 1.5),
            ),
            const SizedBox(height: 8),
            Text(
              isArabic
                  ? 'أجبت على ${state.correct} من ${state.total} سؤال بشكل صحيح'
                  : '${state.correct} / ${state.total} correct',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            _loadMoreButton(cubit, isArabic: isArabic, limit: 50),
            const SizedBox(height: 12),
            _loadMoreButton(cubit, isArabic: isArabic, limit: 100),
            const SizedBox(height: 12),
            _loadMoreButton(cubit, isArabic: isArabic, limit: 150),
          ],
        ),
      ),
    );
  }

  Widget _loadMoreButton(PracticeCubit cubit,
      {required bool isArabic, required int limit}) {
    final label =
        isArabic ? 'تحميل $limit سؤالاً' : 'Download $limit Questions';
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => cubit.downloadMore(limit: limit),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: Text(label,
            style:
                const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      ),
    );
  }

  // ── Finished ───────────────────────────────────────────────────────────────

  Widget _buildFinished(
    BuildContext context,
    PracticeFinished state, {
    required bool isArabic,
    required bool isDark,
  }) {
    final pct =
        state.total > 0 ? (state.correct / state.total * 100).round() : 0;
    final color = pct >= 80
        ? AppColors.success
        : pct >= 50
            ? AppColors.warning
            : AppColors.error;

    final motivationMsg = pct >= 80
        ? (isArabic ? 'ممتاز! استمر هكذا 🌟' : 'Excellent! Keep it up 🌟')
        : pct >= 50
            ? (isArabic
                ? 'جيد! يمكنك تحسين أكثر 💪'
                : 'Good! You can improve 💪')
            : (isArabic
                ? 'حاول مجدداً — المراجعة تصنع الفرق 📚'
                : 'Try again — review makes the difference 📚');

    final medal = pct >= 80 ? '🥇' : pct >= 50 ? '🥈' : '🥉';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Medal + score circle
            Stack(
              alignment: Alignment.topRight,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: color.withValues(alpha: 0.5), width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '$pct%',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                  ),
                ),
                Text(medal, style: const TextStyle(fontSize: 28)),
              ],
            ),

            const SizedBox(height: 16),
            Text(
              isArabic ? 'أحسنت! انتهت الجلسة' : 'Session Complete!',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              motivationMsg,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 24),

            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _statTile(
                  icon: Icons.check_circle_rounded,
                  color: AppColors.success,
                  value: '${state.correct}/${state.total}',
                  label: isArabic ? 'صحيح' : 'Correct',
                  isDark: isDark,
                ),
                _statTile(
                  icon: Icons.local_fire_department_rounded,
                  color: AppColors.warning,
                  value: '${state.bestStreak}',
                  label: isArabic ? 'أفضل سلسلة' : 'Best Streak',
                  isDark: isDark,
                ),
                _statTile(
                  icon: Icons.star_rounded,
                  color: Colors.amber,
                  value: '+${state.xpEarned}',
                  label: 'XP',
                  isDark: isDark,
                ),
              ],
            ),

            if (state.totalXp > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt_rounded,
                        color: Colors.amber, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      isArabic
                          ? 'إجمالي نقاطك: ${state.totalXp} XP'
                          : 'Total XP: ${state.totalXp}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.amber,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // ── Wrong-answer review ───────────────────────────────────────
            if (state.wrongAnswers.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  isArabic ? 'مراجعة الأخطاء' : 'Wrong Answers Review',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...state.wrongAnswers.map((entry) {
                final q = entry.question;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.25)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        q.question,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Amiri',
                          height: 1.6,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Show all options, highlight correct (green) and chosen wrong (red)
                      ...List.generate(q.options.length, (i) {
                        final isCorrect = i == q.correctIndex;
                        final isChosen = i == entry.chosenIndex;
                        final bg = isCorrect
                            ? AppColors.success.withValues(alpha: 0.12)
                            : (isChosen && !isCorrect)
                                ? AppColors.error.withValues(alpha: 0.1)
                                : Colors.transparent;
                        final border = isCorrect
                            ? AppColors.success.withValues(alpha: 0.5)
                            : (isChosen && !isCorrect)
                                ? AppColors.error.withValues(alpha: 0.4)
                                : (isDark
                                    ? AppColors.darkBorder.withValues(alpha: 0.3)
                                    : Colors.grey.withValues(alpha: 0.2));
                        final textColor = isCorrect
                            ? AppColors.success
                            : (isChosen && !isCorrect)
                                ? AppColors.error
                                : (isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.textSecondary);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: border),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isCorrect
                                    ? Icons.check_circle_rounded
                                    : (isChosen && !isCorrect)
                                        ? Icons.cancel_rounded
                                        : Icons.circle_outlined,
                                size: 16,
                                color: textColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  q.options[i],
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontFamily: 'Amiri',
                                    fontWeight: isCorrect
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: textColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
            ],

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.home_rounded, color: Colors.white),
                label: Text(
                  isArabic ? 'العودة للرئيسية' : 'Back to Home',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statTile({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
    required bool isDark,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );

  // ── Empty ──────────────────────────────────────────────────────────────────

  Widget _buildEmpty(
    BuildContext context, {
    required bool isArabic,
    required bool isDark,
  }) {
    final cubit = context.read<PracticeCubit>();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_download_outlined,
                size: 72,
                color: isDark ? Colors.white38 : AppColors.primary.withValues(alpha: 0.4)),
            const SizedBox(height: 20),
            Text(
              isArabic
                  ? 'لا توجد أسئلة متاحة'
                  : 'No questions available',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.textPrimary),
            ),
            const SizedBox(height: 10),
            Text(
              isArabic
                  ? 'تأكد من اتصالك بالإنترنت ثم حاول التحميل مجدداً'
                  : 'Check your internet connection and try downloading again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: isDark ? Colors.white54 : AppColors.textSecondary),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () => cubit.startSession(
                category: widget.category,
                difficulty: widget.difficulty,
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(isArabic ? 'إعادة المحاولة' : 'Retry',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 14)),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(isArabic ? 'رجوع' : 'Go Back',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Error ──────────────────────────────────────────────────────────────────

  Widget _buildError(
    BuildContext context,
    String message, {
    required bool isArabic,
    required bool isDark,
  }) {
    final cubit = context.read<PracticeCubit>();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 60, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => cubit.startSession(
                  category: widget.category, difficulty: widget.difficulty),
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: Text(isArabic ? 'إعادة المحاولة' : 'Retry',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _badge({
    required String label,
    required Color color,
    required bool isDark,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      );

  Color _difficultyColor(String d) {
    switch (d) {
      case 'easy':
        return AppColors.success;
      case 'medium':
        return AppColors.warning;
      case 'hard':
        return AppColors.error;
      case 'expert':
        return const Color(0xFF7B2FBE);
      default:
        return AppColors.primary;
    }
  }

  String _categoryLabel(String cat, bool isArabic) {
    if (!isArabic) return cat;
    switch (cat) {
      case 'quran':
        return 'القرآن';
      case 'hadith':
        return 'الحديث';
      case 'fiqh':
        return 'الفقه';
      case 'seerah':
        return 'السيرة';
      default:
        return cat;
    }
  }
}

// ── Circular timer painter ─────────────────────────────────────────────────

class _CircularTimerPainter extends CustomPainter {
  final double progress; // 1.0 = full, 0.0 = empty
  final Color color;
  final Color bgColor;

  const _CircularTimerPainter({
    required this.progress,
    required this.color,
    required this.bgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 3;
    const startAngle = -math.pi / 2;

    // Background arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      2 * math.pi,
      false,
      Paint()
        ..color = bgColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );

    // Progress arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_CircularTimerPainter old) =>
      old.progress != progress || old.color != color;
}
