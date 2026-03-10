import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../../../../core/constants/app_colors.dart';

// ──────────────────────────────────────────────────────
//  State enum – covers every broadcast situation cleanly
// ──────────────────────────────────────────────────────
enum _RadioState { connecting, playing, paused, error, noNetwork }

class QuranRadioScreen extends StatefulWidget {
  const QuranRadioScreen({super.key});

  @override
  State<QuranRadioScreen> createState() => _QuranRadioScreenState();
}

class _QuranRadioScreenState extends State<QuranRadioScreen>
    with TickerProviderStateMixin {
  late final AudioPlayer _player;
  late final AnimationController _waveController;
  late final AnimationController _pulseController;
  StreamSubscription<PlayerState>? _playerStateSub;

  // إذاعة القرآن الكريم بالقاهرة — Official Egyptian Radio streams
  static const _streams = [
    _RadioStream(label: 'جودة منخفضة', url: 'http://live.sec.gov.eg:9090/quranlow'),
    _RadioStream(label: 'جودة عالية',  url: 'http://live.sec.gov.eg:9090/quranhi'),
  ];

  static const _fallbackUrls = [
    'http://media1.radioways.com/quran',
    'https://n07.radiojar.com/8s5u5tpdtwzuv',
  ];

  int   _selectedStreamIndex = 0;
  _RadioState _state         = _RadioState.connecting;
  bool  _connecting          = false; // re-entrancy guard
  bool  _cancelConnect       = false; // cancellation flag
  bool  _usingFallback       = false;

  // ──────────────────────────  Lifecycle  ──────────────────────────
  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    // Detect unexpected mid-stream drops from the server.
    _playerStateSub = _player.playerStateStream.listen(_onPlayerStateChanged);
    _connect();
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _playerStateSub = null;
    // Pause before dispose so ExoPlayer doesn't need to flush the codec
    // during release. Flushing from a PLAYING state on some devices causes
    // FLUSHING→RESUMING→RUNNING→RELEASING race → LegacyMessageQueue dead thread.
    // Pause keeps the codec in RUNNING (no flush) so release is clean.
    _player.pause().ignore();
    _player.dispose();
    _waveController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _onPlayerStateChanged(PlayerState ps) {
    if (!mounted || _connecting || _playerStateSub == null) return;

    if (_state == _RadioState.playing &&
        ps.processingState == ProcessingState.idle &&
        !ps.playing) {
      // Server dropped the connection while we were live.
      setState(() => _state = _RadioState.error);
      _waveController.stop();
    } else if (ps.playing &&
        ps.processingState == ProcessingState.ready &&
        _state != _RadioState.playing) {
      setState(() => _state = _RadioState.playing);
      if (!_waveController.isAnimating) _waveController.repeat();
    } else if (!ps.playing &&
        ps.processingState == ProcessingState.ready &&
        _state == _RadioState.playing) {
      setState(() => _state = _RadioState.paused);
      _waveController.stop();
    }
  }

  // ──────────────────────────  Connection  ─────────────────────────
  Future<void> _connect() async {
    if (_connecting) return;
    _connecting    = true;
    _cancelConnect = false;
    try {
      if (mounted) {
        setState(() {
          _state        = _RadioState.connecting;
          _usingFallback = false;
        });
        _waveController.stop();
      }

      if (!await _isOnline()) {
        if (!_cancelConnect && mounted) {
          setState(() => _state = _RadioState.noNetwork);
        }
        return;
      }

      if (_cancelConnect) return;

      final urlsToTry = [
        _streams[_selectedStreamIndex].url,
        ..._fallbackUrls,
      ];

      for (int i = 0; i < urlsToTry.length; i++) {
        if (_cancelConnect || !mounted) return;
        await Future<void>.delayed(const Duration(milliseconds: 150));
        if (_cancelConnect || !mounted) return;

        try {
          await _player
              .setAudioSource(
                AudioSource.uri(
                  Uri.parse(urlsToTry[i]),
                  tag: MediaItem(
                    id:     'quran_radio_cairo_$i',
                    title:  'إذاعة القرآن الكريم',
                    artist: 'الإذاعة المصرية — القاهرة',
                  ),
                ),
              )
              .timeout(const Duration(seconds: 8));
          if (_cancelConnect || !mounted) return;
          await _player.play();
          if (mounted && !_cancelConnect) {
            setState(() {
              _state        = _RadioState.playing;
              _usingFallback = i > 0;
            });
            if (!_waveController.isAnimating) _waveController.repeat();
          }
          return;
        } catch (_) {
          // try next URL
        }
      }

      if (!_cancelConnect && mounted) {
        setState(() => _state = _RadioState.error);
        _waveController.stop();
      }
    } finally {
      _connecting = false;
    }
  }

  Future<bool> _isOnline() async {
    try {
      final r = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 2));
      return r.isNotEmpty && r[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ──────────────────────────  Actions  ────────────────────────────
  Future<void> _switchStream(int index) async {
    if (index == _selectedStreamIndex &&
        _state == _RadioState.playing &&
        !_usingFallback) { return; }
    if (_connecting) { _cancelConnect = true; }
    setState(() => _selectedStreamIndex = index);
    // Wait for any in-flight connection to exit.
    while (_connecting) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    await _connect();
  }

  Future<void> _togglePlayPause() async {
    // While connecting: cancel and return to paused/idle state.
    if (_connecting) {
      _cancelConnect = true;
      setState(() {
        _state = _RadioState.paused;
        _usingFallback = false;
      });
      _waveController.stop();
      return;
    }
    if (_state == _RadioState.error || _state == _RadioState.noNetwork) {
      await _connect();
      return;
    }
    if (_player.playing) {
      await _player.pause();
      setState(() => _state = _RadioState.paused);
      _waveController.stop();
    } else if (_player.processingState == ProcessingState.idle ||
               _player.processingState == ProcessingState.completed) {
      await _connect();
    } else {
      await _player.play();
      setState(() => _state = _RadioState.playing);
      if (!_waveController.isAnimating) _waveController.repeat();
    }
  }

  // ──────────────────────────  UI helpers  ─────────────────────────
  bool get _isBuffering =>
      _state == _RadioState.connecting ||
      _player.processingState == ProcessingState.loading ||
      _player.processingState == ProcessingState.buffering;

  bool get _hasError =>
      _state == _RadioState.error || _state == _RadioState.noNetwork;

  // ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.onPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'إذاعة القرآن الكريم',
          style: GoogleFonts.amiriQuran(
            color: AppColors.onPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          textDirection: TextDirection.rtl,
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.gradientStart, AppColors.gradientMid, AppColors.gradientEnd],
            ),
          ),
        ),
      ),
      body: _RadioBackground(
        isDark: isDark,
        child: SafeArea(
          child: StreamBuilder<PlayerState>(
            stream: _player.playerStateStream,
            builder: (context, _) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 28),

                      // ── Station identity card ──
                      _StationHeader(
                        isDark: isDark,
                        pulseController: _pulseController,
                        isLive: _state == _RadioState.playing,
                      ),

                      const SizedBox(height: 32),

                      // ── Wave visualiser ──
                      _WaveVisualiser(
                        controller: _waveController,
                        isActive: _state == _RadioState.playing,
                        isDark: isDark,
                      ),

                      const SizedBox(height: 20),

                      // ── Status chip ──
                      _StateChip(
                        state: _state,
                        usingFallback: _usingFallback,
                        isDark: isDark,
                      ),

                      const SizedBox(height: 24),

                      // ── Play / Pause button ──
                      _PlayButton(
                        state: _state,
                        isBuffering: _isBuffering,
                        onPressed: _togglePlayPause,
                        pulseController: _pulseController,
                        isDark: isDark,
                      ),

                      // Hint shown only while connecting.
                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                        child: _state == _RadioState.connecting
                            ? Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text(
                                  'جارٍ الاتصال... اضغط للإلغاء',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: (isDark ? Colors.white : Colors.black)
                                        .withValues(alpha: 0.45),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),

                      const SizedBox(height: 32),

                      // ── Quality selector ──
                      _QualitySelector(
                        streams: _streams,
                        selectedIndex: _usingFallback ? -1 : _selectedStreamIndex,
                        onSelect: _switchStream,
                        isDark: isDark,
                        usingFallback: _usingFallback,
                        enabled: !_connecting,
                      ),

                      if (_hasError) ...[
                        const SizedBox(height: 20),
                        _ErrorCard(
                          noNetwork: _state == _RadioState.noNetwork,
                          onRetry: _connect,
                        ),
                      ],

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//                      Sub-widgets
// ═══════════════════════════════════════════════════════

// ── Gradient background ──────────────────────────────
class _RadioBackground extends StatelessWidget {
  final bool isDark;
  final Widget child;
  const _RadioBackground({required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0F1419), Color(0xFF1A1F25)],
              )
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF5F0E8), Color(0xFFE8E0D0)],
              ),
      ),
      child: child,
    );
  }
}

// ── Station header (icon + name + live indicator) ────
class _StationHeader extends StatelessWidget {
  final bool isDark;
  final AnimationController pulseController;
  final bool isLive;

  const _StationHeader({
    required this.isDark,
    required this.pulseController,
    required this.isLive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: isDark
            ? const Color(0xFF1E2530)
            : Colors.white,
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: isDark ? 0.35 : 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.30)
                : AppColors.secondary.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Icon with pulsing ring when live
          AnimatedBuilder(
            animation: pulseController,
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.gradientStart, AppColors.gradientEnd],
                ),
                border: Border.all(color: AppColors.secondary, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.radio_rounded,
                color: AppColors.onPrimary,
                size: 44,
              ),
            ),
            builder: (context, child) {
              final scale = isLive
                  ? 1.0 + pulseController.value * 0.06
                  : 1.0;
              final ringOpacity = isLive
                  ? 0.20 + pulseController.value * 0.20
                  : 0.0;
              return Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 108,
                    height: 108,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.secondary.withValues(alpha: ringOpacity),
                        width: 3,
                      ),
                    ),
                  ),
                  Transform.scale(
                    scale: scale,
                    child: child,
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 18),

          Text(
            'إذاعة القرآن الكريم',
            textDirection: TextDirection.rtl,
            style: GoogleFonts.amiriQuran(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.secondary : AppColors.primary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'الإذاعة المصرية  ·  القاهرة',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? AppColors.secondary.withValues(alpha: 0.60)
                  : AppColors.textSecondary,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Animated wave visualiser ────────────────────────
class _WaveVisualiser extends StatelessWidget {
  final AnimationController controller;
  final bool isActive;
  final bool isDark;

  const _WaveVisualiser({
    required this.controller,
    required this.isActive,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = isDark ? AppColors.secondary : AppColors.primary;
    return SizedBox(
      height: 56,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, w) => CustomPaint(
          size: const Size(double.infinity, 56),
          painter: _WavePainter(
            progress: isActive ? controller.value : 0.5,
            color: baseColor,
            isActive: isActive,
          ),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool isActive;
  _WavePainter({required this.progress, required this.color, required this.isActive});

  @override
  void paint(Canvas canvas, Size size) {
    const barCount = 22;
    final spacing  = size.width / (barCount * 2 - 1);

    for (int i = 0; i < barCount; i++) {
      final phase     = (i / barCount + progress) * math.pi * 2;
      final amp       = isActive
          ? (math.sin(phase) * 0.40 + math.sin(phase * 2.1) * 0.15 + 0.60)
              .clamp(0.12, 1.0)
          : (0.18 + (i % 3) * 0.06); // subtle static bars when paused
      final h         = size.height * amp;
      final x         = i * spacing * 2;
      final y         = (size.height - h) / 2;

      final alpha = isActive ? 0.80 : 0.30;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, spacing, h),
          const Radius.circular(4),
        ),
        Paint()
          ..color = color.withValues(alpha: alpha)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) =>
      old.progress != progress || old.isActive != isActive;
}

// ── State chip ──────────────────────────────────────
class _StateChip extends StatelessWidget {
  final _RadioState state;
  final bool usingFallback;
  final bool isDark;
  const _StateChip({required this.state, required this.usingFallback, required this.isDark});

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final IconData icon;
    late final Color bg;
    late final Color fg;

    switch (state) {
      case _RadioState.connecting:
        label = 'جارٍ الاتصال…';
        icon  = Icons.sync_rounded;
        bg    = AppColors.secondary.withValues(alpha: 0.15);
        fg    = AppColors.secondary;
      case _RadioState.playing:
        if (usingFallback) {
          label = 'بث مباشر — رابط احتياطي';
          icon  = Icons.swap_horiz_rounded;
          bg    = const Color(0xFFFF8C00).withValues(alpha: 0.15);
          fg    = const Color(0xFFFF8C00);
        } else {
          label = '● بث مباشر';
          icon  = Icons.graphic_eq_rounded;
          bg    = AppColors.success.withValues(alpha: 0.12);
          fg    = AppColors.success;
        }
      case _RadioState.paused:
        label = 'متوقف مؤقتاً';
        icon  = Icons.pause_circle_outline_rounded;
        bg    = (isDark ? AppColors.darkCard : AppColors.divider).withValues(alpha: 0.5);
        fg    = isDark
            ? AppColors.secondary.withValues(alpha: 0.60)
            : AppColors.textSecondary;
      case _RadioState.noNetwork:
        label = 'لا يوجد اتصال بالإنترنت';
        icon  = Icons.wifi_off_rounded;
        bg    = AppColors.error.withValues(alpha: 0.12);
        fg    = AppColors.error;
      case _RadioState.error:
        label = 'تعذّر الاتصال — اضغط للمحاولة';
        icon  = Icons.error_outline_rounded;
        bg    = AppColors.error.withValues(alpha: 0.12);
        fg    = AppColors.error;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Container(
        key: ValueKey(label),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          textDirection: TextDirection.rtl,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 6),
            Text(
              label,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                color: fg,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Play / Pause button ─────────────────────────────
class _PlayButton extends StatelessWidget {
  final _RadioState state;
  final bool isBuffering;
  final VoidCallback onPressed;
  final AnimationController pulseController;
  final bool isDark;

  const _PlayButton({
    required this.state,
    required this.isBuffering,
    required this.onPressed,
    required this.pulseController,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = state == _RadioState.error || state == _RadioState.noNetwork;
    final isPlaying = state == _RadioState.playing;

    final IconData icon;
    if (isBuffering) {
      icon = Icons.pause_rounded; // placeholder; spinner shown instead
    } else if (hasError) {
      icon = Icons.refresh_rounded;
    } else if (isPlaying) {
      icon = Icons.pause_rounded;
    } else {
      icon = Icons.play_arrow_rounded;
    }

    return GestureDetector(
      onTap: onPressed,
      child: AnimatedBuilder(
        animation: pulseController,
        builder: (_, child) {
          final extraBlur = isPlaying ? pulseController.value * 8 : 0.0;
          return Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.gradientStart, AppColors.gradientEnd],
              ),
              border: Border.all(color: AppColors.secondary, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: isPlaying ? 0.45 : 0.25),
                  blurRadius: 20 + extraBlur,
                  spreadRadius: isPlaying ? 2 : 0,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: child,
          );
        },
        child: isBuffering
            ? Stack(
                alignment: Alignment.center,
                children: [
                  const SizedBox(
                    width: 46,
                    height: 46,
                    child: CircularProgressIndicator(
                      color: AppColors.onPrimary,
                      strokeWidth: 2.5,
                    ),
                  ),
                  const Icon(
                    Icons.stop_rounded,
                    color: AppColors.onPrimary,
                    size: 22,
                  ),
                ],
              )
            : AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  icon,
                  key: ValueKey(icon),
                  color: AppColors.onPrimary,
                  size: 46,
                ),
              ),
      ),
    );
  }
}

// ── Quality selector ────────────────────────────────
class _QualitySelector extends StatelessWidget {
  final List<_RadioStream> streams;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final bool isDark;
  final bool usingFallback;
  final bool enabled;

  const _QualitySelector({
    required this.streams,
    required this.selectedIndex,
    required this.onSelect,
    required this.isDark,
    required this.usingFallback,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'جودة البث',
          textDirection: TextDirection.rtl,
          style: TextStyle(
            color: isDark
                ? AppColors.secondary.withValues(alpha: 0.70)
                : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(streams.length, (i) {
            final selected = i == selectedIndex;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: enabled ? 1.0 : 0.50,
                child: GestureDetector(
                  onTap: enabled ? () => onSelect(i) : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: selected
                          ? const LinearGradient(
                              colors: [AppColors.gradientStart, AppColors.gradientEnd])
                          : null,
                      color: selected
                          ? null
                          : (isDark ? const Color(0xFF1E2530) : Colors.white),
                      border: Border.all(
                        color: selected
                            ? AppColors.secondary
                            : AppColors.secondary.withValues(alpha: 0.22),
                        width: selected ? 1.5 : 1.0,
                      ),
                      boxShadow: selected
                          ? [BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.28),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            )]
                          : null,
                    ),
                    child: Text(
                      streams[i].label,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        color: selected
                            ? AppColors.onPrimary
                            : (isDark ? AppColors.secondary : AppColors.primary),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        if (usingFallback) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFF8C00).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              textDirection: TextDirection.rtl,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 12, color: Color(0xFFFF8C00)),
                const SizedBox(width: 5),
                Text(
                  'يتم التشغيل من رابط احتياطي',
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    color: Color(0xFFFF8C00),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ── Error card with retry ────────────────────────────
class _ErrorCard extends StatelessWidget {
  final bool noNetwork;
  final VoidCallback onRetry;
  const _ErrorCard({required this.noNetwork, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            textDirection: TextDirection.rtl,
            children: [
              Icon(
                noNetwork ? Icons.wifi_off_rounded : Icons.signal_wifi_bad_rounded,
                color: AppColors.error,
                size: 18,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  noNetwork
                      ? 'لا يوجد اتصال بالإنترنت'
                      : 'تعذّر الاتصال بالإذاعة',
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            noNetwork
                ? 'تحقق من اتصالك بالإنترنت ثم اضغط إعادة المحاولة'
                : 'قد تكون الإذاعة غير متاحة مؤقتاً، اضغط إعادة المحاولة',
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.error.withValues(alpha: 0.80),
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 9),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.gradientStart, AppColors.gradientEnd],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'إعادة المحاولة',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  color: AppColors.onPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────  Data model  ─────────────────────────

class _RadioStream {
  final String label;
  final String url;
  const _RadioStream({required this.label, required this.url});
}


