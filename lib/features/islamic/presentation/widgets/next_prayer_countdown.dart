import 'dart:async';
import 'package:flutter/material.dart';
import 'package:adhan/adhan.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/services/prayer_times_cache_service.dart';

/// A widget that displays a countdown to the next prayer time.
class NextPrayerCountdown extends StatefulWidget {
  const NextPrayerCountdown({super.key});

  @override
  State<NextPrayerCountdown> createState() => _NextPrayerCountdownState();
}

class _NextPrayerCountdownState extends State<NextPrayerCountdown> {
  Timer? _timer;
  ({Prayer prayer, String label, DateTime time})? _nextPrayer;
  Duration? _timeRemaining;

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
    final cache = di.sl<PrayerTimesCacheService>();
    
    final today = DateTime.now();
    final cachedTimes = cache.getCachedTimesForDate(today);
    
    if (cachedTimes == null) {
      // Try tomorrow in case we're after Isha
      final tomorrow = today.add(const Duration(days: 1));
      final tomorrowTimes = cache.getCachedTimesForDate(tomorrow);
      
      if (tomorrowTimes == null) {
        setState(() {
          _nextPrayer = null;
          _timeRemaining = null;
        });
        return;
      }
      
      // Next is tomorrow's Fajr
      final fajr = tomorrowTimes['fajr']!;
      setState(() {
        _nextPrayer = (prayer: Prayer.fajr, label: 'Fajr', time: fajr);
        _timeRemaining = fajr.difference(DateTime.now());
      });
      return;
    }

    // Find next prayer from today's times
    final now = DateTime.now();
    final prayers = [
      (prayer: Prayer.fajr, label: 'Fajr', time: cachedTimes['fajr']!),
      (prayer: Prayer.dhuhr, label: 'Dhuhr', time: cachedTimes['dhuhr']!),
      (prayer: Prayer.asr, label: 'Asr', time: cachedTimes['asr']!),
      (prayer: Prayer.maghrib, label: 'Maghrib', time: cachedTimes['maghrib']!),
      (prayer: Prayer.isha, label: 'Isha', time: cachedTimes['isha']!),
    ];

    for (final p in prayers) {
      if (p.time.isAfter(now)) {
        setState(() {
          _nextPrayer = p;
          _timeRemaining = p.time.difference(now);
        });
        return;
      }
    }

    // All prayers passed, check tomorrow's Fajr
    final tomorrow = today.add(const Duration(days: 1));
    final tomorrowTimes = cache.getCachedTimesForDate(tomorrow);
    
    if (tomorrowTimes != null) {
      final fajr = tomorrowTimes['fajr']!;
      setState(() {
        _nextPrayer = (prayer: Prayer.fajr, label: 'Fajr', time: fajr);
        _timeRemaining = fajr.difference(now);
      });
    } else {
      setState(() {
        _nextPrayer = null;
        _timeRemaining = null;
      });
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) return '...';
    
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  IconData _getPrayerIcon(Prayer prayer) {
    switch (prayer) {
      case Prayer.fajr:
        return Icons.wb_twilight;
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
    switch (prayer) {
      case Prayer.fajr:
        return isArabic ? 'الفجر' : 'Fajr';
      case Prayer.dhuhr:
        return isArabic ? 'الظهر' : 'Dhuhr';
      case Prayer.asr:
        return isArabic ? 'العصر' : 'Asr';
      case Prayer.maghrib:
        return isArabic ? 'المغرب' : 'Maghrib';
      case Prayer.isha:
        return isArabic ? 'العشاء' : 'Isha';
      case Prayer.sunrise:
        return isArabic ? 'الشروق' : 'Sunrise';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_nextPrayer == null || _timeRemaining == null) {
      return const SizedBox.shrink();
    }

    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.1),
            AppColors.secondary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getPrayerIcon(_nextPrayer!.prayer),
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic ? 'الصلاة القادمة' : 'Next Prayer',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getPrayerName(context, _nextPrayer!.prayer),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatDuration(_timeRemaining!),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: AppColors.primary,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                '${_nextPrayer!.time.hour.toString().padLeft(2, '0')}:${_nextPrayer!.time.minute.toString().padLeft(2, '0')}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
