import 'package:equatable/equatable.dart';

import '../../data/models/practice_question.dart';

abstract class PracticeState extends Equatable {
  const PracticeState();

  @override
  List<Object?> get props => [];
}

/// A wrong-answer entry for post-session review.
class WrongAnswerEntry {
  final PracticeQuestion question;
  final int chosenIndex;

  const WrongAnswerEntry({required this.question, required this.chosenIndex});
}

/// Initial — nothing loaded yet.
class PracticeInitial extends PracticeState {
  const PracticeInitial();
}

/// Fetching from cache or Firestore.
class PracticeLoading extends PracticeState {
  const PracticeLoading();
}

/// Downloading more questions from Firestore (background, quiz still usable).
class PracticeDownloading extends PracticeState {
  final List<PracticeQuestion> questions;
  final int currentIndex;
  final int correct;

  const PracticeDownloading({
    required this.questions,
    required this.currentIndex,
    required this.correct,
  });

  @override
  List<Object?> get props => [questions, currentIndex, correct];
}

/// Active quiz session.
class PracticeReady extends PracticeState {
  final List<PracticeQuestion> questions;
  final int currentIndex;
  final int correct;

  /// Current consecutive correct-answer streak.
  final int streak;

  /// Best streak achieved so far in this session.
  final int bestStreak;

  /// null = user hasn't selected yet; non-null = selection made.
  final int? selectedIndex;

  /// true = answer revealed (correct/wrong shown).
  final bool answered;

  const PracticeReady({
    required this.questions,
    required this.currentIndex,
    this.correct = 0,
    this.streak = 0,
    this.bestStreak = 0,
    this.selectedIndex,
    this.answered = false,
  });

  PracticeQuestion get currentQuestion => questions[currentIndex];

  bool get isLastQuestion => currentIndex >= questions.length - 1;

  @override
  List<Object?> get props => [
        questions,
        currentIndex,
        correct,
        streak,
        bestStreak,
        selectedIndex,
        answered,
      ];
}

/// All cached questions exhausted. Prompt to download more.
class PracticeNeedsMore extends PracticeState {
  final int correct;
  final int total;
  final int streak;
  final int bestStreak;

  const PracticeNeedsMore({
    required this.correct,
    required this.total,
    this.streak = 0,
    this.bestStreak = 0,
  });

  @override
  List<Object?> get props => [correct, total, streak, bestStreak];
}

/// Session complete (all loaded questions answered).
class PracticeFinished extends PracticeState {
  final int correct;
  final int total;
  final int streak;
  final int bestStreak;

  /// XP earned in this session.
  final int xpEarned;

  /// Cumulative XP (lifetime total after this session).
  final int totalXp;

  /// Questions the user answered incorrectly (for post-session review).
  final List<WrongAnswerEntry> wrongAnswers;

  const PracticeFinished({
    required this.correct,
    required this.total,
    this.streak = 0,
    this.bestStreak = 0,
    this.xpEarned = 0,
    this.totalXp = 0,
    this.wrongAnswers = const [],
  });

  @override
  List<Object?> get props => [correct, total, streak, bestStreak, xpEarned, totalXp, wrongAnswers];
}

/// No questions in cache AND offline.
class PracticeEmpty extends PracticeState {
  const PracticeEmpty();
}

/// An error occurred (Firestore fetch failed, etc.).
class PracticeError extends PracticeState {
  final String message;

  const PracticeError(this.message);

  @override
  List<Object?> get props => [message];
}
