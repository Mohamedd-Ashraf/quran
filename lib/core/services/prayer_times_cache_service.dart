import 'dart:convert';
import 'package:adhan/adhan.dart';
import '../constants/prayer_calculation_constants.dart';
import 'settings_service.dart';

/// Caches prayer times for an upcoming period to support offline use.
class PrayerTimesCacheService {
  final SettingsService _settings;

  PrayerTimesCacheService(this._settings);

  /// Pre-calculate and store prayer times for the next 30 days.
  Future<void> cachePrayerTimes(double latitude, double longitude) async {
    final coords = Coordinates(latitude, longitude);
    
    // Get user's preferred calculation method
    final calculationMethod = _settings.getPrayerCalculationMethod();
    final asrMethod = _settings.getPrayerAsrMethod();
    final params = PrayerCalculationConstants.getCompleteParameters(
      calculationMethod: calculationMethod,
      asrMethod: asrMethod,
    );
    
    final now = DateTime.now();

    // Store prayer times for next 30 days
    final Map<String, Map<String, String>> cachedTimes = {};

    for (int i = 0; i < 30; i++) {
      final date = now.add(Duration(days: i));
      final dateComponents = DateComponents(date.year, date.month, date.day);
      final prayerTimes = PrayerTimes(coords, dateComponents, params);

      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      cachedTimes[dateKey] = {
        'fajr': prayerTimes.fajr.toIso8601String(),
        'sunrise': prayerTimes.sunrise.toIso8601String(),
        'dhuhr': prayerTimes.dhuhr.toIso8601String(),
        'asr': prayerTimes.asr.toIso8601String(),
        'maghrib': prayerTimes.maghrib.toIso8601String(),
        'isha': prayerTimes.isha.toIso8601String(),
      };
    }

    // Add metadata
    final cacheData = {
      'cachedAt': DateTime.now().toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'times': cachedTimes,
    };

    await _settings.setCachedPrayerTimes(jsonEncode(cacheData));
  }

  /// Get cached prayer times for a specific date.
  /// Returns null if cache is invalid, expired, or missing.
  Map<String, DateTime>? getCachedTimesForDate(DateTime date) {
    final cached = _settings.getCachedPrayerTimes();
    if (cached == null) return null;

    try {
      final data = jsonDecode(cached) as Map<String, dynamic>;
      final cachedAt = DateTime.parse(data['cachedAt'] as String);

      // Cache is valid for 7 days
      if (DateTime.now().difference(cachedAt).inDays > 7) {
        return null;
      }

      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final times = (data['times'] as Map<String, dynamic>)[dateKey] as Map<String, dynamic>?;

      if (times == null) return null;

      return {
        'fajr': DateTime.parse(times['fajr'] as String),
        'sunrise': DateTime.parse(times['sunrise'] as String),
        'dhuhr': DateTime.parse(times['dhuhr'] as String),
        'asr': DateTime.parse(times['asr'] as String),
        'maghrib': DateTime.parse(times['maghrib'] as String),
        'isha': DateTime.parse(times['isha'] as String),
      };
    } catch (e) {
      return null;
    }
  }

  /// Check if cache is valid and recent (less than 7 days old).
  bool isCacheValid() {
    final cached = _settings.getCachedPrayerTimes();
    if (cached == null) return false;

    try {
      final data = jsonDecode(cached) as Map<String, dynamic>;
      final cachedAt = DateTime.parse(data['cachedAt'] as String);
      return DateTime.now().difference(cachedAt).inDays <= 7;
    } catch (e) {
      return false;
    }
  }

  /// Get cached location coordinates if available.
  ({double latitude, double longitude})? getCachedLocation() {
    final cached = _settings.getCachedPrayerTimes();
    if (cached == null) return null;

    try {
      final data = jsonDecode(cached) as Map<String, dynamic>;
      return (
        latitude: data['latitude'] as double,
        longitude: data['longitude'] as double,
      );
    } catch (e) {
      return null;
    }
  }
}
