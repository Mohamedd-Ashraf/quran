import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/quiz_question_model.dart';
import '../../data/quiz_repository.dart';
import '../../services/quiz_notification_service.dart';
import 'quiz_state.dart';

class QuizCubit extends Cubit<QuizState> {
  final QuizRepository _repository;
  final QuizNotificationService _notifService;

  Timer? _timer;
  int _remainingSeconds = 0;
  bool _hasSubmitted = false;

  QuizCubit(this._repository, this._notifService) : super(const QuizInitial());

  int get remainingSeconds => _remainingSeconds;

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> load() async {
    _hasSubmitted = false;
    emit(const QuizLoading());

    // Load from Firestore (logged-in) or SharedPrefs (guest)
    await _repository.loadData();

    if (_repository.hasAnsweredToday) {
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

    _startTimer(question.timerSeconds);
    emit(QuizReady(
      question: question,
      streak: _repository.streak,
      totalScore: _repository.totalScore,
    ));
  }

  // ── Timer ─────────────────────────────────────────────────────────────────

  void _startTimer(int seconds) {
    _timer?.cancel();
    _remainingSeconds = seconds;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _remainingSeconds--;
      if (_remainingSeconds <= 0) {
        timer.cancel();
        _onTimeUp();
      }
      // UI reads remainingSeconds via a periodic setState timer in the screen
    });
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

    // selectedIndex = -1 counts as wrong (no matching correctIndex)
    await _repository.submitAnswer(question.id, -1);

    emit(QuizTimeUp(
      question: question,
      totalScore: _repository.totalScore,
      streak: _repository.streak,
    ));
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

    final isCorrect =
        await _repository.submitAnswer(questionId, selectedIndex);

    final question = (state is QuizAnswerSelected)
        ? (state as QuizAnswerSelected).question
        : (state is QuizReady)
            ? (state as QuizReady).question
            : null;

    if (question == null) return;

    emit(QuizResult(
      question: question,
      selectedIndex: selectedIndex,
      isCorrect: isCorrect,
      pointsEarned: isCorrect ? question.points : 0,
      newTotalScore: _repository.totalScore,
      newStreak: _repository.streak,
    ));
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

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
