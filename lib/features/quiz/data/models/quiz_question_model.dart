import 'dart:math';

/// Difficulty level for a quiz question.
enum QuizDifficulty { easy, medium, hard }

/// A single quiz question with four options.
class QuizQuestion {
  /// Unique ID (0–359).
  final int id;
  final String question;
  final List<String> options;

  /// Index into [options] for the correct answer (0–3).
  final int correctIndex;
  final QuizDifficulty difficulty;

  /// Optional brief explanation shown after answering.
  final String? explanation;

  const QuizQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.difficulty,
    this.explanation,
  });

  /// Returns a copy of this question with the options shuffled using [rng].
  /// The [correctIndex] is updated to point to the correct answer's new position.
  QuizQuestion shuffleOptions(Random rng) {
    final shuffled = List<String>.from(options);
    final correctAnswer = options[correctIndex];
    shuffled.shuffle(rng);
    return QuizQuestion(
      id: id,
      question: question,
      options: shuffled,
      correctIndex: shuffled.indexOf(correctAnswer),
      difficulty: difficulty,
      explanation: explanation,
    );
  }

  /// Points awarded for a correct answer based on difficulty.
  int get points {
    switch (difficulty) {
      case QuizDifficulty.easy:
        return 5;
      case QuizDifficulty.medium:
        return 10;
      case QuizDifficulty.hard:
        return 20;
    }
  }

  /// Timer duration in seconds based on difficulty.
  int get timerSeconds {
    return 20; // All questions get 20 seconds regardless of difficulty
  }

  /// Arabic label for difficulty.
  String get difficultyLabelAr {
    switch (difficulty) {
      case QuizDifficulty.easy:
        return 'سهل';
      case QuizDifficulty.medium:
        return 'متوسط';
      case QuizDifficulty.hard:
        return 'صعب';
    }
  }

  /// English label for difficulty.
  String get difficultyLabelEn {
    switch (difficulty) {
      case QuizDifficulty.easy:
        return 'Easy';
      case QuizDifficulty.medium:
        return 'Medium';
      case QuizDifficulty.hard:
        return 'Hard';
    }
  }
}
