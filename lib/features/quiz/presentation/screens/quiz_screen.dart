import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/settings/app_settings_cubit.dart';
import '../../data/models/quiz_question_model.dart';
import '../cubit/quiz_cubit.dart';
import '../cubit/quiz_state.dart';
import 'leaderboard_screen.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> with TickerProviderStateMixin {
  late final QuizCubit _cubit;
  AnimationController? _timerController;
  Timer? _uiTimer;

  @override
  void initState() {
    super.initState();
    _cubit = di.sl<QuizCubit>();
    // Defer load() so the BlocConsumer listener is wired up first,
    // ensuring the QuizLoading → QuizReady transition is caught and
    // _startTimerAnimation() is called correctly.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _cubit.load();
    });
  }

  @override
  void dispose() {
    _timerController?.dispose();
    _uiTimer?.cancel();
    _cubit.close();
    super.dispose();
  }

  void _startTimerAnimation(int totalSeconds) {
    _timerController?.dispose();
    _timerController = AnimationController(
      vsync: this,
      duration: Duration(seconds: totalSeconds),
    );
    _timerController!.forward();

    _uiTimer?.cancel();
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
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

    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isArabic ? 'المسابقة اليومية' : 'Daily Quiz'),
          centerTitle: true,
          flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.emoji_events_rounded),
              tooltip: isArabic ? 'لوحة المتصدرين' : 'Leaderboard',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
                );
              },
            ),
          ],
        ),
        body: BlocConsumer<QuizCubit, QuizState>(
          listener: (context, state) {
            if (state is QuizReady) {
              _startTimerAnimation(state.question.timerSeconds);
            } else if (state is QuizResult ||
                state is QuizTimeUp ||
                state is QuizAlreadyAnswered) {
              _timerController?.stop();
              _uiTimer?.cancel();
            }
          },
          builder: (context, state) {
            if (state is QuizInitial || state is QuizLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is QuizReady) {
              return _buildQuestionView(
                context, state.question, null, state.streak, state.totalScore,
                isArabic: isArabic, isDark: isDark,
              );
            }
            if (state is QuizAnswerSelected) {
              return _buildQuestionView(
                context, state.question, state.selectedIndex, state.streak,
                state.totalScore,
                isArabic: isArabic, isDark: isDark,
              );
            }
            if (state is QuizResult) {
              return _buildResultView(context, state, isArabic: isArabic, isDark: isDark);
            }
            if (state is QuizTimeUp) {
              return _buildTimeUpView(context, state, isArabic: isArabic, isDark: isDark);
            }
            if (state is QuizAlreadyAnswered) {
              return _buildAlreadyAnsweredView(context, state, isArabic: isArabic, isDark: isDark);
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  // ── Question View ───────────────────────────────────────────────────────

  Widget _buildQuestionView(
    BuildContext context,
    QuizQuestion question,
    int? selectedIndex,
    int streak,
    int totalScore, {
    required bool isArabic,
    required bool isDark,
  }) {
    final remaining = _cubit.remainingSeconds;
    final totalTime = question.timerSeconds;
    final progress = totalTime > 0 ? (remaining / totalTime).clamp(0.0, 1.0) : 0.0;
    final optionLabels = isArabic ? ['أ', 'ب', 'ج', 'د'] : ['A', 'B', 'C', 'D'];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // ── Streak badge ──────────────────────────────────────────────────────
        if (streak > 0)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFFED65B),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFED65B).withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_fire_department,
                      color: Colors.deepOrange, size: 16),
                  const SizedBox(width: 5),
                  Text(
                    '$streak ${isArabic ? "أيام" : "days"}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: Color(0xFF574500),
                    ),
                  ),
                ],
              ),
            ),
          ),

        SizedBox(height: streak > 0 ? 20 : 8),

        // ── Timer (left/start) + Difficulty (right/end) ───────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildCircularTimer(remaining, totalTime, progress, isDark, isArabic),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isArabic ? 'الصعوبة' : 'DIFFICULTY',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _difficultyColor(question.difficulty)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _difficultyColor(question.difficulty)
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    isArabic
                        ? question.difficultyLabelAr
                        : question.difficultyLabelEn,
                    style: TextStyle(
                      color: _difficultyColor(question.difficulty),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 28),

        // ── Question card (arch top) ──────────────────────────────────────────
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
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Text(
                  isArabic ? 'السؤال اليومي' : 'Daily Question',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                question.question,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.65,
                  fontFamily: 'Amiri',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isArabic
                    ? '+${question.points} نقطة للإجابة الصحيحة'
                    : '+${question.points} pts for correct answer',
                style: const TextStyle(
                  color: Color(0xFFFED65B),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── Options ──────────────────────────────────────────────────────────
        ...List.generate(question.options.length, (i) {
          final isSelected = selectedIndex == i;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _cubit.selectAnswer(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.secondary
                          : (isDark
                              ? AppColors.darkBorder.withValues(alpha: 0.5)
                              : Colors.grey.withValues(alpha: 0.15)),
                      width: isSelected ? 1.5 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected
                            ? AppColors.secondary.withValues(alpha: 0.18)
                            : Colors.black.withValues(alpha: 0.04),
                        blurRadius: isSelected ? 14 : 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          question.options[i],
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 42,
                        height: 42,
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
                                  color: Colors.white, size: 22)
                              : Text(
                                  optionLabels[i],
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.textSecondary,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),

        const SizedBox(height: 16),

        // ── Submit button ─────────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 58,
          child: ElevatedButton.icon(
            onPressed: selectedIndex != null
                ? () => _cubit.submitAnswer(question.id, selectedIndex)
                : null,
            icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
            label: Text(
              isArabic ? 'إرسال الإجابة' : 'Submit Answer',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor:
                  isDark ? AppColors.darkBorder : AppColors.divider,
              shape: const StadiumBorder(),
              elevation: selectedIndex != null ? 6 : 0,
              shadowColor: AppColors.primary.withValues(alpha: 0.4),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ── Footer ───────────────────────────────────────────────────────────
        Center(
          child: Text(
            isArabic
                ? 'شارك يومياً وتسلق قائمة المتصدرين 🏆'
                : 'Participate daily to climb the rankings 🏆',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textHint,
            ),
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  // ── Circular Timer ──────────────────────────────────────────────────────

  Widget _buildCircularTimer(int remaining, int total, double progress, bool isDark, bool isArabic) {
    final color = remaining <= 5
        ? AppColors.error
        : remaining <= 10
            ? AppColors.warning
            : AppColors.secondary;

    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 5,
              backgroundColor: isDark
                  ? AppColors.darkBorder
                  : Colors.grey.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$remaining',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              Text(
                isArabic ? 'ثانية' : 'sec',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Result View ─────────────────────────────────────────────────────────

  Widget _buildResultView(
    BuildContext context,
    QuizResult state, {
    required bool isArabic,
    required bool isDark,
  }) {
    _timerController?.stop();
    _uiTimer?.cancel();

    final correctColor = AppColors.success;
    final wrongColor = AppColors.error;
    final resultColor = state.isCorrect ? correctColor : wrongColor;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        // Result icon
        Center(
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: resultColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              state.isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: resultColor,
              size: 60,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          state.isCorrect
              ? (isArabic ? 'إجابة صحيحة!' : 'Correct!')
              : (isArabic ? 'إجابة خاطئة' : 'Wrong Answer'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: resultColor,
          ),
        ),
        if (state.isCorrect) ...[
          const SizedBox(height: 8),
          Text(
            isArabic
                ? '+${state.pointsEarned} نقطة'
                : '+${state.pointsEarned} points',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.secondary,
            ),
          ),
        ],

        const SizedBox(height: 24),

        // Question recap
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                state.question.question,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              // Show all options with correct/wrong indicators
              ...List.generate(state.question.options.length, (i) {
                final isCorrectOption = i == state.question.correctIndex;
                final isUserChoice = i == state.selectedIndex;
                Color? bgColor;
                IconData? icon;

                if (isCorrectOption) {
                  bgColor = correctColor.withValues(alpha: 0.1);
                  icon = Icons.check_circle;
                } else if (isUserChoice && !state.isCorrect) {
                  bgColor = wrongColor.withValues(alpha: 0.1);
                  icon = Icons.cancel;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: isCorrectOption
                        ? Border.all(color: correctColor, width: 1.5)
                        : null,
                  ),
                  child: Row(
                    children: [
                      if (icon != null) ...[
                        Icon(icon,
                            color: isCorrectOption ? correctColor : wrongColor,
                            size: 20),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: Text(
                          state.question.options[i],
                          style: TextStyle(
                            fontWeight: isCorrectOption ? FontWeight.w700 : FontWeight.w500,
                            color: isCorrectOption ? correctColor : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              // Explanation
              if (state.question.explanation != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb_outline, color: AppColors.info, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          state.question.explanation!,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Score summary
        _buildScoreSummaryRow(
          isArabic: isArabic,
          isDark: isDark,
          totalScore: state.newTotalScore,
          streak: state.newStreak,
        ),

        const SizedBox(height: 24),

        // Leaderboard button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
              );
            },
            icon: const Icon(Icons.emoji_events_rounded, color: Colors.white),
            label: Text(
              isArabic ? 'لوحة المتصدرين' : 'Leaderboard',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ── Time-up View ────────────────────────────────────────────────────────

  Widget _buildTimeUpView(
    BuildContext context,
    QuizTimeUp state, {
    required bool isArabic,
    required bool isDark,
  }) {
    _timerController?.stop();
    _uiTimer?.cancel();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.timer_off_rounded,
                  color: AppColors.warning, size: 60),
            ),
            const SizedBox(height: 24),
            Text(
              isArabic ? 'انتهى الوقت!' : 'Time\'s Up!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isArabic
                  ? 'الإجابة الصحيحة: ${state.question.options[state.question.correctIndex]}'
                  : 'Correct answer: ${state.question.options[state.question.correctIndex]}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.success,
              ),
            ),
            if (state.question.explanation != null) ...[
              const SizedBox(height: 16),
              Text(
                state.question.explanation!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
                ),
                icon: const Icon(Icons.emoji_events_rounded, color: Colors.white),
                label: Text(
                  isArabic ? 'لوحة المتصدرين' : 'Leaderboard',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Already Answered View ───────────────────────────────────────────────

  Widget _buildAlreadyAnsweredView(
    BuildContext context,
    QuizAlreadyAnswered state, {
    required bool isArabic,
    required bool isDark,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                state.lastAnswerCorrect == true
                    ? Icons.check_circle_rounded
                    : Icons.quiz_rounded,
                color: AppColors.primary,
                size: 60,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isArabic ? 'لقد أجبت على سؤال اليوم' : "You've answered today's question",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isArabic
                  ? 'عُد غداً لسؤال جديد!'
                  : 'Come back tomorrow for a new question!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 32),

            // Stats
            _buildScoreSummaryRow(
              isArabic: isArabic,
              isDark: isDark,
              totalScore: state.totalScore,
              streak: state.streak,
            ),

            const SizedBox(height: 12),

            // Accuracy
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statItem(
                    isArabic ? 'الإجابات' : 'Answered',
                    '${state.totalAnswered}',
                    isDark,
                  ),
                  _statItem(
                    isArabic ? 'صحيحة' : 'Correct',
                    '${state.correctAnswers}',
                    isDark,
                  ),
                  _statItem(
                    isArabic ? 'الدقة' : 'Accuracy',
                    '${(state.totalAnswered > 0 ? (state.correctAnswers / state.totalAnswered * 100).round() : 0)}%',
                    isDark,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
                ),
                icon: const Icon(Icons.emoji_events_rounded, color: Colors.white),
                label: Text(
                  isArabic ? 'لوحة المتصدرين' : 'Leaderboard',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  Widget _buildScoreSummaryRow({
    required bool isArabic,
    required bool isDark,
    required int totalScore,
    required int streak,
  }) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Icon(Icons.stars_rounded, color: AppColors.secondary, size: 28),
                const SizedBox(height: 6),
                Text(
                  '$totalScore',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  isArabic ? 'مجموع النقاط' : 'Total Score',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                const Icon(Icons.local_fire_department, color: Colors.orange, size: 28),
                const SizedBox(height: 6),
                Text(
                  '$streak',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.orange,
                  ),
                ),
                Text(
                  isArabic ? 'أيام متواصلة' : 'Day Streak',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _statItem(String label, String value, bool isDark) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Color _difficultyColor(QuizDifficulty d) {
    switch (d) {
      case QuizDifficulty.easy:
        return AppColors.success;
      case QuizDifficulty.medium:
        return AppColors.warning;
      case QuizDifficulty.hard:
        return AppColors.error;
    }
  }
}
