import 'package:equatable/equatable.dart';
import '../../data/models/leaderboard_entry.dart';

abstract class LeaderboardState extends Equatable {
  const LeaderboardState();

  @override
  List<Object?> get props => [];
}

class LeaderboardInitial extends LeaderboardState {
  const LeaderboardInitial();
}

class LeaderboardLoading extends LeaderboardState {
  const LeaderboardLoading();
}

class LeaderboardLoaded extends LeaderboardState {
  final List<LeaderboardEntry> entries;
  final int? currentUserRank;
  final LeaderboardEntry? currentUserEntry;

  const LeaderboardLoaded({
    required this.entries,
    this.currentUserRank,
    this.currentUserEntry,
  });

  @override
  List<Object?> get props => [entries.length, currentUserRank];
}

class LeaderboardError extends LeaderboardState {
  final String message;
  const LeaderboardError(this.message);

  @override
  List<Object?> get props => [message];
}
