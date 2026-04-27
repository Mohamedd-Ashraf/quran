import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/practice_question.dart';
import '../../data/practice_repository.dart';
import '../../services/answered_questions_service.dart';
import '../../services/xp_service.dart';
import 'practice_state.dart';

class PracticeCubit extends Cubit<PracticeState> {
  final PracticeRepository _repository;
  final XpService _xpService;
  final AnsweredQuestionsService _answeredService;

  String? _category;
  String? _difficulty;
  int _streak = 0;
  int _bestStreak = 0;

  /// Tracks wrong answers this session for post-session review.
  final List<WrongAnswerEntry> _wrongAnswers = [];

  /// Maximum questions per session (0 = unlimited / use full batch).
  int _sessionLimit = 0;

  PracticeCubit(this._repository, this._xpService, this._answeredService)
      : super(const PracticeInitial());

  // ── Start session ──────────────────────────────────────────────────────────

  Future<void> startSession({
    String? category,
    String? difficulty,
    int limit = 0,
  }) async {
    _category = category;
    _difficulty = difficulty;
    _sessionLimit = limit;
    _streak = 0;
    _bestStreak = 0;
    _wrongAnswers.clear();
    _repository.resetCursor(category: category, difficulty: difficulty);

    emit(const PracticeLoading());

    // First try local cache.
    final cached = await _repository.getCachedQuestions(
      category: category,
      difficulty: difficulty,
    );

    if (cached.isNotEmpty) {
      final filtered = await _filterUnseen(cached);
      final shuffled = _applyLimit(_shuffleAll(filtered));
      emit(PracticeReady(questions: shuffled, currentIndex: 0));
      return;
    }

    // Cache empty → fetch from Firestore.
    await _fetchAndStart(50);
  }

  /// Returns unseen questions (not yet answered correctly).
  /// If all are answered (pool exhausted) → clears answered set and returns all.
  Future<List<PracticeQuestion>> _filterUnseen(
      List<PracticeQuestion> all) async {
    final answered = await _answeredService.getAnswered(
      category: _category,
      difficulty: _difficulty,
    );
    if (answered.isEmpty) return all;

    final unseen = all.where((q) => !answered.contains(q.id)).toList();
    if (unseen.isNotEmpty) return unseen;

    // Pool exhausted → reset and return all
    await _answeredService.clearAnswered(
      category: _category,
      difficulty: _difficulty,
    );
    return all;
  }

  Future<void> _fetchAndStart(int limit) async {
    try {
      final fresh = await _repository.fetchAndCache(
        limit: limit,
        category: _category,
        difficulty: _difficulty,
      );

      if (fresh.isEmpty) {
        emit(const PracticeEmpty());
        return;
      }

      final filtered = await _filterUnseen(fresh);
      final shuffled = _applyLimit(_shuffleAll(filtered));
      emit(PracticeReady(questions: shuffled, currentIndex: 0));
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied' ||
          e.code == 'unavailable' ||
          e.code == 'network-request-failed') {
        final cached = await _repository.getCachedQuestions(
          category: _category,
          difficulty: _difficulty,
        );
        if (cached.isNotEmpty) {
          final filtered = await _filterUnseen(cached);
          emit(PracticeReady(
              questions: _applyLimit(_shuffleAll(filtered)),
              currentIndex: 0));
        } else {
          emit(const PracticeEmpty());
        }
      } else {
        emit(PracticeError('فشل تحميل الأسئلة: [${e.code}] ${e.message}'));
      }
    } catch (e) {
      emit(PracticeError('فشل تحميل الأسئلة: $e'));
    }
  }

  // ── In-session interactions ────────────────────────────────────────────────

  void selectAnswer(int index) {
    final s = state;
    if (s is! PracticeReady || s.answered) return;
    emit(PracticeReady(
      questions: s.questions,
      currentIndex: s.currentIndex,
      correct: s.correct,
      streak: s.streak,
      bestStreak: s.bestStreak,
      selectedIndex: index,
      answered: false,
    ));
  }

  void confirmAnswer() {
    final s = state;
    if (s is! PracticeReady || s.selectedIndex == null || s.answered) return;
    _submitAnswer(s, s.selectedIndex!);
  }

  /// Called by the quiz screen when the timer expires — auto-submits a wrong
  /// answer (index -1 means no valid option chosen).
  void timerExpired() {
    final s = state;
    if (s is! PracticeReady || s.answered) return;
    // Select a dummy index that cannot match correctIndex (use -1 sentinel).
    // We handle -1 in the UI to show "time's up" highlighting.
    _submitAnswer(s, -1);
  }

  void _submitAnswer(PracticeReady s, int selectedIndex) {
    final isCorrect = selectedIndex == s.currentQuestion.correctIndex;
    final newCorrect = s.correct + (isCorrect ? 1 : 0);

    final newStreak = isCorrect ? s.streak + 1 : 0;
    final newBestStreak =
        newStreak > s.bestStreak ? newStreak : s.bestStreak;
    _streak = newStreak;
    _bestStreak = newBestStreak;

    // No-repeat: correct → mark answered; wrong → ensure unmarked + track for review
    final qId = s.currentQuestion.id;
    if (isCorrect) {
      _answeredService.markAnswered(
        qId,
        category: _category,
        difficulty: _difficulty,
      );
    } else {
      _answeredService.unmarkAnswered(
        qId,
        category: _category,
        difficulty: _difficulty,
      );
      _wrongAnswers.add(WrongAnswerEntry(question: s.currentQuestion, chosenIndex: selectedIndex));
    }

    emit(PracticeReady(
      questions: s.questions,
      currentIndex: s.currentIndex,
      correct: newCorrect,
      streak: newStreak,
      bestStreak: newBestStreak,
      selectedIndex: selectedIndex,
      answered: true,
    ));
  }

  void nextQuestion() {
    final s = state;
    if (s is! PracticeReady || !s.answered) return;

    if (!s.isLastQuestion) {
      emit(PracticeReady(
        questions: s.questions,
        currentIndex: s.currentIndex + 1,
        correct: s.correct,
        streak: s.streak,
        bestStreak: s.bestStreak,
      ));
      return;
    }

    _finishSession(correct: s.correct, total: s.questions.length);
  }

  Future<void> _finishSession({
    required int correct,
    required int total,
  }) async {
    // Compute XP — use mixed difficulty if category is null.
    final difficulty = _difficulty ?? 'easy';
    final xpEarned = XpService.sessionXp(
      correct: correct,
      bestStreak: _bestStreak,
      difficulty: difficulty,
    );
    final totalXp = await _xpService.addXp(xpEarned);

    final exhausted = _repository.isExhausted(
      category: _category,
      difficulty: _difficulty,
    );

    if (exhausted || _sessionLimit > 0) {
      emit(PracticeFinished(
        correct: correct,
        total: total,
        streak: _streak,
        bestStreak: _bestStreak,
        xpEarned: xpEarned,
        totalXp: totalXp,
        wrongAnswers: List.from(_wrongAnswers),
      ));
    } else {
      emit(PracticeNeedsMore(
        correct: correct,
        total: total,
        streak: _streak,
        bestStreak: _bestStreak,
      ));
    }
  }

  // ── Load more ──────────────────────────────────────────────────────────────

  Future<int> downloadMore({required int limit}) async {
    final prev = state;
    int prevCorrect = 0;
    int prevTotal = 0;
    List<PracticeQuestion> prevQuestions = [];

    if (prev is PracticeNeedsMore) {
      prevCorrect = prev.correct;
      prevTotal = prev.total;
    } else if (prev is PracticeReady) {
      prevCorrect = prev.correct;
      prevQuestions = prev.questions;
    }

    emit(PracticeDownloading(
      questions: prevQuestions,
      currentIndex: prevQuestions.isEmpty ? 0 : prevQuestions.length - 1,
      correct: prevCorrect,
    ));

    try {
      final fresh = await _repository.fetchAndCache(
        limit: limit,
        category: _category,
        difficulty: _difficulty,
      );

      if (fresh.isEmpty) {
        final xpEarned = XpService.sessionXp(
          correct: prevCorrect,
          bestStreak: _bestStreak,
          difficulty: _difficulty ?? 'easy',
        );
        final totalXp = await _xpService.addXp(xpEarned);
        emit(PracticeFinished(
          correct: prevCorrect,
          total: prevTotal,
          streak: _streak,
          bestStreak: _bestStreak,
          xpEarned: xpEarned,
          totalXp: totalXp,
          wrongAnswers: List.from(_wrongAnswers),
        ));
        return 0;
      }

      final shuffled = _shuffleAll(fresh);
      emit(PracticeReady(
        questions: shuffled,
        currentIndex: 0,
        correct: prevCorrect,
        streak: _streak,
        bestStreak: _bestStreak,
      ));
      return fresh.length;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied' ||
          e.code == 'unavailable' ||
          e.code == 'network-request-failed') {
        final xpEarned = XpService.sessionXp(
          correct: prevCorrect,
          bestStreak: _bestStreak,
          difficulty: _difficulty ?? 'easy',
        );
        final totalXp = await _xpService.addXp(xpEarned);
        emit(PracticeFinished(
          correct: prevCorrect,
          total: prevTotal,
          streak: _streak,
          bestStreak: _bestStreak,
          xpEarned: xpEarned,
          totalXp: totalXp,
          wrongAnswers: List.from(_wrongAnswers),
        ));
        return 0;
      } else {
        emit(PracticeError('فشل تحميل المزيد: [${e.code}] ${e.message}'));
        return -1;
      }
    } catch (e) {
      emit(PracticeError('فشل تحميل المزيد: $e'));
      return -1;
    }
  }

  /// Returns number of locally cached questions for current filters.
  Future<int> getOfflineCount() async {
    return _repository.getCachedCount(category: _category, difficulty: _difficulty);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  List<PracticeQuestion> _shuffleAll(List<PracticeQuestion> list) {
    final rng = Random();
    final shuffledList = List<PracticeQuestion>.from(list)..shuffle(rng);
    return shuffledList.map((q) => q.shuffleOptions(rng)).toList();
  }

  List<PracticeQuestion> _applyLimit(List<PracticeQuestion> list) {
    if (_sessionLimit <= 0 || list.length <= _sessionLimit) return list;
    return list.sublist(0, _sessionLimit);
  }
}
