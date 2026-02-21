import 'package:equatable/equatable.dart';
import '../../../core/services/offline_audio_service.dart';

// ──────────────────────────────────────────────────────────────
//  States
// ──────────────────────────────────────────────────────────────

abstract class DownloadManagerState extends Equatable {
  const DownloadManagerState();

  @override
  List<Object?> get props => [];
}

/// Nothing is happening; no saved session exists.
class DownloadIdle extends DownloadManagerState {
  const DownloadIdle();
}

/// A previous session was found in storage — user can resume or dismiss.
class DownloadResumable extends DownloadManagerState {
  final String edition;
  final List<int> pendingSurahs;
  final List<int> completedSurahs;
  final int totalSurahs;
  final String mode; // 'all' | 'selective'
  final DateTime? startedAt;

  const DownloadResumable({
    required this.edition,
    required this.pendingSurahs,
    required this.completedSurahs,
    required this.totalSurahs,
    required this.mode,
    this.startedAt,
  });

  int get remaining => pendingSurahs.length;
  int get completed => completedSurahs.length;
  double get percent =>
      totalSurahs == 0 ? 0 : completed / totalSurahs * 100;

  @override
  List<Object?> get props =>
      [edition, pendingSurahs, completedSurahs, totalSurahs, mode, startedAt];
}

/// Preparing download list (fetching URLs from API).
class DownloadInitializing extends DownloadManagerState {
  final int currentSurah;
  final int totalSurahs;

  const DownloadInitializing({
    required this.currentSurah,
    required this.totalSurahs,
  });

  @override
  List<Object?> get props => [currentSurah, totalSurahs];
}

/// Download is running.
class DownloadInProgress extends DownloadManagerState {
  final OfflineAudioProgress progress;
  final List<int> completedSurahs;
  final List<int> pendingSurahs;
  final int totalSurahs;
  final String edition;

  const DownloadInProgress({
    required this.progress,
    required this.completedSurahs,
    required this.pendingSurahs,
    required this.totalSurahs,
    required this.edition,
  });

  double get surahPercent =>
      totalSurahs == 0 ? 0 : completedSurahs.length / totalSurahs * 100;

  // Each DownloadInProgress emission must always reach the UI, even if the
  // list contents haven't changed yet. Use identity equality so that BLoC
  // never deduplicates two consecutive progress states.
  @override
  bool operator ==(Object other) => identical(this, other);

  @override
  int get hashCode => identityHashCode(this);

  @override
  List<Object?> get props =>
      [progress, completedSurahs, pendingSurahs, totalSurahs, edition];
}

/// User requested cancel; download is winding down.
class DownloadCancelling extends DownloadManagerState {
  const DownloadCancelling();
}

/// Finished successfully.
class DownloadCompleted extends DownloadManagerState {
  final int totalFiles;
  final String edition;

  const DownloadCompleted({required this.totalFiles, required this.edition});

  @override
  List<Object?> get props => [totalFiles, edition];
}

/// Ended with an error (network, API, etc.).
class DownloadFailed extends DownloadManagerState {
  final String message;
  final List<int> completedSurahs;
  final List<int> pendingSurahs;
  /// True when the failure is a network/DNS outage (not a server or app error).
  final bool isNetworkError;

  const DownloadFailed({
    required this.message,
    required this.completedSurahs,
    required this.pendingSurahs,
    this.isNetworkError = false,
  });

  bool get hasProgress => completedSurahs.isNotEmpty;

  @override
  List<Object?> get props =>
      [message, completedSurahs, pendingSurahs, isNetworkError];
}
