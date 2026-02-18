import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/audio/ayah_audio_cubit.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/surah_names.dart';
import '../bloc/surah/surah_bloc.dart';
import '../bloc/surah/surah_state.dart';

/// Islamic-themed audio player with complex ornamental design
class IslamicAudioPlayer extends StatelessWidget {
  final bool isArabicUi;

  const IslamicAudioPlayer({super.key, required this.isArabicUi});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AyahAudioCubit, AyahAudioState>(
      builder: (context, audioState) {
        final visible = audioState.status != AyahAudioStatus.idle;
        if (!visible) return const SizedBox.shrink();

        final isSurahMode = audioState.mode == AyahAudioMode.surah;
        final isPlaying = audioState.status == AyahAudioStatus.playing;
        final isBuffering = audioState.status == AyahAudioStatus.buffering;

        final cubit = context.read<AyahAudioCubit>();

        // Get the actual playing surah name from audioState
        final playingSurahNumber = audioState.surahNumber;
        final playingAyahNumber = audioState.ayahNumber;

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary.withValues(alpha: 0.15),
                AppColors.primary.withValues(alpha: 0.08),
                AppColors.secondary.withValues(alpha: 0.12),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Stack(
              children: [
                // Islamic pattern background
                Positioned.fill(
                  child: CustomPaint(
                    painter: _AudioPlayerPatternPainter(
                      color: AppColors.primary,
                    ),
                  ),
                ),
                // Main content
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title with Islamic frame - built from audioState
                      Builder(
                        builder: (context) {
                          String title = '';
                          if (playingSurahNumber != null) {
                            // Use static surah names - no need to depend on SurahBloc state
                            String surahName = SurahNames.getName(
                              playingSurahNumber,
                              isArabicUi,
                            );

                            // Fallback if invalid surah number
                            if (surahName.isEmpty) {
                              surahName = isArabicUi
                                  ? 'القرآن الكريم'
                                  : 'Quran';
                            }

                            if (playingAyahNumber != null) {
                              title =
                                  '$surahName • ${isArabicUi ? 'الآية' : 'Ayah'} $playingAyahNumber';
                            } else {
                              title = surahName;
                            }
                          } else {
                            title = isArabicUi ? 'القرآن الكريم' : 'Quran';
                          }

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.3,
                                    ),
                                    width: 1,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.primary.withValues(alpha: 0.05),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildIslamicIcon(
                                      Icons.music_note,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    _buildIslamicIcon(
                                      Icons.music_note,
                                      size: 14,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                          );
                        },
                      ),

                      // Controls with Islamic design
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Previous button
                          if (isSurahMode)
                            _buildControlButton(
                              icon: Icons.skip_previous_rounded,
                              onPressed: () => cubit.previous(),
                              tooltip: isArabicUi ? 'السابق' : 'Previous',
                            ),
                          if (isSurahMode) const SizedBox(width: 8),

                          // Play/Pause button (larger)
                          _buildPlayPauseButton(
                            isPlaying: isPlaying,
                            isBuffering: isBuffering,
                            onPressed: () {
                              if (isSurahMode && playingSurahNumber != null) {
                                // Get number of ayahs from SurahBloc
                                final surahState = context
                                    .read<SurahBloc>()
                                    .state;
                                int? numberOfAyahs;
                                if (surahState is SurahListLoaded) {
                                  try {
                                    final surah = surahState.surahs.firstWhere(
                                      (s) => s.number == playingSurahNumber,
                                    );
                                    numberOfAyahs = surah.numberOfAyahs;
                                  } catch (e) {
                                    numberOfAyahs = null;
                                  }
                                }
                                if (numberOfAyahs != null) {
                                  cubit.togglePlaySurah(
                                    surahNumber: playingSurahNumber,
                                    numberOfAyahs: numberOfAyahs,
                                  );
                                }
                              } else {
                                if (audioState.surahNumber != null &&
                                    audioState.ayahNumber != null) {
                                  cubit.togglePlayAyah(
                                    surahNumber: audioState.surahNumber!,
                                    ayahNumber: audioState.ayahNumber!,
                                  );
                                }
                              }
                            },
                            tooltip: isPlaying
                                ? (isArabicUi ? 'إيقاف مؤقت' : 'Pause')
                                : (isBuffering
                                      ? (isArabicUi
                                            ? 'جاري التحميل…'
                                            : 'Loading…')
                                      : (isArabicUi ? 'تشغيل' : 'Play')),
                          ),

                          if (isSurahMode) const SizedBox(width: 8),
                          // Next button
                          if (isSurahMode)
                            _buildControlButton(
                              icon: Icons.skip_next_rounded,
                              onPressed: () => cubit.next(),
                              tooltip: isArabicUi ? 'التالي' : 'Next',
                            ),

                          const SizedBox(width: 8),
                          // Stop button
                          _buildControlButton(
                            icon: Icons.stop_rounded,
                            onPressed: () => cubit.stop(),
                            tooltip: isArabicUi ? 'إيقاف' : 'Stop',
                            color: AppColors.error,
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Progress bar with Islamic design
                      StreamBuilder<Duration>(
                        stream: cubit.positionStream,
                        builder: (context, posSnap) {
                          return StreamBuilder<Duration?>(
                            stream: cubit.durationStream,
                            builder: (context, durSnap) {
                              final pos = posSnap.data ?? Duration.zero;
                              final dur = durSnap.data ?? Duration.zero;
                              final maxMs = dur.inMilliseconds;
                              final value = maxMs <= 0
                                  ? 0.0
                                  : (pos.inMilliseconds / maxMs).clamp(
                                      0.0,
                                      1.0,
                                    );

                              return Column(
                                children: [
                                  // Custom Islamic progress bar
                                  Stack(
                                    children: [
                                      // Background track
                                      Container(
                                        height: 6,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            3,
                                          ),
                                          gradient: LinearGradient(
                                            colors: [
                                              AppColors.primary.withValues(
                                                alpha: 0.1,
                                              ),
                                              AppColors.primary.withValues(
                                                alpha: 0.2,
                                              ),
                                              AppColors.primary.withValues(
                                                alpha: 0.1,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // Progress
                                      FractionallySizedBox(
                                        widthFactor: value,
                                        child: Container(
                                          height: 6,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              3,
                                            ),
                                            gradient: LinearGradient(
                                              colors: [
                                                AppColors.primary,
                                                AppColors.secondary,
                                              ],
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppColors.primary
                                                    .withValues(alpha: 0.5),
                                                blurRadius: 8,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // Progress indicator ornament
                                      if (value > 0)
                                        Positioned(
                                          left:
                                              (MediaQuery.of(
                                                        context,
                                                      ).size.width -
                                                      32) *
                                                  value -
                                              6,
                                          top: -2,
                                          child: Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: RadialGradient(
                                                colors: [
                                                  AppColors.secondary,
                                                  AppColors.primary,
                                                ],
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: AppColors.secondary
                                                      .withValues(alpha: 0.6),
                                                  blurRadius: 6,
                                                  spreadRadius: 1,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),

                                  // Time labels
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _formatDuration(pos),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              fontSize: 11,
                                              color: AppColors.textSecondary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      Text(
                                        _formatDuration(dur),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              fontSize: 11,
                                              color: AppColors.textSecondary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),

                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildIslamicIcon(IconData icon, {double size = 20}) {
    return Container(
      width: size + 8,
      height: size + 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.2),
            AppColors.primary.withValues(alpha: 0.05),
          ],
        ),
      ),
      child: Icon(
        icon,
        size: size,
        color: AppColors.primary.withValues(alpha: 0.7),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    Color? color,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: (color ?? AppColors.primary).withValues(alpha: 0.3),
            width: 1.5,
          ),
          gradient: RadialGradient(
            colors: [
              (color ?? AppColors.primary).withValues(alpha: 0.1),
              (color ?? AppColors.primary).withValues(alpha: 0.05),
              Colors.transparent,
            ],
          ),
        ),
        child: IconButton(
          icon: Icon(icon, color: color ?? AppColors.primary),
          onPressed: onPressed,
          iconSize: 20,
          padding: EdgeInsets.zero,
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
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              AppColors.primary,
              AppColors.primary.withValues(alpha: 0.8),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 12,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: AppColors.secondary.withValues(alpha: 0.3),
              blurRadius: 16,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Pulsing ring animation when playing
            if (isPlaying)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(seconds: 2),
                builder: (context, value, child) {
                  return Container(
                    width: 52 + (value * 16),
                    height: 52 + (value * 16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.secondary.withValues(
                          alpha: 0.5 * (1 - value),
                        ),
                        width: 2,
                      ),
                    ),
                  );
                },
                onEnd: () {
                  // Loop animation
                },
              ),
            // Icon
            IconButton(
              icon: Icon(
                isBuffering
                    ? Icons.hourglass_top_rounded
                    : (isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded),
                color: Colors.white,
              ),
              onPressed: onPressed,
              iconSize: 36,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Custom painter for Islamic pattern background
class _AudioPlayerPatternPainter extends CustomPainter {
  final Color color;

  _AudioPlayerPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const patternSize = 30.0;
    for (double x = 0; x < size.width; x += patternSize) {
      for (double y = 0; y < size.height; y += patternSize) {
        // Draw small Islamic geometric pattern
        final center = Offset(x + patternSize / 2, y + patternSize / 2);
        final radius = patternSize / 4;

        // Draw 4-pointed star
        final path = Path();
        for (int i = 0; i < 8; i++) {
          final angle = (i * math.pi / 4) - math.pi / 2;
          final r = i % 2 == 0 ? radius : radius / 2;
          final px = center.dx + r * math.cos(angle);
          final py = center.dy + r * math.sin(angle);

          if (i == 0) {
            path.moveTo(px, py);
          } else {
            path.lineTo(px, py);
          }
        }
        path.close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
