import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/services/settings_service.dart';
import '../../data/models/leaderboard_entry.dart';
import '../../data/quiz_repository.dart';
import 'leaderboard_state.dart';

class LeaderboardCubit extends Cubit<LeaderboardState> {
  final QuizRepository _repository;

  LeaderboardCubit(this._repository) : super(const LeaderboardInitial());

  // ── Load leaderboard ──────────────────────────────────────────────────────

  Future<void> load() async {
    // DEBUG: log cubit lifecycle
    print('[LeaderboardCubit] load() called — isClosed=$isClosed');
    if (isClosed) {
      print('[LeaderboardCubit] load() called after close — aborting early');
      return;
    }

    emit(const LeaderboardLoading());

    try {
      // Ensure in-memory data is fresh (needed for guest user stats)
      print('[LeaderboardCubit] calling _repository.loadData() ��� isClosed=$isClosed');
      await _repository.loadData();

      // DEBUG: check if cubit was closed while awaiting loadData
      print('[LeaderboardCubit] after loadData() — isClosed=$isClosed');
      if (isClosed) {
        print('[LeaderboardCubit] cubit closed after loadData() — aborting (this confirms navigation-away as root cause)');
        return;
      }

      final entries = await _repository.getTopUsers(limit: 50);
      final user = FirebaseAuth.instance.currentUser;

      // DEBUG: check if cubit was closed while awaiting getTopUsers
      print('[LeaderboardCubit] after getTopUsers() — isClosed=$isClosed, entries=${entries.length}');
      if (isClosed) {
        print('[LeaderboardCubit] cubit closed after getTopUsers() — aborting');
        return;
      }

      int? userRank;
      LeaderboardEntry? userEntry;

      if (user != null && !user.isAnonymous) {
        // Fetch rank and entry in parallel
        print('[LeaderboardCubit] calling Future.wait for rank+entry — isClosed=$isClosed');
        final results = await Future.wait([
          _repository.getUserRank(user.uid),
          _repository.getUserEntry(user.uid),
        ]);
        // DEBUG: check if cubit was closed while awaiting Future.wait
        print('[LeaderboardCubit] after Future.wait — isClosed=$isClosed');
        if (isClosed) {
          print('[LeaderboardCubit] cubit closed after Future.wait — aborting (confirms back-navigation during Firestore fetch)');
          return;
        }
        userRank = results[0] as int?;
        userEntry = results[1] as LeaderboardEntry?;

        // User answered but Firestore write is still in-flight — show local data
        if (userEntry == null && _repository.totalAnswered > 0) {
          userEntry = LeaderboardEntry(
            uid: user.uid,
            displayName: user.displayName ?? (di.sl<SettingsService>().getAppLanguage() == 'ar' ? 'مستخدم' : 'User'),
            photoUrl: user.photoURL,
            totalScore: _repository.totalScore,
            streak: _repository.streak,
            correctAnswers: _repository.correctAnswers,
            totalAnswered: _repository.totalAnswered,
          );
        }
      } else {
        // Guest — show local stats, not on the public board
        if (_repository.totalAnswered > 0) {
          userEntry = LeaderboardEntry(
            uid: 'local',
            displayName: di.sl<SettingsService>().getAppLanguage() == 'ar' ? 'أنت' : 'You',
            totalScore: _repository.totalScore,
            streak: _repository.streak,
            correctAnswers: _repository.correctAnswers,
            totalAnswered: _repository.totalAnswered,
          );
        }
      }

      // DEBUG: final guard before emitting loaded state
      print('[LeaderboardCubit] about to emit LeaderboardLoaded — isClosed=$isClosed');
      if (isClosed) {
        print('[LeaderboardCubit] cubit closed before final emit — aborting');
        return;
      }

      emit(LeaderboardLoaded(
        entries: entries,
        currentUserRank: userRank,
        currentUserEntry: userEntry,
      ));
    } catch (e) {
      print('[LeaderboardCubit] caught error — isClosed=$isClosed, error=$e');
      if (isClosed) {
        print('[LeaderboardCubit] cubit already closed — suppressing error emit');
        return;
      }
      emit(LeaderboardError(e.toString()));
    }
  }
}
