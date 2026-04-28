import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';


import '../services/ayah_audio_service.dart';
import '../services/adhan_notification_service.dart';
import '../services/offline_audio_service.dart';
import '../di/injection_container.dart' as di;
import '../services/settings_service.dart';

enum AyahAudioMode { ayah, surah, word, radio }

enum AyahAudioStatus { idle, buffering, playing, paused, error }

class AyahAudioState extends Equatable {
  final AyahAudioStatus status;
  final AyahAudioMode mode;
  final int? surahNumber;
  final int? ayahNumber;
  final String? errorMessage;
  /// 0-based index in the surah queue (0 when not in queue mode).
  final int queueIndex;
  /// Total number of surahs in the queue (0 = not in queue mode).
  final int queueTotal;
  /// 1-based word index within the ayah (only set in word mode).
  final int? wordIndex;
  final String? liveStreamUrl;
  final String? mediaTitle;
  final String? mediaSubtitle;

  const AyahAudioState({
    required this.status,
    this.mode = AyahAudioMode.ayah,
    this.surahNumber,
    this.ayahNumber,
    this.errorMessage,
    this.queueIndex = 0,
    this.queueTotal = 0,
    this.wordIndex,
    this.liveStreamUrl,
    this.mediaTitle,
    this.mediaSubtitle,
  });

  const AyahAudioState.idle()
      : status = AyahAudioStatus.idle,
        mode = AyahAudioMode.ayah,
        surahNumber = null,
        ayahNumber = null,
        errorMessage = null,
        queueIndex = 0,
        queueTotal = 0,
          wordIndex = null,
          liveStreamUrl = null,
          mediaTitle = null,
          mediaSubtitle = null;

  bool get hasTarget => surahNumber != null && ayahNumber != null;
        bool get isLiveStream => mode == AyahAudioMode.radio && liveStreamUrl != null;
        bool get hasPlayableTarget => hasTarget || isLiveStream;
  bool get isQueueMode => queueTotal > 1;

  bool isCurrent(int s, int a) => surahNumber == s && ayahNumber == a;
  bool isCurrentWord(int s, int a, int w) =>
      mode == AyahAudioMode.word && surahNumber == s && ayahNumber == a && wordIndex == w;

  @override
  List<Object?> get props => [
    status,
    mode,
    surahNumber,
    ayahNumber,
    errorMessage,
    queueIndex,
    queueTotal,
    wordIndex,
    liveStreamUrl,
    mediaTitle,
    mediaSubtitle,
  ];

  AyahAudioState copyWith({
    AyahAudioStatus? status,
    AyahAudioMode? mode,
    int? surahNumber,
    int? ayahNumber,
    String? errorMessage,
    bool clearError = false,
    int? queueIndex,
    int? queueTotal,
    int? wordIndex,
    bool clearWordIndex = false,
    String? liveStreamUrl,
    String? mediaTitle,
    String? mediaSubtitle,
    bool clearLiveStream = false,
  }) {
    return AyahAudioState(
      status: status ?? this.status,
      mode: mode ?? this.mode,
      surahNumber: surahNumber ?? this.surahNumber,
      ayahNumber: ayahNumber ?? this.ayahNumber,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      queueIndex: queueIndex ?? this.queueIndex,
      queueTotal: queueTotal ?? this.queueTotal,
      wordIndex: clearWordIndex ? null : (wordIndex ?? this.wordIndex),
      liveStreamUrl: clearLiveStream ? null : (liveStreamUrl ?? this.liveStreamUrl),
      mediaTitle: clearLiveStream ? null : (mediaTitle ?? this.mediaTitle),
      mediaSubtitle: clearLiveStream ? null : (mediaSubtitle ?? this.mediaSubtitle),
    );
  }
}

/// A single item in a structured audio queue that supports both full-surah
/// and ayah-range playback.
sealed class AyahAudioQueueItem {
  const AyahAudioQueueItem._();

  factory AyahAudioQueueItem.fullSurah({
    required int surahNumber,
    required int numberOfAyahs,
  }) = _FullSurahQueueItem;

  factory AyahAudioQueueItem.ayahRange({
    required int surahNumber,
    required int startAyah,
    required int endAyah,
  }) = _AyahRangeQueueItem;
}

final class _FullSurahQueueItem extends AyahAudioQueueItem {
  final int surahNumber;
  final int numberOfAyahs;
  const _FullSurahQueueItem({
    required this.surahNumber,
    required this.numberOfAyahs,
  }) : super._();
}

final class _AyahRangeQueueItem extends AyahAudioQueueItem {
  final int surahNumber;
  final int startAyah;
  final int endAyah;
  const _AyahRangeQueueItem({
    required this.surahNumber,
    required this.startAyah,
    required this.endAyah,
  }) : super._();
}

// ── Artwork cache helper ──────────────────────────────────────────────────────
// audio_service promotes file:// artwork to native `artCacheFile` metadata.
// We copy Flutter assets to temp files once, then reuse those file URIs so
// foreground media notifications can load stable local artwork.
final _artworkUriCache = <String, Uri>{};

Future<Uri?> _resolveArtworkUri(String assetPath) async {
  if (_artworkUriCache.containsKey(assetPath)) {
    return _artworkUriCache[assetPath];
  }
  try {
    final cacheDir = await getTemporaryDirectory();
    final fileName = assetPath.replaceAll('/', '_').replaceAll(' ', '_');
    final file = File('${cacheDir.path}/$fileName');
    if (!await file.exists()) {
      final data = await rootBundle.load(assetPath);
      await file.writeAsBytes(data.buffer.asUint8List());
    }
    final uri = Uri.file(file.path);
    _artworkUriCache[assetPath] = uri;
    return uri;
  } catch (_) {
    return null;
  }
}

class AyahAudioCubit extends Cubit<AyahAudioState> {
  final AyahAudioService _service;
  final AudioPlayer _player;
  final AdhanNotificationService _adhanService;

  StreamSubscription<PlayerState>? _playerSub;
  StreamSubscription<int?>? _indexSub;
  StreamSubscription<Duration?>? _durationCacheSub;
  bool _initialized = false;

  /// Cached artwork URIs (resolved from Flutter assets to temp files).
  Uri? _telawahArtUri;
  Uri? _radioArtUri;

  Future<Uri?> _telawahArt() async =>
      _telawahArtUri ??= await _resolveArtworkUri('assets/logo/files/quraan telawa.jpg');

  Future<Uri?> _radioArt() async =>
      _radioArtUri ??= await _resolveArtworkUri('assets/logo/files/islam radio.jpg');

  // ── Surah queue ───────────────────────────────────────────────────────────
  /// Items waiting to be played.  Each item is a surah + ayah-count pair.
  List<({int surahNumber, int numberOfAyahs})> _surahQueue = [];
  int _surahQueueIndex = 0;

  // ── Structured queue (supports ayah ranges) ───────────────────────────────
  List<AyahAudioQueueItem> _structuredQueue = [];
  int _structuredQueueIndex = 0;

  // ── Playlist progress tracking ────────────────────────────────────────────
  /// Total items in the playlist (ayahs + silence items interleaved).
  int _playlistLength = 1;
  /// Number of ayah items only (excludes silence gaps).
  int _ayahCount = 1;
  /// Ayah number of the first item in the playlist (1 for full surahs,
  /// [startAyah] for range playback).
  int _firstAyahNumber = 1;
  /// Index of the item currently being played.
  int _currentItemIndex = 0;
  /// Known duration for each completed / loaded playlist item.
  final Map<int, Duration> _itemDurations = {};
  /// Sum of durations of all items that have already *finished* playing.
  Duration _accumulatedDuration = Duration.zero;
  /// Silence gap injected between consecutive ayahs.
  static const Duration _ayahGap = Duration.zero;
  /// Tag used on SilenceAudioSource items so we can identify them.
  static const String _kSilenceTag = 'silence';
  /// True while [seekToAbsolute] is in progress.
  /// Suppresses spurious `ProcessingState.completed` events that just_audio
  /// fires during the internal FLUSHING/RESUMING cycle of a seek operation.
  bool _isSeeking = false;

  // ── Timed-range playback (single-source, position-based) ─────────────────────
  // Active only for isTimedSurahEdition when playing a surah or ayah range.
  // A SINGLE surah file is loaded once; ayah boundaries are tracked via the
  // positionStream.  This avoids loading the same remote file N times in
  // a ConcatenatingAudioSource and eliminates clip-to-clip seek latency.
  List<({int ayah, int startMs, int endMs})> _timedSegments  = [];
  int  _timedRangeStart   = 0; // first ayah in the requested range (1-based)
  int  _timedRangeEnd     = 0; // last ayah in the requested range (1-based)
  int  _timedRangeStartMs = 0; // absolute file offset of range start (ms)
  int  _timedRangeEndMs   = 0; // absolute file offset of range end (ms)
  bool _isTimedRangeMode  = false;
  StreamSubscription<Duration>? _timedPosSub;

  AyahAudioCubit(this._service, this._adhanService)
    : _player = AudioPlayer(),
      super(const AyahAudioState.idle()) {
    _init();
  }

  /// Returns the surah name for [surahNumber] (1-based) in the app language.
  String _surahNameFor(int surahNumber) {
    final isAr = di.sl<SettingsService>().getAppLanguage() == 'ar';
    final names = isAr ? _kSurahNamesAr : _kSurahNamesEn;
    if (surahNumber >= 1 && surahNumber <= names.length) {
      return isAr ? 'سورة ${names[surahNumber - 1]}' : 'Surah ${names[surahNumber - 1]}';
    }
    return isAr ? 'سورة $surahNumber' : 'Surah $surahNumber';
  }

  Future<void> _init() async {

    try {
      final session = await AudioSession.instance;
      // Configure for music/media playback with ducking support.
      // audio_session only has native effects on Android/iOS/macOS;
      // on Windows/Linux it's a no-op and must not throw.
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.duckOthers,
        avAudioSessionMode: AVAudioSessionMode.spokenAudio,
        avAudioSessionRouteSharingPolicy:
            AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      ));
    } catch (e) {
      // audio_session may fail on desktop platforms — not fatal.
      debugPrint('[Audio] AudioSession configure failed (non-fatal): $e');
    }

    if (isClosed) return;

    // Ensure playback never loops unless explicitly enabled.
    await _player.setLoopMode(LoopMode.off);
    await _player.setShuffleModeEnabled(false);

    if (isClosed) return;
    _initialized = true;

    // Cache the duration of the current item whenever it becomes known.
    _durationCacheSub = _player.durationStream.listen((dur) {
      if (isClosed || dur == null) return;
      _itemDurations[_currentItemIndex] = dur;
    });

    _playerSub = _player.playerStateStream.listen(
      (ps) {
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
        // Suppress false 'completed' that just_audio fires during the
        // FLUSHING → FLUSHED → RESUMING cycle triggered by a seek.
        if (_isSeeking) return;
        _onPlaylistCompleted();
        return;
      }

      if (ps.playing) {
        emit(state.copyWith(status: AyahAudioStatus.playing, clearError: true));
      } else {
        // If we have a target, treat as paused; otherwise idle.
        emit(
          state.copyWith(
            status: state.hasPlayableTarget
                ? AyahAudioStatus.paused
                : AyahAudioStatus.idle,
            clearError: true,
          ),
        );
      }
    },
      onError: (Object e, StackTrace st) {
        if (isClosed) return;
        emit(
          state.copyWith(
            status: AyahAudioStatus.error,
            errorMessage: e.toString().replaceFirst('Exception: ', ''),
          ),
        );
      },
    );

    _indexSub = _player.currentIndexStream.listen((idx) {
      if (isClosed) return;
      if (idx == null) return;

      // ── Accumulate duration of the item we just left ──────────────────────
      if (idx > _currentItemIndex) {
        // For silence items use the fixed gap; for ayah items use cached dur.
        final prev = _currentItemIndex;
        final sequence = _player.sequenceState;
        final prevTag = (sequence != null && prev < sequence.sequence.length)
            ? sequence.sequence[prev].tag
            : null;
        final dur = prevTag == _kSilenceTag
            ? _ayahGap
            : (_itemDurations[prev] ?? Duration.zero);
        _accumulatedDuration += dur;
      }
      _currentItemIndex = idx;

      if (state.mode != AyahAudioMode.surah) return;

      // Get the ayah number from the audio source tag
      final sequence = _player.sequenceState;
      if (sequence != null && idx < sequence.sequence.length) {
        final tag = sequence.sequence[idx].tag;
        // Silence items: keep current ayah highlighted, don't change state.
        if (tag == _kSilenceTag) return;
        if (tag is MediaItem) {
          final ayahNum = int.tryParse(tag.id.split('_').last);
          if (ayahNum != null) {
            emit(state.copyWith(ayahNumber: ayahNum));
            return;
          }
        }
      }

      // Fallback: derive ayah number from playlist position.
      // Even indices are ayahs; odd indices are silences (never reach here).
      // Each ayah occupies 2 slots (ayah + silence) except the last.
      emit(state.copyWith(ayahNumber: _firstAyahNumber + idx ~/ 2));
    });
  }

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;

  /// True when the active edition only provides surah-level audio (the 10
  /// Qira'at editions served by mp3quran.net). No individual ayah files exist
  /// for these; any ayah tap redirects to full-surah playback.
  bool get isSurahLevelEdition => _service.isSurahLevelEdition;

  // ── Playlist-aware streams ───────────────────────────────────────────────

  /// Position relative to the START of the playlist.
  /// For single-ayah mode this is identical to [positionStream].
  /// For page/surah mode it accumulates the durations of completed items.
  Stream<Duration> get effectivePositionStream => _isTimedRangeMode
      ? _player.positionStream.map((pos) {
          final clampedMs = pos.inMilliseconds.clamp(
            0,
            _timedRangeEndMs - _timedRangeStartMs,
          );
          return Duration(milliseconds: clampedMs);
        })
      : _player.positionStream.map((pos) => _accumulatedDuration + pos);

  /// Total duration of the full playlist.
  /// Uses actual cached durations for known items; estimates the rest via
  /// the running average.  The estimate only changes for the *unknown* part,
  /// so already-known durations never shift the total unexpectedly.
  Stream<Duration?> get effectiveDurationStream => _isTimedRangeMode
      ? _player.positionStream.map(
          (_) => Duration(milliseconds: _timedRangeEndMs - _timedRangeStartMs))
      : _player.durationStream.map((_) => _computeEffectiveDuration());

  /// Compute the effective total duration synchronously so both the stream
  /// and [seekToAbsolute] can call it without duplicating logic.
  Duration? _computeEffectiveDuration() {
    if (_ayahCount <= 1) return _player.duration;

    // Fixed total silence duration is always known.
    final silenceTotal = _ayahGap * (_ayahCount - 1);

    // Sum the durations we ACTUALLY know (even playlist indices = ayahs).
    int knownCount = 0;
    int knownTotalMs = 0;
    for (var i = 0; i < _playlistLength; i += 2) {
      final d = _itemDurations[i];
      if (d != null && d > Duration.zero) {
        knownCount++;
        knownTotalMs += d.inMilliseconds;
      }
    }

    if (knownCount == 0) return _player.duration; // nothing known yet

    if (knownCount >= _ayahCount) {
      // All ayah durations are known — return the exact total.
      return Duration(milliseconds: knownTotalMs) + silenceTotal;
    }

    // Estimate ONLY the unknown ayahs using the average of the known ones.
    // This keeps the known part of the sum fixed, so the total only shifts
    // by (avgChange × unknownCount) as new data arrives — not by
    // (avgChange × totalAyahCount) as the old formula did.
    final unknownCount = _ayahCount - knownCount;
    final avgMs = knownTotalMs / knownCount;
    final estimatedTotalMs =
        knownTotalMs + (avgMs * unknownCount).round() + silenceTotal.inMilliseconds;
    return Duration(milliseconds: estimatedTotalMs);
  }

  // ── Queue helpers ─────────────────────────────────────────────────────────

  /// Called when the current audio source finishes.
  /// If a surah queue is active, starts the next surah; otherwise goes idle.
  void _onPlaylistCompleted() {
    // Guard: ignore if we're already idle (prevents double-fire when both
    // the position listener and _playerSub fire for the same completion).
    if (state.status == AyahAudioStatus.idle) return;

    // Structured queue takes priority.
    if (_structuredQueue.isNotEmpty &&
        _structuredQueueIndex < _structuredQueue.length - 1) {
      _resetTimedRangeState();
      final next = _structuredQueueIndex + 1;
      _structuredQueueIndex = next;
      Future(() => _playStructuredItem(next));
      return;
    }
    if (_structuredQueue.isNotEmpty) {
      _structuredQueue = [];
      _structuredQueueIndex = 0;
      _resetTimedRangeState();
      emit(const AyahAudioState.idle());
      _player.stop();
      return;
    }

    if (_surahQueue.isNotEmpty &&
        _surahQueueIndex < _surahQueue.length - 1) {
      _resetTimedRangeState();
      final next = _surahQueueIndex + 1;
      _surahQueueIndex = next;
      // Schedule async work in the next microtask so the listener can return.
      Future(() => _playSurahQueueItem(next));
      return;
    }
    // Queue exhausted or no queue — fully stop the player.
    // Calling stop() sets just_audio's internal playing flag to false so
    // just_audio_background will not try to auto-resume when audio focus
    // returns after a transient interruption (e.g. a notification sound).
    _surahQueue = [];
    _surahQueueIndex = 0;
    _resetTimedRangeState();
    emit(const AyahAudioState.idle());
    _player.stop(); // intentionally not awaited — fire-and-forget
  }

  /// Cancels the position listener and clears all timed-range state.
  /// Must be called at the start of every new playback action.
  void _resetTimedRangeState() {
    _timedPosSub?.cancel();
    _timedPosSub      = null;
    _isTimedRangeMode = false;
    _timedSegments    = [];
    _timedRangeStart  = 0;
    _timedRangeEnd    = 0;
    _timedRangeStartMs = 0;
    _timedRangeEndMs   = 0;
  }

  Future<void> _playSurahQueueItem(int index) async {
    if (index < 0 || index >= _surahQueue.length) return;
    final item = _surahQueue[index];
    await _playSurahInternal(
      surahNumber: item.surahNumber,
      numberOfAyahs: item.numberOfAyahs,
      queueIndex: index,
      queueTotal: _surahQueue.length,
    );
  }

  /// Play a list of surahs one after another (queue / playlist mode).
  Future<void> playQueue(
    List<({int surahNumber, int numberOfAyahs})> surahs,
  ) async {
    if (surahs.isEmpty) return;
    _surahQueue = List.of(surahs);
    _surahQueueIndex = 0;
    await _playSurahQueueItem(0);
  }

  /// Play a structured queue that can mix full-surah and ayah-range items.
  Future<void> playStructuredQueue(List<AyahAudioQueueItem> items) async {
    if (items.isEmpty) return;
    _structuredQueue = List.of(items);
    _structuredQueueIndex = 0;
    // Clear simple surah queue so the two modes don't interfere.
    _surahQueue = [];
    _surahQueueIndex = 0;
    await _playStructuredItem(0);
  }

  Future<void> _playStructuredItem(int index) async {
    if (index < 0 || index >= _structuredQueue.length) return;
    final item = _structuredQueue[index];
    switch (item) {
      case _FullSurahQueueItem(:final surahNumber, :final numberOfAyahs):
        await _playSurahInternal(
          surahNumber: surahNumber,
          numberOfAyahs: numberOfAyahs,
          queueIndex: index,
          queueTotal: _structuredQueue.length,
        );
      case _AyahRangeQueueItem(:final surahNumber, :final startAyah, :final endAyah):
        await _playAyahRangeInternal(
          surahNumber: surahNumber,
          startAyah: startAyah,
          endAyah: endAyah,
          queueIndex: index,
          queueTotal: _structuredQueue.length,
        );
    }
  }

  // ── Timed-range playback (per-ayah with position tracking) ─────────────────

  /// Plays [startAyah]..[endAyah] from [surahNumber] using a SINGLE surah-level
  /// audio file with a position listener for ayah tracking.  This approach
  /// avoids loading the same remote file N times via ClippingAudioSource and
  /// delivers accurate, gap-free per-ayah playback.
  Future<void> _playTimedRange({
    required int surahNumber,
    required int startAyah,
    required int endAyah,
    int queueIndex = 0,
    int queueTotal = 0,
  }) async {
    _resetTimedRangeState();
    await _adhanService.stopCurrentAdhan();
    if (!_initialized) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    _resetPlaylistTracking(1);
    emit(
      AyahAudioState(
        status: AyahAudioStatus.buffering,
        mode: AyahAudioMode.surah,
        surahNumber: surahNumber,
        ayahNumber: startAyah,
        queueIndex: queueIndex,
        queueTotal: queueTotal,
      ),
    );

    try {
      final result = await _service.resolveTimedSurahSource(
        surahNumber: surahNumber,
      );
      final segments = result.segments;
      final segMap = <int, ({int ayah, int startMs, int endMs})>{
        for (final s in segments) s.ayah: s,
      };

      final basmala    = segMap[0];
      final startEntry = segMap[startAyah];
      // Fall back to the last available segment when a reader's timing API
      // omits the final ayah (e.g. Qalon narration: 285 entries for Baqara
      // which has 286 ayahs).  This keeps per-ayah tracking alive for all
      // earlier ayahs instead of bailing out to untracked full-surah play.
      final endEntry = segMap[endAyah] ??
          (segMap.isEmpty
              ? null
              : segMap.values.reduce((a, b) => a.ayah > b.ayah ? a : b));

      if (startEntry == null || endEntry == null) {
        // Timing data incomplete — fall back to full surah without tracking.
        final src  = result.source;
        final isAr = di.sl<SettingsService>().getAppLanguage() == 'ar';
        final artUri = await _telawahArt();
        final mi   = MediaItem(
          id: '${surahNumber}_$startAyah',
          title: _surahNameFor(surahNumber),
          album: isAr ? 'الآية $startAyah' : 'Verse $startAyah',
          artist: isAr ? 'القرآن الكريم' : 'The Holy Quran',
          artUri: artUri,
        );
        final fallback = src.isLocal
            ? AudioSource.file(src.localFilePath!, tag: mi)
            : AudioSource.uri(src.remoteUri!, tag: mi);
        await _player.setAudioSource(fallback);
        await _player.setLoopMode(LoopMode.off);
        await _player.setShuffleModeEnabled(false);
        await _player.play();
        return;
      }

      // Include Basmala in ayah 1: use ayah-0 startMs when available;
      // fall back to 0 (beginning of file) for readers that omit ayah 0.
      final rangeStartMs = startAyah == 1
          ? (basmala?.startMs ?? 0)
          : startEntry.startMs;
      final rangeEndMs = endEntry.endMs;

      _timedSegments     = segments;
      _timedRangeStart   = startAyah;
      _timedRangeEnd     = endAyah;
      _timedRangeStartMs = rangeStartMs;
      _timedRangeEndMs   = rangeEndMs;
      _isTimedRangeMode  = true;

      final isAr = di.sl<SettingsService>().getAppLanguage() == 'ar';
      final artUri = await _telawahArt();
      final firstMediaItem = MediaItem(
        id: '${surahNumber}_$startAyah',
        title: _surahNameFor(surahNumber),
        album: isAr ? 'الآية $startAyah' : 'Verse $startAyah',
        artist: isAr ? 'القرآن الكريم' : 'The Holy Quran',
        artUri: artUri,
      );
      final src = result.source;
      final innerSource = src.isLocal
          ? AudioSource.file(src.localFilePath!, tag: firstMediaItem)
          : AudioSource.uri(src.remoteUri!, tag: firstMediaItem);
      final AudioSource audioSrc = ClippingAudioSource(
        child: innerSource,
        start: Duration(milliseconds: rangeStartMs),
        end: Duration(milliseconds: rangeEndMs),
        tag: firstMediaItem,
      );

      await _player.setAudioSource(audioSrc);
      await _player.setLoopMode(LoopMode.off);
      await _player.setShuffleModeEnabled(false);

      await _player.play();

      _startTimedPositionMonitoring(
        surahNumber: surahNumber,
        segMap: segMap,
        queueIndex: queueIndex,
        queueTotal: queueTotal,
      );
    } catch (e) {
      _resetTimedRangeState();
      emit(
        AyahAudioState(
          status: AyahAudioStatus.error,
          mode: AyahAudioMode.surah,
          surahNumber: surahNumber,
          ayahNumber: startAyah,
          queueIndex: queueIndex,
          queueTotal: queueTotal,
          errorMessage: e.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  /// Listens to the player position and updates the current ayah number in
  /// the state as playback crosses ayah boundaries (using the timing map).
  ///
  /// In timed-range mode the loaded source is clipped to the requested range,
  /// so the player's reported position is relative to the clip start while the
  /// timing entries remain absolute offsets inside the original surah file.
  void _startTimedPositionMonitoring({
    required int surahNumber,
    required Map<int, ({int ayah, int startMs, int endMs})> segMap,
    int queueIndex = 0,
    int queueTotal = 0,
  }) {
    _timedPosSub?.cancel();
    int lastReportedAyah = _timedRangeStart;
    final basmala = segMap[0];

    _timedPosSub = _player.positionStream.listen((pos) {
      if (!_isTimedRangeMode || isClosed) return;
      if (state.mode != AyahAudioMode.surah) return;
      if (state.surahNumber != surahNumber) return;

      final posMs = pos.inMilliseconds;
      final absolutePosMs = _timedRangeStartMs + posMs;

      // Find the highest ayah whose start offset is ≤ current position.
      int currentAyah = _timedRangeStart;
      for (var a = _timedRangeStart; a <= _timedRangeEnd; a++) {
        final seg = segMap[a];
        if (seg == null) continue;
        final segStartMs = a == 1
            ? (basmala?.startMs ?? 0)
            : seg.startMs;
        if (absolutePosMs >= segStartMs) {
          currentAyah = a;
        } else {
          break; // list is sorted, no need to continue
        }
      }

      if (currentAyah != lastReportedAyah) {
        lastReportedAyah = currentAyah;
        if (!isClosed) emit(state.copyWith(ayahNumber: currentAyah));
      }
    });
  }

  /// Skip to the next surah in the queue. No-op if not in queue mode or
  /// already at the last surah.
  Future<void> nextSurah() async {
    if (_surahQueue.isEmpty) return;
    final next = _surahQueueIndex + 1;
    if (next >= _surahQueue.length) return;
    _surahQueueIndex = next;
    await _playSurahQueueItem(next);
  }

  /// Go back to the previous surah in the queue. No-op if not in queue mode
  /// or already at the first surah.
  Future<void> previousSurah() async {
    if (_surahQueue.isEmpty) return;
    final prev = _surahQueueIndex - 1;
    if (prev < 0) return;
    _surahQueueIndex = prev;
    await _playSurahQueueItem(prev);
  }

  Future<void> togglePlayAyah({
    required int surahNumber,
    required int ayahNumber,
  }) async {
    // ── Pure surah-level editions (mp3quran.net, no timing data) ────────────
    // No per-ayah audio; tapping any ayah plays (or toggles) the whole surah.
    if (_service.isSurahLevelEdition) {
      if (state.mode == AyahAudioMode.surah &&
          state.surahNumber == surahNumber) {
        if (_player.playing) { await pause(); return; }
        if (state.status == AyahAudioStatus.paused) { await resume(); return; }
      }
      await playAyah(surahNumber: surahNumber, ayahNumber: ayahNumber);
      return;
    }

    // ── Timed surah editions (mp3quran.net + timing data) ───────────────────
    // Per-ayah playback is supported via position tracking in a single file.
    if (_service.isTimedSurahEdition) {
      // ── Currently in surah/range mode for the SAME surah ──────────────────
      if (state.mode == AyahAudioMode.surah &&
          state.surahNumber == surahNumber) {
        // Same ayah that's playing → pause.
        if (state.ayahNumber == ayahNumber) {
          if (_player.playing) { await pause(); return; }
          if (state.status == AyahAudioStatus.paused) { await resume(); return; }
        }
        // Different ayah in the SAME surah while in timed-range mode → seek.
        if (_isTimedRangeMode &&
            ayahNumber >= _timedRangeStart &&
            ayahNumber <= _timedRangeEnd &&
            _timedSegments.isNotEmpty) {
          final segMap = <int, ({int ayah, int startMs, int endMs})>{
            for (final s in _timedSegments) s.ayah: s,
          };
          final basmala = segMap[0];
          final seg = segMap[ayahNumber];
          if (seg != null) {
            // Use ayah-0 startMs when available; fall back to 0 so the
            // Basmala is not skipped for readers without an explicit entry.
            final seekMs = ayahNumber == 1
                ? (basmala?.startMs ?? 0)
                : seg.startMs;
            final relativeSeekMs = seekMs.clamp(
              _timedRangeStartMs,
              _timedRangeEndMs,
            ) - _timedRangeStartMs;
            _isSeeking = true;
            try {
              await _player.seek(Duration(milliseconds: relativeSeekMs));
            } finally {
              await Future<void>.delayed(const Duration(milliseconds: 50));
              _isSeeking = false;
            }
            emit(state.copyWith(ayahNumber: ayahNumber));
            if (!_player.playing) await _player.play();
            return;
          }
        }
      }
      // ── Currently in single-ayah mode for the SAME ayah ───────────────────
      if (state.mode == AyahAudioMode.ayah &&
          state.isCurrent(surahNumber, ayahNumber)) {
        if (_player.playing) { await pause(); return; }
        if (state.status == AyahAudioStatus.paused) { await resume(); return; }
      }
      // ── Different surah or out-of-range ayah → play that single ayah ──────
      await playAyah(surahNumber: surahNumber, ayahNumber: ayahNumber);
      return;
    }

    // ── Regular per-ayah editions (everyayah.com etc.) ──────────────────────
    if (state.mode == AyahAudioMode.ayah &&
        state.isCurrent(surahNumber, ayahNumber)) {
      if (_player.playing) {
        await pause();
        return;
      }
      // Resume from current position instead of restarting from the beginning.
      if (state.status == AyahAudioStatus.paused) {
        await resume();
        return;
      }
    }

    await playAyah(surahNumber: surahNumber, ayahNumber: ayahNumber);
  }

  void _resetPlaylistTracking(int ayahCount, {int firstAyahNumber = 1}) {
    _ayahCount = ayahCount;
    _firstAyahNumber = firstAyahNumber;
    // When gap > 0: N ayahs + (N-1) silences = 2N-1 items.
    // When gap == 0: no silence items inserted, so exactly N items.
    final hasGap = _ayahGap > Duration.zero;
    _playlistLength = (ayahCount <= 1 || !hasGap) ? ayahCount : 2 * ayahCount - 1;
    _currentItemIndex = 0;
    _accumulatedDuration = Duration.zero;
    _itemDurations.clear();
    // Pre-populate known durations for silence items (odd indices, only when gap > 0).
    if (hasGap) {
      for (var i = 1; i < _playlistLength; i += 2) {
        _itemDurations[i] = _ayahGap;
      }
    }
  }

  Future<void> playAyah({
    required int surahNumber,
    required int ayahNumber,
  }) async {
    // ── Surah-level editions (10-Qira'at from mp3quran.net) ─────────────────
    // No per-ayah source exists for these editions; redirect to surah mode so
    // the player correctly plays the full surah file once rather than looping
    // it under a misleading 'ayah' state.
    if (_service.isSurahLevelEdition) {
      _surahQueue = [];
      _surahQueueIndex = 0;
      final numberOfAyahs = OfflineAudioService.getAyahCount(surahNumber);
      await _playSurahInternal(
        surahNumber: surahNumber,
        numberOfAyahs: numberOfAyahs,
      );
      return;
    }

    // Clear any active queue when playing a single ayah.
    _surahQueue = [];
    _surahQueueIndex = 0;
    // Stop Adhan (await so native stop completes before audio starts).
    await _adhanService.stopCurrentAdhan();
    if (!_initialized) {
      // Best-effort: allow _init() to finish.
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    _resetPlaylistTracking(1);
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

      final isAr = di.sl<SettingsService>().getAppLanguage() == 'ar';
      final artUri = await _telawahArt();
      final mediaItem = MediaItem(
        id: '${surahNumber}_$ayahNumber',
        title: isAr ? 'الآية $ayahNumber' : 'Verse $ayahNumber',
        album: _surahNameFor(surahNumber),
        artist: isAr ? 'القرآن الكريم' : 'The Holy Quran',
        artUri: artUri,
      );
      late final AudioSource audioSrc;
      if (source.isTimed) {
        final inner = source.isLocal
            ? AudioSource.file(source.localFilePath!, tag: mediaItem)
            : AudioSource.uri(source.remoteUri!, tag: mediaItem);
        audioSrc = ClippingAudioSource(
          child: inner,
          start: source.startTime,
          end: source.endTime,
          tag: mediaItem,
        );
      } else if (source.isLocal) {
        audioSrc = AudioSource.file(source.localFilePath!, tag: mediaItem);
      } else {
        audioSrc = AudioSource.uri(source.remoteUri!, tag: mediaItem);
      }
      await _player.setAudioSource(audioSrc);

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

  Future<void> playLiveStream({
    required String url,
    required String title,
    required String subtitle,
  }) async {
    _surahQueue = [];
    _surahQueueIndex = 0;
    await _adhanService.stopCurrentAdhan();
    if (!_initialized) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    _resetPlaylistTracking(1);
    emit(
      AyahAudioState(
        status: AyahAudioStatus.buffering,
        mode: AyahAudioMode.radio,
        liveStreamUrl: url,
        mediaTitle: title,
        mediaSubtitle: subtitle,
      ),
    );

    try {
      // Radio mode: load radio artwork from asset cache for notification.
      final radioArtUri = await _radioArt();
      final mediaItem = MediaItem(
        id: 'radio_${url.hashCode}',
        title: title,
        album: subtitle,
        artist: subtitle,
        artUri: radioArtUri,
        extras: const {'isLive': true},
      );
      await _player.setAudioSource(
        AudioSource.uri(Uri.parse(url), tag: mediaItem),
      );
      await _player.setLoopMode(LoopMode.off);
      await _player.setShuffleModeEnabled(false);
      unawaited(_player.play());
    } catch (e) {
      emit(
        AyahAudioState(
          status: AyahAudioStatus.error,
          mode: AyahAudioMode.radio,
          liveStreamUrl: url,
          mediaTitle: title,
          mediaSubtitle: subtitle,
          errorMessage: e.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  // ── Word-by-word playback ─────────────────────────────────────────────────

  /// Play a single word.  [wordIndex] is 1-based (first word = 1).
  ///
  /// Audio source: audio.qurancdn.com word-by-word CDN.
  /// NOTE: This CDN only provides one reciter: Mishary Rashid Al-Afasy.
  /// The selected Quran reciter in settings does NOT affect word-by-word audio.
  Future<void> playWord({
    required int surahNumber,
    required int ayahNumber,
    required int wordIndex,
  }) async {
    // Stop Adhan / any active playback first.
    await _adhanService.stopCurrentAdhan();
    if (!_initialized) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    _surahQueue = [];
    _surahQueueIndex = 0;
    _resetPlaylistTracking(1);

    emit(
      AyahAudioState(
        status: AyahAudioStatus.buffering,
        mode: AyahAudioMode.word,
        surahNumber: surahNumber,
        ayahNumber: ayahNumber,
        wordIndex: wordIndex,
      ),
    );

    final s = surahNumber.toString().padLeft(3, '0');
    final a = ayahNumber.toString().padLeft(3, '0');
    final w = wordIndex.toString().padLeft(3, '0');
    final uri = Uri.parse(
      'https://audio.qurancdn.com/wbw/${s}_${a}_$w.mp3',
    );

    try {
      final isAr = di.sl<SettingsService>().getAppLanguage() == 'ar';
      final artUri = await _telawahArt();
      final mediaItem = MediaItem(
        id: 'word_${surahNumber}_${ayahNumber}_$wordIndex',
        title: isAr ? 'الآية $ayahNumber - كلمة $wordIndex' : 'Verse $ayahNumber - Word $wordIndex',
        album: _surahNameFor(surahNumber),
        artist: isAr ? 'القرآن الكريم' : 'The Holy Quran',
        artUri: artUri,
      );
      await _player.setAudioSource(AudioSource.uri(uri, tag: mediaItem));
      await _player.setLoopMode(LoopMode.off);
      await _player.setShuffleModeEnabled(false);
      await _player.play();
    } catch (e) {
      emit(
        AyahAudioState(
          status: AyahAudioStatus.error,
          mode: AyahAudioMode.word,
          surahNumber: surahNumber,
          ayahNumber: ayahNumber,
          wordIndex: wordIndex,
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
    // Clear queue when toggling a single surah.
    _surahQueue = [];
    _surahQueueIndex = 0;
    await playSurah(surahNumber: surahNumber, numberOfAyahs: numberOfAyahs);
  }

  Future<void> playSurah({
    required int surahNumber,
    required int numberOfAyahs,
  }) async {
    // Clear any existing queue when playing a standalone surah.
    _surahQueue = [];
    _surahQueueIndex = 0;
    await _playSurahInternal(
      surahNumber: surahNumber,
      numberOfAyahs: numberOfAyahs,
      queueIndex: 0,
      queueTotal: 0,
    );
  }

  /// Core surah-playback logic shared by [playSurah] and [_playSurahQueueItem].
  Future<void> _playSurahInternal({
    required int surahNumber,
    required int numberOfAyahs,
    int queueIndex = 0,
    int queueTotal = 0,
  }) async {
    // ── Timed editions: single-source position-based playback ────────────────
    if (_service.isTimedSurahEdition) {
      await _playTimedRange(
        surahNumber: surahNumber,
        startAyah: 1,
        endAyah: numberOfAyahs,
        queueIndex: queueIndex,
        queueTotal: queueTotal,
      );
      return;
    }

    // Stop Adhan (await so native stop completes before audio starts).
    await _adhanService.stopCurrentAdhan();
    if (!_initialized) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    _resetPlaylistTracking(numberOfAyahs);
    emit(
      AyahAudioState(
        status: AyahAudioStatus.buffering,
        mode: AyahAudioMode.surah,
        surahNumber: surahNumber,
        ayahNumber: 1,
        queueIndex: queueIndex,
        queueTotal: queueTotal,
      ),
    );

    try {
      final sources = await _service.resolveSurahAyahAudio(
        surahNumber: surahNumber,
        numberOfAyahs: numberOfAyahs,
      );

      // Surah-level editions (e.g. 10-Qira'at from mp3quran.net) return a
      // single-item list (one file = entire surah). Re-sync the playlist
      // tracking so the cubit does not expect N individual items.
      if (sources.length != numberOfAyahs) {
        _resetPlaylistTracking(sources.length);
      }

      final isAr = di.sl<SettingsService>().getAppLanguage() == 'ar';
      final artUri = await _telawahArt();
      final children = <AudioSource>[];
      for (var i = 0; i < sources.length; i++) {
        final ayahNumber = i + 1;
        final s = sources[i];
        // Full-surah mode: title = surah name, album = current ayah number.
        final mediaItem = MediaItem(
          id: '${surahNumber}_$ayahNumber',
          title: _surahNameFor(surahNumber),
          album: isAr ? 'الآية $ayahNumber' : 'Verse $ayahNumber',
          artist: isAr ? 'القرآن الكريم' : 'The Holy Quran',
          artUri: artUri,
        );
        if (s.isTimed) {
          final inner = s.isLocal
              ? AudioSource.file(s.localFilePath!, tag: mediaItem)
              : AudioSource.uri(s.remoteUri!, tag: mediaItem);
          children.add(ClippingAudioSource(
            child: inner,
            start: s.startTime,
            end: s.endTime,
            tag: mediaItem,
          ));
        } else if (s.isLocal) {
          children.add(AudioSource.file(s.localFilePath!, tag: mediaItem));
        } else {
          children.add(AudioSource.uri(s.remoteUri!, tag: mediaItem));
        }
        // Add silence gap after every ayah except the last.
        if (_ayahGap > Duration.zero && i < sources.length - 1) {
          children.add(
            SilenceAudioSource(duration: _ayahGap, tag: _kSilenceTag),
          );
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
          queueIndex: queueIndex,
          queueTotal: queueTotal,
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
    await _playAyahRangeInternal(
      surahNumber: surahNumber,
      startAyah: startAyah,
      endAyah: endAyah,
    );
  }

  Future<void> _playAyahRangeInternal({
    required int surahNumber,
    required int startAyah,
    required int endAyah,
    int queueIndex = 0,
    int queueTotal = 0,
  }) async {
    // ── Pure surah-level editions: redirect to full-surah playback ───────────
    if (_service.isSurahLevelEdition) {
      final numberOfAyahs = OfflineAudioService.getAyahCount(surahNumber);
      await _playSurahInternal(
        surahNumber: surahNumber,
        numberOfAyahs: numberOfAyahs,
        queueIndex: queueIndex,
        queueTotal: queueTotal,
      );
      return;
    }
    // ── Timed editions: single-source position-based playback ────────────────
    if (_service.isTimedSurahEdition) {
      await _playTimedRange(
        surahNumber: surahNumber,
        startAyah: startAyah,
        endAyah: endAyah,
        queueIndex: queueIndex,
        queueTotal: queueTotal,
      );
      return;
    }

    // Stop Adhan (await so native stop completes before audio starts).
    await _adhanService.stopCurrentAdhan();
    if (!_initialized) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    _resetPlaylistTracking(endAyah - startAyah + 1, firstAyahNumber: startAyah);
    emit(
      AyahAudioState(
        status: AyahAudioStatus.buffering,
        mode: AyahAudioMode.surah,
        surahNumber: surahNumber,
        ayahNumber: startAyah,
        queueIndex: queueIndex,
        queueTotal: queueTotal,
      ),
    );

    try {
      final isAr = di.sl<SettingsService>().getAppLanguage() == 'ar';
      final artUri = await _telawahArt();
      final children = <AudioSource>[];
      for (var ayahNumber = startAyah; ayahNumber <= endAyah; ayahNumber++) {
        final source = await _service.resolveAyahAudio(
          surahNumber: surahNumber,
          ayahNumber: ayahNumber,
        );

        // Ayah-range mode (from mushaf): title = ayah number, album = surah name.
        final mediaItem = MediaItem(
          id: '${surahNumber}_$ayahNumber',
          title: isAr ? 'الآية $ayahNumber' : 'Verse $ayahNumber',
          album: _surahNameFor(surahNumber),
          artist: isAr ? 'القرآن الكريم' : 'The Holy Quran',
          artUri: artUri,
        );
        if (source.isLocal) {
          children.add(
            AudioSource.file(source.localFilePath!, tag: mediaItem),
          );
        } else {
          children.add(AudioSource.uri(source.remoteUri!, tag: mediaItem));
        }
        // Add silence gap after every ayah except the last.
        if (_ayahGap > Duration.zero && ayahNumber < endAyah) {
          children.add(
            SilenceAudioSource(duration: _ayahGap, tag: _kSilenceTag),
          );
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
          queueIndex: queueIndex,
          queueTotal: queueTotal,
          errorMessage: e.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  /// Seek to [position] in the current audio (effective / playlist-aware).
  ///
  /// For single-ayah mode this maps directly to [AudioPlayer.seek].
  /// For playlist (surah) mode it walks the accumulated item durations to
  /// find the correct playlist index + in-item offset.
  Future<void> seekToAbsolute(Duration position) async {
    if (state.mode == AyahAudioMode.radio) return;
    if (position < Duration.zero) position = Duration.zero;

    // ── Timed-range mode: slider position is relative to range start ─────────
    if (_isTimedRangeMode) {
      final rangeMs = (_timedRangeEndMs - _timedRangeStartMs).clamp(1, double.maxFinite.toInt());
      final clampedMs = position.inMilliseconds.clamp(0, rangeMs - 500);
      _isSeeking = true;
      try {
        await _player.seek(Duration(milliseconds: clampedMs));
      } finally {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        _isSeeking = false;
        if (!isClosed &&
            _player.playerState.processingState == ProcessingState.completed) {
          _onPlaylistCompleted();
        }
      }
      return;
    }

    _isSeeking = true;
    try {
      // Single-item: just seek directly.
      if (_ayahCount <= 1) {
        final dur = _player.duration;
        if (dur != null && position > dur) position = dur;
        await _player.seek(position);
        return;
      }

      // ── Average ayah duration (for items whose duration isn't cached yet) ──
      // We need this because just_audio only reports the duration of the
      // *current* item.  Items ahead of the playhead haven't been loaded yet
      // so their durations are unknown.  Using 0 for them causes the walk to
      // fall through to the last item and seek past its end → player stops.
      int knownCount = 0;
      int knownTotalMs = 0;
      for (var i = 0; i < _playlistLength; i += 2) {
        final d = _itemDurations[i];
        if (d != null && d > Duration.zero) {
          knownCount++;
          knownTotalMs += d.inMilliseconds;
        }
      }
      // Fallback: 30 s average when nothing is known (shouldn't happen if the
      // user has been playing long enough to touch the slider).
      final avgAyahMs =
          knownCount > 0 ? knownTotalMs ~/ knownCount : 30000;

      // ── Clamp position to estimated total duration ─────────────────────────
      // Re-use the same formula as _computeEffectiveDuration so the seek
      // clamp is always consistent with what the slider shows.
      final silenceTotalMs = _ayahGap.inMilliseconds * (_ayahCount - 1);
      final unknownCount = _ayahCount - knownCount;
      final estimatedTotalMs = knownCount > 0
          ? knownTotalMs + (avgAyahMs * unknownCount) + silenceTotalMs
          : avgAyahMs * _ayahCount + silenceTotalMs;
      // Keep 500 ms margin so we don't accidentally seek to the very end.
      final maxSeekMs = (estimatedTotalMs - 500).clamp(0, estimatedTotalMs);
      if (position.inMilliseconds > maxSeekMs) {
        position = Duration(milliseconds: maxSeekMs);
      }

      // ── Walk the playlist to find target item + in-item offset ─────────────
      Duration consumed = Duration.zero;
      final hasGap = _ayahGap > Duration.zero;
      for (var i = 0; i < _playlistLength; i++) {
        // When gap > 0: even indices are ayahs, odd are silences.
        // When gap == 0: all indices are ayahs.
        final isAyahItem = !hasGap || i.isEven;
        // Use the actual cached duration if available, otherwise estimate.
        final dur = _itemDurations[i] ??
            (isAyahItem
                ? Duration(milliseconds: avgAyahMs)
                : _ayahGap);

        final end = consumed + dur;
        if (end > position || i == _playlistLength - 1) {
          final offsetInItem = position - consumed;
          final clamped =
              offsetInItem.isNegative ? Duration.zero : offsetInItem;
          // Update tracking so effectivePositionStream stays consistent.
          _currentItemIndex = i;
          _accumulatedDuration = consumed;
          await _player.seek(clamped, index: i);
          return;
        }
        consumed += dur;
      }
    } finally {
      // Give the player a frame to settle its internal state before we
      // re-enable completion handling.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      _isSeeking = false;
      // If the player landed in 'completed' during the seek-guard window
      // (e.g. the user dragged past the last known position), handle it now.
      if (!isClosed &&
          _player.playerState.processingState == ProcessingState.completed) {
        _onPlaylistCompleted();
      }
    }
  }

  Future<void> pause() async {
    if (state.mode == AyahAudioMode.radio) {
      await _player.stop();
      emit(state.copyWith(status: AyahAudioStatus.paused, clearError: true));
      return;
    }
    await _player.pause();
    emit(state.copyWith(status: AyahAudioStatus.paused));
  }

  Future<void> resume() async {
    if (state.mode == AyahAudioMode.radio) {
      final url = state.liveStreamUrl;
      final title = state.mediaTitle;
      final subtitle = state.mediaSubtitle;
      if (url == null || title == null || subtitle == null) return;
      await playLiveStream(url: url, title: title, subtitle: subtitle);
      return;
    }
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
    _surahQueue = [];
    _surahQueueIndex = 0;
    _resetTimedRangeState();
    await _player.stop();
    emit(const AyahAudioState.idle());
  }

  @override
  Future<void> close() async {
    await _playerSub?.cancel();
    await _indexSub?.cancel();
    await _durationCacheSub?.cancel();
    _timedPosSub?.cancel();
    // Pause before dispose so ExoPlayer doesn't need to flush the codec
    // during release. Flushing from a PLAYING state on some devices causes
    // FLUSHING→RESUMING→RUNNING→RELEASING race → LegacyMessageQueue dead thread.
    // Pause keeps the codec in RUNNING (no flush) so release is clean.
    try { await _player.pause(); } catch (_) {}
    await _player.dispose();
    return super.close();
  }
}

// ── Notification metadata helpers ─────────────────────────────────────────────
// Arabic surah names indexed 1–114.  Used to build human-readable MediaItem
// titles in the system media notification / lock-screen player.
const _kSurahNamesAr = [
  'الفاتحة', 'البقرة', 'آل عمران', 'النساء', 'المائدة',
  'الأنعام', 'الأعراف', 'الأنفال', 'التوبة', 'يونس',
  'هود', 'يوسف', 'الرعد', 'إبراهيم', 'الحجر',
  'النحل', 'الإسراء', 'الكهف', 'مريم', 'طه',
  'الأنبياء', 'الحج', 'المؤمنون', 'النور', 'الفرقان',
  'الشعراء', 'النمل', 'القصص', 'العنكبوت', 'الروم',
  'لقمان', 'السجدة', 'الأحزاب', 'سبأ', 'فاطر',
  'يس', 'الصافات', 'ص', 'الزمر', 'غافر',
  'فصلت', 'الشورى', 'الزخرف', 'الدخان', 'الجاثية',
  'الأحقاف', 'محمد', 'الفتح', 'الحجرات', 'ق',
  'الذاريات', 'الطور', 'النجم', 'القمر', 'الرحمن',
  'الواقعة', 'الحديد', 'المجادلة', 'الحشر', 'الممتحنة',
  'الصف', 'الجمعة', 'المنافقون', 'التغابن', 'الطلاق',
  'التحريم', 'الملك', 'القلم', 'الحاقة', 'المعارج',
  'نوح', 'الجن', 'المزمل', 'المدثر', 'القيامة',
  'الإنسان', 'المرسلات', 'النبأ', 'النازعات', 'عبس',
  'التكوير', 'الانفطار', 'المطففين', 'الانشقاق', 'البروج',
  'الطارق', 'الأعلى', 'الغاشية', 'الفجر', 'البلد',
  'الشمس', 'الليل', 'الضحى', 'الشرح', 'التين',
  'العلق', 'القدر', 'البينة', 'الزلزلة', 'العاديات',
  'القارعة', 'التكاثر', 'العصر', 'الهمزة', 'الفيل',
  'قريش', 'الماعون', 'الكوثر', 'الكافرون', 'النصر',
  'المسد', 'الإخلاص', 'الفلق', 'الناس',
];

const _kSurahNamesEn = [
  'Al-Fatihah', 'Al-Baqarah', 'Aal-E-Imran', 'An-Nisa', 'Al-Maidah',
  'Al-Anam', 'Al-Araf', 'Al-Anfal', 'At-Tawbah', 'Yunus',
  'Hud', 'Yusuf', 'Ar-Ra\'d', 'Ibrahim', 'Al-Hijr',
  'An-Nahl', 'Al-Isra', 'Al-Kahf', 'Maryam', 'Ta-Ha',
  'Al-Anbiya', 'Al-Hajj', 'Al-Muminun', 'An-Nur', 'Al-Furqan',
  'Ash-Shuara', 'An-Naml', 'Al-Qasas', 'Al-Ankabut', 'Ar-Rum',
  'Luqman', 'As-Sajdah', 'Al-Ahzab', 'Saba', 'Fatir',
  'Ya-Sin', 'As-Saffat', 'Sad', 'Az-Zumar', 'Ghafir',
  'Fussilat', 'Ash-Shura', 'Az-Zukhruf', 'Ad-Dukhan', 'Al-Jathiyah',
  'Al-Ahqaf', 'Muhammad', 'Al-Fath', 'Al-Hujurat', 'Qaf',
  'Adh-Dhariyat', 'At-Tur', 'An-Najm', 'Al-Qamar', 'Ar-Rahman',
  'Al-Waqiah', 'Al-Hadid', 'Al-Mujadilah', 'Al-Hashr', 'Al-Mumtahanah',
  'As-Saff', 'Al-Jumuah', 'Al-Munafiqun', 'At-Taghabun', 'At-Talaq',
  'At-Tahrim', 'Al-Mulk', 'Al-Qalam', 'Al-Haqqah', 'Al-Maarij',
  'Nuh', 'Al-Jinn', 'Al-Muzzammil', 'Al-Muddathir', 'Al-Qiyamah',
  'Al-Insan', 'Al-Mursalat', 'An-Naba', 'An-Naziat', 'Abasa',
  'At-Takwir', 'Al-Infitar', 'Al-Mutaffifin', 'Al-Inshiqaq', 'Al-Buruj',
  'At-Tariq', 'Al-Ala', 'Al-Ghashiyah', 'Al-Fajr', 'Al-Balad',
  'Ash-Shams', 'Al-Lail', 'Ad-Duha', 'Ash-Sharh', 'At-Tin',
  'Al-Alaq', 'Al-Qadr', 'Al-Bayyinah', 'Az-Zalzalah', 'Al-Adiyat',
  'Al-Qariah', 'At-Takathur', 'Al-Asr', 'Al-Humazah', 'Al-Fil',
  'Quraysh', 'Al-Maun', 'Al-Kawthar', 'Al-Kafirun', 'An-Nasr',
  'Al-Masad', 'Al-Ikhlas', 'Al-Falaq', 'An-Nas',
];
