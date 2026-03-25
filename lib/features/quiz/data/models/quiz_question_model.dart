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
    switch (difficulty) {
      case QuizDifficulty.easy:
        return 20;
      case QuizDifficulty.medium:
        return 15;
      case QuizDifficulty.hard:
        return 10;
    }
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
