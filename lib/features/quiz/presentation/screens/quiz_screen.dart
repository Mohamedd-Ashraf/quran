import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/settings/app_settings_cubit.dart';
import '../../../../core/utils/number_style_utils.dart';
import '../../../../core/utils/utf16_sanitizer.dart';
import '../../data/quiz_repository.dart';
import '../../data/models/quiz_question_model.dart';
import '../cubit/quiz_cubit.dart';
import '../cubit/quiz_state.dart';
import 'leaderboard_screen.dart';
import 'quiz_admin_preview_screen.dart';

class QuizScreen extends StatefulWidget {
  /// When `true`, the landing screen is shown before the timer starts.
  /// Set this only when opening the quiz from a notification tap.
  /// Navigating from within the app should use `fromNotification: false`
  /// (the default) to skip the landing screen and go straight to the question.
  final bool fromNotification;

  const QuizScreen({super.key, this.fromNotification = false});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> with TickerProviderStateMixin {
  late final QuizCubit _cubit;
  late final QuizRepository _quizRepository;
  AnimationController? _timerController;
  Timer? _uiTimer;
  Timer? _visibilityUiTimer;
  bool? _isAnonymous;
  DateTime? _lastVisibilityToggleAt;
  bool _isUpdatingVisibility = false;

  @override
  void initState() {
    super.initState();
    _cubit = di.sl<QuizCubit>();
    _quizRepository = di.sl<QuizRepository>();
    // Defer load() so the BlocConsumer listener is wired up first,
    // ensuring the QuizLoading → QuizReady transition is caught and
    // _startTimerAnimation() is called correctly.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _cubit.load(skipLanding: !widget.fromNotification);
      _loadVisibilityPreference();
    });
  }

  @override
  void dispose() {
    _timerController?.dispose();
    _uiTimer?.cancel();
    _visibilityUiTimer?.cancel();
    _cubit.close();
    super.dispose();
  }

  Future<void> _loadVisibilityPreference() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;

    final pref = await _quizRepository.getLeaderboardVisibilityPreference(
      uid: user.uid,
    );
    if (!mounted) return;
    setState(() {
      _isAnonymous = pref.isAnonymous;
      _lastVisibilityToggleAt = pref.lastToggleAt?.toUtc();
    });
    _ensureVisibilityTicker();
  }

  bool _visibilityLocked() {
    final last = _lastVisibilityToggleAt;
    if (last == null) return false;
    final until = last.add(const Duration(seconds: 20));
    return until.isAfter(DateTime.now().toUtc());
  }

  int _visibilityRemainingSeconds() {
    final last = _lastVisibilityToggleAt;
    if (last == null) return 0;
    final until = last.add(const Duration(seconds: 20));
    final remaining = until.difference(DateTime.now().toUtc()).inSeconds;
    return remaining.clamp(0, 20);
  }

  void _ensureVisibilityTicker() {
    _visibilityUiTimer?.cancel();
    if (!_visibilityLocked()) return;
    _visibilityUiTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (!_visibilityLocked()) {
        timer.cancel();
      }
      setState(() {});
    });
  }

  Future<void> _toggleVisibility(bool value, {required bool isArabic}) async {
    if (_isUpdatingVisibility) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;

    if (_visibilityLocked()) {
      final seconds = _visibilityRemainingSeconds();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'انتظر ${_localizeInt(seconds, isArabic: true)} ثانية قبل التبديل مرة أخرى.'
                : 'Please wait $seconds seconds before switching again.',
          ),
        ),
      );
      return;
    }

    setState(() => _isUpdatingVisibility = true);
    try {
      await _quizRepository.updateLeaderboardVisibilityPreference(
        uid: user.uid,
        isAnonymous: value,
      );
      if (!mounted) return;
      setState(() {
        _isAnonymous = value;
        _lastVisibilityToggleAt = DateTime.now().toUtc();
      });
      _ensureVisibilityTicker();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'تم التحديث فوراً. يمكنك التبديل مرة أخرى بعد ٢٠ ثانية.'
                : 'Updated instantly. You can toggle again in 20 seconds.',
          ),
        ),
      );
    } on LeaderboardVisibilityCooldownException catch (e) {
      if (!mounted) return;
      final seconds = e.remaining.inSeconds.clamp(1, 999);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'انتظر ${_localizeInt(seconds, isArabic: true)} ثانية قبل التبديل مرة أخرى.'
                : 'Please wait $seconds seconds before switching again.',
          ),
        ),
      );
      await _loadVisibilityPreference();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'تعذر حفظ الإعداد الآن. حاول مرة أخرى.'
                : 'Could not save setting now. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isUpdatingVisibility = false);
    }
  }

  Widget _buildInlineVisibilityTile({
    required bool isArabic,
    required bool isDark,
  }) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return const SizedBox.shrink();

    final value = _isAnonymous ?? false;

    final locked = _visibilityLocked();
    final remaining = _visibilityRemainingSeconds();

    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: (locked || _isUpdatingVisibility)
            ? null
            : (v) => _toggleVisibility(v, isArabic: isArabic),
        activeThumbColor: AppColors.primary,
        isThreeLine: true,
        title: Text(
          isArabic
              ? 'إخفاء اسمي في لوحة الصدارة'
              : 'Hide my name on leaderboard',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          isArabic
              ? (locked
                    ? 'عند التفعيل سيظهر اسمك كمستخدم مجهول. متاح التبديل بعد ${_localizeInt(remaining, isArabic: true)} ثانية.'
                    : 'عند التفعيل سيظهر اسمك كمستخدم مجهول')
              : (locked
                    ? 'When enabled, your name appears as an anonymous user. Toggle available again in $remaining seconds.'
                    : 'When enabled, your name appears as an anonymous user.'),
          style: TextStyle(
            fontSize: 12,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
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

  String _localizeInt(int value, {required bool isArabic}) {
    return localizeNumber(value, isArabic: isArabic);
  }

  String _localizeTextDigits(String text, {required bool isArabic}) {
    return localizeDigits(text, isArabic: isArabic);
  }

  Widget _digitAwareText({
    required String text,
    required TextStyle style,
    required bool isArabic,
    TextAlign textAlign = TextAlign.start,
    TextDirection? textDirection,
    int? maxLines,
    TextOverflow overflow = TextOverflow.clip,
  }) {
    final safeText = sanitizeUtf16(text);
    if (!isArabic) {
      return Text(
        safeText,
        style: style,
        textAlign: textAlign,
        textDirection: textDirection,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    return buildRichTextWithAmiriDigits(
      text: safeText,
      baseStyle: style,
      amiriStyle: amiriDigitTextStyle(
        style,
        fontWeight: style.fontWeight ?? FontWeight.w700,
        height: style.height,
      ),
      textAlign: textAlign,
      textDirection: textDirection,
      maxLines: maxLines,
      overflow: overflow,
    );
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
          title: Text(isArabic ? 'التحدي اليومي' : 'Daily Challenge'),
          centerTitle: true,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
            ),
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
              onLongPress: () {
                QuizAdminPreviewScreen.isAdmin().then((isAdmin) {
                  if (!context.mounted || !isAdmin) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const QuizAdminPreviewScreen(),
                    ),
                  );
                });
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
            } else if (state is QuizOfflineUnavailable) {
              _timerController?.stop();
              _uiTimer?.cancel();
            } else if (state is QuizSubmitError) {
              _startTimerAnimation(state.question.timerSeconds);
              final isAr = context
                  .read<AppSettingsCubit>()
                  .state
                  .appLanguageCode
                  .toLowerCase()
                  .startsWith('ar');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isAr
                        ? 'تعذر حفظ إجابتك. تحقق من اتصالك وحاول مجدداً.'
                        : 'Could not save your answer. Check your connection and try again.',
                  ),
                  backgroundColor: Colors.red.shade700,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          },
          builder: (context, state) {
            if (state is QuizInitial || state is QuizLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is QuizReadyToStart) {
              return _buildLandingView(
                context,
                state,
                isArabic: isArabic,
                isDark: isDark,
              );
            }
            if (state is QuizOfflineUnavailable) {
              return _buildOfflineUnavailableView(
                context,
                state,
                isArabic: isArabic,
                isDark: isDark,
              );
            }

            final question = _getQuestionFromState(state);
            if (question == null) {
              if (state is QuizResult) {
                return _buildResultView(
                  context,
                  state,
                  isArabic: isArabic,
                  isDark: isDark,
                );
              }
              if (state is QuizTimeUp) {
                return _buildTimeUpView(
                  context,
                  state,
                  isArabic: isArabic,
                  isDark: isDark,
                );
              }
              if (state is QuizAlreadyAnswered) {
                return _buildAlreadyAnsweredView(
                  context,
                  state,
                  isArabic: isArabic,
                  isDark: isDark,
                );
              }
              return const SizedBox.shrink();
            }

            int? selectedIndex;
            if (state is QuizReady) {
              selectedIndex = null;
            } else if (state is QuizAnswerSelected) {
              selectedIndex = state.selectedIndex;
            } else if (state is QuizSubmitError) {
              selectedIndex = state.selectedIndex;
            }

            return _buildQuestionView(
              context,
              question,
              selectedIndex,
              _getStreakFromState(state),
              _getScoreFromState(state),
              isArabic: isArabic,
              isDark: isDark,
            );
          },
        ),
        floatingActionButton: BlocBuilder<QuizCubit, QuizState>(
          builder: (context, state) => _buildStickySubmitButton(context, state),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  QuizQuestion? _getQuestionFromState(QuizState state) {
    if (state is QuizReady) return state.question;
    if (state is QuizAnswerSelected) return state.question;
    if (state is QuizSubmitError) return state.question;
    return null;
  }

  int _getStreakFromState(QuizState state) {
    if (state is QuizReady) return state.streak;
    if (state is QuizAnswerSelected) return state.streak;
    if (state is QuizResult) return state.newStreak;
    if (state is QuizTimeUp) return state.streak;
    return 0;
  }

  int _getScoreFromState(QuizState state) {
    if (state is QuizReady) return state.totalScore;
    if (state is QuizAnswerSelected) return state.totalScore;
    if (state is QuizResult) return state.newTotalScore;
    if (state is QuizTimeUp) return state.totalScore;
    return 0;
  }

  Widget _buildStickySubmitButton(BuildContext context, QuizState state) {
    int? selectedIndex;

    if (state is QuizReady) {
      selectedIndex = null;
    } else if (state is QuizAnswerSelected) {
      selectedIndex = state.selectedIndex;
    } else if (state is QuizSubmitError) {
      selectedIndex = state.selectedIndex;
    } else {
      return const SizedBox.shrink();
    }

    final isArabic = context
        .watch<AppSettingsCubit>()
        .state
        .appLanguageCode
        .toLowerCase()
        .startsWith('ar');

    return SizedBox(
      width: MediaQuery.of(context).size.width - 32,
      height: 56,
      child: FloatingActionButton.extended(
        onPressed: selectedIndex != null
            ? () {
                final question = _getQuestionFromState(state);
                if (question != null && selectedIndex != null) {
                  _cubit.submitAnswer(question.id, selectedIndex);
                }
              }
            : null,
        backgroundColor: selectedIndex != null
            ? AppColors.primary
            : Colors.grey.shade400,
        elevation: selectedIndex != null ? 8 : 2,
        focusElevation: selectedIndex != null ? 12 : 4,
        heroTag: 'quizSubmit',
        label: Text(
          isArabic ? 'إرسال الإجابة' : 'Submit Answer',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildOfflineUnavailableView(
    BuildContext context,
    QuizOfflineUnavailable state, {
    required bool isArabic,
    required bool isDark,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 72,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            const SizedBox(height: 16),
            Text(
              isArabic
                  ? 'لا يمكن فتح سؤال اليوم بدون اتصال.'
                  : 'Today\'s question needs an internet connection.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              state.message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Landing View (shown before the timer starts) ──────────────────────────

  Widget _buildLandingView(
    BuildContext context,
    QuizReadyToStart state, {
    required bool isArabic,
    required bool isDark,
  }) {
    final diffColor = _difficultyColor(state.question.difficulty);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Icon ────────────────────────────────────────────────────────
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.quiz_rounded,
                color: Colors.white,
                size: 44,
              ),
            ),

            const SizedBox(height: 28),

            // ── Title ────────────────────────────────────────────────────────
            Text(
              isArabic ? 'سؤال اليوم جاهز!' : "Today's Question is Ready!",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            ),

            const SizedBox(height: 10),

            Text(
              isArabic
                  ? 'الوقت يبدأ فقط لما تضغط ابدأ'
                  : 'Timer starts only when you tap Start',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 32),

            // ── Stats row ────────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _landingStat(
                  icon: Icons.local_fire_department,
                  iconColor: Colors.deepOrange,
                  label: isArabic ? 'السلسلة' : 'Streak',
                  value: _localizeInt(state.streak, isArabic: isArabic),
                  isArabic: isArabic,
                  isDark: isDark,
                ),
                const SizedBox(width: 16),
                _landingStat(
                  icon: Icons.star_rounded,
                  iconColor: const Color(0xFFFFC107),
                  label: isArabic ? 'نقاطك' : 'Your Score',
                  value: _localizeInt(state.totalScore, isArabic: isArabic),
                  isArabic: isArabic,
                  isDark: isDark,
                ),
                const SizedBox(width: 16),
                _landingStat(
                  icon: Icons.timer_rounded,
                  iconColor: AppColors.primary,
                  label: isArabic ? 'الوقت' : 'Time',
                  value: _localizeTextDigits(
                    '${state.question.timerSeconds}s',
                    isArabic: isArabic,
                  ),
                  isArabic: isArabic,
                  isDark: isDark,
                ),
              ],
            ),

            const SizedBox(height: 28),

            // ── Difficulty / Points badges ───────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: diffColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: diffColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    isArabic
                        ? state.question.difficultyLabelAr
                        : state.question.difficultyLabelEn,
                    style: TextStyle(
                      color: diffColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.secondary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: _digitAwareText(
                    text: isArabic
                        ? '+${_localizeInt(state.question.points, isArabic: true)} نقطة'
                        : '+${state.question.points} pts',
                    style: const TextStyle(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    isArabic: isArabic,
                    textAlign: TextAlign.center,
                    textDirection: isArabic
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),

            // ── Start button ─────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: () => _cubit.startQuiz(),
                icon: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                label: Text(
                  isArabic ? 'ابدأ التحدي' : 'Start Challenge',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: const StadiumBorder(),
                  elevation: 8,
                  shadowColor: AppColors.primary.withValues(alpha: 0.45),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _landingStat({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required bool isArabic,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 6),
          _digitAwareText(
            text: value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            isArabic: isArabic,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
            ),
          ),
        ],
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
    final progress = totalTime > 0
        ? (remaining / totalTime).clamp(0.0, 1.0)
        : 0.0;
    final optionLabels = isArabic ? ['أ', 'ب', 'ج', 'د'] : ['A', 'B', 'C', 'D'];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 90),
      children: [
        // ── Streak badge ──────────────────────────────────────────────────────
        if (streak > 0)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFED65B),
                borderRadius: BorderRadius.circular(16),
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
                  const Icon(
                    Icons.local_fire_department,
                    color: Colors.deepOrange,
                    size: 16,
                  ),
                  const SizedBox(width: 5),
                  _digitAwareText(
                    text:
                        '${_localizeInt(streak, isArabic: isArabic)} ${isArabic ? "أيام" : "days"}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: Color(0xFF574500),
                    ),
                    isArabic: isArabic,
                    textDirection: isArabic
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                  ),
                ],
              ),
            ),
          ),

        SizedBox(height: streak > 0 ? 20 : 8),

        // ── Timer (left/start) + Difficulty + ID (right/end) ─────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildCircularTimer(
              remaining,
              totalTime,
              progress,
              isDark,
              isArabic,
            ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _difficultyColor(
                      question.difficulty,
                    ).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _difficultyColor(
                        question.difficulty,
                      ).withValues(alpha: 0.3),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  isArabic ? 'التحدي اليومي' : 'Daily Challenge',
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
              _digitAwareText(
                text: isArabic
                    ? '+${_localizeInt(question.points, isArabic: true)} نقطة للإجابة الصحيحة'
                    : '+${question.points} pts for correct answer',
                style: const TextStyle(
                  color: Color(0xFFFED65B),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                isArabic: isArabic,
                textAlign: TextAlign.center,
                textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
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
                    horizontal: 16,
                    vertical: 14,
                  ),
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
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 22,
                                )
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

        const SizedBox(height: 12),

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
      ],
    );
  }

  // ── Circular Timer ──────────────────────────────────────────────────────

  Widget _buildCircularTimer(
    int remaining,
    int total,
    double progress,
    bool isDark,
    bool isArabic,
  ) {
    final color = remaining <= 5
        ? AppColors.error
        : remaining <= 10
        ? AppColors.warning
        : AppColors.secondary;

    final remainingText = _localizeInt(remaining, isArabic: isArabic);

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
              _digitAwareText(
                text: remainingText,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
                isArabic: isArabic,
                textAlign: TextAlign.center,
              ),
              Text(
                isArabic ? 'ثانية' : 'sec',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
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
              state.isCorrect
                  ? Icons.check_circle_rounded
                  : Icons.cancel_rounded,
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
          _digitAwareText(
            text: isArabic
                ? '+${_localizeInt(state.pointsEarned, isArabic: true)} نقطة'
                : '+${state.pointsEarned} points',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.secondary,
            ),
            isArabic: isArabic,
            textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: isCorrectOption
                        ? Border.all(color: correctColor, width: 1.5)
                        : (isUserChoice && !state.isCorrect)
                        ? Border.all(color: wrongColor, width: 1.5)
                        : Border.all(
                            color: isDark
                                ? AppColors.darkBorder.withValues(alpha: 0.6)
                                : Colors.grey.withValues(alpha: 0.3),
                            width: 1,
                          ),
                  ),
                  child: Row(
                    children: [
                      if (icon != null) ...[
                        Icon(
                          icon,
                          color: isCorrectOption ? correctColor : wrongColor,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: Text(
                          state.question.options[i],
                          style: TextStyle(
                            fontWeight: isCorrectOption
                                ? FontWeight.w700
                                : FontWeight.w500,
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
                    border: Border.all(
                      color: AppColors.info.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: AppColors.info,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          state.question.explanation!,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.textPrimary,
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
        _buildInlineVisibilityTile(isArabic: isArabic, isDark: isDark),
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
              child: Icon(
                Icons.timer_off_rounded,
                color: AppColors.warning,
                size: 60,
              ),
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
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
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
                icon: const Icon(
                  Icons.emoji_events_rounded,
                  color: Colors.white,
                ),
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
            _buildInlineVisibilityTile(isArabic: isArabic, isDark: isDark),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 64),
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
              isArabic
                  ? 'لقد أجبت على سؤال اليوم'
                  : "You've answered today's question",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
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
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
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
                    _localizeInt(state.totalAnswered, isArabic: isArabic),
                    isDark,
                    isArabic: isArabic,
                  ),
                  _statItem(
                    isArabic ? 'صحيحة' : 'Correct',
                    _localizeInt(state.correctAnswers, isArabic: isArabic),
                    isDark,
                    isArabic: isArabic,
                  ),
                  _statItem(
                    isArabic ? 'الدقة' : 'Accuracy',
                    _localizeTextDigits(
                      '${(state.totalAnswered > 0 ? (state.correctAnswers / state.totalAnswered * 100).round() : 0)}%',
                      isArabic: isArabic,
                    ),
                    isDark,
                    isArabic: isArabic,
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
                icon: const Icon(
                  Icons.emoji_events_rounded,
                  color: Colors.white,
                ),
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
            _buildInlineVisibilityTile(isArabic: isArabic, isDark: isDark),
              ],
            ),
          ),
        );
      },
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
                _digitAwareText(
                  text: _localizeInt(totalScore, isArabic: isArabic),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                  isArabic: isArabic,
                  textAlign: TextAlign.center,
                ),
                Text(
                  isArabic ? 'مجموع النقاط' : 'Total Score',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
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
                const Icon(
                  Icons.local_fire_department,
                  color: Colors.orange,
                  size: 28,
                ),
                const SizedBox(height: 6),
                _digitAwareText(
                  text: _localizeInt(streak, isArabic: isArabic),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.orange,
                  ),
                  isArabic: isArabic,
                  textAlign: TextAlign.center,
                ),
                Text(
                  isArabic ? 'أيام متواصلة' : 'Day Streak',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _statItem(
    String label,
    String value,
    bool isDark, {
    required bool isArabic,
  }) {
    return Column(
      children: [
        _digitAwareText(
          text: value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
          isArabic: isArabic,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary,
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
