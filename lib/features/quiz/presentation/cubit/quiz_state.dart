import 'package:equatable/equatable.dart';
import '../../data/models/quiz_question_model.dart';

abstract class QuizState extends Equatable {
  const QuizState();

  @override
  List<Object?> get props => [];
}

/// Initial state before loading.
class QuizInitial extends QuizState {
  const QuizInitial();
}

/// Loading today's question.
class QuizLoading extends QuizState {
  const QuizLoading();
}

/// Quiz requires internet to load and submit today's answer.
class QuizOfflineUnavailable extends QuizState {
  final String message;

  const QuizOfflineUnavailable({required this.message});

  @override
  List<Object?> get props => [message];
}

/// Question loaded — waiting for the user to press "Start".
/// The countdown timer has NOT started yet.
class QuizReadyToStart extends QuizState {
  final QuizQuestion question;
  final int streak;
  final int totalScore;

  const QuizReadyToStart({
    required this.question,
    required this.streak,
    required this.totalScore,
  });

  @override
  List<Object?> get props => [question.id, streak, totalScore];
}

/// Today's question is ready to answer.
class QuizReady extends QuizState {
  final QuizQuestion question;
  final int streak;
  final int totalScore;

  const QuizReady({
    required this.question,
    required this.streak,
    required this.totalScore,
  });

  @override
  List<Object?> get props => [question.id, streak, totalScore];
}

/// User has selected an answer, countdown is active.
class QuizAnswerSelected extends QuizState {
  final QuizQuestion question;
  final int selectedIndex;
  final int streak;
  final int totalScore;

  const QuizAnswerSelected({
    required this.question,
    required this.selectedIndex,
    required this.streak,
    required this.totalScore,
  });

  @override
  List<Object?> get props => [question.id, selectedIndex, streak, totalScore];
}

/// Answer submitted — showing result.
class QuizResult extends QuizState {
  final QuizQuestion question;
  final int selectedIndex;
  final bool isCorrect;
  final int pointsEarned;
  final int newTotalScore;
  final int newStreak;

  const QuizResult({
    required this.question,
    required this.selectedIndex,
    required this.isCorrect,
    required this.pointsEarned,
    required this.newTotalScore,
    required this.newStreak,
  });

  @override
  List<Object?> get props => [
        question.id,
        selectedIndex,
        isCorrect,
        pointsEarned,
        newTotalScore,
        newStreak,
      ];
}

/// User has already answered today.
class QuizAlreadyAnswered extends QuizState {
  final int totalScore;
  final int streak;
  final int correctAnswers;
  final int totalAnswered;
  final bool? lastAnswerCorrect;
  final int lastAnswerPoints;

  const QuizAlreadyAnswered({
    required this.totalScore,
    required this.streak,
    required this.correctAnswers,
    required this.totalAnswered,
    this.lastAnswerCorrect,
    required this.lastAnswerPoints,
  });

  @override
  List<Object?> get props => [
        totalScore,
        streak,
        correctAnswers,
        totalAnswered,
        lastAnswerCorrect,
        lastAnswerPoints,
      ];
}

/// Timer ran out before answering.
class QuizTimeUp extends QuizState {
  final QuizQuestion question;
  final int totalScore;
  final int streak;

  const QuizTimeUp({
    required this.question,
    required this.totalScore,
    required this.streak,
  });

  @override
  List<Object?> get props => [question.id, totalScore, streak];
}

/// Answer submission failed (network or server-side rule rejection).
/// [retryInProgress] > 0 means a countdown is running before auto-retry.
/// When 0, no more retries — user must exit.
class QuizSubmitError extends QuizState {
  final QuizQuestion question;
  final int selectedIndex;
  final String message;
  /// Seconds remaining before auto-retry.  0 = countdown finished, manual action needed.
  final int retryInProgress;

  const QuizSubmitError({
    required this.question,
    required this.selectedIndex,
    required this.message,
    this.retryInProgress = 0,
  });

  @override
  List<Object?> get props => [question.id, selectedIndex, message, retryInProgress];
}
