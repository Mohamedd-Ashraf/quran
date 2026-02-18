import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';

import '../services/ayah_audio_service.dart';

enum AyahAudioMode { ayah, surah }

enum AyahAudioStatus { idle, buffering, playing, paused, error }

class AyahAudioState extends Equatable {
  final AyahAudioStatus status;
  final AyahAudioMode mode;
  final int? surahNumber;
  final int? ayahNumber;
  final String? errorMessage;

  const AyahAudioState({
    required this.status,
    this.mode = AyahAudioMode.ayah,
    this.surahNumber,
    this.ayahNumber,
    this.errorMessage,
  });

  const AyahAudioState.idle() : this(status: AyahAudioStatus.idle);

  bool get hasTarget => surahNumber != null && ayahNumber != null;

  bool isCurrent(int s, int a) => surahNumber == s && ayahNumber == a;

  @override
  List<Object?> get props => [
    status,
    mode,
    surahNumber,
    ayahNumber,
    errorMessage,
  ];

  AyahAudioState copyWith({
    AyahAudioStatus? status,
    AyahAudioMode? mode,
    int? surahNumber,
    int? ayahNumber,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AyahAudioState(
      status: status ?? this.status,
      mode: mode ?? this.mode,
      surahNumber: surahNumber ?? this.surahNumber,
      ayahNumber: ayahNumber ?? this.ayahNumber,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AyahAudioCubit extends Cubit<AyahAudioState> {
  final AyahAudioService _service;
  final AudioPlayer _player;

  StreamSubscription<PlayerState>? _playerSub;
  StreamSubscription<int?>? _indexSub;
  bool _initialized = false;

  AyahAudioCubit(this._service)
    : _player = AudioPlayer(),
      super(const AyahAudioState.idle()) {
    _init();
  }

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());

    if (isClosed) return;

    // Ensure playback never loops unless explicitly enabled.
    await _player.setLoopMode(LoopMode.off);
    await _player.setShuffleModeEnabled(false);

    if (isClosed) return;
    _initialized = true;

    _playerSub = _player.playerStateStream.listen((ps) {
      if (isClosed) return;
      final processing = ps.processingState;
      if (processing == ProcessingState.loading ||
          processing == ProcessingState.buffering) {
        emit(
          state.copyWith(status: AyahAudioStatus.buffering, clearError: true),
        );
        return;
      }

      if (processing == ProcessingState.completed) {
        // Auto-hide player by resetting to idle after completion
        emit(const AyahAudioState.idle());
        return;
      }

      if (ps.playing) {
        emit(state.copyWith(status: AyahAudioStatus.playing, clearError: true));
      } else {
        // If we have a target, treat as paused; otherwise idle.
        emit(
          state.copyWith(
            status: state.hasTarget
                ? AyahAudioStatus.paused
                : AyahAudioStatus.idle,
            clearError: true,
          ),
        );
      }
    });

    _indexSub = _player.currentIndexStream.listen((idx) {
      if (isClosed) return;
      if (idx == null) return;
      if (state.mode != AyahAudioMode.surah) return;

      // Get the ayah number from the audio source tag
      final sequence = _player.sequenceState;
      if (sequence != null && idx < sequence.sequence.length) {
        final tag = sequence.sequence[idx].tag;
        if (tag is int) {
          emit(state.copyWith(ayahNumber: tag));
          return;
        }
      }

      // Fallback: assume playlist starts from ayah 1
      emit(state.copyWith(ayahNumber: idx + 1));
    });
  }

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;

  Future<void> togglePlayAyah({
    required int surahNumber,
    required int ayahNumber,
  }) async {
    if (state.mode == AyahAudioMode.ayah &&
        state.isCurrent(surahNumber, ayahNumber) &&
        _player.playing) {
      await pause();
      return;
    }

    await playAyah(surahNumber: surahNumber, ayahNumber: ayahNumber);
  }

  Future<void> playAyah({
    required int surahNumber,
    required int ayahNumber,
  }) async {
    if (!_initialized) {
      // Best-effort: allow _init() to finish.
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    emit(
      AyahAudioState(
        status: AyahAudioStatus.buffering,
        mode: AyahAudioMode.ayah,
        surahNumber: surahNumber,
        ayahNumber: ayahNumber,
      ),
    );

    try {
      final source = await _service.resolveAyahAudio(
        surahNumber: surahNumber,
        ayahNumber: ayahNumber,
      );

      if (source.isLocal) {
        await _player.setAudioSource(AudioSource.file(source.localFilePath!));
      } else {
        await _player.setAudioSource(AudioSource.uri(source.remoteUri!));
      }

      await _player.setLoopMode(LoopMode.off);
      await _player.setShuffleModeEnabled(false);

      await _player.play();
    } catch (e) {
      emit(
        AyahAudioState(
          status: AyahAudioStatus.error,
          mode: AyahAudioMode.ayah,
          surahNumber: surahNumber,
          ayahNumber: ayahNumber,
          errorMessage: e.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  Future<void> togglePlaySurah({
    required int surahNumber,
    required int numberOfAyahs,
  }) async {
    if (state.mode == AyahAudioMode.surah && state.surahNumber == surahNumber) {
      if (_player.playing) {
        await pause();
      } else {
        await resume();
      }
      return;
    }

    await playSurah(surahNumber: surahNumber, numberOfAyahs: numberOfAyahs);
  }

  Future<void> playSurah({
    required int surahNumber,
    required int numberOfAyahs,
  }) async {
    if (!_initialized) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    emit(
      AyahAudioState(
        status: AyahAudioStatus.buffering,
        mode: AyahAudioMode.surah,
        surahNumber: surahNumber,
        ayahNumber: 1,
      ),
    );

    try {
      final sources = await _service.resolveSurahAyahAudio(
        surahNumber: surahNumber,
        numberOfAyahs: numberOfAyahs,
      );

      final children = <AudioSource>[];
      for (var i = 0; i < sources.length; i++) {
        final ayahNumber = i + 1;
        final s = sources[i];
        if (s.isLocal) {
          children.add(AudioSource.file(s.localFilePath!, tag: ayahNumber));
        } else {
          children.add(AudioSource.uri(s.remoteUri!, tag: ayahNumber));
        }
      }

      final playlist = ConcatenatingAudioSource(children: children);
      await _player.setAudioSource(
        playlist,
        initialIndex: 0,
        initialPosition: Duration.zero,
      );
      await _player.setLoopMode(LoopMode.off);
      await _player.setShuffleModeEnabled(false);
      await _player.play();
    } catch (e) {
      emit(
        AyahAudioState(
          status: AyahAudioStatus.error,
          mode: AyahAudioMode.surah,
          surahNumber: surahNumber,
          ayahNumber: 1,
          errorMessage: e.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  /// Plays a specific range of ayahs from a surah
  Future<void> playAyahRange({
    required int surahNumber,
    required int startAyah,
    required int endAyah,
  }) async {
    if (!_initialized) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    emit(
      AyahAudioState(
        status: AyahAudioStatus.buffering,
        mode: AyahAudioMode.surah,
        surahNumber: surahNumber,
        ayahNumber: startAyah,
      ),
    );

    try {
      final children = <AudioSource>[];
      for (var ayahNumber = startAyah; ayahNumber <= endAyah; ayahNumber++) {
        final source = await _service.resolveAyahAudio(
          surahNumber: surahNumber,
          ayahNumber: ayahNumber,
        );

        if (source.isLocal) {
          children.add(
            AudioSource.file(source.localFilePath!, tag: ayahNumber),
          );
        } else {
          children.add(AudioSource.uri(source.remoteUri!, tag: ayahNumber));
        }
      }

      final playlist = ConcatenatingAudioSource(children: children);
      await _player.setAudioSource(
        playlist,
        initialIndex: 0,
        initialPosition: Duration.zero,
      );
      await _player.setLoopMode(LoopMode.off);
      await _player.setShuffleModeEnabled(false);
      await _player.play();
    } catch (e) {
      emit(
        AyahAudioState(
          status: AyahAudioStatus.error,
          mode: AyahAudioMode.surah,
          surahNumber: surahNumber,
          ayahNumber: startAyah,
          errorMessage: e.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  Future<void> pause() async {
    await _player.pause();
    emit(state.copyWith(status: AyahAudioStatus.paused));
  }

  Future<void> resume() async {
    await _player.play();
    emit(state.copyWith(status: AyahAudioStatus.playing));
  }

  Future<void> next() async {
    if (state.mode != AyahAudioMode.surah) return;
    if (!_player.hasNext) return;
    await _player.seekToNext();
  }

  Future<void> previous() async {
    if (state.mode != AyahAudioMode.surah) return;
    if (!_player.hasPrevious) return;
    await _player.seekToPrevious();
  }

  Future<void> stop() async {
    await _player.stop();
    emit(const AyahAudioState.idle());
  }

  @override
  Future<void> close() async {
    await _playerSub?.cancel();
    await _indexSub?.cancel();
    try {
      await _player.stop();
    } catch (_) {}
    await _player.dispose();
    return super.close();
  }
}
