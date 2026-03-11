import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/audio/ayah_audio_cubit.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/surah_names.dart';
import '../bloc/surah/surah_bloc.dart';
import '../bloc/surah/surah_state.dart';

/// Islamic-themed audio player with ornamental design.
///
/// Features:
/// - Drag-to-seek progress bar with +-10 s quick-seek buttons
/// - Time display handles durations > 1 hour (H:MM:SS)
/// - Pause/resume without restarting from the beginning
/// - RTL-aware skip prev/next icons
/// - Starts collapsed (mini pill) every time audio begins
class IslamicAudioPlayer extends StatefulWidget {
  final bool isArabicUi;

  /// Optional notifier that mirrors the player's collapsed state so
  /// parent widgets can shrink/grow their content area accordingly.
  final ValueNotifier<bool>? collapsedNotifier;

  const IslamicAudioPlayer({
    super.key,
    required this.isArabicUi,
    this.collapsedNotifier,
  });

  @override
  State<IslamicAudioPlayer> createState() => _IslamicAudioPlayerState();
}

class _IslamicAudioPlayerState extends State<IslamicAudioPlayer> {
  // null = not dragging; a value (0–1) = user is dragging the slider.
  // Using ValueNotifier means onChanged never calls setState, so the
  // BlocBuilder tree is NOT rebuilt mid-drag → gesture stays alive.
  final _dragNotifier = ValueNotifier<double?>(null);

  // Whether the player is collapsed into the mini pill.
  // Starts true so the player always appears as a mini pill first.
  bool _collapsed = true;

  Duration _lastPos = Duration.zero;
  Duration _lastDur = Duration.zero;

  void _setCollapsed(bool value) {
    if (_collapsed == value) return;
    setState(() => _collapsed = value);
    widget.collapsedNotifier?.value = value;
  }

  @override
  void dispose() {
    _dragNotifier.dispose();
    super.dispose();
  }

  void _seekRelative(AyahAudioCubit cubit, Duration delta) {
    // If dragging, base the seek on the drag position, not the stream position.
    final base = _dragNotifier.value != null
        ? Duration(milliseconds: (_dragNotifier.value! * _lastDur.inMilliseconds).round())
        : _lastPos;
    final target = base + delta;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > _lastDur ? _lastDur : target);
    cubit.seekToAbsolute(clamped);
  }

  void _onPlayPauseTap(
    BuildContext context,
    AyahAudioCubit cubit,
    AyahAudioState audioState,
    bool isSurahMode,
    bool isRadioMode,
    bool isPlaying,
    int? playingSurahNumber,
  ) {
    if (isRadioMode) {
      if (isPlaying) {
        cubit.pause();
      } else {
        cubit.resume();
      }
      return;
    }

    if (isSurahMode) {
      if (isPlaying) {
        cubit.pause();
      } else if (audioState.status == AyahAudioStatus.paused) {
        cubit.resume();
      } else if (playingSurahNumber != null) {
        final surahState = context.read<SurahBloc>().state;
        int? numberOfAyahs;
        if (surahState is SurahListLoaded) {
          try {
            final surah = surahState.surahs
                .firstWhere((s) => s.number == playingSurahNumber);
            numberOfAyahs = surah.numberOfAyahs;
          } catch (_) {}
        }
        if (numberOfAyahs != null) {
          cubit.togglePlaySurah(
            surahNumber: playingSurahNumber,
            numberOfAyahs: numberOfAyahs,
          );
        }
      }
    } else {
      if (audioState.surahNumber != null && audioState.ayahNumber != null) {
        cubit.togglePlayAyah(
          surahNumber: audioState.surahNumber!,
          ayahNumber: audioState.ayahNumber!,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabicUi = widget.isArabicUi;

    return BlocConsumer<AyahAudioCubit, AyahAudioState>(
      // Auto-collapse whenever audio starts from idle (new session begins).
      listenWhen: (prev, curr) =>
          prev.status == AyahAudioStatus.idle &&
          curr.status != AyahAudioStatus.idle,
      listener: (ctx, newState) => _setCollapsed(true),
      builder: (context, audioState) {
        if (audioState.status == AyahAudioStatus.idle) {
          return const SizedBox.shrink();
        }

        final isSurahMode = audioState.mode == AyahAudioMode.surah;
        final isRadioMode = audioState.mode == AyahAudioMode.radio;
        final isPlaying = audioState.status == AyahAudioStatus.playing;
        final isBuffering = audioState.status == AyahAudioStatus.buffering;
        final cubit = context.read<AyahAudioCubit>();
        final playingSurahNumber = audioState.surahNumber;
        final playingAyahNumber = audioState.ayahNumber;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        // RTL-aware icons:
        // Flutter Row auto-reverses child ORDER in RTL so positions are correct,
        // but Material directional icons do NOT auto-mirror their arrow, so we
        // swap the icon DATA to keep the arrow pointing in the right direction.
        final isRtl = Directionality.of(context) == TextDirection.rtl;

        // Skip prev / next
        final prevIcon =
            isRtl ? Icons.skip_next_rounded : Icons.skip_previous_rounded;
        final nextIcon =
            isRtl ? Icons.skip_previous_rounded : Icons.skip_next_rounded;

        // ±10 s seek — same logic: Row puts replay on RIGHT in RTL, so its
        // circular arrow would point the "wrong" way; swap data to match.
        final rewindIcon =
            isRtl ? Icons.forward_10_rounded : Icons.replay_10_rounded;
        final fastFwdIcon =
            isRtl ? Icons.replay_10_rounded : Icons.forward_10_rounded;

        // Build title string
        String surahName = '';
        if (isRadioMode) {
          surahName = isArabicUi ? 'إذاعة القرآن الكريم' : 'Quran Radio';
        } else if (playingSurahNumber != null) {
          surahName = SurahNames.getName(playingSurahNumber, isArabicUi);
          if (surahName.isEmpty) {
            surahName = isArabicUi ? '\u0627\u0644\u0642\u0631\u0622\u0646 \u0627\u0644\u0643\u0631\u064a\u0645' : 'Quran';
          }
        } else {
          surahName = isArabicUi ? '\u0627\u0644\u0642\u0631\u0622\u0646 \u0627\u0644\u0643\u0631\u064a\u0645' : 'Quran';
        }
        final queueSuffix = audioState.isQueueMode
            ? ' (${audioState.queueIndex + 1}/${audioState.queueTotal})'
            : '';
        final ayahLabel = !isRadioMode && playingAyahNumber != null
            ? ' \u2022 ${isArabicUi ? '\u0622\u064a\u0629 $playingAyahNumber' : 'Ayah $playingAyahNumber'}'
            : '';
        final radioSuffix = isRadioMode
          ? ' \u2022 ${isArabicUi ? 'بث مباشر' : 'Live Stream'}'
          : '';
        final titleText = isRadioMode
          ? '$surahName$radioSuffix'
          : '$surahName$queueSuffix$ayahLabel';

        // ── Collapsed mini pill ──────────────────────────────────────────
        if (_collapsed) {
          return GestureDetector(
            onTap: () => _setCollapsed(false),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryDark.withValues(alpha: 0.22),
                    blurRadius: 14,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      color: isDark
                          ? const Color(0xFF1A1F25).withValues(alpha: 0.70)
                          : Colors.white.withValues(alpha: 0.68),
                      border: Border.all(
                        color: AppColors.secondary.withValues(alpha: 0.30),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Expand chevron
                  Icon(Icons.expand_less_rounded,
                      size: 20,
                      color: AppColors.secondary.withValues(alpha: 0.8)),
                  const SizedBox(width: 8),
                  // Mini play/pause button
                  GestureDetector(
                    onTap: () => _onPlayPauseTap(
                      context, cubit, audioState,
                      isSurahMode, isRadioMode, isPlaying, playingSurahNumber,
                    ),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.9),
                      ),
                      child: Icon(
                        isBuffering
                            ? Icons.hourglass_empty_rounded
                            : (isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded),
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Mini stop button
                  GestureDetector(
                    onTap: () => cubit.stop(),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.error.withValues(alpha: 0.12),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.55),
                          width: 1.2,
                        ),
                      ),
                      child: Icon(
                        Icons.stop_rounded,
                        color: AppColors.error.withValues(alpha: 0.85),
                        size: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Surah/ayah label
                  Flexible(
                    child: Text(
                      titleText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? const Color(0xFFCCCCCC)
                            : AppColors.primary.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ],
              ),
                  ),
                ),
              ),
            ),
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Decorative top edge — tap anywhere on bar to collapse ───────────
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _setCollapsed(true),
              child: const _TopEdgeOrnament(),
            ),

            // ── Main player body ─────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          const Color(0xFF0F1419),
                          const Color(0xFF1A1F25),
                          const Color(0xFF1C2530),
                        ]
                      : [
                          const Color(0xFFF7F3E9),
                          const Color(0xFFF3EFE3),
                          const Color(0xFFEDF2EC),
                        ],
                  stops: const [0.0, 0.55, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryDark.withValues(alpha: 0.22),
                    blurRadius: 20,
                    offset: const Offset(0, -3),
                  ),
                  BoxShadow(
                    color: AppColors.secondary.withValues(alpha: 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Stack(
                  children: [
                    // Khatam (8-star) Islamic geometric pattern
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _KhatamPatternPainter(
                            color: AppColors.secondary),
                      ),
                    ),

                    // Soft top-edge vignette
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: SizedBox(
                        height: 28,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                (isDark ? Colors.white : Colors.white)
                                    .withValues(alpha: isDark ? 0.06 : 0.22),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ── Title row with collapse button ─────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Collapse button — also tappable via top ornament bar above
                              GestureDetector(
                                onTap: () => _setCollapsed(true),
                                child: SizedBox(
                                  width: 36,
                                  height: 36,
                                  child: Icon(
                                    Icons.expand_more_rounded,
                                    size: 26,
                                    color: AppColors.secondary
                                        .withValues(alpha: 0.85),
                                  ),
                                ),
                              ),
                              const _OrnamentRow(mirrored: false),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 2),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: AppColors.primary
                                        .withValues(alpha: 0.06),
                                    border: Border.all(
                                      color: AppColors.secondary
                                          .withValues(alpha: 0.22),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    titleText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.2,
                                          color: AppColors.primary
                                              .withValues(alpha: 0.90),
                                        ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const _OrnamentRow(mirrored: true),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // Transport controls
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (audioState.isQueueMode) ...[
                                _buildControlButton(
                                  icon: prevIcon,
                                  onPressed: audioState.queueIndex > 0
                                      ? () => cubit.previousSurah()
                                      : null,
                                  tooltip: isArabicUi ? 'السورة السابقة' : 'Previous Surah',
                                ),
                                const SizedBox(width: 10),
                              ],

                              _buildPlayPauseButton(
                                isPlaying: isPlaying,
                                isBuffering: isBuffering,
                                onPressed: () => _onPlayPauseTap(
                                  context,
                                  cubit,
                                  audioState,
                                  isSurahMode,
                                  isRadioMode,
                                  isPlaying,
                                  playingSurahNumber,
                                ),
                                tooltip: isPlaying
                                    ? (isArabicUi ? '\u0625\u064a\u0642\u0627\u0641 \u0645\u0624\u0642\u062a' : 'Pause')
                                    : (isBuffering
                                        ? (isArabicUi
                                            ? '\u062c\u0627\u0631\u064a \u0627\u0644\u062a\u062d\u0645\u064a\u0644\u2026'
                                            : 'Loading\u2026')
                                        : (isArabicUi ? '\u062a\u0634\u063a\u064a\u0644' : 'Play')),
                              ),

                              if (audioState.isQueueMode) ...[
                                const SizedBox(width: 10),
                                _buildControlButton(
                                  icon: nextIcon,
                                  onPressed: audioState.queueIndex < audioState.queueTotal - 1
                                      ? () => cubit.nextSurah()
                                      : null,
                                  tooltip: isArabicUi ? 'السورة التالية' : 'Next Surah',
                                ),
                              ],

                              const SizedBox(width: 12),

                              // Stop button
                              Tooltip(
                                message: isArabicUi ? '\u0625\u064a\u0642\u0627\u0641' : 'Stop',
                                child: InkWell(
                                  onTap: () => cubit.stop(),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          AppColors.error
                                              .withValues(alpha: 0.14),
                                          AppColors.error
                                              .withValues(alpha: 0.04),
                                        ],
                                      ),
                                      border: Border.all(
                                        color: AppColors.error
                                            .withValues(alpha: 0.52),
                                        width: 1.2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.error
                                              .withValues(alpha: 0.14),
                                          blurRadius: 7,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.stop_rounded,
                                      color: AppColors.error
                                          .withValues(alpha: 0.85),
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 4),

                          if (isRadioMode)
                            Padding(
                              padding: const EdgeInsets.only(top: 8, bottom: 6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  color: AppColors.secondary.withValues(alpha: 0.10),
                                  border: Border.all(
                                    color: AppColors.secondary.withValues(alpha: 0.22),
                                  ),
                                ),
                                child: Text(
                                  isArabicUi
                                      ? 'بث مباشر من المشغل العام للتطبيق'
                                      : 'Live stream in the app media player',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary.withValues(alpha: 0.80),
                                      ),
                                ),
                              ),
                            )
                          else
                            StreamBuilder<Duration>(
                            stream: cubit.effectivePositionStream,
                            builder: (context, posSnap) {
                              return StreamBuilder<Duration?>(
                                stream: cubit.effectiveDurationStream,
                                builder: (context, durSnap) {
                                  final pos = posSnap.data ?? Duration.zero;
                                  final dur = durSnap.data ?? Duration.zero;
                                  _lastPos = pos;
                                  _lastDur = dur;

                                  final maxMs = dur.inMilliseconds;
                                  final isInteractive = maxMs > 0;
                                  final streamValue = isInteractive
                                      ? (pos.inMilliseconds / maxMs)
                                          .clamp(0.0, 1.0)
                                      : 0.0;

                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Non-surah mode: ±10s above slider
                                      if (!isSurahMode)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: 2),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              _buildSeekButton(
                                                icon: rewindIcon,
                                                tooltip: isArabicUi
                                                    ? 'رجوع ١٠ ثواني'
                                                    : 'Back 10s',
                                                onPressed: isInteractive
                                                    ? () => _seekRelative(
                                                        cubit,
                                                        const Duration(
                                                            seconds: -10))
                                                    : null,
                                                forwardDir: false,
                                              ),
                                              const SizedBox(width: 6),
                                              _buildSeekButton(
                                                icon: fastFwdIcon,
                                                tooltip: isArabicUi
                                                    ? 'تقديم ١٠ ثواني'
                                                    : 'Forward 10s',
                                                onPressed: isInteractive
                                                    ? () => _seekRelative(
                                                        cubit,
                                                        const Duration(
                                                            seconds: 10))
                                                    : null,
                                                forwardDir: true,
                                              ),
                                            ],
                                          ),
                                        ),

                                      // ValueListenableBuilder wraps only the
                                      // Slider + time labels — drag updates here
                                      // without touching the BlocBuilder tree.
                                      ValueListenableBuilder<double?>(
                                        valueListenable: _dragNotifier,
                                        builder: (context, dragVal, _) {
                                          final sliderValue =
                                              dragVal ?? streamValue;
                                          final displayPos = dragVal != null
                                              ? Duration(
                                                  milliseconds:
                                                      (dragVal * maxMs).round())
                                              : pos;

                                          return Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              SliderTheme(
                                                data: SliderTheme.of(context)
                                                    .copyWith(
                                                  trackHeight: 3.5,
                                                  thumbShape:
                                                      const RoundSliderThumbShape(
                                                          enabledThumbRadius:
                                                              6.5),
                                                  overlayShape:
                                                      const RoundSliderOverlayShape(
                                                          overlayRadius: 16),
                                                  activeTrackColor:
                                                      AppColors.secondary
                                                          .withValues(alpha: 0.82),
                                                  inactiveTrackColor:
                                                      AppColors.primary
                                                          .withValues(alpha: 0.10),
                                                  thumbColor: AppColors.secondary,
                                                  overlayColor: AppColors.secondary
                                                      .withValues(alpha: 0.15),
                                                ),
                                                child: Slider(
                                                  value: sliderValue,
                                                  onChanged: isInteractive
                                                      ? (v) {
                                                          _dragNotifier.value = v;
                                                        }
                                                      : null,
                                                  onChangeEnd: isInteractive
                                                      ? (v) {
                                                          cubit.seekToAbsolute(
                                                              Duration(
                                                                  milliseconds:
                                                                      (v * maxMs)
                                                                          .round()));
                                                          _dragNotifier.value =
                                                              null;
                                                        }
                                                      : null,
                                                ),
                                              ),

                                              // Time labels
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 4),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    _TimeLabel(_formatDuration(
                                                        displayPos)),
                                                    // Surah mode: inline ±10s
                                                    if (isSurahMode)
                                                      Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          _buildSeekButton(
                                                            icon: rewindIcon,
                                                            tooltip: isArabicUi
                                                                ? 'رجوع ١٠'
                                                                : 'Back 10s',
                                                            onPressed: isInteractive
                                                                ? () =>
                                                                    _seekRelative(
                                                                        cubit,
                                                                        const Duration(
                                                                            seconds:
                                                                                -10))
                                                                : null,
                                                            forwardDir: false,
                                                            small: true,
                                                          ),
                                                          _buildSeekButton(
                                                            icon: fastFwdIcon,
                                                            tooltip: isArabicUi
                                                                ? 'تقديم ١٠'
                                                                : 'Fwd 10s',
                                                            onPressed: isInteractive
                                                                ? () =>
                                                                    _seekRelative(
                                                                        cubit,
                                                                        const Duration(
                                                                            seconds:
                                                                                10))
                                                                : null,
                                                            forwardDir: true,
                                                            small: true,
                                                          ),
                                                        ],
                                                      ),
                                                    _TimeLabel(
                                                        _formatDuration(dur)),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),

                          const SizedBox(height: 2),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSeekButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    required bool forwardDir,
    bool small = false,
  }) {
    final sz = small ? 16.0 : 20.0;
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.all(small ? 3 : 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: enabled
                ? AppColors.secondary.withValues(alpha: 0.10)
                : Colors.transparent,
          ),
          child: Icon(
            icon,
            size: sz,
            color: enabled
                ? AppColors.secondary.withValues(alpha: 0.90)
                : AppColors.secondary.withValues(alpha: 0.25),
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required String tooltip,
  }) {
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary.withValues(alpha: enabled ? 0.14 : 0.05),
                AppColors.primary.withValues(alpha: enabled ? 0.05 : 0.02),
              ],
            ),
            border: Border.all(
              color: AppColors.secondary.withValues(alpha: enabled ? 0.48 : 0.20),
              width: 1.2,
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Icon(
            icon,
            color: AppColors.primary.withValues(alpha: enabled ? 0.85 : 0.30),
            size: 17,
          ),
        ),
      ),
    );
  }

  Widget _buildPlayPauseButton({
    required bool isPlaying,
    required bool isBuffering,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onPressed,
        child: SizedBox(
          width: 60,
          height: 60,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outermost animated gold ring — fades in while playing
              TweenAnimationBuilder<double>(
                key: ValueKey(isPlaying),
                tween: Tween(
                    begin: isPlaying ? 0.0 : 1.0,
                    end: isPlaying ? 1.0 : 0.0),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOut,
                builder: (context, v, _) {
                  return Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color:
                            AppColors.secondary.withValues(alpha: 0.32 * v),
                        width: 1.5,
                      ),
                    ),
                  );
                },
              ),
              // Static middle ring — always visible, subtle gold
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.22),
                    width: 0.8,
                  ),
                ),
              ),
              // Gradient inner disc with deep shadow
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.gradientMid, AppColors.primaryDark],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryDark.withValues(alpha: 0.42),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: AppColors.secondary.withValues(alpha: 0.14),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              Icon(
                isBuffering
                    ? Icons.hourglass_top_rounded
                    : (isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded),
                color: AppColors.secondary.withValues(alpha: 0.95),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ornamental helper widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Elaborate decorative top edge of the player panel.
/// Renders a green↔gold gradient bar, a gold shimmer glow beneath it,
/// and a floating gold diamond centred on the bar.
class _TopEdgeOrnament extends StatelessWidget {
  const _TopEdgeOrnament();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 12,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 2 px gradient bar: transparent → gold → green → gold → transparent
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 2,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0x000D5E3A),
                    Color(0xB3D4AF37),
                    Color(0xCC0D5E3A),
                    Color(0xB3D4AF37),
                    Color(0x000D5E3A),
                  ],
                  stops: [0.0, 0.2, 0.5, 0.8, 1.0],
                ),
              ),
            ),
          ),
          // Gold radiance glow beneath the bar
          Positioned(
            top: 2,
            left: 0,
            right: 0,
            child: Container(
              height: 10,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.secondary.withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Floating diamond centred on the bar
          Align(
            alignment: Alignment.topCenter,
            child: Transform.translate(
              offset: const Offset(0, -3),
              child: const _GoldDiamond(size: 8),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ornamental row flanking the title text.
/// Left side  (mirrored=false): line → small ◆ → large ◆
/// Right side (mirrored=true):  large ◆ → small ◆ → line
class _OrnamentRow extends StatelessWidget {
  final bool mirrored;
  const _OrnamentRow({required this.mirrored});

  @override
  Widget build(BuildContext context) {
    final line = Container(
      width: 16,
      height: 0.8,
      color: AppColors.secondary.withValues(alpha: 0.50),
    );
    const sm = _GoldDiamond(size: 4.5);
    const lg = _GoldDiamond(size: 7.0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: mirrored
          ? [lg, const SizedBox(width: 3), sm, const SizedBox(width: 3), line]
          : [line, const SizedBox(width: 3), sm, const SizedBox(width: 3), lg],
    );
  }
}

/// Pill-shaped styled time label used on the seek bar.
class _TimeLabel extends StatelessWidget {
  final String text;
  const _TimeLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: isDark
            ? AppColors.primary.withValues(alpha: 0.18)
            : AppColors.primary.withValues(alpha: 0.06),
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: isDark ? 0.30 : 0.18),
          width: 0.6,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: isDark
              ? AppColors.secondary.withValues(alpha: 0.85)
              : AppColors.primary.withValues(alpha: 0.58),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Tiny rotated gold square — the core diamond ornamental element.
class _GoldDiamond extends StatelessWidget {
  final double size;
  const _GoldDiamond({required this.size});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: math.pi / 4,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.goldGradientStart, AppColors.goldGradientEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(1.5),
        ),
      ),
    );
  }
}

/// Proper Islamic khatam (8-pointed star) tessellation used as the player
/// background pattern.
///
/// Layer 1 — 8-pointed stars at half-cell-offset grid points (main motif).
/// Layer 2 — Small rotated squares at grid corners (connecting diamond cells
///           that complete the traditional khatam interlace).
class _KhatamPatternPainter extends CustomPainter {
  final Color color;
  const _KhatamPatternPainter({required this.color});

  static const _cell = 34.0;

  @override
  void paint(Canvas canvas, Size size) {
    final starPaint = Paint()
      ..color = color.withValues(alpha: 0.055)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..strokeJoin = StrokeJoin.round;

    final linkPaint = Paint()
      ..color = color.withValues(alpha: 0.032)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;

    const outer = _cell * 0.40;
    const inner = outer * 0.42;

    // 8-pointed stars at half-cell-offset grid points
    for (double x = _cell / 2; x < size.width + _cell; x += _cell) {
      for (double y = _cell / 2; y < size.height + _cell; y += _cell) {
        _star8(canvas, starPaint, Offset(x, y), outer, inner);
      }
    }

    // Connecting rotated squares at grid corners
    for (double x = 0; x < size.width + _cell; x += _cell) {
      for (double y = 0; y < size.height + _cell; y += _cell) {
        _diamond(canvas, linkPaint, Offset(x, y), _cell * 0.20);
      }
    }
  }

  void _star8(Canvas canvas, Paint p, Offset c, double r, double ir) {
    final path = Path();
    for (int i = 0; i < 8; i++) {
      final oa = (i * math.pi / 4) - math.pi / 2;
      final ia = oa + math.pi / 8;
      if (i == 0) {
        path.moveTo(c.dx + r * math.cos(oa), c.dy + r * math.sin(oa));
      } else {
        path.lineTo(c.dx + r * math.cos(oa), c.dy + r * math.sin(oa));
      }
      path.lineTo(c.dx + ir * math.cos(ia), c.dy + ir * math.sin(ia));
    }
    path.close();
    canvas.drawPath(path, p);
  }

  void _diamond(Canvas canvas, Paint p, Offset c, double h) {
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy - h)
        ..lineTo(c.dx + h, c.dy)
        ..lineTo(c.dx, c.dy + h)
        ..lineTo(c.dx - h, c.dy)
        ..close(),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _KhatamPatternPainter old) =>
      old.color != color;
}
