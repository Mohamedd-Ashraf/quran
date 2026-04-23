import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
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

  // ── Pending offline-sync keys ─────────────────────────────────────────────
  static const _kPendingSync = 'quiz_pending_sync';
  static const _kPendingSyncDate = 'quiz_pending_sync_date';

  // ── Active-timer persistence keys ────────────────────────────────────────
  // These let us resume the correct countdown when the user leaves and returns
  // to the quiz mid-session (back navigation, app kill, etc.).
  static const _kTimerQuestionId    = 'quiz_timer_question_id';
  static const _kTimerStartMs       = 'quiz_timer_start_ms';
  static const _kTimerTotalSeconds  = 'quiz_timer_total_seconds';

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

  /// The shuffled question served today; used by [submitAnswer] to validate
  /// the user's choice against the shuffled [correctIndex].
  QuizQuestion? _todayShuffledQuestion;

  /// The server-side timestamp of the user's last answer (from Firestore).
  /// Stored as UTC. Used to derive [_lastAnsweredDate] so the date check
  /// is based on server time, not the device clock.
  DateTime? _lastAnsweredServerTimestamp;

  /// The current UTC time as reported by the Firestore server, fetched once
  /// per [loadData] call.  Used by [_todayString] so that device-clock
  /// manipulation cannot trick the client into showing a new question when
  /// the user has already answered today.
  DateTime? _serverNowUtc;

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
    // Always apply any locally-saved pending answer, regardless of whether
    // Firestore succeeded or fell back to prefs. Without this, an app that
    // can't reach Firestore shows stale pre-answer score/streak.
    _applyPendingLocalAnswerIfValid();
  }

  void _loadFromPrefs() {
    _serverNowUtc = null; // guests use device time; no server sync needed
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
        _answeredIds = _parseIds(d['answeredIdsJson'] as String?);
        _lastAnswerCorrect = d['lastAnswerCorrect'] as bool?;
        _lastAnswerPoints = d['lastAnswerPoints'] as int? ?? 0;
        // Derive _lastAnsweredDate from the SERVER timestamp (UTC).
        // This is the key anti-cheat: the date string is always based on
        // what Firestore recorded, never on the device clock at write time.
        // Even if the user manipulates their device date, the next loadData()
        // call restores the correct server-sourced date here.
        final ts = d['lastAnsweredTimestamp'];
        if (ts is Timestamp) {
          _lastAnsweredServerTimestamp = ts.toDate().toUtc();
          final dt = _lastAnsweredServerTimestamp!;
          _lastAnsweredDate = '${dt.year}-'
              '${dt.month.toString().padLeft(2, '0')}-'
              '${dt.day.toString().padLeft(2, '0')}';
        } else {
          _lastAnsweredServerTimestamp = null;
          _lastAnsweredDate = d['lastAnsweredDate'] as String?;
        }
        // Fetch authoritative server time so _todayString() is not
        // influenced by the device clock (guards against clock-advance cheats).
        // Condition: any user who has answered before (has a lastAnsweredDate),
        // including old documents that pre-date the lastAnsweredTimestamp field.
        if (_lastAnsweredDate != null && _lastAnsweredDate!.isNotEmpty) {
          _serverNowUtc = await _fetchServerNow();
        }
        debugPrint('[Quiz] Loaded from Firestore for ${_user!.uid}');
      } else {
        // First sign-in: preserve question history and seed from local prefs
        // so the user continues their question sequence and cannot re-answer
        // questions. Score counters are intentionally reset to 0 on Firestore
        // to prevent SharedPrefs manipulation (score inflation attack).
        _userSeed = _ensureSeedInPrefs();
        _answeredIds = _parseIds(_prefs.getString(_kAnsweredIds));
        _lastAnsweredDate = _prefs.getString(_kLastDate);
        _totalScore = 0;
        _streak = 0;
        _correctAnswers = 0;
        _totalAnswered = 0;
        _lastAnswerCorrect = null;
        _lastAnswerPoints = 0;
        await _saveToFirestore();
        debugPrint('[Quiz] Initialized Firestore document for ${_user!.uid}');
      }
    } catch (e, st) {
      debugPrint('[Quiz] Firestore load failed, using local prefs: $e\n$st');
      _loadFromPrefs();
    }
    // Note: _applyPendingLocalAnswerIfValid() is called in loadData() after
    // this returns, so it runs regardless of Firestore success or fallback.
  }

  /// Overlays the locally-saved post-answer data when there is a pending sync
  /// for today AND Firestore doesn't already show an answer for today.
  void _applyPendingLocalAnswerIfValid() {
    if (!hasPendingSync) return;
    final pendingDate = _prefs.getString(_kPendingSyncDate) ?? '';
    if (pendingDate != _todayString()) {
      // Pending is stale (different day) — discard.
      _clearPendingSync();
      return;
    }
    if (hasAnsweredToday) {
      // Firestore already has today's answer — pending is no longer needed.
      _clearPendingSync();
      return;
    }
    // Override in-memory state with locally saved post-answer values.
    _totalScore = _prefs.getInt(_kScore) ?? _totalScore;
    _streak = _prefs.getInt(_kStreak) ?? _streak;
    _correctAnswers = _prefs.getInt(_kCorrect) ?? _correctAnswers;
    _totalAnswered = _prefs.getInt(_kTotal) ?? _totalAnswered;
    _lastAnsweredDate = pendingDate;
    _answeredIds = _parseIds(_prefs.getString(_kAnsweredIds));
    _lastAnswerCorrect = _prefs.getBool(_kLastCorrect);
    _lastAnswerPoints = _prefs.getInt(_kLastPoints) ?? 0;
    debugPrint('[Quiz] Applied pending offline answer to in-memory state');
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  /// Saves quiz state to Firestore.
  ///
  /// When [isAnswer] is true (i.e. the user just answered a question),
  /// a server-side `lastAnsweredTimestamp` is written so that Firestore
  /// security rules can enforce the calendar-day check.
  ///
  /// Returns `true` on success, `false` on any failure.
  Future<bool> _saveToFirestore({bool isAnswer = false}) async {
    final user = _user;
    if (user == null || user.isAnonymous) return false;
    try {
      final data = <String, dynamic>{
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
      };
      if (isAnswer) {
        data['lastAnsweredTimestamp'] = FieldValue.serverTimestamp();
      }
      await _firestore.collection(_collection).doc(user.uid).set(
            data,
            SetOptions(merge: true),
          );
      debugPrint('[Quiz] Saved to Firestore for ${user.uid}');
      return true;
    } catch (e, st) {
      debugPrint('[Quiz] Firestore save failed: $e\n$st');
      return false;
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
    // _lastAnsweredDate is derived from the server timestamp (UTC) for
    // authenticated users (see _loadFromFirestore). _todayString() also
    // uses UTC. So this comparison is immune to device-clock manipulation:
    // even if the user advances their device date, the server-sourced date
    // is loaded fresh from Firestore on every app open and overrides any
    // local value. The Firestore security rule (UTC day-number comparison)
    // is the authoritative hard enforcement.
    final d = _lastAnsweredDate;
    return d != null && d.isNotEmpty && d == _todayString();
  }

  // ── Today's question ──────────────────────────────────────────────────────

  /// Returns true if the currently signed-in user is the admin.
  Future<bool> _isAdmin() async {
    final uid = _user?.uid;
    if (uid == null) return false;

    final remoteConfig = FirebaseRemoteConfig.instance;
    try {
      await remoteConfig.fetchAndActivate();
    } catch (_) {
      // Keep last activated value when fetch fails.
    }

    final adminUid = remoteConfig.getString('admin_uid').trim();
    return adminUid.isNotEmpty && uid.trim() == adminUid;
  }

  /// Public getter so the cubit can also bypass admin checks.
  Future<bool> get isAdmin => _isAdmin();

  /// Returns today's question, or null if already answered today.
  /// Admin users bypass the daily answer limit and can answer multiple times.
  Future<QuizQuestion?> getTodayQuestion() async {
    // Allow admin to bypass the daily limit
    final isAdmin = await _isAdmin();
    if (hasAnsweredToday && !isAdmin) return null;
    final dayIndex = _answeredIds.length % quizQuestionsPool.length;
    final base = quizQuestionsPool[_getShuffledOrder()[dayIndex]];
    // Shuffle the four options using a deterministic seed derived from the
    // user's personal seed and the question id, so the order is consistent
    // if the app restarts mid-question but differs per-user and per-question.
    final rng = Random(_userSeed ^ (base.id * 2654435761));
    _todayShuffledQuestion = base.shuffleOptions(rng);
    return _todayShuffledQuestion;
  }

  // ── Submit answer ─────────────────────────────────────────────────────────

  /// Records the answer, updates stats, persists to Firestore or prefs.
  /// Returns true if the answer was correct.
  /// Throws [Exception] if the authenticated user's Firestore write is rejected
  /// (e.g. security-rule violation), so the UI can show an error instead of
  /// phantom points.
  Future<bool> submitAnswer(int questionId, int selectedIndex) async {
    // Use the shuffled question (with updated correctIndex) if available;
    // fall back to the pool entry for safety (e.g. admin re-answer flows).
    final question = (_todayShuffledQuestion?.id == questionId)
        ? _todayShuffledQuestion!
        : quizQuestionsPool[questionId];
    final isCorrect = selectedIndex == question.correctIndex;
    final points = isCorrect ? question.points : 0;

    // Update in-memory cache immediately.
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
    // Approximate server timestamp; will be overwritten with real value
    // from Firestore on the next loadData() call.
    _lastAnsweredServerTimestamp = DateTime.now();

    // Persist — await Firestore write to ensure server-side rules validate
    // the submission (anti-cheat). For guests, save to local prefs.
    if (_isLoggedIn) {
      final saved = await _saveToFirestore(isAnswer: true);
      if (!saved) {
        // Firestore write failed (offline or transient error).
        // Accept the answer locally and schedule a sync for when connectivity
        // returns. Do NOT revert in-memory state — the user gets the result now.
        await _saveToPrefs();
        await _prefs.setBool(_kPendingSync, true);
        await _prefs.setString(_kPendingSyncDate, _todayString());
        debugPrint('[Quiz] Offline: answer saved locally, pending Firestore sync.');
      }
    } else {
      await _saveToPrefs();
    }

    return isCorrect;
  }

  // ── Active-timer state ───────────────────────────────────────────────────

  /// Persists the moment the countdown timer started for [questionId].
  /// Called by [QuizCubit._startTimer] so the start time survives app kills
  /// and back-navigation (a new cubit can resume from the correct remaining
  /// time instead of restarting the clock).
  Future<void> saveTimerStartTime({
    required int questionId,
    required DateTime startTime,
    required int totalSeconds,
  }) async {
    await Future.wait([
      _prefs.setInt(_kTimerQuestionId, questionId),
      _prefs.setInt(_kTimerStartMs, startTime.millisecondsSinceEpoch),
      _prefs.setInt(_kTimerTotalSeconds, totalSeconds),
    ]);
  }

  /// Clears the persisted timer state.
  /// Called after the user submits an answer or the timer expires.
  Future<void> clearTimerState() async {
    await Future.wait([
      _prefs.remove(_kTimerQuestionId),
      _prefs.remove(_kTimerStartMs),
      _prefs.remove(_kTimerTotalSeconds),
    ]);
  }

  /// Returns the persisted timer state for [questionId], or null if none is
  /// stored or the stored state belongs to a different question.
  ///
  /// The returned record:
  ///  - `startTime`    — wall-clock moment the timer started
  ///  - `totalSeconds` — the original total duration
  ///  - `elapsedSeconds` — seconds elapsed since `startTime` (using DateTime.now())
  ///  - `remainingSeconds` — clamped to [0, totalSeconds]
  ({
    DateTime startTime,
    int totalSeconds,
    int elapsedSeconds,
    int remainingSeconds,
  })? getActiveTimerState(int questionId) {
    final storedId = _prefs.getInt(_kTimerQuestionId);
    if (storedId != questionId) return null;

    final startMs = _prefs.getInt(_kTimerStartMs);
    final total   = _prefs.getInt(_kTimerTotalSeconds);
    if (startMs == null || total == null) return null;

    final startTime = DateTime.fromMillisecondsSinceEpoch(startMs);
    final elapsed   = DateTime.now().difference(startTime).inSeconds;
    final remaining = (total - elapsed).clamp(0, total);

    return (
      startTime: startTime,
      totalSeconds: total,
      elapsedSeconds: elapsed,
      remainingSeconds: remaining,
    );
  }

  // ── Offline sync ──────────────────────────────────────────────────────────

  bool get hasPendingSync => _prefs.getBool(_kPendingSync) ?? false;

  /// Attempts to push the locally-saved offline answer to Firestore.
  /// Returns true if the sync succeeded (or was no longer needed).
  Future<bool> syncPendingAnswer() async {
    if (!hasPendingSync) return false;
    if (!_isLoggedIn) {
      await _clearPendingSync();
      return false;
    }
    // Load fresh Firestore state, which also calls _applyPendingLocalAnswerIfValid
    // so in-memory state reflects the pending answer.
    await loadData();

    // If pending was stale or already synced during loadData, we're done.
    if (!hasPendingSync) return true;

    // In-memory state now has the pending answer applied; write it to Firestore.
    final saved = await _saveToFirestore(isAnswer: true);
    if (saved) {
      await _clearPendingSync();
      debugPrint('[Quiz] Pending offline answer synced to Firestore.');
      return true;
    }
    debugPrint('[Quiz] Pending sync still failing (still offline?).');
    return false;
  }

  Future<void> _clearPendingSync() async {
    await _prefs.remove(_kPendingSync);
    await _prefs.remove(_kPendingSyncDate);
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
    // When the user completes all 360 questions and cycles back, mix
    // the seed with the cycle number so the order differs each round.
    final cycle = _answeredIds.length ~/ quizQuestionsPool.length;
    final ids = List<int>.generate(quizQuestionsPool.length, (i) => i);
    ids.shuffle(Random(_userSeed + cycle * 7919)); // 7919 = large prime
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

  /// Returns today's date as "YYYY-MM-DD" using the Firestore server clock
  /// ([_serverNowUtc]) when available, falling back to device UTC.
  /// This prevents device-clock manipulation from bypassing the daily limit.
  String _todayString() {
    final now = _serverNowUtc ?? DateTime.now().toUtc();
    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  bool _wasYesterdayAnswered() {
    final d = _lastAnsweredDate;
    if (d == null || d.isEmpty) return false;
    try {
      final last = DateTime.parse(d);
      final yesterday =
          (_serverNowUtc ?? DateTime.now().toUtc()).subtract(const Duration(days: 1));
      return last.year == yesterday.year &&
          last.month == yesterday.month &&
          last.day == yesterday.day;
    } catch (_) {
      return false;
    }
  }

  /// Writes a server timestamp to a lightweight per-user document and reads
  /// it back, returning the Firestore server's current UTC time.
  /// Costs 1 Firestore write + 1 read per call; only called when the user
  /// has a prior quiz answer (to keep costs minimal for new users).
  /// Uses the existing `users/{uid}/data/_quiz_ping` path whose rules
  /// are already deployed, avoiding the need for a separate collection.
  Future<DateTime?> _fetchServerNow() async {
    try {
      final ref =
          _firestore.doc('users/${_user!.uid}/data/_quiz_ping');
      await ref.set({'ts': FieldValue.serverTimestamp()});
      final snap = await ref.get();
      final ts = snap.get('ts');
      if (ts is Timestamp) return ts.toDate().toUtc();
    } catch (e) {
      debugPrint('[Quiz] _fetchServerNow failed (falling back to device): $e');
    }
    return null;
  }
}
