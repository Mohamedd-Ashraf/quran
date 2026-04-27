import 'package:shared_preferences/shared_preferences.dart';

/// Local XP service — stored in SharedPreferences only, never synced to Firestore.
///
/// XP is awarded per correct answer in practice mode:
///   easy   → 1 XP
///   medium → 2 XP
///   hard   → 3 XP
/// Streak bonus: every 5-correct streak grants +5 XP (one-time per milestone).
class XpService {
  static const _kTotalXp = 'practice_total_xp';

  // ── Read ──────────────────────────────────────────────────────────────────

  Future<int> getTotalXp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kTotalXp) ?? 0;
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  /// Adds [amount] XP and returns the new total.
  Future<int> addXp(int amount) async {
    if (amount <= 0) return getTotalXp();
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_kTotalXp) ?? 0;
    final updated = current + amount;
    await prefs.setInt(_kTotalXp, updated);
    return updated;
  }

  // ── Calculation helpers ───────────────────────────────────────────────────

  /// Returns the XP value for a single correct answer based on difficulty.
  static int xpForDifficulty(String difficulty) {
    switch (difficulty) {
      case 'easy':
        return 1;
      case 'medium':
        return 2;
      case 'hard':
        return 3;
      case 'expert':
        return 5;
      default:
        return 1;
    }
  }

  /// Returns streak-bonus XP if [streak] hits a 5-multiple milestone,
  /// otherwise 0.
  static int streakBonus(int streak) {
    if (streak > 0 && streak % 5 == 0) return 5;
    return 0;
  }

  /// Computes total session XP from correct answers list and best streak.
  static int sessionXp({
    required int correct,
    required int bestStreak,
    required String difficulty,
  }) {
    final base = correct * xpForDifficulty(difficulty);
    // One streak bonus per every 5 correct in best streak.
    final bonuses = (bestStreak ~/ 5) * 5;
    return base + bonuses;
  }
}
