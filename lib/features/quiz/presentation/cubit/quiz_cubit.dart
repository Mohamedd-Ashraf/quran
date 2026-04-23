import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/quiz_question_model.dart';
import '../../data/quiz_repository.dart';
import '../../services/quiz_notification_service.dart';
import 'quiz_state.dart';

class QuizCubit extends Cubit<QuizState> with WidgetsBindingObserver {
  final QuizRepository _repository;
  final QuizNotificationService _notifService;

  Timer? _timer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  int _remainingSeconds = 0;
  bool _hasSubmitted = false;

  /// Wall-clock time when the question was shown. Used ONLY to compute the
  /// cross-session elapsed time (app kill → reopen). The in-session ticker
  /// uses [_sessionStopwatch] instead, which is monotonic and immune to
  /// device-clock manipulation.
  DateTime? _questionStartTime;
  int _totalTimerSeconds = 0;

  /// Monotonic stopwatch started when the in-session countdown begins.
  /// Counts forward from zero regardless of system clock changes, so rolling
  /// the device clock backward cannot extend the countdown.
  Stopwatch? _sessionStopwatch;

  /// Remaining seconds at the moment the stopwatch was (re)started.
  /// Updated on initial start and again after each app-resume recalculation.
  int _sessionStartRemaining = 0;

  QuizCubit(this._repository, this._notifService) : super(const QuizInitial()) {
    WidgetsBinding.instance.addObserver(this);
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (isOnline) _trySyncPendingAnswer();
    });
  }

  int get remainingSeconds => _remainingSeconds;

  // ── Load ──────────────────────────────────────────────────────────────────

  /// [skipLanding] — when `true`, skips the landing/ready screen and starts
  /// the timer immediately. Pass `true` when the user navigates from within
  /// the app; pass `false` (default) only when arriving from a notification.
  Future<void> load({bool skipLanding = false}) async {
    _hasSubmitted = false;
    _questionStartTime = null;
    _totalTimerSeconds = 0;
    emit(const QuizLoading());

    // Load from Firestore (logged-in) or SharedPrefs (guest)
    await _repository.loadData();

    // Admins bypass the daily-answer limit so they can test freely.
    final isAdmin = await _repository.isAdmin;
    if (_repository.hasAnsweredToday && !isAdmin) {
      emit(QuizAlreadyAnswered(
        totalScore: _repository.totalScore,
        streak: _repository.streak,
        correctAnswers: _repository.correctAnswers,
        totalAnswered: _repository.totalAnswered,
        lastAnswerCorrect: _repository.lastAnswerCorrect,
        lastAnswerPoints: _repository.lastAnswerPoints,
      ));
      return;
    }

    final question = await _repository.getTodayQuestion();
    if (question == null) {
      emit(QuizAlreadyAnswered(
        totalScore: _repository.totalScore,
        streak: _repository.streak,
        correctAnswers: _repository.correctAnswers,
        totalAnswered: _repository.totalAnswered,
        lastAnswerCorrect: _repository.lastAnswerCorrect,
        lastAnswerPoints: _repository.lastAnswerPoints,
      ));
      return;
    }

    // ── Check for a previously-started (and still-running) timer ─────────
    // If the user opened the question, backed out, killed the app, or lost
    // connectivity, the timer start-time was persisted to SharedPrefs.
    // We resume from the actual elapsed wall-clock time instead of resetting.
    final saved = _repository.getActiveTimerState(question.id);
    if (saved != null) {
      if (saved.remainingSeconds <= 0) {
        // Timer expired while the user was away (back-nav, app kill, etc.).
        // Set internal state so _submitAsTimeout can use it, then call it.
        // IMPORTANT: do NOT set _hasSubmitted here — _submitAsTimeout does it.
        // IMPORTANT: do NOT clearTimerState here — _submitAsTimeout does it on success.
        _questionStartTime = saved.startTime;
        _totalTimerSeconds = saved.totalSeconds;
        _remainingSeconds = 0;
        // _submitAsTimeout emits QuizTimeUp immediately before the Firestore write,
        // so the UI updates without waiting for the network.
        await _submitAsTimeout(question);
        return;
      }
      // Resume the countdown from the correct remaining time.
      // Timer state is already saved — no need to re-persist.
      _startTimer(question.timerSeconds, startTime: saved.startTime);
      emit(QuizReady(
        question: question,
        streak: _repository.streak,
        totalScore: _repository.totalScore,
      ));
      return;
    }

    if (skipLanding) {
      // Persist the timer start time BEFORE starting the ticker so the state
      // is on disk even if the app is killed immediately after this point.
      final startTime = DateTime.now();
      await _repository.saveTimerStartTime(
        questionId: question.id,
        startTime: startTime,
        totalSeconds: question.timerSeconds,
      );
      _startTimer(question.timerSeconds, startTime: startTime);
      emit(QuizReady(
        question: question,
        streak: _repository.streak,
        totalScore: _repository.totalScore,
      ));
    } else {
      // Navigated from a notification — show landing screen first so the
      // timer only starts when the user consciously presses "Start".
      emit(QuizReadyToStart(
        question: question,
        streak: _repository.streak,
        totalScore: _repository.totalScore,
      ));
    }
  }

  /// Called when the user presses the "Start" button on the landing screen.
  /// Starts the countdown timer and transitions to [QuizReady].
  Future<void> startQuiz() async {
    final s = state;
    if (s is! QuizReadyToStart) return;
    // Persist BEFORE starting the ticker — survives immediate app kill.
    final startTime = DateTime.now();
    await _repository.saveTimerStartTime(
      questionId: s.question.id,
      startTime: startTime,
      totalSeconds: s.question.timerSeconds,
    );
    _startTimer(s.question.timerSeconds, startTime: startTime);
    emit(QuizReady(
      question: s.question,
      streak: s.streak,
      totalScore: s.totalScore,
    ));
  }

  // ── Timer ─────────────────────────────────────────────────────────────────

  /// Starts (or resumes) the countdown ticker from [startTime].
  /// Does NOT persist state — callers must call [QuizRepository.saveTimerStartTime]
  /// before invoking this method.
  void _startTimer(int seconds, {required DateTime startTime}) {
    _timer?.cancel();
    _sessionStopwatch?.stop();

    _totalTimerSeconds = seconds;
    _questionStartTime = startTime;

    // One-time DateTime.now() call: compute how far we are into this session
    // (matters when resuming after an app kill — cross-session elapsed is fine
    // here since the attacker would have to roll the clock back BEFORE killing
    // the app, giving at most the time elapsed while the app was closed back,
    // which is bounded by [seconds] anyway).
    final crossSessionElapsed =
        DateTime.now().difference(startTime).inSeconds.clamp(0, seconds);
    _sessionStartRemaining = seconds - crossSessionElapsed;
    _remainingSeconds = _sessionStartRemaining;

    // From here the Stopwatch drives the ticker — monotonic, immune to any
    // subsequent system-clock change (forward or backward).
    _sessionStopwatch = Stopwatch()..start();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final elapsed = _sessionStopwatch!.elapsed.inSeconds;
      _remainingSeconds = (_sessionStartRemaining - elapsed).clamp(0, _sessionStartRemaining);
      if (_remainingSeconds <= 0) {
        timer.cancel();
        _onTimeUp();
      }
      // UI reads remainingSeconds via a periodic setState timer in the screen
    });
  }

  /// Called by Flutter when the app transitions to/from background.
  /// If the user has backgrounded the app while a question is active and
  /// the full timer duration has already elapsed, auto-submit as a timeout.
  /// Also retries any pending offline sync on resume.
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      _trySyncPendingAnswer();
    }
    if (lifecycleState == AppLifecycleState.resumed &&
        _questionStartTime != null &&
        !_hasSubmitted) {
      // One-time DateTime.now() call on resume: compute cross-session elapsed
      // (time the app was closed/backgrounded) and recalibrate the remaining
      // seconds. After this, the Stopwatch takes over again — so any clock
      // manipulation that happens AFTER the user reopens the app has no effect.
      final crossSessionElapsed =
          DateTime.now().difference(_questionStartTime!).inSeconds;
      _remainingSeconds =
          (_totalTimerSeconds - crossSessionElapsed).clamp(0, _totalTimerSeconds);
      if (_remainingSeconds <= 0) {
        _timer?.cancel();
        _sessionStopwatch?.stop();
        _onTimeUp();
        return;
      }
      // Reset the Stopwatch from this new baseline so the in-session ticker
      // counts forward from the recalibrated remaining time.
      _sessionStartRemaining = _remainingSeconds;
      _sessionStopwatch = Stopwatch()..start();
    }
  }

  void _onTimeUp() {
    final currentState = state;
    if (currentState is QuizReady) {
      _submitAsTimeout(currentState.question);
    } else if (currentState is QuizAnswerSelected) {
      // Auto-submit the selected answer when time runs out
      submitAnswer(currentState.question.id, currentState.selectedIndex);
    }
  }

  Future<void> _submitAsTimeout(QuizQuestion question) async {
    if (_hasSubmitted) return;
    _hasSubmitted = true;

    // Emit QuizTimeUp IMMEDIATELY — don't block on the Firestore write.
    // Timeout is always wrong (0 points, streak resets to 0), so the values
    // shown are accurate without waiting for the repository to update.
    // The actual submission (and clearTimerState) happen below in the background.
    emit(QuizTimeUp(
      question: question,
      totalScore: _repository.totalScore,
      streak: 0, // timeout = wrong answer = streak resets
    ));

    try {
      // selectedIndex = -1 counts as wrong (no matching correctIndex).
      // submitAnswer already handles offline gracefully via pending-sync.
      await _repository.submitAnswer(question.id, -1);
      await _repository.clearTimerState();
    } catch (e) {
      // QuizTimeUp is already showing — don't revert or re-emit.
      // The pending-sync mechanism will retry when connectivity returns.
      // Do NOT revert _hasSubmitted: we must not re-show the question.
      debugPrint('[Quiz] Timeout submission failed: $e');
    }
  }

  // ── Answer selection ──────────────────────────────────────────────────────

  void selectAnswer(int index) {
    if (_hasSubmitted) return;
    final currentState = state;
    final QuizQuestion? question;
    final int streak;
    final int totalScore;

    if (currentState is QuizReady) {
      question = currentState.question;
      streak = currentState.streak;
      totalScore = currentState.totalScore;
    } else if (currentState is QuizAnswerSelected) {
      question = currentState.question;
      streak = currentState.streak;
      totalScore = currentState.totalScore;
    } else {
      return;
    }

    emit(QuizAnswerSelected(
      question: question,
      selectedIndex: index,
      streak: streak,
      totalScore: totalScore,
    ));
  }

  // ── Submit answer ─────────────────────────────────────────────────────────

  Future<void> submitAnswer(int questionId, int selectedIndex) async {
    if (_hasSubmitted) return;
    _hasSubmitted = true;
    _timer?.cancel();

    final question = (state is QuizAnswerSelected)
        ? (state as QuizAnswerSelected).question
        : (state is QuizReady)
            ? (state as QuizReady).question
            : null;

    if (question == null) return;

    try {
      final isCorrect =
          await _repository.submitAnswer(questionId, selectedIndex);

      // Clear the persisted timer — question is now answered.
      await _repository.clearTimerState();

      emit(QuizResult(
        question: question,
        selectedIndex: selectedIndex,
        isCorrect: isCorrect,
        pointsEarned: isCorrect ? question.points : 0,
        newTotalScore: _repository.totalScore,
        newStreak: _repository.streak,
      ));
    } catch (e) {
      // Revert submission lock so user can retry after resolving the error
      // (e.g. network restored). In-memory state was already reverted by
      // the repository before throwing.
      _hasSubmitted = false;
      _timer?.cancel();
      // Resume from the ORIGINAL start time — not from now. The timer state
      // is still in SharedPrefs (clearTimerState is only called on success),
      // so passing _questionStartTime avoids resetting the clock.
      if (_questionStartTime != null) {
        _startTimer(question.timerSeconds, startTime: _questionStartTime!);
      }
      emit(QuizSubmitError(
        question: question,
        selectedIndex: selectedIndex,
        message: e.toString(),
      ));
    }
  }

  // ── Notification settings ─────────────────────────────────────────────────

  Future<void> setNotificationsEnabled(bool enabled) async {
    await _repository.setNotificationsEnabled(enabled);
    if (!enabled) {
      await _notifService.cancelAll();
    } else {
      await _notifService.scheduleDailyReminder();
    }
  }

  // ── Cleanup ───────────────────────────────────────────────────────────────

  // ── Offline sync ──────────────────────────────────────────────────────────

  Future<void> _trySyncPendingAnswer() async {
    if (!_repository.hasPendingSync) return;
    try {
      final synced = await _repository.syncPendingAnswer();
      if (synced) {
        debugPrint('[Quiz] Offline answer successfully synced to Firestore');
      }
    } catch (e) {
      debugPrint('[Quiz] Pending sync attempt failed: $e');
    }
  }

  @override
  Future<void> close() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _sessionStopwatch?.stop();
    _connectivitySub?.cancel();
    return super.close();
  }
}
