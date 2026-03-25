import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'datasources/quiz_questions_data.dart';
import 'models/quiz_question_model.dart';

/// Manages daily quiz state: which question, score, streak, answer history.
///
/// Each user gets a unique order of the 360 questions based on a seed
/// derived from their install time. This prevents users from sharing answers.
class QuizService {
  static const String _keySeed = 'quiz_user_seed';
  static const String _keyTotalScore = 'quiz_total_score';
  static const String _keyStreak = 'quiz_streak';
  static const String _keyCorrectAnswers = 'quiz_correct_answers';
  static const String _keyTotalAnswered = 'quiz_total_answered';
  static const String _keyLastAnsweredDate = 'quiz_last_answered_date';
  static const String _keyAnsweredIds = 'quiz_answered_ids';
  static const String _keyLastAnswerCorrect = 'quiz_last_answer_correct';
  static const String _keyLastAnswerPoints = 'quiz_last_answer_points';
  static const String _keyNotificationsEnabled = 'quiz_notifications_enabled';
  static const String _keyReminderHour = 'quiz_reminder_hour';
  static const String _keyReminderMinute = 'quiz_reminder_minute';

  final SharedPreferences _prefs;

  QuizService(this._prefs);

  // ── Seed management ──────────────────────────────────────────────────────

  /// Returns a stable per-user seed. Generated once on first access.
  int get userSeed {
    var seed = _prefs.getInt(_keySeed);
    if (seed == null) {
      seed = DateTime.now().microsecondsSinceEpoch % 1000000;
      _prefs.setInt(_keySeed, seed);
    }
    return seed;
  }

  // ── Shuffled question order ──────────────────────────────────────────────

  /// Returns the shuffled list of question IDs unique to this user.
  List<int> _getShuffledOrder() {
    final ids = List<int>.generate(quizQuestionsPool.length, (i) => i);
    ids.shuffle(Random(userSeed));
    return ids;
  }

  /// Returns which day index the user is on (0-based, wraps every 360 days).
  int get _dayIndex {
    final answered = answeredIds;
    return answered.length % quizQuestionsPool.length;
  }

  // ── Today's question ─────────────────────────────────────────────────────

  /// Returns today's question for this user, or null if already answered today.
  QuizQuestion? getTodayQuestion() {
    if (hasAnsweredToday) return null;
    final order = _getShuffledOrder();
    final questionId = order[_dayIndex];
    return quizQuestionsPool[questionId];
  }

  /// Whether the user has already answered today's question.
  bool get hasAnsweredToday {
    final lastDate = _prefs.getString(_keyLastAnsweredDate);
    if (lastDate == null) return false;
    final today = _todayString();
    return lastDate == today;
  }

  // ── Answer submission ────────────────────────────────────────────────────

  /// Submits an answer for today's question. Returns true if correct.
  Future<bool> submitAnswer(int questionId, int selectedIndex) async {
    final question = quizQuestionsPool[questionId];
    final isCorrect = selectedIndex == question.correctIndex;
    final points = isCorrect ? question.points : 0;

    // Update score
    final currentScore = totalScore;
    await _prefs.setInt(_keyTotalScore, currentScore + points);

    // Update streak
    final wasYesterdayAnswered = _wasYesterdayAnswered();
    if (isCorrect) {
      final currentStreak = streak;
      if (wasYesterdayAnswered || currentStreak == 0) {
        await _prefs.setInt(_keyStreak, currentStreak + 1);
      } else {
        await _prefs.setInt(_keyStreak, 1);
      }
    } else {
      // Wrong answer — reset streak only if they had a streak going.
      // Keep streak if this is their first wrong answer in a while.
      // Actually, streak counts consecutive DAYS of answering correctly.
      await _prefs.setInt(_keyStreak, 0);
    }

    // Update counters
    await _prefs.setInt(_keyTotalAnswered, totalAnswered + 1);
    if (isCorrect) {
      await _prefs.setInt(_keyCorrectAnswers, correctAnswers + 1);
    }

    // Mark today as answered
    await _prefs.setString(_keyLastAnsweredDate, _todayString());

    // Save answered question ID
    final answered = answeredIds;
    answered.add(questionId);
    await _prefs.setString(_keyAnsweredIds, jsonEncode(answered));

    // Save last answer details for result screen
    await _prefs.setBool(_keyLastAnswerCorrect, isCorrect);
    await _prefs.setInt(_keyLastAnswerPoints, points);

    return isCorrect;
  }

  // ── Score & stats ────────────────────────────────────────────────────────

  int get totalScore => _prefs.getInt(_keyTotalScore) ?? 0;
  int get streak => _prefs.getInt(_keyStreak) ?? 0;
  int get correctAnswers => _prefs.getInt(_keyCorrectAnswers) ?? 0;
  int get totalAnswered => _prefs.getInt(_keyTotalAnswered) ?? 0;

  bool? get lastAnswerCorrect => _prefs.getBool(_keyLastAnswerCorrect);
  int get lastAnswerPoints => _prefs.getInt(_keyLastAnswerPoints) ?? 0;

  double get accuracy =>
      totalAnswered == 0 ? 0.0 : correctAnswers / totalAnswered;

  List<int> get answeredIds {
    final json = _prefs.getString(_keyAnsweredIds);
    if (json == null) return [];
    try {
      return (jsonDecode(json) as List).cast<int>().toList();
    } catch (_) {
      return [];
    }
  }

  // ── Notification settings ────────────────────────────────────────────────

  bool get notificationsEnabled =>
      _prefs.getBool(_keyNotificationsEnabled) ?? true;

  Future<void> setNotificationsEnabled(bool enabled) async {
    await _prefs.setBool(_keyNotificationsEnabled, enabled);
  }

  int get reminderHour => _prefs.getInt(_keyReminderHour) ?? 20;
  int get reminderMinute => _prefs.getInt(_keyReminderMinute) ?? 0;

  Future<void> setReminderTime(int hour, int minute) async {
    await _prefs.setInt(_keyReminderHour, hour);
    await _prefs.setInt(_keyReminderMinute, minute);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  bool _wasYesterdayAnswered() {
    final lastDate = _prefs.getString(_keyLastAnsweredDate);
    if (lastDate == null) return false;
    try {
      final last = DateTime.parse(lastDate);
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      return last.year == yesterday.year &&
          last.month == yesterday.month &&
          last.day == yesterday.day;
    } catch (_) {
      return false;
    }
  }

  /// Returns the app language code.
  String getAppLanguage() => _prefs.getString('app_language') ?? 'ar';
}
