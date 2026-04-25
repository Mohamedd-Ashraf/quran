import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/network_info.dart';
import '../../data/models/quiz_question_model.dart';
import '../../data/quiz_repository.dart';
import '../../services/quiz_notification_service.dart';
import 'quiz_state.dart';

class QuizCubit extends Cubit<QuizState> with WidgetsBindingObserver {
  final QuizRepository _repository;
  final QuizNotificationService _notifService;
  final NetworkInfo _networkInfo;

  Timer? _timer;
  int _remainingSeconds = 0;
  bool _hasSubmitted = false;

  /// Timer for the retry countdown when a submission fails due to no internet.
  Timer? _retryTimer;

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

  QuizCubit(this._repository, this._notifService, this._networkInfo)
      : super(const QuizInitial()) {
    WidgetsBinding.instance.addObserver(this);
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
    _retryTimer?.cancel();

    // Check connectivity BEFORE showing loading indicator — avoids infinite spinner.
    final isConnected = await _networkInfo.isConnected;
    if (!isConnected) {
      emit(const QuizOfflineUnavailable(
        message: 'Connect to the internet to answer today\'s question.',
      ));
      return;
    }

    emit(const QuizLoading());

    if (!_repository.isLoggedIn) {
      emit(const QuizOfflineUnavailable(
        message: 'You need to sign in to answer today\'s question.',
      ));
      return;
    }

    // Load from Firestore for signed-in users.
    try {
      await _repository.loadData();
    } catch (e) {
      emit(QuizOfflineUnavailable(
        message: 'Could not load today\'s question. Check your connection and try again.',
      ));
      return;
    }

    if (_repository.hasAnsweredToday) {
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
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
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

    await _repository.saveLocalAnsweredDate();
    await _repository.savePendingQuestionId(question.id);

    emit(QuizTimeUp(
      question: question,
      totalScore: _repository.totalScore,
      streak: 0,
    ));

    // Check connectivity before attempting Firestore — Firestore offline
    // persistence silently succeeds on local writes, which would bypass our
    // retry/sync logic and give the user a false positive.
    final isConnected = await _networkInfo.isConnected;
    if (!isConnected) {
      await _repository.clearTimerState();
      // Data is saved locally; will be synced on next load() when online.
      return;
    }

    try {
      await _repository.submitAnswer(question.id, -1);
      await _repository.clearPendingQuestionId();
      await _repository.clearTimerState();
    } catch (e) {
      await _repository.clearTimerState();
      debugPrint('[Quiz] Timeout submission failed: $e');
    }
  }

  // ── Answer selection ──────────────────────────────────────────────────────

  void selectAnswer(int index) {
    if (_hasSubmitted) return;
    // Block answer changes during retry hold — user must wait for countdown.
    final currentState = state;
    if (currentState is QuizSubmitError && currentState.retryInProgress > 0) {
      return;
    }
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
    _retryTimer?.cancel();

    final question = (state is QuizAnswerSelected)
        ? (state as QuizAnswerSelected).question
        : (state is QuizReady)
            ? (state as QuizReady).question
        : (state is QuizSubmitError)
            ? (state as QuizSubmitError).question
            : null;

    if (question == null) return;

    // Persist locally BEFORE any network attempt so the question is never
    // shown again today even if the app is killed mid-transaction.
    await _repository.saveLocalAnsweredDate();
    await _repository.savePendingQuestionId(questionId);

    // Check connectivity BEFORE attempting Firestore.  Firestore offline
    // persistence silently completes local writes without throwing, which
    // would bypass our retry mechanism and give the user a false positive
    // — the answer appears saved locally but may never reach the server.
    final isConnected = await _networkInfo.isConnected;
    if (!isConnected) {
      _hasSubmitted = false;
      _timer?.cancel();
      _startRetryCountdown(question, selectedIndex, 'No internet connection.');
      return;
    }

    try {
      final isCorrect =
          await _repository.submitAnswer(questionId, selectedIndex);

      await _repository.clearPendingQuestionId();
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
      // Firestore write failed despite connectivity check (e.g. security rule
      // rejection, transient server error). Fall through to retry flow.
      _hasSubmitted = false;
      _timer?.cancel();
      _startRetryCountdown(question, selectedIndex, e.toString());
    }
  }

  void _startRetryCountdown(QuizQuestion question, int selectedIndex, String error) {
    int secondsLeft = 5;
    emit(QuizSubmitError(
      question: question,
      selectedIndex: selectedIndex,
      message: error,
      retryInProgress: secondsLeft,
    ));

    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      secondsLeft--;
      if (secondsLeft <= 0) {
        timer.cancel();
        // Countdown done — retry once, then give up if it fails again.
        _retrySubmit(question.id, selectedIndex);
      } else {
        emit(QuizSubmitError(
          question: question,
          selectedIndex: selectedIndex,
          message: error,
          retryInProgress: secondsLeft,
        ));
      }
    });
  }

  Future<void> _retrySubmit(int questionId, int selectedIndex) async {
    final question = (state is QuizSubmitError)
        ? (state as QuizSubmitError).question
        : null;
    if (question == null) return;

    final isConnected = await _networkInfo.isConnected;
    if (!isConnected) {
      emit(QuizSubmitError(
        question: question,
        selectedIndex: selectedIndex,
        message: 'No internet connection.',
        retryInProgress: 0,
      ));
      return;
    }

    try {
      final isCorrect =
          await _repository.submitAnswer(questionId, selectedIndex);
      await _repository.clearPendingQuestionId();
      await _repository.clearTimerState();

      emit(QuizResult(
        question: question,
        selectedIndex: selectedIndex,
        isCorrect: isCorrect,
        pointsEarned: isCorrect ? question.points : 0,
        newTotalScore: _repository.totalScore,
        newStreak: _repository.streak,
      ));
    } catch (_) {
      emit(QuizSubmitError(
        question: question,
        selectedIndex: selectedIndex,
        message: 'Could not save. Please try again later.',
        retryInProgress: 0,
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

  @override
  Future<void> close() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _retryTimer?.cancel();
    _sessionStopwatch?.stop();
    return super.close();
  }
}
