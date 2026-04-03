import 'dart:async';
import 'package:flutter/material.dart';
import 'package:adhan/adhan.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/prayer_time_helper.dart';

/// A widget that displays a countdown to the next prayer time.
class NextPrayerCountdown extends StatefulWidget {
  const NextPrayerCountdown({super.key});

  @override
  State<NextPrayerCountdown> createState() => _NextPrayerCountdownState();
}

class _NextPrayerCountdownState extends State<NextPrayerCountdown> {
  Timer? _timer;
  NextPrayerInfo? _nextPrayer;

  @override
  void initState() {
    super.initState();
    _calculateNextPrayer();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _calculateNextPrayer();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _calculateNextPrayer() {
    setState(() {
      _nextPrayer = PrayerTimeHelper.getNextPrayer();
    });
  }

  IconData _getPrayerIcon(Prayer prayer) {
    switch (prayer) {
      case Prayer.fajr:
        return Icons.wb_twilight;
      case Prayer.sunrise:
        return Icons.wb_twilight_rounded;
      case Prayer.dhuhr:
        return Icons.wb_sunny;
      case Prayer.asr:
        return Icons.sunny;
      case Prayer.maghrib:
        return Icons.wb_twilight;
      case Prayer.isha:
        return Icons.nights_stay;
      default:
        return Icons.access_time;
    }
  }

  String _getPrayerName(BuildContext context, Prayer prayer) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return isArabic
        ? PrayerTimeHelper.getArabicName(prayer)
        : PrayerTimeHelper.getEnglishName(prayer);
  }

  @override
  Widget build(BuildContext context) {
    if (_nextPrayer == null) {
      return const SizedBox.shrink();
    }

    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isSunrise = _nextPrayer!.prayer == Prayer.sunrise;

    // Sunrise uses a warm amber palette; prayers use the default green.
    const sunGold   = Color(0xFFF59E0B);
    const sunOrange = Color(0xFFFB923C);
    final activeColor  = isSunrise ? sunGold   : AppColors.primary;
    final activeBorder = isSunrise ? sunOrange : AppColors.primary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isSunrise
              ? [
                  sunGold.withValues(alpha: 0.10),
                  sunOrange.withValues(alpha: 0.05),
                ]
              : [
                  AppColors.primary.withValues(alpha: 0.1),
                  AppColors.secondary.withValues(alpha: 0.05),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: activeBorder.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: activeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getPrayerIcon(_nextPrayer!.prayer),
              color: activeColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSunrise
                      ? (isArabic ? 'وقت الشروق' : 'Sunrise')
                      : (isArabic ? 'الصلاة القادمة' : 'Next Prayer'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isSunrise
                            ? sunGold.withValues(alpha: 0.80)
                            : AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  isSunrise
                      ? (isArabic ? 'الشروق' : 'Sunrise')
                      : _getPrayerName(context, _nextPrayer!.prayer),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: activeColor,
                      ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                PrayerTimeHelper.formatDuration(_nextPrayer!.remaining),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: activeColor,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                () {
                  final h = _nextPrayer!.time.hour;
                  final m = _nextPrayer!.time.minute;
                  final period = isArabic
                      ? (h >= 12 ? 'م' : 'ص')
                      : (h >= 12 ? 'PM' : 'AM');
                  final hour12 = h % 12 == 0 ? 12 : h % 12;
                  return '${hour12.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period';
                }(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isSunrise
                          ? sunGold.withValues(alpha: 0.70)
                          : AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
