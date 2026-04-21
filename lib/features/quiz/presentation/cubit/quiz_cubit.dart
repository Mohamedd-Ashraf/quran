import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/quiz_question_model.dart';
import '../../data/quiz_repository.dart';
import '../../services/quiz_notification_service.dart';
import 'quiz_state.dart';

class QuizCubit extends Cubit<QuizState> with WidgetsBindingObserver {
  final QuizRepository _repository;
  final QuizNotificationService _notifService;

  Timer? _timer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  int _remainingSeconds = 0;
  bool _hasSubmitted = false;

  /// Wall-clock time when the question was shown. Used to compute actual
  /// elapsed time when the app resumes from background, preventing the
  /// timer-pause cheat (backgrounding the app to buy extra thinking time).
  DateTime? _questionStartTime;
  int _totalTimerSeconds = 0;

  QuizCubit(this._repository, this._notifService) : super(const QuizInitial()) {
    WidgetsBinding.instance.addObserver(this);
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (isOnline) _trySyncPendingAnswer();
    });
  }

  int get remainingSeconds => _remainingSeconds;

  // ── Load ──────────────────────────────────────────────────────────────────

  /// [skipLanding] — when `true`, skips the landing/ready screen and starts
  /// the timer immediately. Pass `true` when the user navigates from within
  /// the app; pass `false` (default) only when arriving from a notification.
  Future<void> load({bool skipLanding = false}) async {
    _hasSubmitted = false;
    _questionStartTime = null;
    _totalTimerSeconds = 0;
    emit(const QuizLoading());

    // Load from Firestore (logged-in) or SharedPrefs (guest)
    await _repository.loadData();

    // Admins bypass the daily-answer limit so they can test freely.
    if (_repository.hasAnsweredToday && !_repository.isAdmin) {
      emit(QuizAlreadyAnswered(
        totalScore: _repository.totalScore,
        streak: _repository.streak,
        correctAnswers: _repository.correctAnswers,
        totalAnswered: _repository.totalAnswered,
        lastAnswerCorrect: _repository.lastAnswerCorrect,
        lastAnswerPoints: _repository.lastAnswerPoints,
      ));
      return;
    }

    final question = _repository.getTodayQuestion();
    if (question == null) {
      emit(QuizAlreadyAnswered(
        totalScore: _repository.totalScore,
        streak: _repository.streak,
        correctAnswers: _repository.correctAnswers,
        totalAnswered: _repository.totalAnswered,
        lastAnswerCorrect: _repository.lastAnswerCorrect,
        lastAnswerPoints: _repository.lastAnswerPoints,
      ));
      return;
    }

    if (skipLanding) {
      // Navigated from within the app — start the timer immediately.
      _startTimer(question.timerSeconds);
      emit(QuizReady(
        question: question,
        streak: _repository.streak,
        totalScore: _repository.totalScore,
      ));
    } else {
      // Navigated from a notification — show landing screen first so the
      // timer only starts when the user consciously presses "Start".
      emit(QuizReadyToStart(
        question: question,
        streak: _repository.streak,
        totalScore: _repository.totalScore,
      ));
    }
  }

  /// Called when the user presses the "Start" button on the landing screen.
  /// Starts the countdown timer and transitions to [QuizReady].
  void startQuiz() {
    final s = state;
    if (s is! QuizReadyToStart) return;
    _startTimer(s.question.timerSeconds);
    emit(QuizReady(
      question: s.question,
      streak: s.streak,
      totalScore: s.totalScore,
    ));
  }

  // ── Timer ─────────────────────────────────────────────────────────────────

  void _startTimer(int seconds) {
    _timer?.cancel();
    _remainingSeconds = seconds;
    _totalTimerSeconds = seconds;
    _questionStartTime = DateTime.now();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Compute remaining time from actual wall-clock elapsed time.
      // This is cheat-proof: backgrounding the app doesn't pause DateTime.now().
      final elapsed = DateTime.now().difference(_questionStartTime!).inSeconds;
      _remainingSeconds = (_totalTimerSeconds - elapsed).clamp(0, _totalTimerSeconds);
      if (_remainingSeconds <= 0) {
        timer.cancel();
        _onTimeUp();
      }
      // UI reads remainingSeconds via a periodic setState timer in the screen
    });
  }

  /// Called by Flutter when the app transitions to/from background.
  /// If the user has backgrounded the app while a question is active and
  /// the full timer duration has already elapsed, auto-submit as a timeout.
  /// Also retries any pending offline sync on resume.
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      _trySyncPendingAnswer();
    }
    if (lifecycleState == AppLifecycleState.resumed &&
        _questionStartTime != null &&
        !_hasSubmitted) {
      final elapsed =
          DateTime.now().difference(_questionStartTime!).inSeconds;
      _remainingSeconds =
          (_totalTimerSeconds - elapsed).clamp(0, _totalTimerSeconds);
      if (_remainingSeconds <= 0) {
        _timer?.cancel();
        _onTimeUp();
      }
    }
  }

  void _onTimeUp() {
    final currentState = state;
    if (currentState is QuizReady) {
      _submitAsTimeout(currentState.question);
    } else if (currentState is QuizAnswerSelected) {
      submitAnswer(currentState.question.id, currentState.selectedIndex);
    }
  }

  Future<void> _submitAsTimeout(QuizQuestion question) async {
    if (_hasSubmitted) return;
    _hasSubmitted = true;

    try {
      // selectedIndex = -1 counts as wrong (no matching correctIndex)
      await _repository.submitAnswer(question.id, -1);
      emit(QuizTimeUp(
        question: question,
        totalScore: _repository.totalScore,
        streak: _repository.streak,
      ));
    } catch (e) {
      // Revert submission lock so user can retry.
      _hasSubmitted = false;
      emit(QuizSubmitError(
        question: question,
        selectedIndex: -1,
        message: e.toString(),
      ));
    }
  }

  // ── Answer selection ──────────────────────────────────────────────────────

  void selectAnswer(int index) {
    if (_hasSubmitted) return;
    final currentState = state;
    final QuizQuestion? question;
    final int streak;
    final int totalScore;

    if (currentState is QuizReady) {
      question = currentState.question;
      streak = currentState.streak;
      totalScore = currentState.totalScore;
    } else if (currentState is QuizAnswerSelected) {
      question = currentState.question;
      streak = currentState.streak;
      totalScore = currentState.totalScore;
    } else {
      return;
    }

    emit(QuizAnswerSelected(
      question: question,
      selectedIndex: index,
      streak: streak,
      totalScore: totalScore,
    ));
  }

  // ── Submit answer ─────────────────────────────────────────────────────────

  Future<void> submitAnswer(int questionId, int selectedIndex) async {
    if (_hasSubmitted) return;
    _hasSubmitted = true;
    _timer?.cancel();

    final question = (state is QuizAnswerSelected)
        ? (state as QuizAnswerSelected).question
        : (state is QuizReady)
            ? (state as QuizReady).question
            : null;

    if (question == null) return;

    try {
      final isCorrect =
          await _repository.submitAnswer(questionId, selectedIndex);

      emit(QuizResult(
        question: question,
        selectedIndex: selectedIndex,
        isCorrect: isCorrect,
        pointsEarned: isCorrect ? question.points : 0,
        newTotalScore: _repository.totalScore,
        newStreak: _repository.streak,
      ));
    } catch (e) {
      // Revert submission lock so user can retry after resolving the error
      // (e.g. network restored). In-memory state was already reverted by
      // the repository before throwing.
      _hasSubmitted = false;
      _timer?.cancel();
      _startTimer(question.timerSeconds);
      emit(QuizSubmitError(
        question: question,
        selectedIndex: selectedIndex,
        message: e.toString(),
      ));
    }
  }

  // ── Notification settings ─────────────────────────────────────────────────

  Future<void> setNotificationsEnabled(bool enabled) async {
    await _repository.setNotificationsEnabled(enabled);
    if (!enabled) {
      await _notifService.cancelAll();
    } else {
      await _notifService.scheduleDailyReminder();
    }
  }

  // ── Cleanup ───────────────────────────────────────────────────────────────

  // ── Offline sync ──────────────────────────────────────────────────────────

  Future<void> _trySyncPendingAnswer() async {
    if (!_repository.hasPendingSync) return;
    try {
      final synced = await _repository.syncPendingAnswer();
      if (synced) {
        debugPrint('[Quiz] Offline answer successfully synced to Firestore');
      }
    } catch (e) {
      debugPrint('[Quiz] Pending sync attempt failed: $e');
    }
  }

  @override
  Future<void> close() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _connectivitySub?.cancel();
    return super.close();
  }
}
