import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class IslamicLogo extends StatelessWidget {
  final double size;
  final Color? primaryColor;
  final Color? accentColor;

  const IslamicLogo({
    super.key,
    this.size = 200,
    this.primaryColor,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _IslamicPatternPainter(
        primary: primaryColor ?? AppColors.primary,
        accent: accentColor ?? AppColors.secondary,
      ),
    );
  }
}

class _IslamicPatternPainter extends CustomPainter {
  final Color primary;
  final Color accent;

  _IslamicPatternPainter({required this.primary, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    final Paint linePaint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.02
      ..isAntiAlias = true;

    final Paint fillPaint = Paint()
      ..color = primary
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Draw background circle (optional, usually transparent is better for logos)
    // canvas.drawCircle(center, radius, fillPaint..color = primary.withOpacity(0.1));

    // 1. Draw the 8-pointed Star (Rub el Hizb) Base
    final Path starPath = _createStarPath(center, radius * 0.9, 8);
    canvas.drawPath(starPath, fillPaint);
    canvas.drawPath(starPath, linePaint);

    // 2. Draw Inner Geometric Interlace (Complex Pattern)
    // This creates a rotated square inside the star
    final double innerRadius = radius * 0.6;
    final Path innerSquare1 = _createPolygonPath(center, innerRadius, 4, 0);
    final Path innerSquare2 = _createPolygonPath(center, innerRadius, 4, math.pi / 4);
    
    final Paint innerLinePaint = Paint()
      ..color = Colors.white.withOpacity(0.9) // White lines on green looks very clean
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.015;

    canvas.drawPath(innerSquare1, innerLinePaint);
    canvas.drawPath(innerSquare2, innerLinePaint);

    // 3. Central Calligraphy Placeholder (Circle)
    final double centerCircleRadius = radius * 0.25;
    final Paint centerFill = Paint()..color = accent;
    canvas.drawCircle(center, centerCircleRadius, centerFill);
    
    // Draw decorative rim around center
    canvas.drawCircle(
      center, 
      centerCircleRadius * 0.85, 
      Paint()..color = primary
    );
  }

  Path _createStarPath(Offset center, double radius, int points) {
    final Path path = Path();
    final double step = math.pi / points; // Half step for the inner points
    final double innerRadius = radius * 0.75; // Ratio for 8-pointed star

    // Start at the top point
    path.moveTo(
      center.dx + radius * math.cos(-math.pi / 2),
      center.dy + radius * math.sin(-math.pi / 2),
    );

    for (int i = 1; i <= points * 2; i++) {
      final double angle = -math.pi / 2 + step * i;
      final double r = (i.isEven) ? radius : innerRadius;
      path.lineTo(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
    }
    path.close();
    return path;
  }

  Path _createPolygonPath(Offset center, double radius, int sides, double startAngle) {
    final Path path = Path();
    final double angleStep = (2 * math.pi) / sides;

    path.moveTo(
      center.dx + radius * math.cos(startAngle),
      center.dy + radius * math.sin(startAngle),
    );

    for (int i = 1; i < sides; i++) {
      path.lineTo(
        center.dx + radius * math.cos(startAngle + angleStep * i),
        center.dy + radius * math.sin(startAngle + angleStep * i),
      );
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
