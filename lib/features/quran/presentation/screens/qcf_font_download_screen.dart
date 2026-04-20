import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/services/qcf_font_download_service.dart';
import '../../../../core/settings/app_settings_cubit.dart';

// -- Palette -------------------------------------------------------------------
const _kBgTop     = Color(0xFF061510);
const _kBgBottom  = Color(0xFF0C2318);
const _kGold      = Color(0xFFC8A84B);
const _kGoldLight = Color(0xFFE2C97E);
const _kGoldDim   = Color(0xFF8A7030);
const _kCream     = Color(0xFFF5EFD9);
const _kSubText   = Color(0xFF90A898);
const _kBarBg     = Color(0xFF1A3524);
const _kDivider   = Color(0xFF2A4535);

/// Full-screen widget shown on first launch (or when fonts are incomplete) to
/// let the user download the remaining 538 QCF tajweed font files.
class QcfFontDownloadScreen extends StatefulWidget {
  /// Called when the user taps "لاحقاً" (skip) or when the download completes.
  final VoidCallback onDone;

  const QcfFontDownloadScreen({super.key, required this.onDone});

  /// Pushes [QcfFontDownloadScreen] only when fonts are not fully downloaded.
  /// Otherwise calls [onDone] immediately.
  static Future<void> showIfNeeded(
    BuildContext context, {
    required VoidCallback onDone,
  }) async {
    final complete = await QcfFontDownloadService.isFullyDownloaded();
    if (complete) { onDone(); return; }
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => QcfFontDownloadScreen(onDone: onDone),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  State<QcfFontDownloadScreen> createState() => _QcfFontDownloadScreenState();
}

enum _DLState { idle, downloading, done, error }

class _QcfFontDownloadScreenState extends State<QcfFontDownloadScreen>
    with SingleTickerProviderStateMixin {
  _DLState _state      = _DLState.idle;
  double   _progress   = 0.0;
  int      _pending    = 0;
  int      _done       = 0;
  String   _phase      = '';
  CancelToken? _cancelToken;

  late final AnimationController _glowCtrl;
  late final Animation<double>   _glowAnim;

  bool _isAr(BuildContext context) => context
      .read<AppSettingsCubit>()
      .state
      .appLanguageCode
      .toLowerCase()
      .startsWith('ar');

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _glowAnim = CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut);
    _loadPending();
  }

  Future<void> _loadPending() async {
    final c = await QcfFontDownloadService.pendingDownloadCount();
    if (mounted) setState(() => _pending = c);
  }

  Future<void> _startDownload() async {
    if (_state == _DLState.downloading) return;
    _cancelToken = CancelToken();
    setState(() { _state = _DLState.downloading; _progress = 0; _done = 0; });

    final ok = await QcfFontDownloadService.downloadAll(
      onProgress: (p) { if (mounted) setState(() => _progress = p); },
      onPhase:    (ph) { if (mounted) setState(() => _phase = ph); },
      onPageDone: (_)  { if (mounted) setState(() => _done++); },
      cancelToken: _cancelToken,
    );

    if (!mounted) return;
    if (ok) {
      setState(() { _state = _DLState.done; _progress = 1.0; });
      await Future.delayed(const Duration(milliseconds: 900));
      widget.onDone();
    } else {
      setState(() => _state = _DLState.error);
    }
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    _glowCtrl.dispose();
    super.dispose();
  }

  // -- Build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_kBgTop, _kBgBottom],
          ),
        ),
        child: SafeArea(
          child: Directionality(
            textDirection: _isAr(context) ? TextDirection.rtl : TextDirection.ltr,
            child: Column(
              children: [
                // -- Ornamental header --------------------------------------
                _OrnamentalHeader(glowAnim: _glowAnim),

                // -- Scrollable body ----------------------------------------
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Title
                        Text(
                          _isAr(context) ? 'خطوط القرآن الكريم' : 'Quran Fonts',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.cairo(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: _kGold,
                            shadows: [
                              Shadow(
                                color: _kGold.withValues(alpha: 0.45),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Sub-title
                        Text(
                          _isAr(context) ? 'تحميل خطوط المصحف المدني' : 'Download Medina Mushaf Fonts',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.cairo(
                            fontSize: 15,
                            color: _kGoldLight.withValues(alpha: 0.75),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // -- Decorative divider -----------------------------
                        const _OrnamentalDivider(),
                        const SizedBox(height: 20),

                        // Description
                        Text(
                          _isAr(context)
                              ? 'لعرض المصحف بالخط العثماني الحفص يحتاج التطبيق إلى تحميل '
                              'ملفات الخطوط مرة واحدة فقط، وتُخزّن على جهازك للاستخدام '
                              'بدون إنترنت.'
                              : 'To display the Mushaf in Uthmani Hafs script, the app needs to '
                              'download font files once. They are stored on your device for '
                              'offline use.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            color: _kCream.withValues(alpha: 0.8),
                            height: 1.75,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // -- Size notice ------------------------------------
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                          decoration: BoxDecoration(
                            color: _kGold.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: _kGold.withValues(alpha: 0.28),
                                width: 1),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.wifi_rounded,
                                  size: 16,
                                  color: _kGold.withValues(alpha: 0.7)),
                              const SizedBox(width: 8),
                              Text(
                                _isAr(context) ? 'الحجم التقريبي: ٦٥ ميجابايت (تحميل لمرة واحدة)' : 'Approx. size: 65 MB (one-time download)',
                                style: GoogleFonts.cairo(
                                  fontSize: 13,
                                  color: _kGoldLight.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),

                        // -- Progress area ----------------------------------
                        if (_state == _DLState.downloading ||
                            _state == _DLState.done) ...[
                          _ProgressSection(
                            progress: _progress,
                            done: _done,
                            pending: _pending,
                            phase: _phase,
                            isDone: _state == _DLState.done,
                          ),
                          const SizedBox(height: 24),
                        ],

                        // -- Error ------------------------------------------
                        if (_state == _DLState.error) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: Colors.red.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.wifi_off_rounded,
                                    color: Colors.redAccent, size: 22),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _isAr(context) ? 'فشل التحميل - تحقق من الاتصال بالإنترنت' : 'Download failed - check your internet connection',
                                    style: GoogleFonts.cairo(
                                      color: Colors.redAccent.shade100,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // -- Primary button ---------------------------------
                        if (_state != _DLState.done)
                          _GoldButton(
                            label: _state == _DLState.error
                                ? (_isAr(context) ? 'إعادة المحاولة' : 'Retry')
                                : (_isAr(context) ? 'تحميل خطوط المصحف' : 'Download Mushaf Fonts'),
                            isLoading: _state == _DLState.downloading,
                            onTap: _state == _DLState.downloading
                                ? null
                                : _startDownload,
                          ),

                        const SizedBox(height: 14),

                        // -- Skip -------------------------------------------
                        if (_state != _DLState.done &&
                            _state != _DLState.downloading)
                          GestureDetector(
                            onTap: widget.onDone,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 6),
                              child: Text(
                                _isAr(context) ? 'لاحقاً - تصفح القرآن بالعرض المبسّط' : 'Later - Browse Quran in Simplified View',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.cairo(
                                  fontSize: 13,
                                  color: _kSubText,
                                  decoration: TextDecoration.underline,
                                  decorationColor: _kSubText,
                                ),
                              ),
                            ),
                          ),

                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -- Ornamental header ---------------------------------------------------------

class _OrnamentalHeader extends StatelessWidget {
  final Animation<double> glowAnim;
  const _OrnamentalHeader({required this.glowAnim});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Backdrop glow circle
          AnimatedBuilder(
            animation: glowAnim,
            builder: (_, __) => Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _kGold.withValues(
                        alpha: 0.08 + 0.10 * glowAnim.value),
                    blurRadius: 60 + 30 * glowAnim.value,
                    spreadRadius: 10,
                  ),
                ],
              ),
            ),
          ),
          // Outer ornamental ring
          CustomPaint(
            size: const Size(180, 180),
            painter: _StarRingPainter(color: _kGoldDim),
          ),
          // Inner ring
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: _kGold.withValues(alpha: 0.35), width: 1),
              color: _kGold.withValues(alpha: 0.06),
            ),
          ),
          // Quran icon
          Icon(
            Icons.menu_book_rounded,
            size: 52,
            color: _kGold.withValues(alpha: 0.92),
          ),
        ],
      ),
    );
  }
}

// -- Star-ring custom painter --------------------------------------------------

class _StarRingPainter extends CustomPainter {
  final Color color;
  const _StarRingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width / 2 - 4;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Dashed circle
    const totalDash = 120;
    final dashStep = 2 * math.pi / totalDash;
    for (int i = 0; i < totalDash; i += 2) {
      final startA = i * dashStep;
      final endA   = startA + dashStep * 0.7;
      canvas.drawArc(
          Rect.fromCircle(center: Offset(cx, cy), radius: r),
          startA, endA - startA, false, paint);
    }

    // 8 star points
    final tipPaint = Paint()
      ..color = color.withValues(alpha: 0.65)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 8; i++) {
      final angle = i * math.pi / 4 - math.pi / 8;
      final tipX  = cx + (r + 5) * math.cos(angle);
      final tipY  = cy + (r + 5) * math.sin(angle);
      canvas.drawCircle(Offset(tipX, tipY), 2, tipPaint);
    }
  }

  @override
  bool shouldRepaint(_StarRingPainter old) => old.color != color;
}

// -- Ornamental divider --------------------------------------------------------

class _OrnamentalDivider extends StatelessWidget {
  const _OrnamentalDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.transparent,
                _kGoldDim.withValues(alpha: 0.65),
              ]),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text('✦', style: TextStyle(color: _kGold.withValues(alpha: 0.7), fontSize: 12)),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                _kGoldDim.withValues(alpha: 0.65),
                Colors.transparent,
              ]),
            ),
          ),
        ),
      ],
    );
  }
}

// -- Progress section ----------------------------------------------------------

class _ProgressSection extends StatelessWidget {
  final double progress;
  final int done;
  final int pending;
  final String phase;
  final bool isDone;

  const _ProgressSection({
    required this.progress,
    required this.done,
    required this.pending,
    required this.phase,
    required this.isDone,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Phase label
        if (phase.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone ? _kGold : _kGoldLight,
                    boxShadow: [
                      BoxShadow(
                          color: _kGold.withValues(alpha: isDone ? 0.6 : 0.3),
                          blurRadius: 6),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isDone ? 'اكتمل التحميل ✓' : phase,
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      color: isDone ? _kGold : _kCream.withValues(alpha: 0.85),
                      fontWeight: isDone ? FontWeight.w700 : FontWeight.normal,
                    ),
                  ),
                ),
                Text(
                  '$percent%',
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    color: _kGoldLight,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              // Background track
              Container(
                height: 12,
                color: _kBarBg,
              ),
              // Fill
              AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 300),
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _kGoldDim,
                        _kGold,
                        _kGoldLight,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _kGold.withValues(alpha: 0.5),
                        blurRadius: 8,
                        offset: const Offset(0, 0),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Count label - only shown during extraction phase (not archive-download phase)
        if (!isDone && pending > 0 && (done > 0 || phase.contains('استخراج')))
          Text(
            '$done / $pending صفحة',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 12,
              color: _kSubText,
            ),
          ),
      ],
    );
  }
}

// -- Gold button ---------------------------------------------------------------

class _GoldButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onTap;

  const _GoldButton({
    required this.label,
    required this.isLoading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: onTap != null
              ? const LinearGradient(
                  colors: [Color(0xFF9A7124), _kGold, Color(0xFFDAB44E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: onTap == null ? _kBarBg : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: onTap != null ? _kGoldLight.withValues(alpha: 0.4) : _kDivider,
            width: 1,
          ),
          boxShadow: onTap != null
              ? [
                  BoxShadow(
                    color: _kGold.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF0C2318)),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.download_rounded,
                      color: onTap != null
                          ? const Color(0xFF0C2318)
                          : _kSubText,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: GoogleFonts.cairo(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: onTap != null
                            ? const Color(0xFF0C2318)
                            : _kSubText,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
