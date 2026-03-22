import 'dart:async';

import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/prayer_calculation_constants.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../core/services/prayer_times_cache_service.dart';
import '../../../../core/settings/app_settings_cubit.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/services/reverse_geocoding_service.dart';
import 'adhan_settings_screen.dart';

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  final LocationService _location = const LocationService();

  bool _loading = true;
  String? _error;

  PrayerTimes? _prayerTimes;
  Coordinates? _coordinates;
  String _calcMethodId = 'egyptian';
  bool _locationFromCache = false;
  bool _updatingLocation = false;
  String? _placeName;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Loads prayer times. Uses cached coordinates by default to avoid
  /// prompting the user for location every time.
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _prayerTimes = null;
      _coordinates = null;
      _locationFromCache = false;
      _placeName = null;
    });

    final settings = di.sl<SettingsService>();
    final cachedCoords = settings.getLastKnownCoordinates();

    if (cachedCoords != null) {
      // Use saved coordinates – no need to ask for location permission again
      _computePrayerTimes(cachedCoords, settings, fromCache: true);
      return;
    }

    // No cached location yet – fetch fresh GPS
    await _fetchFreshLocation(settings);
  }

  /// Forces a fresh GPS reading and saves the new coordinates to cache.
  Future<void> _updateLocation() async {
    setState(() => _updatingLocation = true);
    final settings = di.sl<SettingsService>();
    await _fetchFreshLocation(settings);
    setState(() => _updatingLocation = false);
  }

  Future<void> _fetchFreshLocation(SettingsService settings) async {
    setState(() {
      _loading = true;
      _error = null;
      _prayerTimes = null;
      _coordinates = null;
      _locationFromCache = false;
      _placeName = null;
    });

    final permission = await _location.ensurePermission();
    if (!mounted) return;

    if (permission != LocationPermissionState.granted) {
      setState(() {
        _loading = false;
        _error = _permissionError(permission);
      });
      return;
    }

    try {
      final pos = await _location.getPosition();
      final coords = Coordinates(pos.latitude, pos.longitude);

      // Save location to local storage for future use
      await settings.setLastKnownCoordinates(pos.latitude, pos.longitude);

      // Cache prayer times for next 30 days (offline support)
      await di.sl<PrayerTimesCacheService>().cachePrayerTimes(
        pos.latitude,
        pos.longitude,
        locationName: null,
      );

      // Auto-detect calculation method if user hasn't manually overridden it
      if (settings.getPrayerMethodAutoDetected()) {
        final autoMethod = PrayerCalculationConstants.methodFromCoordinates(
          pos.latitude, pos.longitude,
        );
        await settings.setPrayerCalculationMethod(autoMethod);
      }

      if (!mounted) return;
      _computePrayerTimes(coords, settings, fromCache: false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is TimeoutException
            ? 'Timed out getting GPS fix. Try again or move to an open area.'
            : e.toString();
      });
    }
  }

  /// Computes prayer times from given [coords] and updates state.
  void _computePrayerTimes(
    Coordinates coords,
    SettingsService settings, {
    required bool fromCache,
  }) {
    final calcMethod = settings.getPrayerCalculationMethod();
    final asrMethod = settings.getPrayerAsrMethod();
    final params = PrayerCalculationConstants.getCompleteParameters(
      calculationMethod: calcMethod,
      asrMethod: asrMethod,
    );

    final now = DateTime.now();
    final prayerTimes = PrayerTimes(
      coords,
      DateComponents(now.year, now.month, now.day),
      params,
    );

    if (!mounted) return;
    setState(() {
      _loading = false;
      _coordinates = coords;
      _prayerTimes = prayerTimes;
      _calcMethodId = calcMethod;
      _locationFromCache = fromCache;
    });
    _fetchPlaceName(coords);
  }

  Future<void> _fetchPlaceName(Coordinates coords) async {
    final isArabic = context
        .read<AppSettingsCubit>()
        .state
        .appLanguageCode
        .toLowerCase()
        .startsWith('ar');
    final name = await ReverseGeocodingService.getPlaceName(
      coords.latitude,
      coords.longitude,
      arabic: isArabic,
    );
    if (mounted && name != null) {
      setState(() => _placeName = name);
      // Save location name to cache after it's fetched
      await di.sl<PrayerTimesCacheService>().cachePrayerTimes(
        coords.latitude,
        coords.longitude,
        locationName: name,
      );
    }
  }

  String _permissionError(LocationPermissionState state) {
    switch (state) {
      case LocationPermissionState.serviceDisabled:
        return 'Location services are disabled.';
      case LocationPermissionState.denied:
        return 'Location permission denied.';
      case LocationPermissionState.deniedForever:
        return 'Location permission permanently denied.';
      case LocationPermissionState.granted:
        return '';
    }
  }

  String _formatTime(BuildContext context, DateTime dt) {
    final local = dt.toLocal();
    final tod = TimeOfDay.fromDateTime(local);
    return MaterialLocalizations.of(context).formatTimeOfDay(
      tod,
      alwaysUse24HourFormat: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabicUi = context
        .watch<AppSettingsCubit>()
        .state
        .appLanguageCode
        .toLowerCase()
        .startsWith('ar');

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabicUi ? 'مواقيت الصلاة' : 'Prayer Times'),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        actions: [
          // Update / change location
          _updatingLocation
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                )
              : IconButton(
                  onPressed: _updateLocation,
                  icon: const Icon(Icons.my_location_rounded),
                  tooltip:
                      isArabicUi ? 'تحديث الموقع' : 'Update Location',
                ),
          IconButton(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AdhanSettingsScreen(),
                ),
              );
              // Reload after returning from settings (method may have changed)
              _load();
            },
            icon: const Icon(Icons.settings_rounded),
            tooltip: isArabicUi ? 'إعدادات الأذان' : 'Adhan Settings',
          ),
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(
                  isArabicUi: isArabicUi,
                  message: isArabicUi
                      ? 'تعذر الحصول على الموقع/المواقيت: $_error'
                      : 'Could not get location/prayer times: $_error',
                  onOpenSettings: () async {
                    await _location.openAppSettings();
                  },
                  onOpenLocation: () async {
                    await _location.openLocationSettings();
                  },
                )
              : _PrayerTimesBody(
                  isArabicUi: isArabicUi,
                  prayerTimes: _prayerTimes!,
                  coordinates: _coordinates!,
                  calcMethodId: _calcMethodId,
                  locationFromCache: _locationFromCache,
                  placeName: _placeName,
                  onUpdateLocation: _updateLocation,
                  formatTime: (dt) => _formatTime(context, dt),
                ),
    );
  }
}

class _PrayerTimesBody extends StatefulWidget {
  final bool isArabicUi;
  final PrayerTimes prayerTimes;
  final Coordinates coordinates;
  final String calcMethodId;
  final bool locationFromCache;
  final String? placeName;
  final VoidCallback onUpdateLocation;
  final String Function(DateTime) formatTime;

  const _PrayerTimesBody({
    required this.isArabicUi,
    required this.prayerTimes,
    required this.coordinates,
    required this.calcMethodId,
    required this.locationFromCache,
    this.placeName,
    required this.onUpdateLocation,
    required this.formatTime,
  });

  @override
  State<_PrayerTimesBody> createState() => _PrayerTimesBodyState();
}

class _PrayerTimesBodyState extends State<_PrayerTimesBody> {
  Timer? _minuteTimer;

  @override
  void initState() {
    super.initState();
    // Refresh every minute so the next-prayer highlight stays current.
    _minuteTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _minuteTimer?.cancel();
    super.dispose();
  }

  /// Returns the next upcoming mandatory prayer (skips sunrise).
  Prayer _nextPrayer() {
    final now = DateTime.now();
    final pt = widget.prayerTimes;
    if (now.isBefore(pt.fajr.toLocal()))    return Prayer.fajr;
    if (now.isBefore(pt.dhuhr.toLocal()))   return Prayer.dhuhr;
    if (now.isBefore(pt.asr.toLocal()))     return Prayer.asr;
    if (now.isBefore(pt.maghrib.toLocal())) return Prayer.maghrib;
    if (now.isBefore(pt.isha.toLocal()))    return Prayer.isha;
    return Prayer.none; // after Isha
  }

  /// Human-readable countdown string to [target].
  String _timeUntil(DateTime target) {
    final diff = target.toLocal().difference(DateTime.now());
    if (diff.isNegative) return '';
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    if (h > 0) {
      return widget.isArabicUi ? 'بعد ${h}س ${m}د' : 'in ${h}h ${m}m';
    }
    return widget.isArabicUi ? 'بعد ${m}د' : 'in ${m}m';
  }

  String _formattedDate() {
    final now = DateTime.now();
    final isArabicUi = widget.isArabicUi;
    final weekdays = isArabicUi
        ? ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد']
        : ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = isArabicUi
        ? ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر']
        : ['January','February','March','April','May','June','July','August','September','October','November','December'];
    return isArabicUi
        ? '${weekdays[now.weekday - 1]}، ${now.day} ${months[now.month - 1]} ${now.year}'
        : '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final next        = _nextPrayer();
    final isArabicUi  = widget.isArabicUi;
    final pt          = widget.prayerTimes;
    final formatTime  = widget.formatTime;
    final methodInfo  = PrayerCalculationConstants.calculationMethods[widget.calcMethodId];
    final methodLabel = methodInfo == null
        ? widget.calcMethodId
        : (isArabicUi ? methodInfo.nameAr : methodInfo.nameEn);

    // Pre-compute countdowns for each prayer
    String countdown(Prayer p) {
      if (next != p) return '';
      return switch (p) {
        Prayer.fajr    => _timeUntil(pt.fajr),
        Prayer.dhuhr   => _timeUntil(pt.dhuhr),
        Prayer.asr     => _timeUntil(pt.asr),
        Prayer.maghrib => _timeUntil(pt.maghrib),
        Prayer.isha    => _timeUntil(pt.isha),
        _              => '',
      };
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [const Color(0xFF0D1B2A), const Color(0xFF0A1520), const Color(0xFF080F18)]
              : [const Color(0xFFF4F7F6), const Color(0xFFECF2EF), const Color(0xFFE8F0EC)],
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 36),
        children: [
          _HeaderRow(
            dateStr: _formattedDate(),
            isArabicUi: isArabicUi,
            coordinates: widget.coordinates,
            placeName: widget.placeName,
            locationFromCache: widget.locationFromCache,
            onUpdateLocation: widget.onUpdateLocation,
            isDark: isDark,
          ),
          const SizedBox(height: 16),
          _PrayerTile(
            prayerKey: 'fajr',
            title: isArabicUi ? 'الفجر' : 'Fajr',
            time: formatTime(pt.fajr),
            isNext: next == Prayer.fajr,
            countdown: countdown(Prayer.fajr),
            isArabicUi: isArabicUi,
          ),
          _SunriseTile(
            title: isArabicUi ? 'الشروق' : 'Sunrise',
            time: formatTime(pt.sunrise),
          ),
          _PrayerTile(
            prayerKey: 'dhuhr',
            title: isArabicUi ? 'الظهر' : 'Dhuhr',
            time: formatTime(pt.dhuhr),
            isNext: next == Prayer.dhuhr,
            countdown: countdown(Prayer.dhuhr),
            isArabicUi: isArabicUi,
          ),
          _PrayerTile(
            prayerKey: 'asr',
            title: isArabicUi ? 'العصر' : 'Asr',
            time: formatTime(pt.asr),
            isNext: next == Prayer.asr,
            countdown: countdown(Prayer.asr),
            isArabicUi: isArabicUi,
          ),
          _PrayerTile(
            prayerKey: 'maghrib',
            title: isArabicUi ? 'المغرب' : 'Maghrib',
            time: formatTime(pt.maghrib),
            isNext: next == Prayer.maghrib,
            countdown: countdown(Prayer.maghrib),
            isArabicUi: isArabicUi,
          ),
          _PrayerTile(
            prayerKey: 'isha',
            title: isArabicUi ? 'العشاء' : 'Isha',
            time: formatTime(pt.isha),
            isNext: next == Prayer.isha,
            countdown: countdown(Prayer.isha),
            isArabicUi: isArabicUi,
          ),
          const SizedBox(height: 20),
          _MethodCard(
            label: isArabicUi ? 'طريقة الحساب' : 'Calculation Method',
            value: methodLabel,
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

// ─── Header: date + location ──────────────────────────────────────────────────
class _HeaderRow extends StatelessWidget {
  final String dateStr;
  final bool isArabicUi;
  final Coordinates coordinates;
  final String? placeName;
  final bool locationFromCache;
  final VoidCallback onUpdateLocation;
  final bool isDark;

  const _HeaderRow({
    required this.dateStr,
    required this.isArabicUi,
    required this.coordinates,
    this.placeName,
    required this.locationFromCache,
    required this.onUpdateLocation,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? const Color(0xFF1A2535) : Colors.white;
    final border  = AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.10);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: isDark ? 0.08 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            isArabicUi ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Date row
          Row(
            children: [
              if (!isArabicUi) ...[
                Icon(Icons.calendar_today_rounded,
                    size: 13, color: AppColors.primary.withValues(alpha: 0.65)),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  dateStr,
                  textAlign: isArabicUi ? TextAlign.right : TextAlign.left,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                  ),
                ),
              ),
              if (isArabicUi) ...[
                const SizedBox(width: 6),
                Icon(Icons.calendar_today_rounded,
                    size: 13, color: AppColors.primary.withValues(alpha: 0.65)),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Divider(
            height: 1,
            color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
          ),
          const SizedBox(height: 10),
          // Location row
          Row(
            children: [
              if (!isArabicUi) ...[
                Icon(Icons.location_on_rounded,
                    size: 13, color: AppColors.textSecondary.withValues(alpha: 0.7)),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  placeName ??
                      '${coordinates.latitude.toStringAsFixed(4)}°, '
                      '${coordinates.longitude.toStringAsFixed(4)}°',
                  textAlign: isArabicUi ? TextAlign.right : TextAlign.left,
                  style: TextStyle(
                    fontSize: placeName != null ? 12.5 : 11.5,
                    fontWeight: placeName != null ? FontWeight.w500 : FontWeight.normal,
                    color: isDark ? Colors.white54 : AppColors.textSecondary,
                  ),
                ),
              ),
              if (isArabicUi) ...[
                const SizedBox(width: 4),
                Icon(Icons.location_on_rounded,
                    size: 13,
                    color: AppColors.textSecondary.withValues(alpha: 0.7)),
              ],
              if (locationFromCache) ...[
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: onUpdateLocation,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary
                          .withValues(alpha: isDark ? 0.18 : 0.09),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.my_location_rounded,
                            size: 11, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          isArabicUi ? 'تحديث' : 'Update',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Per-prayer visual meta ───────────────────────────────────────────────────
class _PrayerMeta {
  final IconData icon;
  final Color lightColor;
  final Color darkColor;
  const _PrayerMeta(this.icon, this.lightColor, this.darkColor);
  Color resolve(bool isDark) => isDark ? darkColor : lightColor;
}

// Natural "sky through the day" palette — each prayer reflects its moment.
// Same saturation / lightness family → unified, not a traffic light.
const _pMeta = <String, _PrayerMeta>{
  // Fajr – before dawn: calm steel-blue like the pre-dawn sky
  'fajr':    _PrayerMeta(Icons.nights_stay_rounded,  Color(0xFF4A6484), Color(0xFF82A6C8)),
  // Dhuhr – midday: deep sage-green, connects to the app's Islamic green theme
  'dhuhr':   _PrayerMeta(Icons.light_mode_rounded,   Color(0xFF2A7A50), Color(0xFF58B882)),
  // Asr – afternoon: warm olive-green, earthy afternoon light
  'asr':     _PrayerMeta(Icons.wb_sunny_rounded,     Color(0xFF5C7848), Color(0xFF8FB872)),
  // Maghrib – dusk: soft dusty-mauve (the horizon, very muted — not hot pink)
  'maghrib': _PrayerMeta(Icons.wb_twilight_rounded,  Color(0xFF7A6282), Color(0xFFAA8EB8)),
  // Isha – night: deep cool navy-blue like the night sky
  'isha':    _PrayerMeta(Icons.bedtime_rounded,      Color(0xFF2C4C78), Color(0xFF6888B8)),
};

// ─── Prayer tile ──────────────────────────────────────────────────────────────
class _PrayerTile extends StatelessWidget {
  final String prayerKey;
  final String title;
  final String time;
  final bool isNext;
  final String countdown;
  final bool isArabicUi;

  const _PrayerTile({
    required this.prayerKey,
    required this.title,
    required this.time,
    required this.isNext,
    required this.countdown,
    required this.isArabicUi,
  });

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final meta    = _pMeta[prayerKey]!;
    final color   = meta.resolve(isDark);
    final surface = isDark ? const Color(0xFF182030) : Colors.white;

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Container(
        decoration: BoxDecoration(
          color: isNext
              ? (isDark
                  ? Color.lerp(surface, color, 0.12)!
                  : Color.lerp(Colors.white, color, 0.06)!)
              : surface,
          borderRadius: BorderRadius.circular(18),
          border: isNext
              ? Border.all(color: color.withValues(alpha: isDark ? 0.50 : 0.38), width: 1.5)
              : Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.04),
                  width: 0.8,
                ),
          boxShadow: [
            BoxShadow(
              color: isNext
                  ? color.withValues(alpha: isDark ? 0.22 : 0.14)
                  : Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
              blurRadius: isNext ? 16 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Left accent bar — gradient fades to match card
                Container(
                  width: isNext ? 4 : 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        color.withValues(alpha: isNext ? 0.90 : 0.30),
                        color.withValues(alpha: isNext ? 0.55 : 0.10),
                      ],
                    ),
                  ),
                ),
                // Card content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    child: Row(
                      children: [
                        // Icon — circular, softer
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color.withValues(
                                alpha: isNext
                                    ? (isDark ? 0.20 : 0.12)
                                    : (isDark ? 0.10 : 0.07)),
                          ),
                          child: Icon(meta.icon, color: color, size: 20),
                        ),
                        const SizedBox(width: 13),
                        // Name + badges column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16.5,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.92)
                                      : const Color(0xFF1A2B3C),
                                ),
                              ),
                              if (isNext) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.88),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        isArabicUi ? 'التالي' : 'Next',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    if (countdown.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        countdown,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: color.withValues(alpha: 0.80),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Time chip — clean pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 13, vertical: 8),
                          decoration: BoxDecoration(
                            color: color.withValues(
                                alpha: isNext
                                    ? (isDark ? 0.22 : 0.14)
                                    : (isDark ? 0.12 : 0.08)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            time,
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
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

// ─── Sunrise tile (amber/gold — not a prayer) ─────────────────────────────────
class _SunriseTile extends StatelessWidget {
  final String title;
  final String time;

  const _SunriseTile({
    required this.title,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const sunGold   = Color(0xFFF59E0B);
    const sunOrange = Color(0xFFFB923C);
    const sunDeep   = Color(0xFFEA580C);
    const textLight = Color(0xFF92400E);
    const textDark  = Color(0xFFFFD970);

    final surface    = isDark ? const Color(0xFF1A2535) : const Color(0xFFFFFBF0);
    final titleColor = isDark ? textDark : textLight;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? sunGold.withValues(alpha: 0.15)
                : sunGold.withValues(alpha: 0.28),
          ),
          boxShadow: [
            BoxShadow(
              color: sunGold.withValues(alpha: isDark ? 0.06 : 0.10),
              blurRadius: 7,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Gradient left accent bar (fades top→bottom like a sunrise)
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        sunGold.withValues(alpha: 0.55),
                        sunGold.withValues(alpha: 0.20),
                      ],
                    ),
                  ),
                ),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        // Sun icon with ambient glow ring
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: sunGold.withValues(
                                    alpha: isDark ? 0.08 : 0.10),
                              ),
                            ),
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: sunGold.withValues(
                                    alpha: isDark ? 0.15 : 0.16),
                                border: Border.all(
                                  color: sunGold.withValues(alpha: 0.35),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                Icons.wb_twilight_rounded,
                                color: sunGold.withValues(alpha: 0.65),
                                size: 19,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        // Title + horizon stripes
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 17,
                                  color: titleColor,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  _HorizonBar(sunGold, 24, 0.65),
                                  const SizedBox(width: 3),
                                  _HorizonBar(sunOrange, 14, 0.45),
                                  const SizedBox(width: 3),
                                  _HorizonBar(sunDeep, 8, 0.30),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Time badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: sunGold.withValues(
                                alpha: isDark ? 0.16 : 0.10),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            time,
                            style: TextStyle(
                              color: isDark ? textDark : textLight,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
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

class _HorizonBar extends StatelessWidget {
  final Color color;
  final double width;
  final double opacity;

  const _HorizonBar(this.color, this.width, this.opacity);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 2.5,
      decoration: BoxDecoration(
        color: color.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

// ─── Calculation method card ──────────────────────────────────────────────────
class _MethodCard extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _MethodCard({
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.primary.withValues(alpha: 0.12)
            : AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: isDark ? 0.20 : 0.10),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.calculate_rounded,
              size: 17,
              color: AppColors.primary.withValues(alpha: 0.65)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final bool isArabicUi;
  final String message;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenLocation;

  const _ErrorState({
    required this.isArabicUi,
    required this.message,
    required this.onOpenSettings,
    required this.onOpenLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.location_off, size: 56, color: AppColors.error),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton(
                onPressed: onOpenLocation,
                child: Text(isArabicUi ? 'إعدادات الموقع' : 'Location Settings'),
              ),
              OutlinedButton(
                onPressed: onOpenSettings,
                child: Text(isArabicUi ? 'إعدادات التطبيق' : 'App Settings'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
