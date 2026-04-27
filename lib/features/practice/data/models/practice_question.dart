import 'dart:math';

/// Category for a practice question.
enum PracticeCategory { quran, hadith, fiqh, seerah }

/// Difficulty for a practice question.
enum PracticeDifficulty { easy, medium, hard, expert }

extension PracticeCategoryX on PracticeCategory {
  String get value {
    switch (this) {
      case PracticeCategory.quran:
        return 'quran';
      case PracticeCategory.hadith:
        return 'hadith';
      case PracticeCategory.fiqh:
        return 'fiqh';
      case PracticeCategory.seerah:
        return 'seerah';
    }
  }

  String get labelAr {
    switch (this) {
      case PracticeCategory.quran:
        return 'القرآن الكريم';
      case PracticeCategory.hadith:
        return 'الحديث الشريف';
      case PracticeCategory.fiqh:
        return 'الفقه';
      case PracticeCategory.seerah:
        return 'السيرة النبوية';
    }
  }

  static PracticeCategory fromString(String s) {
    switch (s) {
      case 'quran':
        return PracticeCategory.quran;
      case 'hadith':
        return PracticeCategory.hadith;
      case 'fiqh':
        return PracticeCategory.fiqh;
      case 'seerah':
        return PracticeCategory.seerah;
      default:
        return PracticeCategory.quran;
    }
  }
}

extension PracticeDifficultyX on PracticeDifficulty {
  String get value {
    switch (this) {
      case PracticeDifficulty.easy:
        return 'easy';
      case PracticeDifficulty.medium:
        return 'medium';
      case PracticeDifficulty.hard:
        return 'hard';
      case PracticeDifficulty.expert:
        return 'expert';
    }
  }

  String get labelAr {
    switch (this) {
      case PracticeDifficulty.easy:
        return 'سهل';
      case PracticeDifficulty.medium:
        return 'متوسط';
      case PracticeDifficulty.hard:
        return 'صعب';
      case PracticeDifficulty.expert:
        return 'خبير';
    }
  }

  static PracticeDifficulty fromString(String s) {
    switch (s) {
      case 'easy':
        return PracticeDifficulty.easy;
      case 'medium':
        return PracticeDifficulty.medium;
      case 'hard':
        return PracticeDifficulty.hard;
      case 'expert':
        return PracticeDifficulty.expert;
      default:
        return PracticeDifficulty.easy;
    }
  }
}

class PracticeQuestion {
  final String id;
  final String question;
  final List<String> options;
  final int correctIndex;
  final PracticeCategory category;
  final PracticeDifficulty difficulty;

  const PracticeQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.category,
    required this.difficulty,
  });

  // ── Firestore ──────────────────────────────────────────────────────────────

  factory PracticeQuestion.fromFirestore(String id, Map<String, dynamic> data) {
    return PracticeQuestion(
      id: id,
      question: data['question'] as String,
      options: List<String>.from(data['options'] as List),
      correctIndex: data['correctIndex'] as int,
      category: PracticeCategoryX.fromString(data['category'] as String),
      difficulty:
          PracticeDifficultyX.fromString(data['difficulty'] as String),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'question': question,
        'options': options,
        'correctIndex': correctIndex,
        'category': category.value,
        'difficulty': difficulty.value,
      };

  // ── sqflite ───────────────────────────────────────────────────────────────

  factory PracticeQuestion.fromRow(Map<String, dynamic> row) {
    return PracticeQuestion(
      id: row['id'] as String,
      question: row['question'] as String,
      options: [
        row['option0'] as String,
        row['option1'] as String,
        row['option2'] as String,
        row['option3'] as String,
      ],
      correctIndex: row['correct_index'] as int,
      category: PracticeCategoryX.fromString(row['category'] as String),
      difficulty:
          PracticeDifficultyX.fromString(row['difficulty'] as String),
    );
  }

  Map<String, dynamic> toRow() => {
        'id': id,
        'question': question,
        'option0': options[0],
        'option1': options[1],
        'option2': options[2],
        'option3': options[3],
        'correct_index': correctIndex,
        'category': category.value,
        'difficulty': difficulty.value,
        'cached_at': DateTime.now().millisecondsSinceEpoch,
      };

  // ── Helpers ───────────────────────────────────────────────────────────────

  PracticeQuestion shuffleOptions(Random rng) {
    final shuffled = List<String>.from(options);
    final correct = options[correctIndex];
    shuffled.shuffle(rng);
    return PracticeQuestion(
      id: id,
      question: question,
      options: shuffled,
      correctIndex: shuffled.indexOf(correct),
      category: category,
      difficulty: difficulty,
    );
  }
}
