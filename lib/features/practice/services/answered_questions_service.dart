import 'package:shared_preferences/shared_preferences.dart';

/// Tracks which practice question IDs the user answered correctly.
///
/// Correct answers → added to the answered set (skipped in future sessions).
/// Wrong answers   → not added (appear again).
/// Pool exhausted  → [clearAnswered] resets so all questions re-appear.
///
/// Persistence: SharedPreferences key per [category]×[difficulty] combination
/// so different filters maintain independent tracking.
class AnsweredQuestionsService {
  static const _prefix = 'practice_answered';

  static String _key(String? category, String? difficulty) {
    final c = category ?? 'all';
    final d = difficulty ?? 'all';
    return '${_prefix}_${c}_$d';
  }

  /// Returns the set of answered question IDs for the given filter.
  Future<Set<String>> getAnswered({
    String? category,
    String? difficulty,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key(category, difficulty)) ?? [];
    return list.toSet();
  }

  /// Marks [questionId] as correctly answered.
  Future<void> markAnswered(
    String questionId, {
    String? category,
    String? difficulty,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _key(category, difficulty);
    final current = prefs.getStringList(key) ?? [];
    if (!current.contains(questionId)) {
      current.add(questionId);
      await prefs.setStringList(key, current);
    }
  }

  /// Removes [questionId] from the answered set (called on wrong answer,
  /// ensuring the question can appear again).
  Future<void> unmarkAnswered(
    String questionId, {
    String? category,
    String? difficulty,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _key(category, difficulty);
    final current = prefs.getStringList(key) ?? [];
    if (current.remove(questionId)) {
      await prefs.setStringList(key, current);
    }
  }

  /// Resets answered tracking for the given filter (called when pool exhausted).
  Future<void> clearAnswered({
    String? category,
    String? difficulty,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(category, difficulty));
  }
}
