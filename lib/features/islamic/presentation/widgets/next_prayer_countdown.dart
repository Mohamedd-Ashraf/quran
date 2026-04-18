import 'dart:async';
import 'package:flutter/material.dart';
import 'package:adhan/adhan.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/prayer_time_helper.dart';
import '../../../../core/services/prayer_times_cache_service.dart';
import '../../../../core/di/injection_container.dart' as di;

/// A widget that displays a countdown to the next prayer time.
class NextPrayerCountdown extends StatefulWidget {
  const NextPrayerCountdown({super.key});

  @override
  State<NextPrayerCountdown> createState() => _NextPrayerCountdownState();
}

class _NextPrayerCountdownState extends State<NextPrayerCountdown> {
  Timer? _timer;
  NextPrayerInfo? _nextPrayer;
  NextPrayerInfo? _currentPrayer;

  // Cached Cairo style — avoids calling GoogleFonts on every rebuild
  // which triggers repeated network font-load attempts and exceptions.
  static final TextStyle _cairoBase = GoogleFonts.cairo();
  static TextStyle _cairo({
    required double fontSize,
    required FontWeight fontWeight,
    Color? color,
    double? height,
    List<FontFeature>? fontFeatures,
  }) => _cairoBase.copyWith(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height,
    fontFeatures: fontFeatures,
  );

  // Amiri — classical Arabic calligraphic font, gives traditional Quran-style
  // numerals while fully respecting TextStyle color.
  static final TextStyle _amiriBase = GoogleFonts.amiri();
  static TextStyle _digitStyle({
    required double fontSize,
    Color? color,
    double? height,
  }) => _amiriBase.copyWith(
    fontSize: fontSize,
    color: color,
    height: height,
    fontWeight: FontWeight.w700,
  );

  /// Convert ASCII digits to Arabic-Indic (same as verse numbers in Quran pages).
  static String _toArabicNum(int n) {
    const d = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return n.toString().split('').map((c) => d[int.parse(c)]).join();
  }

  @override
  void initState() {
    super.initState();
    _calculate();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _calculate());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _calculate() {
    setState(() {
      _nextPrayer = PrayerTimeHelper.getNextPrayer();
      _currentPrayer = PrayerTimeHelper.getCurrentPrayer();
    });
  }

  IconData _getPrayerIcon(Prayer prayer) {
    switch (prayer) {
      case Prayer.fajr:    return Icons.wb_twilight;
      case Prayer.sunrise: return Icons.wb_twilight_rounded;
      case Prayer.dhuhr:   return Icons.wb_sunny_rounded;
      case Prayer.asr:     return Icons.sunny;
      case Prayer.maghrib: return Icons.wb_twilight;
      case Prayer.isha:    return Icons.nights_stay_rounded;
      default:             return Icons.access_time;
    }
  }

  String _getPrayerName(BuildContext context, Prayer prayer) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return isArabic
        ? PrayerTimeHelper.getArabicName(prayer)
        : PrayerTimeHelper.getEnglishName(prayer);
  }

  /// Converts ASCII digits 0-9 to Arabic-Indic ٠-٩.
  String _toArabicDigits(String input) {
    const ar = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return input.split('').map((c) {
      final d = int.tryParse(c);
      return d != null ? ar[d] : c;
    }).join();
  }

  /// Returns 0..1 — how far through the current prayer window we are.
  double _getProgress() {
    if (_nextPrayer == null) return 0;
    final now = DateTime.now();
    if (_currentPrayer != null) {
      final total =
          _nextPrayer!.time.difference(_currentPrayer!.time).inSeconds;
      final elapsed = now.difference(_currentPrayer!.time).inSeconds;
      if (total > 0) return (elapsed / total).clamp(0.0, 1.0);
    }
    // Fallback: assume a 2-hour window
    final remaining = _nextPrayer!.remaining.inSeconds;
    const window = 7200;
    return ((window - remaining) / window).clamp(0.0, 1.0);
  }

  // ─── Design tokens ─────────────────────────────────────────────────────
  // Dark card: saturated greens
  static const _darkCard1    = Color(0xFF1B6B47);
  static const _darkCard2    = Color(0xFF0D4A2E);
  // Light card: darker mint — more substantial on light backgrounds
  static const _lightCard1   = Color(0xFFD0EAE0);
  static const _lightCard2   = Color(0xFFB0E0CC);

  static const _goldLight    = Color(0xFFF0D060);
  static const _goldLightSub = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    if (_nextPrayer == null) return const SizedBox.shrink();

    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isSunrise = _nextPrayer!.prayer == Prayer.sunrise;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = _getProgress();

    // ── Adaptive colours ──────────────────────────────────────────────────
    final cardColor1   = isDark ? _darkCard1 : _lightCard1;
    final cardColor2   = isDark ? _darkCard2 : _lightCard2;
    // Text on dark card → bright gold/white. On light mint card → dark green.
    final nameColor    = isDark ? _goldLight  : AppColors.primary;
    final labelColor   = isDark
        ? _goldLightSub.withValues(alpha: 0.65)
        : AppColors.textSecondary;
    final timeColor    = isDark
        ? Colors.white.withValues(alpha: 0.42)
        : AppColors.textPrimary;
    final heroColor    = isDark ? Colors.white : AppColors.primaryDark;
    final remainColor  = isDark
        ? Colors.white.withValues(alpha: 0.38)
        : AppColors.textSecondary.withValues(alpha: 0.70);
    final iconBgColor  = isDark
        ? _goldLightSub.withValues(alpha: 0.12)
        : AppColors.primary.withValues(alpha: 0.10);
    final iconBorder   = isDark
        ? _goldLightSub.withValues(alpha: 0.35)
        : AppColors.primary.withValues(alpha: 0.22);
    final iconColor    = isDark ? _goldLight : AppColors.primary;
    final shadowColor  = isDark
        ? _goldLightSub.withValues(alpha: 0.14)
        : AppColors.primary.withValues(alpha: 0.10);
    final cardBorder   = isDark
        ? _goldLightSub.withValues(alpha: 0.22)
        : AppColors.primary.withValues(alpha: 0.18);
    // Green gradient only — no gold
    final progressG1   = isDark ? const Color(0xFF2EAD72) : const Color(0xFF6EE7B7);
    final progressG2   = isDark ? const Color(0xFF1A8A58) : const Color(0xFF34D399);
    final progressG3   = isDark ? const Color(0xFF1A8A58) : AppColors.primary;
    final trackColor   = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : AppColors.primary.withValues(alpha: 0.12);

    // Build prayer time string
    final h = _nextPrayer!.time.hour;
    final m = _nextPrayer!.time.minute;
    final period = isArabic ? (h >= 12 ? 'م' : 'ص') : (h >= 12 ? 'PM' : 'AM');
    final hour12 = h % 12 == 0 ? 12 : h % 12;
    final hour12Str = isArabic ? _toArabicNum(hour12) : hour12.toString().padLeft(2, '0');
    final mStr = isArabic ? _toArabicNum(m) : m.toString().padLeft(2, '0');
    final prayerTimeStr = '$hour12Str:$mStr $period';

    // Countdown
    final secs = _nextPrayer!.remaining.inSeconds;
    String fmt(int v) => v.toString().padLeft(2, '0');
    // Convert to Arabic numerals using same method as verse numbers
    final displayH = isArabic ? _toArabicNum(secs ~/ 3600) : fmt(secs ~/ 3600);
    final displayM = isArabic ? _toArabicNum((secs % 3600) ~/ 60) : fmt((secs % 3600) ~/ 60);
    final displayS = isArabic ? _toArabicNum(secs % 60) : fmt(secs % 60);

    // Labels
    final locationName = di.sl<PrayerTimesCacheService>().getCachedLocationName();
    final prayerName = isSunrise
        ? (isArabic ? 'الشروق' : 'Sunrise')
        : _getPrayerName(context, _nextPrayer!.prayer);
    final labelStr = isSunrise
        ? (isArabic ? 'وقت الشروق' : 'Sunrise Time')
        : (isArabic ? 'الصلاة القادمة' : 'Next Prayer');

    // Countdown accent colours
    final unitColor    = isDark ? _goldLightSub.withValues(alpha: 0.65) : AppColors.primary.withValues(alpha: 0.55);
    final sepColor     = isDark ? Colors.white.withValues(alpha: 0.22) : AppColors.primary.withValues(alpha: 0.28);
    final dividerColor = isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.primary.withValues(alpha: 0.09);
    final countdownDigitColor = isDark ? Colors.white : Colors.black;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cardColor1, cardColor2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Prayer identity row ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Prayer icon bubble
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: iconBorder, width: 1),
                  ),
                  child: Icon(
                    _getPrayerIcon(_nextPrayer!.prayer),
                    color: iconColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                // Prayer label + name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        labelStr,
                        style: TextStyle(
                          color: labelColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        prayerName,
                        style: _cairo(
                          color: nameColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                // Prayer time + location (right side)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (locationName != null && locationName.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_on_rounded, size: 10, color: labelColor),
                          const SizedBox(width: 2),
                          Text(
                            locationName,
                            style: TextStyle(fontSize: 10, color: labelColor),
                          ),
                        ],
                      ),
                    const SizedBox(height: 3),
                    Text(
                      prayerTimeStr,
                      style: isArabic 
                          ? _digitStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontSize: 16,
                              height: 1.0,
                            )
                          : _cairo(
                              color: timeColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // ── Divider ────────────────────────────────────────────────────────
          Container(height: 1, color: dividerColor, margin: const EdgeInsets.symmetric(horizontal: 10)),
          // ── Countdown — always LTR: hours → minutes → seconds ──────────────
          Directionality(
            textDirection: TextDirection.ltr,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: Row(
                children: [
                  _CountUnit(value: displayH, label: isArabic ? 'ساعات'  : 'Hours',   digitColor: countdownDigitColor, labelColor: unitColor),
                  _CountSep(color: sepColor),
                  _CountUnit(value: displayM, label: isArabic ? 'دقائق'  : 'Minutes', digitColor: countdownDigitColor, labelColor: unitColor),
                  _CountSep(color: sepColor),
                  _CountUnit(value: displayS, label: isArabic ? 'ثواني'  : 'Seconds', digitColor: countdownDigitColor, labelColor: unitColor),
                ],
              ),
            ),
          ),
          // ─── Gradient progress bar ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: _GradientProgressBar(
              progress: progress,
              colors: [progressG1, progressG2, progressG3],
              trackColor: trackColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Countdown unit: label above, large digit below
// ─────────────────────────────────────────────────────────────────────────────

class _CountUnit extends StatelessWidget {
  final String value;
  final String label;
  final Color digitColor;
  final Color labelColor;
  const _CountUnit({
    required this.value,
    required this.label,
    required this.digitColor,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: labelColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: _NextPrayerCountdownState._digitStyle(
              color: digitColor,
              fontSize: 30,
              height: 1.0,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Colon separator between countdown units
// ─────────────────────────────────────────────────────────────────────────────

class _CountSep extends StatelessWidget {
  final Color color;
  const _CountSep({required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 13), // align with digit (below label)
      child: Text(
        ':',
        style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w700, height: 1.0),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Gradient progress bar helper
// ─────────────────────────────────────────────────────────────────────────────

class _GradientProgressBar extends StatelessWidget {
  final double progress;
  final List<Color> colors;
  final Color trackColor;

  const _GradientProgressBar({
    required this.progress,
    required this.colors,
    required this.trackColor,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final fillWidth = constraints.maxWidth * progress.clamp(0.0, 1.0);
        return ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(
            height: 5,
            width: constraints.maxWidth,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(color: trackColor),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: fillWidth,
                    height: 5,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: colors),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
