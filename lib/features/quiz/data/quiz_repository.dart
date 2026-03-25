import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'datasources/quiz_questions_data.dart';
import 'models/leaderboard_entry.dart';
import 'models/quiz_question_model.dart';

/// Single source of truth for all quiz data.
///
/// - **Authenticated users** → Firestore `quiz_leaderboard/{uid}` (read + write).
///   This same document powers the leaderboard, so there is no separate upload step.
/// - **Guest users** → SharedPreferences (local only, not shown on leaderboard).
/// - **Device settings** (notifications, reminder time) → always SharedPreferences.
///
/// Firestore document shape:
/// ```
/// quiz_leaderboard/{uid}:
///   displayName, photoUrl                          ← shown on leaderboard
///   totalScore, streak, correctAnswers, totalAnswered
///   lastAnsweredDate (YYYY-MM-DD), answeredIdsJson (JSON string)
///   userSeed (int), lastAnswerCorrect (bool?), lastAnswerPoints (int)
///   lastUpdated (Timestamp)
/// ```
class QuizRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final SharedPreferences _prefs;

  static const String _collection = 'quiz_leaderboard';

  // ── SharedPrefs keys (guests + device-only settings) ─────────────────────
  static const _kSeed = 'quiz_user_seed';
  static const _kScore = 'quiz_total_score';
  static const _kStreak = 'quiz_streak';
  static const _kCorrect = 'quiz_correct_answers';
  static const _kTotal = 'quiz_total_answered';
  static const _kLastDate = 'quiz_last_answered_date';
  static const _kAnsweredIds = 'quiz_answered_ids';
  static const _kLastCorrect = 'quiz_last_answer_correct';
  static const _kLastPoints = 'quiz_last_answer_points';
  static const _kNotifEnabled = 'quiz_notifications_enabled';
  static const _kReminderHour = 'quiz_reminder_hour';
  static const _kReminderMinute = 'quiz_reminder_minute';

  // ── In-memory session cache ───────────────────────────────────────────────
  int _totalScore = 0;
  int _streak = 0;
  int _correctAnswers = 0;
  int _totalAnswered = 0;
  String? _lastAnsweredDate;
  List<int> _answeredIds = [];
  bool? _lastAnswerCorrect;
  int _lastAnswerPoints = 0;
  int _userSeed = 0;

  QuizRepository(this._firestore, this._auth, this._prefs);

  // ── Auth helpers ──────────────────────────────────────────────────────────

  User? get _user => _auth.currentUser;
  bool get _isLoggedIn => _user != null && !_user!.isAnonymous;

  // ── Load ──────────────────────────────────────────────────────────────────

  /// Loads quiz data from Firestore (logged-in) or SharedPreferences (guest).
  /// Always fetches fresh data; safe to call on every screen open.
  Future<void> loadData() async {
    if (_isLoggedIn) {
      await _loadFromFirestore();
    } else {
      _loadFromPrefs();
    }
  }

  void _loadFromPrefs() {
    _userSeed = _ensureSeedInPrefs();
    _totalScore = _prefs.getInt(_kScore) ?? 0;
    _streak = _prefs.getInt(_kStreak) ?? 0;
    _correctAnswers = _prefs.getInt(_kCorrect) ?? 0;
    _totalAnswered = _prefs.getInt(_kTotal) ?? 0;
    _lastAnsweredDate = _prefs.getString(_kLastDate);
    _answeredIds = _parseIds(_prefs.getString(_kAnsweredIds));
    _lastAnswerCorrect = _prefs.getBool(_kLastCorrect);
    _lastAnswerPoints = _prefs.getInt(_kLastPoints) ?? 0;
  }

  Future<void> _loadFromFirestore() async {
    try {
      final doc = await _firestore
          .collection(_collection)
          .doc(_user!.uid)
          .get();

      if (doc.exists) {
        final d = doc.data()!;
        _userSeed = d['userSeed'] as int? ?? _ensureSeedInPrefs();
        _totalScore = d['totalScore'] as int? ?? 0;
        _streak = d['streak'] as int? ?? 0;
        _correctAnswers = d['correctAnswers'] as int? ?? 0;
        _totalAnswered = d['totalAnswered'] as int? ?? 0;
        _lastAnsweredDate = d['lastAnsweredDate'] as String?;
        _answeredIds = _parseIds(d['answeredIdsJson'] as String?);
        _lastAnswerCorrect = d['lastAnswerCorrect'] as bool?;
        _lastAnswerPoints = d['lastAnswerPoints'] as int? ?? 0;
        debugPrint('[Quiz] Loaded from Firestore for ${_user!.uid}');
      } else {
        // First time — migrate any local prefs data to Firestore
        _loadFromPrefs();
        if (_totalAnswered > 0) {
          unawaited(_saveToFirestore());
          debugPrint('[Quiz] Migrated local data to Firestore for ${_user!.uid}');
        }
      }
    } catch (e, st) {
      debugPrint('[Quiz] Firestore load failed, using local prefs: $e\n$st');
      _loadFromPrefs();
    }
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _saveToFirestore() async {
    final user = _user;
    if (user == null || user.isAnonymous) return;
    try {
      await _firestore.collection(_collection).doc(user.uid).set({
        'displayName': user.displayName ?? 'مستخدم',
        'photoUrl': user.photoURL,
        'totalScore': _totalScore,
        'streak': _streak,
        'correctAnswers': _correctAnswers,
        'totalAnswered': _totalAnswered,
        'lastAnsweredDate': _lastAnsweredDate,
        'answeredIdsJson': jsonEncode(_answeredIds),
        'lastAnswerCorrect': _lastAnswerCorrect,
        'lastAnswerPoints': _lastAnswerPoints,
        'userSeed': _userSeed,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('[Quiz] Saved to Firestore for ${user.uid}');
    } catch (e, st) {
      debugPrint('[Quiz] Firestore save failed: $e\n$st');
    }
  }

  Future<void> _saveToPrefs() async {
    await Future.wait([
      _prefs.setInt(_kScore, _totalScore),
      _prefs.setInt(_kStreak, _streak),
      _prefs.setInt(_kCorrect, _correctAnswers),
      _prefs.setInt(_kTotal, _totalAnswered),
      _prefs.setString(_kLastDate, _lastAnsweredDate ?? ''),
      _prefs.setString(_kAnsweredIds, jsonEncode(_answeredIds)),
      _prefs.setBool(_kLastCorrect, _lastAnswerCorrect ?? false),
      _prefs.setInt(_kLastPoints, _lastAnswerPoints),
    ]);
  }

  // ── Getters (from in-memory cache) ────────────────────────────────────────

  int get totalScore => _totalScore;
  int get streak => _streak;
  int get correctAnswers => _correctAnswers;
  int get totalAnswered => _totalAnswered;
  bool? get lastAnswerCorrect => _lastAnswerCorrect;
  int get lastAnswerPoints => _lastAnswerPoints;
  double get accuracy =>
      _totalAnswered == 0 ? 0.0 : _correctAnswers / _totalAnswered;

  bool get hasAnsweredToday {
    final d = _lastAnsweredDate;
    return d != null && d.isNotEmpty && d == _todayString();
  }

  // ── Today's question ──────────────────────────────────────────────────────

  /// Returns today's question, or null if already answered today.
  QuizQuestion? getTodayQuestion() {
    if (hasAnsweredToday) return null;
    final dayIndex = _answeredIds.length % quizQuestionsPool.length;
    return quizQuestionsPool[_getShuffledOrder()[dayIndex]];
  }

  // ── Submit answer ─────────────────────────────────────────────────────────

  /// Records the answer, updates stats, persists to Firestore or prefs.
  /// Returns true if the answer was correct.
  Future<bool> submitAnswer(int questionId, int selectedIndex) async {
    final question = quizQuestionsPool[questionId];
    final isCorrect = selectedIndex == question.correctIndex;
    final points = isCorrect ? question.points : 0;

    // Update in-memory cache immediately
    _totalScore += points;
    if (isCorrect) {
      final wasYesterday = _wasYesterdayAnswered();
      _streak = (wasYesterday || _streak == 0) ? _streak + 1 : 1;
      _correctAnswers++;
    } else {
      _streak = 0;
    }
    _totalAnswered++;
    _lastAnsweredDate = _todayString();
    _answeredIds.add(questionId);
    _lastAnswerCorrect = isCorrect;
    _lastAnswerPoints = points;

    // Persist — fire-and-forget for Firestore (non-blocking), await for prefs
    if (_isLoggedIn) {
      unawaited(_saveToFirestore());
    } else {
      await _saveToPrefs();
    }

    return isCorrect;
  }

  // ── Leaderboard ───────────────────────────────────────────────────────────

  /// Fetches the top [limit] users sorted by total score descending.
  /// Throws on Firestore error so [LeaderboardCubit] can emit the error state.
  Future<List<LeaderboardEntry>> getTopUsers({int limit = 50}) async {
    final snapshot = await _firestore
        .collection(_collection)
        .orderBy('totalScore', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map(LeaderboardEntry.fromFirestore).toList();
  }

  /// Returns the 1-based rank of [uid], or null if not found.
  Future<int?> getUserRank(String uid) async {
    try {
      final userDoc =
          await _firestore.collection(_collection).doc(uid).get();
      if (!userDoc.exists) return null;
      final userScore =
          (userDoc.data() as Map<String, dynamic>)['totalScore'] as int? ?? 0;
      final higher = await _firestore
          .collection(_collection)
          .where('totalScore', isGreaterThan: userScore)
          .count()
          .get();
      return (higher.count ?? 0) + 1;
    } catch (e, st) {
      debugPrint('[Quiz] getUserRank failed: $e\n$st');
      return null;
    }
  }

  /// Fetches the leaderboard entry for [uid], or null if not found.
  Future<LeaderboardEntry?> getUserEntry(String uid) async {
    try {
      final doc =
          await _firestore.collection(_collection).doc(uid).get();
      if (!doc.exists) return null;
      return LeaderboardEntry.fromFirestore(doc);
    } catch (e, st) {
      debugPrint('[Quiz] getUserEntry failed: $e\n$st');
      return null;
    }
  }

  // ── Notification settings (always device-local) ───────────────────────────

  bool get notificationsEnabled => _prefs.getBool(_kNotifEnabled) ?? true;

  Future<void> setNotificationsEnabled(bool enabled) =>
      _prefs.setBool(_kNotifEnabled, enabled);

  int get reminderHour => _prefs.getInt(_kReminderHour) ?? 20;
  int get reminderMinute => _prefs.getInt(_kReminderMinute) ?? 0;

  Future<void> setReminderTime(int hour, int minute) => Future.wait([
        _prefs.setInt(_kReminderHour, hour),
        _prefs.setInt(_kReminderMinute, minute),
      ]);

  // ── App language ──────────────────────────────────────────────────────────

  String getAppLanguage() => _prefs.getString('app_language') ?? 'ar';

  // ── Private helpers ───────────────────────────────────────────────────────

  int _ensureSeedInPrefs() {
    var seed = _prefs.getInt(_kSeed);
    if (seed == null) {
      seed = DateTime.now().microsecondsSinceEpoch % 1000000;
      _prefs.setInt(_kSeed, seed);
    }
    return seed;
  }

  List<int> _getShuffledOrder() {
    final ids = List<int>.generate(quizQuestionsPool.length, (i) => i);
    ids.shuffle(Random(_userSeed));
    return ids;
  }

  List<int> _parseIds(String? json) {
    if (json == null || json.isEmpty) return [];
    try {
      return (jsonDecode(json) as List).cast<int>();
    } catch (_) {
      return [];
    }
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  bool _wasYesterdayAnswered() {
    final d = _lastAnsweredDate;
    if (d == null || d.isEmpty) return false;
    try {
      final last = DateTime.parse(d);
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      return last.year == yesterday.year &&
          last.month == yesterday.month &&
          last.day == yesterday.day;
    } catch (_) {
      return false;
    }
  }
}
