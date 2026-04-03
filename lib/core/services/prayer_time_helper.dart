import 'package:adhan/adhan.dart';

import '../di/injection_container.dart' as di;
import 'prayer_times_cache_service.dart';

/// Data class for next-prayer information.
class NextPrayerInfo {
  final Prayer prayer;
  final String label;
  final DateTime time;
  final Duration remaining;

  const NextPrayerInfo({
    required this.prayer,
    required this.label,
    required this.time,
    required this.remaining,
  });
}

/// Shared helper that computes the current/next prayer and remaining time.
///
/// Used by both [NextPrayerCountdown] widget and the persistent foreground
/// notification so the logic is never duplicated.
class PrayerTimeHelper {
  const PrayerTimeHelper._();

  static const Map<String, String> arabicPrayerNames = {
    'fajr': 'الفجر',
    'sunrise': 'الشروق',
    'dhuhr': 'الظهر',
    'asr': 'العصر',
    'maghrib': 'المغرب',
    'isha': 'العشاء',
  };

  static const Map<String, String> englishPrayerNames = {
    'fajr': 'Fajr',
    'sunrise': 'Sunrise',
    'dhuhr': 'Dhuhr',
    'asr': 'Asr',
    'maghrib': 'Maghrib',
    'isha': 'Isha',
  };

  /// Ordered prayer list for iteration.
  static const List<({Prayer prayer, String key})> orderedPrayers = [
    (prayer: Prayer.fajr, key: 'fajr'),
    (prayer: Prayer.sunrise, key: 'sunrise'),
    (prayer: Prayer.dhuhr, key: 'dhuhr'),
    (prayer: Prayer.asr, key: 'asr'),
    (prayer: Prayer.maghrib, key: 'maghrib'),
    (prayer: Prayer.isha, key: 'isha'),
  ];

  /// Returns the next upcoming prayer with label and time remaining.
  /// Returns `null` if no cached prayer data is available.
  static NextPrayerInfo? getNextPrayer({PrayerTimesCacheService? cache}) {
    cache ??= di.sl<PrayerTimesCacheService>();
    final now = DateTime.now();
    final today = now;
    final cachedTimes = cache.getCachedTimesForDate(today);

    if (cachedTimes == null) {
      // Try tomorrow in case we're after Isha
      final tomorrow = today.add(const Duration(days: 1));
      final tomorrowTimes = cache.getCachedTimesForDate(tomorrow);
      if (tomorrowTimes == null) return null;

      final fajr = tomorrowTimes['fajr']!;
      return NextPrayerInfo(
        prayer: Prayer.fajr,
        label: 'Fajr',
        time: fajr,
        remaining: fajr.difference(now),
      );
    }

    // Find next prayer from today's times
    for (final p in orderedPrayers) {
      final time = cachedTimes[p.key];
      if (time != null && time.isAfter(now)) {
        return NextPrayerInfo(
          prayer: p.prayer,
          label: englishPrayerNames[p.key]!,
          time: time,
          remaining: time.difference(now),
        );
      }
    }

    // All prayers passed ➜ check tomorrow's Fajr
    final tomorrow = today.add(const Duration(days: 1));
    final tomorrowTimes = cache.getCachedTimesForDate(tomorrow);
    if (tomorrowTimes != null) {
      final fajr = tomorrowTimes['fajr']!;
      return NextPrayerInfo(
        prayer: Prayer.fajr,
        label: 'Fajr',
        time: fajr,
        remaining: fajr.difference(now),
      );
    }
    return null;
  }

  /// Returns the current prayer (the most recent one that has started).
  /// Returns `null` if no cached data or before Fajr.
  static NextPrayerInfo? getCurrentPrayer({PrayerTimesCacheService? cache}) {
    cache ??= di.sl<PrayerTimesCacheService>();
    final now = DateTime.now();
    final cachedTimes = cache.getCachedTimesForDate(now);
    if (cachedTimes == null) return null;

    // Walk prayers in reverse to find the latest one that has passed.
    // Skip sunrise – it's not a prayer.
    const prayersOnly = [
      (prayer: Prayer.isha, key: 'isha'),
      (prayer: Prayer.maghrib, key: 'maghrib'),
      (prayer: Prayer.asr, key: 'asr'),
      (prayer: Prayer.dhuhr, key: 'dhuhr'),
      (prayer: Prayer.fajr, key: 'fajr'),
    ];

    for (final p in prayersOnly) {
      final time = cachedTimes[p.key];
      if (time != null && !time.isAfter(now)) {
        return NextPrayerInfo(
          prayer: p.prayer,
          label: englishPrayerNames[p.key]!,
          time: time,
          remaining: now.difference(time),
        );
      }
    }
    return null;
  }

  /// Localized prayer name in Arabic.
  static String getArabicName(Prayer prayer) {
    switch (prayer) {
      case Prayer.fajr:
        return 'الفجر';
      case Prayer.sunrise:
        return 'الشروق';
      case Prayer.dhuhr:
        return 'الظهر';
      case Prayer.asr:
        return 'العصر';
      case Prayer.maghrib:
        return 'المغرب';
      case Prayer.isha:
        return 'العشاء';
      default:
        return '';
    }
  }

  /// Localized prayer name in English.
  static String getEnglishName(Prayer prayer) {
    switch (prayer) {
      case Prayer.fajr:
        return 'Fajr';
      case Prayer.sunrise:
        return 'Sunrise';
      case Prayer.dhuhr:
        return 'Dhuhr';
      case Prayer.asr:
        return 'Asr';
      case Prayer.maghrib:
        return 'Maghrib';
      case Prayer.isha:
        return 'Isha';
      default:
        return '';
    }
  }

  /// Format a [Duration] as HH:MM:SS or MM:SS.
  static String formatDuration(Duration duration) {
    if (duration.isNegative) return '...';

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  /// Format a [Duration] as HH:MM (no seconds) for the notification.
  static String formatDurationShort(Duration duration) {
    if (duration.isNegative) return '...';

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}';
  }
}
