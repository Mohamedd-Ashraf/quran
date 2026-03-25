import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'models/leaderboard_entry.dart';
import 'quiz_service.dart';

/// Manages Firestore leaderboard for the daily quiz.
///
/// Firestore structure:
/// ```
/// quiz_leaderboard/{uid}:
///   displayName, photoUrl, totalScore, streak, correctAnswers, totalAnswered, lastUpdated
/// ```
class QuizCloudService {
  final FirebaseFirestore _firestore;
  final QuizService _quizService;

  static const String _collection = 'quiz_leaderboard';

  QuizCloudService(this._firestore, this._quizService);

  CollectionReference get _leaderboardRef =>
      _firestore.collection(_collection);

  // ── Upload score ─────────────────────────────────────────────────────────

  /// Uploads the current user's score to the leaderboard.
  Future<void> uploadScore(User user) async {
    if (user.isAnonymous) return;

    try {
      final entry = LeaderboardEntry(
        uid: user.uid,
        displayName: user.displayName ?? 'مستخدم',
        photoUrl: user.photoURL,
        totalScore: _quizService.totalScore,
        streak: _quizService.streak,
        correctAnswers: _quizService.correctAnswers,
        totalAnswered: _quizService.totalAnswered,
      );

      await _leaderboardRef.doc(user.uid).set(
            entry.toMap(),
            SetOptions(merge: true),
          );
      debugPrint('QuizCloud: uploaded score for ${user.uid}');
    } catch (e, st) {
      debugPrint('QuizCloud: upload failed: $e\n$st');
    }
  }

  // ── Fetch leaderboard ────────────────────────────────────────────────────

  /// Fetches the top N users sorted by total score descending.
  Future<List<LeaderboardEntry>> getTopUsers({int limit = 50}) async {
    try {
      final snapshot = await _leaderboardRef
          .orderBy('totalScore', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => LeaderboardEntry.fromFirestore(doc))
          .toList();
    } catch (e, st) {
      debugPrint('QuizCloud: fetch leaderboard failed: $e\n$st');
      return [];
    }
  }

  /// Gets the current user's rank (1-based). Returns null if not found.
  Future<int?> getUserRank(String uid) async {
    try {
      // Get user's score
      final userDoc = await _leaderboardRef.doc(uid).get();
      if (!userDoc.exists) return null;

      final userData = userDoc.data() as Map<String, dynamic>?;
      final userScore = userData?['totalScore'] as int? ?? 0;

      // Count users with higher score
      final higherCount = await _leaderboardRef
          .where('totalScore', isGreaterThan: userScore)
          .count()
          .get();

      return (higherCount.count ?? 0) + 1;
    } catch (e, st) {
      debugPrint('QuizCloud: get rank failed: $e\n$st');
      return null;
    }
  }

  /// Gets the current user's leaderboard entry.
  Future<LeaderboardEntry?> getUserEntry(String uid) async {
    try {
      final doc = await _leaderboardRef.doc(uid).get();
      if (!doc.exists) return null;
      return LeaderboardEntry.fromFirestore(doc);
    } catch (e, st) {
      debugPrint('QuizCloud: get user entry failed: $e\n$st');
      return null;
    }
  }
}
