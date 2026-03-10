import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qcf_quran/qcf_quran.dart';

import '../../../../core/constants/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// QcfPageviewDemoScreen
// عرض كامل للمصحف الشريف بخطوط QCF الرسمية باستخدام PageviewQuran
// يبدأ العرض من سورة البقرة (صفحة 2) بشكل افتراضي
// ─────────────────────────────────────────────────────────────────────────────

class QcfPageviewDemoScreen extends StatefulWidget {
  /// 1-based starting page. Default is 2 (Al-Baqarah).
  final int initialPage;

  const QcfPageviewDemoScreen({super.key, this.initialPage = 2});

  @override
  State<QcfPageviewDemoScreen> createState() => _QcfPageviewDemoScreenState();
}

class _QcfPageviewDemoScreenState extends State<QcfPageviewDemoScreen> {
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor =
        isDark ? const Color(0xFF0E1A12) : const Color(0xFFFFF9ED);
    final textColor =
        isDark ? const Color(0xFFE8E8E8) : const Color(0xFF1A1A1A);
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.18)
        : const Color(0xFFC8A84B).withValues(alpha: 0.55);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: Text(
          'المصحف الشريف',
          style: GoogleFonts.amiriQuran(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Center(
              child: Text(
                _toArabicNumerals(_currentPage),
                style: GoogleFonts.amiriQuran(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        color: bgColor,
        // ── Islamic background pattern ──────────────────────────────────
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _IslamicPatternPainter(color: AppColors.primary),
              ),
            ),
            // ── Quran PageView ──────────────────────────────────────────
            Column(
              children: [
                // Top thin divider bar
                Container(
                  height: 1,
                  color: dividerColor,
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final screenSize = MediaQuery.of(context).size;

                      // Compute responsive scaling ratios so QcfPage
                      // adapts to the actual available area instead of
                      // the full screen dimensions.
                      final double sp = constraints.maxWidth.isFinite
                          ? constraints.maxWidth / screenSize.width
                          : 1.0;
                      final double h = constraints.maxHeight.isFinite
                          ? constraints.maxHeight / screenSize.height
                          : 1.0;

                      return PageviewQuran(
                        initialPageNumber: widget.initialPage,
                        sp: sp,
                        h: h,
                        physics: const BouncingScrollPhysics(),
                        theme: QcfThemeData(
                          verseTextColor: textColor,
                          pageBackgroundColor: Colors.transparent,
                          verseHeight: 2.2,
                        ),
                        onPageChanged: (page) {
                          if (mounted) setState(() => _currentPage = page);
                          HapticFeedback.selectionClick();
                        },
                      );
                    },
                  ),
                ),
                // Bottom page-number footer
                Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: bgColor,
                    border: Border(
                      top: BorderSide(color: dividerColor, width: 0.8),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.asset(
                        'assets/logo/files/transparent/label.png',
                        height: 28,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.80)
                            : null,
                        errorBuilder: (context, error, stack) => const SizedBox.shrink(),
                      ),
                      Text(
                        _toArabicNumerals(_currentPage),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.amiriQuran(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF3D1C00),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Arabic numeral helper ─────────────────────────────────────────────────────
String _toArabicNumerals(int n) {
  const digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  return n.toString().split('').map((c) {
    final d = int.tryParse(c);
    return d != null ? digits[d] : c;
  }).join();
}

// ── Subtle Islamic trellis background painter ─────────────────────────────────
class _IslamicPatternPainter extends CustomPainter {
  final Color color;
  const _IslamicPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.022)
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;

    const step = 28.0;
    for (double x = 0; x < size.width + step; x += step) {
      for (double y = 0; y < size.height + step; y += step) {
        canvas.drawCircle(Offset(x, y), step * 0.36, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_IslamicPatternPainter old) => old.color != color;
}
