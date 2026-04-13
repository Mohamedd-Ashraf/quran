import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/services/location_service.dart';
import '../../../../core/services/reverse_geocoding_service.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../core/settings/app_settings_cubit.dart';
import 'qiblah_map_widget.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class QiblahScreen extends StatefulWidget {
  const QiblahScreen({super.key});

  @override
  State<QiblahScreen> createState() => _QiblahScreenState();
}

class _QiblahScreenState extends State<QiblahScreen>
    with SingleTickerProviderStateMixin {
  // ── Location state ─────────────────────────────────────────────────────────
  bool _loading = true;
  String? _error;
  double? _qiblahAngle; // Calculated Qibla direction from North (degrees)
  double? _lat;
  double? _lng;
  bool _locationFromCache = false;
  bool _updatingLocation = false;
  String? _placeName;

  // ── Compass sensor state ───────────────────────────────────────────────────
  double _heading = 0; // Current phone heading from North (degrees, 0–360)
  double? _compassAccuracy; // Android: 0–3 (3=HIGH best); iOS: degrees (lower=better)
  bool _hasCompass = true; // false if device has no magnetometer
  bool _calibrationDialogShown = false; // show calibration dialog only once
  StreamSubscription<CompassEvent>? _compassSub;

  // Circular smoothing buffer for heading values
  final List<double> _headingHistory = [];
  static const int _smoothWindow = 6;

  // ── Location-choice gate ────────────────────────────────────────────────────
  /// true while we're waiting for the user to choose cached vs. fresh GPS.
  bool _showingLocationChoice = false;

  // ── Calibration step ────────────────────────────────────────────────────────
  /// true while showing calibration instructions before entering compass.
  bool _showCalibrationStep = false;

  // ── View mode toggle ───────────────────────────────────────────────────────
  /// true = Qibla Map view, false = Compass view (default)
  bool _showMap = false;

  // ── Alignment state ────────────────────────────────────────────────────────
  bool _aligned = false;
  bool _vibratedOnce = false;

  // ── Glow animation ─────────────────────────────────────────────────────────
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;

  final LocationService _location = const LocationService();

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );

    _startCompass();
    _loadLocation();
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    _compassSub?.cancel();
    super.dispose();
  }

  // ─── Compass ───────────────────────────────────────────────────────────────

  void _startCompass() {
    final stream = FlutterCompass.events;
    if (stream == null) {
      // Device has no magnetometer sensor
      if (mounted) setState(() => _hasCompass = false);
      return;
    }
    _compassSub = stream.listen((event) {
      if (!mounted) return;
      if (event.heading == null) return;
      final smoothed = _circularSmooth(event.heading!);
      setState(() {
        _heading = smoothed;
        _compassAccuracy = event.accuracy;
      });
      _checkAlignment(smoothed);

      // Show calibration dialog once, on the first reading that shows poor
      // accuracy (and only after the compass body is visible).
      if (!_calibrationDialogShown &&
          _compassAccuracy != null &&
          _needsCalibration(_compassAccuracy!) &&
          !_loading &&
          !_showingLocationChoice &&
          _error == null) {
        _calibrationDialogShown = true;
        // Small delay so the screen has finished building before the dialog.
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) _showCalibrationDialog();
        });
      }
    });
  }

  /// Circular (angular) mean for smooth heading without wraparound jumps.
  double _circularSmooth(double raw) {
    _headingHistory.add(raw);
    if (_headingHistory.length > _smoothWindow) _headingHistory.removeAt(0);

    double sinSum = 0, cosSum = 0;
    for (final h in _headingHistory) {
      final r = h * math.pi / 180;
      sinSum += math.sin(r);
      cosSum += math.cos(r);
    }
    final n = _headingHistory.length;
    final avg =
        math.atan2(sinSum / n, cosSum / n) * 180 / math.pi;
    return avg < 0 ? avg + 360 : avg;
  }

  void _checkAlignment(double heading) {
    if (_qiblahAngle == null) return;
    final diff = _signedAngleDiff(heading, _qiblahAngle!).abs();
    final aligned = diff <= 5.0;

    if (aligned && !_vibratedOnce) {
      HapticFeedback.vibrate();
      _vibratedOnce = true;
    }
    if (!aligned) _vibratedOnce = false;
    if (_aligned != aligned && mounted) setState(() => _aligned = aligned);
  }

  /// Returns signed difference in [-180, 180].
  static double _signedAngleDiff(double a, double b) {
    double d = (a - b) % 360;
    if (d > 180) d -= 360;
    if (d < -180) d += 360;
    return d;
  }

  /// Platform-aware calibration check.
  /// Android: accuracy is a sensor level 0–3 (3 = HIGH is best).
  /// iOS: accuracy is in degrees (lower = better, e.g. 15° is fine).
  bool _needsCalibration(double accuracy) {
    if (Platform.isAndroid) {
      return accuracy < 3; // below SENSOR_STATUS_ACCURACY_HIGH
    } else {
      return accuracy > 15; // more than 15° error
    }
  }

  /// Shows a one-time dialog instructing the user to calibrate the compass.
  void _showCalibrationDialog() {
    final isAr = context
        .read<AppSettingsCubit>()
        .state
        .appLanguageCode
        .toLowerCase()
        .startsWith('ar');
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final isDialogDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDialogDark
              ? const Color(0xFF0F1F14)
              : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.sensors_off_rounded, color: Colors.amber, size: 22),
              const SizedBox(width: 10),
              Text(
                isAr ? 'البوصلة تحتاج معايرة' : 'Compass Calibration Needed',
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isAr
                    ? 'دقة بوصلتك منخفضة، مما قد يؤثر على اتجاه القبلة. اتبع الخطوات التالية لإعادة المعايرة:'
                    : 'Your compass accuracy is low, which may affect Qiblah direction. Follow these steps to recalibrate:',
                style: TextStyle(
                  color: isDialogDark
                      ? Colors.white.withValues(alpha: 0.80)
                      : AppColors.textPrimary.withValues(alpha: 0.85),
                  fontSize: 13,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  '∞',
                  style: TextStyle(
                    fontSize: 56,
                    color: Colors.amber.withValues(alpha: 0.85),
                    height: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _CalibDialogStep(n: '1', text: isAr ? 'أمسك الهاتف أفقياً أمامك.' : 'Hold the phone flat in front of you.'),
              const SizedBox(height: 8),
              _CalibDialogStep(n: '2', text: isAr ? 'حرك الهاتف ببطء على شكل رمز ∞ (3–5 مرات)، مبتعداً عن المعادن.' : 'Slowly move it in a figure-8 pattern 3–5 times, away from metal.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                isAr ? 'فهمت' : 'Got it',
                style: const TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ─── Location & Qibla calculation ─────────────────────────────────────────

  Future<void> _loadLocation() async {
    final settings = di.sl<SettingsService>();
    final cached = settings.getLastKnownCoordinates();
    if (cached != null) {
      // Ask the user: reuse saved coordinates or grab fresh GPS?
      setState(() {
        _loading = false;
        _showingLocationChoice = true;
      });
      // Pre-fetch place name so it's ready when the user decides.
      _fetchPlaceName(cached.latitude, cached.longitude);
      return;
    }
    // No cached coordinates – go straight to GPS
    setState(() {
      _loading = true;
      _error = null;
    });
    await _fetchFreshLocation();
  }

  /// User chose to keep the last saved location.
  void _useCachedLocation() {
    final cached = di.sl<SettingsService>().getLastKnownCoordinates()!;
    setState(() => _showingLocationChoice = false);
    _computeQibla(cached, fromCache: true);
  }

  /// User chose to acquire a fresh GPS fix.
  Future<void> _requestFreshLocation() async {
    setState(() => _showingLocationChoice = false);
    await _fetchFreshLocation();
  }

  Future<void> _fetchFreshLocation() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _updatingLocation = true;
    });

    final permission = await _location.ensurePermission();
    if (!mounted) return;

    if (permission != LocationPermissionState.granted) {
      setState(() {
        _loading = false;
        _updatingLocation = false;
        _error = _permissionMessage(permission);
      });
      return;
    }

    try {
      final pos = await _location.getPosition();
      await di.sl<SettingsService>().setLastKnownCoordinates(
        pos.latitude,
        pos.longitude,
      );
      if (!mounted) return;
      _computeQibla(
        Coordinates(pos.latitude, pos.longitude),
        fromCache: false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _updatingLocation = false;
        _error = e is TimeoutException
            ? 'Timed out getting GPS fix. Move to an open area and try again.'
            : e.toString();
      });
    }
  }

  void _computeQibla(Coordinates coords, {required bool fromCache}) {
    final qibla = Qibla(coords);
    setState(() {
      _loading = false;
      _updatingLocation = false;
      _qiblahAngle = qibla.direction;
      _lat = coords.latitude;
      _lng = coords.longitude;
      _locationFromCache = fromCache;
      _showCalibrationStep = true;
      _calibrationDialogShown = true; // skip auto-dialog; step screen shown
    });
    _fetchPlaceName(coords.latitude, coords.longitude);
  }

  Future<void> _fetchPlaceName(double lat, double lng) async {
    final isAr = context
        .read<AppSettingsCubit>()
        .state
        .appLanguageCode
        .toLowerCase()
        .startsWith('ar');
    final name = await ReverseGeocodingService.getPlaceName(
      lat, lng, arabic: isAr,
    );
    if (mounted && name != null) setState(() => _placeName = name);
  }

  String _permissionMessage(LocationPermissionState s) {
    switch (s) {
      case LocationPermissionState.serviceDisabled:
        return 'Location services are disabled. Please enable them.';
      case LocationPermissionState.denied:
        return 'Location permission was denied.';
      case LocationPermissionState.deniedForever:
        return 'Location permission permanently denied. Open app settings to grant it.';
      case LocationPermissionState.granted:
        return '';
    }
  }

  String _cardinalLabel(double deg) {
    const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    return dirs[((deg + 22.5) / 45).floor() % 8];
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isAr = context
        .watch<AppSettingsCubit>()
        .state
        .appLanguageCode
        .toLowerCase()
        .startsWith('ar');

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'القِبلة' : 'Qiblah'),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        actions: [
          if (!_showingLocationChoice &&
              !_loading &&
              _error == null &&
              !_showCalibrationStep &&
              _hasCompass)
            IconButton(
              icon: const Icon(Icons.explore_rounded),
              tooltip: isAr ? 'معايرة البوصلة' : 'Calibrate Compass',
              onPressed: () => setState(() => _showCalibrationStep = true),
            ),
          if (_updatingLocation)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.my_location_rounded),
              tooltip: isAr ? 'تحديث الموقع' : 'Update Location',
              onPressed: _fetchFreshLocation,
            ),
        ],
      ),
      body: _showingLocationChoice
          ? _buildLocationChoice(isAr)
          : _loading
              ? _buildLoading(isAr)
              : _error != null
                  ? _buildError(isAr)
                  : _showCalibrationStep
                      ? _buildCalibrationStep(isAr)
                      : _buildCompassBody(isAr),
    );
  }

  // ── Location choice gate ──────────────────────────────────────────────────

  Widget _buildLocationChoice(bool isAr) {
    final cached = di.sl<SettingsService>().getLastKnownCoordinates();
    final latStr = cached?.latitude.toStringAsFixed(4) ?? '';
    final lngStr = cached?.longitude.toStringAsFixed(4) ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const [
                  Color(0xFF0A1C12),
                  Color(0xFF071309),
                  Color(0xFF040D07),
                ]
              : const [
                  Color(0xFFF8F5EE),
                  Color(0xFFF2EDE0),
                  Color(0xFFEBE4D4),
                ],
        ),
      ),
      child: Stack(
        children: [
          // ── Arch painter – full bleed behind safe area ────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 210,
              child: CustomPaint(painter: _IslamicArchPainter(isDark: isDark)),
            ),
          ),

          // ── Content ───────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 30),

                // ── Hero badge ─────────────────────────────────────────
                AnimatedBuilder(
                  animation: _glowAnim,
                  builder: (_, __) => Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 116,
                        height: 116,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.secondary.withValues(
                                  alpha: 0.28 * _glowAnim.value),
                              blurRadius: 40 * _glowAnim.value,
                              spreadRadius: 6 * _glowAnim.value,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const SweepGradient(
                            colors: [
                              AppColors.secondary,
                              AppColors.accent,
                              AppColors.secondary,
                            ],
                          ),
                        ),
                      ),
                      Container(
                        width: 86,
                        height: 86,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: isDark
                                ? const [Color(0xFF1E5C3A), Color(0xFF0C2018)]
                                : const [Color(0xFF1A8A58), Color(0xFF0D5E3A)],
                            radius: 0.85,
                          ),
                        ),
                        child: const Icon(
                          Icons.my_location_rounded,
                          size: 40,
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Title ──────────────────────────────────────────────
                Text(
                  isAr ? 'حدِّد موقعك' : 'Set Your Location',
                  style: GoogleFonts.amiri(
                    fontSize: isAr ? 28 : 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.secondary,
                    shadows: [
                      Shadow(
                        color: AppColors.secondary.withValues(alpha: 0.35),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  child: Text(
                    isAr
                        ? 'يحتاج التطبيق إلى موقعك لحساب اتجاه القِبلة بدقة'
                        : 'Your location is needed to determine the Qibla direction',
                    style: TextStyle(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.40)
                          : AppColors.textSecondary.withValues(alpha: 0.80),
                      fontSize: 13,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 32),

                // ── Choice cards ────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Column(
                    children: [
                      // Primary: use saved
                      _LocationCard(
                        labelText: isAr ? 'الموقع المحفوظ' : 'Saved Location',
                        icon: Icons.bookmark_rounded,
                        title: isAr ? 'استخدام الموقع المحفوظ' : 'Use Saved Location',
                        subtitle: _placeName ?? '$latStr°,  $lngStr°',
                        isPrimary: true,
                        onTap: _useCachedLocation,
                      ),
                      const SizedBox(height: 14),
                      // Secondary: fresh GPS
                      _LocationCard(
                        labelText: isAr ? 'موقع جديد / GPS' : 'GPS / New Location',
                        icon: Icons.gps_fixed_rounded,
                        title: isAr ? 'تحديد موقع جديد (GPS)' : 'Get Fresh GPS Location',
                        subtitle: isAr
                            ? 'أدق · يستغرق بضع ثوانٍ'
                            : 'More precise · takes a few seconds',
                        isPrimary: false,
                        onTap: _requestFreshLocation,
                      ),
                    ],
                  ),
                ),

                const Spacer(),
                // ── Bottom ornament ─────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Text(
                    '❧',
                    style: TextStyle(
                      fontSize: 22,
                      color: AppColors.secondary.withValues(alpha: 0.25),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Loading ────────────────────────────────────────────────────────────────

  Widget _buildLoading(bool isAr) {
    return _DarkGradientBackground(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                color: AppColors.secondary,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isAr ? 'جارٍ تحديد موقعك…' : 'Locating you…',
              style: GoogleFonts.amiri(
                color: AppColors.secondary,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Error ──────────────────────────────────────────────────────────────────

  Widget _buildError(bool isAr) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _DarkGradientBackground(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off_rounded,
              size: 72,
              color: AppColors.secondary.withValues(alpha: 0.70),
            ),
            const SizedBox(height: 24),
            Text(
              isAr ? 'تعذّر تحديد موقعك' : 'Could Not Get Your Location',
              style: GoogleFonts.cinzel(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.secondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Text(
              _error!,
              style: TextStyle(
                color: isDark ? Colors.white60 : AppColors.textSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _fetchFreshLocation,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(isAr ? 'إعادة المحاولة' : 'Retry'),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.secondary,
                    side: const BorderSide(color: AppColors.secondary),
                  ),
                  onPressed: _location.openAppSettings,
                  icon: const Icon(Icons.settings_rounded),
                  label: Text(isAr ? 'الإعدادات' : 'App Settings'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Calibration step (shown before compass) ─────────────────────────────

  Widget _buildCalibrationStep(bool isAr) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const [
                  Color(0xFF0A1C12),
                  Color(0xFF071309),
                  Color(0xFF040D07),
                ]
              : const [
                  Color(0xFFF8F5EE),
                  Color(0xFFF2EDE0),
                  Color(0xFFEBE4D4),
                ],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // ── Animated compass hero ───────────────────────────────────
              AnimatedBuilder(
                animation: _glowAnim,
                builder: (_, __) => Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer glow ring
                    Container(
                      width: 124,
                      height: 124,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.secondary
                                .withValues(alpha: 0.22 * _glowAnim.value),
                            blurRadius: 36 * _glowAnim.value,
                            spreadRadius: 8 * _glowAnim.value,
                          ),
                        ],
                      ),
                    ),
                    // Ring
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          colors: [
                            AppColors.secondary.withValues(alpha: 0.80),
                            AppColors.accent.withValues(alpha: 0.40),
                            AppColors.secondary.withValues(alpha: 0.80),
                          ],
                        ),
                      ),
                    ),
                    // Inner disc
                    Container(
                      width: 96,
                      height: 96,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [Color(0xFF1A3D28), Color(0xFF0C1E12)],
                          radius: 0.85,
                        ),
                      ),
                      child: Transform.rotate(
                        angle: _glowAnim.value * math.pi * 0.15,
                        child: const Icon(
                          Icons.explore_rounded,
                          size: 44,
                          color: AppColors.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // ── Title ───────────────────────────────────────────────────
              Text(
                isAr ? 'معايرة البوصلة' : 'Compass Calibration',
                style: GoogleFonts.amiri(
                  fontSize: isAr ? 28 : 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondary,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // ── Subtitle ────────────────────────────────────────────────
              Text(
                isAr
                    ? 'اتبع الخطوات للحصول على اتجاه قِبلة دقيق'
                    : 'Follow the steps for an accurate Qibla direction',
                style: TextStyle(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.45)
                      : AppColors.textSecondary.withValues(alpha: 0.80),
                  fontSize: 13,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 26),

              // ── Figure-8 banner ─────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            AppColors.primary.withValues(alpha: 0.70),
                            AppColors.primary.withValues(alpha: 0.40),
                          ]
                        : [
                            AppColors.primary.withValues(alpha: 0.06),
                            AppColors.primary.withValues(alpha: 0.03),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: AppColors.secondary.withValues(alpha: isDark ? 0.30 : 0.45),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '∞',
                      style: TextStyle(
                        fontSize: 64,
                        color: AppColors.secondary.withValues(alpha: 0.92),
                        height: 1.0,
                        shadows: [
                          Shadow(
                            color: AppColors.secondary.withValues(alpha: 0.55),
                            blurRadius: 18,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isAr
                          ? 'حرّك الهاتف على شكل الرمز أعلاه'
                          : 'Move the phone in the pattern above',
                      style: TextStyle(
                        color: AppColors.secondary.withValues(alpha: 0.70),
                        fontSize: 12,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ── Step cards ──────────────────────────────────────────────
              _CalibStepCard(
                num: '1',
                icon: Icons.phone_android_rounded,
                isAr: isAr,
                text: isAr
                    ? 'أمسك الهاتف أفقياً أمامك بعيداً عن أي أجسام معدنية.'
                    : 'Hold the phone flat in front of you, away from metal objects.',
              ),
              const SizedBox(height: 10),
              _CalibStepCard(
                num: '2',
                icon: Icons.air_rounded,
                isAr: isAr,
                text: isAr
                    ? 'حرّك الهاتف ببطء في الهواء على شكل ∞ من ثلاث إلى خمس مرات.'
                    : 'Slowly swing the phone in a figure-8 (∞) pattern 3–5 times.',
              ),
              const SizedBox(height: 10),
              _CalibStepCard(
                num: '3',
                icon: Icons.rotate_90_degrees_ccw_rounded,
                isAr: isAr,
                text: isAr
                    ? 'أدِر الهاتف على محاوره الثلاثة (أفقي، رأسي، جانبي) أثناء الحركة.'
                    : 'Tilt and rotate the phone on all three axes while moving.',
              ),
              const SizedBox(height: 10),
              _CalibStepCard(
                num: '4',
                icon: Icons.speaker_rounded,
                isAr: isAr,
                iconColor: const Color(0xFFEF9A9A),
                text: isAr
                    ? 'ابتعد عن المغناطيس ومكبرات الصوت والأجهزة الإلكترونية القريبة.'
                    : 'Stay away from magnets, speakers, and nearby electronics.',
              ),
              const SizedBox(height: 24),

              // ── CTA button ──────────────────────────────────────────────
              GestureDetector(
                onTap: () => setState(() => _showCalibrationStep = false),
                child: Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [AppColors.secondary, AppColors.accent],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.secondary.withValues(alpha: 0.45),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF0A1C12),
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isAr
                            ? 'تمّت المعايرة — انتقل للبوصلة'
                            : 'Done — Open Compass',
                        style: GoogleFonts.cairo(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0A1C12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Skip hint ───────────────────────────────────────────────
              TextButton(
                onPressed: () => setState(() => _showCalibrationStep = false),
                child: Text(
                  isAr ? 'تخطي المعايرة' : 'Skip calibration',
                  style: TextStyle(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.30)
                        : AppColors.textSecondary.withValues(alpha: 0.55),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Main compass body ──────────────────────────────────────────────────────

  // ── Mode toggle pill ────────────────────────────────────────────────────

  Widget _buildModeToggle(bool isAr) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 10, 28, 4),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0A0F14) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark
                ? AppColors.secondary.withValues(alpha: 0.28)
                : AppColors.primary.withValues(alpha: 0.20),
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.15),
              blurRadius: 12,
            ),
          ],
        ),
        child: Row(
          children: [
            _ModeTab(
              icon: Icons.explore_rounded,
              label: isAr ? 'البوصلة' : 'Compass',
              selected: !_showMap,
              onTap: () => setState(() => _showMap = false),
            ),
            _ModeTab(
              icon: Icons.map_rounded,
              label: isAr ? 'الخريطة' : 'Map',
              selected: _showMap,
              onTap: () => setState(() => _showMap = true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompassBody(bool isAr) {
    // ── Map mode: delegate entirely to QiblahMapWidget ───────────────────
    if (_showMap) {
      return _DarkGradientBackground(
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: _buildModeToggle(isAr),
            ),
            Expanded(
              child: QiblahMapWidget(
                userLat: _lat!,
                userLng: _lng!,
                qiblahAngle: _qiblahAngle!,
                isAr: isAr,
              ),
            ),
          ],
        ),
      );
    }

    final qiblaAngle = _qiblahAngle!;
    // Arrow on screen = qiblaAngle − heading.
    // When this equals 0 the arrow points UP → phone is facing Qibla.
    final arrowRad = (qiblaAngle - _heading) * math.pi / 180;
    final compassAccuracyOk = _compassAccuracy == null
        ? true // not yet received; don't flash warning immediately
        : !_needsCalibration(_compassAccuracy!);

    return _DarkGradientBackground(
      child: SafeArea(
        child: Column(
          children: [
            // ── Mode toggle ───────────────────────────────────────────────
            _buildModeToggle(isAr),

            // ── Location caption ──────────────────────────────────────────
            if (_lat != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      size: 13,
                      color: AppColors.secondary.withValues(alpha: 0.60),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _placeName != null
                            ? '$_placeName'
                                '${_locationFromCache ? '  ·  ${isAr ? 'من الذاكرة' : 'cached'}' : ''}'
                            : '${_lat!.toStringAsFixed(4)}°, ${_lng!.toStringAsFixed(4)}°'
                                '${_locationFromCache ? '  ·  ${isAr ? 'من الذاكرة' : 'cached'}' : ''}',
                        style: TextStyle(
                          color: AppColors.secondary.withValues(alpha: 0.50),
                          fontSize: 11,
                          letterSpacing: 0.3,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

            // ── No-compass fallback notice ────────────────────────────────
            if (!_hasCompass)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.amber,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isAr
                              ? 'جهازك لا يحتوي على بوصلة. يُعرض اتجاه القبلة كزاوية ثابتة فقط.'
                              : 'No compass sensor found. Showing Qiblah angle as a static reference.',
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Compass ───────────────────────────────────────────────────
            Expanded(
              child: Center(
                child: AnimatedBuilder(
                  animation: _glowAnim,
                  builder: (context, child) => _QiblahCompassWidget(
                    heading: _heading,
                    arrowRad: arrowRad,
                    aligned: _aligned,
                    glowIntensity: _aligned ? _glowAnim.value : 0,
                    showLiveArrow: _hasCompass,
                    qiblahAngle: qiblaAngle,
                  ),
                ),
              ),
            ),

            // ── Info cards ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  if (_hasCompass)
                    Expanded(
                      child: _InfoCard(
                        icon: Icons.navigation_rounded,
                        label: isAr ? 'اتجاه الهاتف' : 'Heading',
                        value: '${_heading.toStringAsFixed(0)}°',
                        sub: _cardinalLabel(_heading),
                      ),
                    ),
                  if (_hasCompass) const SizedBox(width: 10),
                  Expanded(
                    child: _InfoCard(
                      icon: Icons.mosque_rounded,
                      label: isAr ? 'اتجاه القبلة' : 'Qiblah',
                      value: '${qiblaAngle.toStringAsFixed(1)}°',
                      sub: _cardinalLabel(qiblaAngle),
                      highlight: true,
                    ),
                  ),
                  if (_hasCompass && !compassAccuracyOk) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: _InfoCard(
                        icon: Icons.sensors_rounded,
                        label: isAr ? 'دقة البوصلة' : 'Accuracy',
                        value:
                            '±${_compassAccuracy?.toStringAsFixed(0) ?? '?'}°',
                        sub: isAr ? 'تحتاج معايرة' : 'needs cal.',
                        warning: true,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Alignment banner ──────────────────────────────────────────
            if (_hasCompass)
              _AlignmentBanner(
                aligned: _aligned,
                isAr: isAr,
                glowIntensity: _aligned ? _glowAnim.value : 1.0,
              ),

            // ── Calibration card ──────────────────────────────────────────
            if (_hasCompass && !compassAccuracyOk)
              _CalibrationCard(isAr: isAr),
            const SizedBox(height: 22),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  DARK GRADIENT BACKGROUND
// ─────────────────────────────────────────────────────────────────────────────

class _DarkGradientBackground extends StatelessWidget {
  final Widget child;
  const _DarkGradientBackground({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const [
                  Color(0xFF0C2018), // deep Islamic green
                  Color(0xFF091C13),
                  Color(0xFF050D0A),
                ]
              : const [
                  Color(0xFFF0EDE6), // warm off-white
                  AppColors.background,
                  AppColors.surfaceVariant,
                ],
        ),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  COMPASS WIDGET – stack of layers
// ─────────────────────────────────────────────────────────────────────────────

class _QiblahCompassWidget extends StatelessWidget {
  final double heading; // phone bearing from North (degrees)
  final double arrowRad; // pre-computed arrow angle in radians
  final bool aligned;
  final double glowIntensity; // 0–1 animated value
  final bool showLiveArrow; // false when no compass sensor
  final double qiblahAngle; // fallback for no-sensor devices

  const _QiblahCompassWidget({
    required this.heading,
    required this.arrowRad,
    required this.aligned,
    required this.glowIntensity,
    required this.showLiveArrow,
    required this.qiblahAngle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Static fallback: arrow points to qiblahAngle from North on screen.
    final effectiveArrowRad =
        showLiveArrow ? arrowRad : qiblahAngle * math.pi / 180;

    return SizedBox(
      width: 320,
      height: 320,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Green glow halo when aligned
          if (aligned)
            Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.greenAccent.withValues(
                      alpha: 0.28 * glowIntensity,
                    ),
                    blurRadius: 50 * glowIntensity,
                    spreadRadius: 12 * glowIntensity,
                  ),
                ],
              ),
            ),

          // Sweep-gradient outer gold ring
          Container(
            width: 318,
            height: 318,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const SweepGradient(
                colors: [
                  AppColors.secondary,
                  AppColors.accent,
                  Color(0xFFF9E87A),
                  AppColors.secondary,
                  Color(0xFFB8860B),
                  AppColors.secondary,
                ],
                stops: [0.0, 0.18, 0.50, 0.68, 0.84, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondary,
                  blurRadius: 0,
                  spreadRadius: 0,
                ),
              ],
            ),
          ),

          // Rotating compass face (N always at actual North)
          Transform.rotate(
            angle: -heading * math.pi / 180,
            child: SizedBox(
              width: 298,
              height: 298,
              child: CustomPaint(
                  painter: _IslamicCompassFacePainter(isDark: isDark)),
            ),
          ),

          // Inner disc – dark on dark theme for contrast, warm cream on light
          Container(
            width: 208,
            height: 208,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? const Color(0xFF06100C) : const Color(0xFFF5F0E8),
              border: Border.all(
                color: AppColors.secondary.withValues(alpha: 0.20),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.65 : 0.18),
                  blurRadius: 18,
                  spreadRadius: 5,
                ),
              ],
            ),
          ),

          // Qiblah arrow – rotated so it always points toward Mecca
          Transform.rotate(
            angle: effectiveArrowRad,
            child: SizedBox(
              width: 208,
              height: 208,
              child: CustomPaint(
                painter: _QiblahArrowPainter(aligned: aligned),
              ),
            ),
          ),

          // Fixed ▲ marker at top = direction phone is currently facing
          if (showLiveArrow)
            Positioned(
              top: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: (isDark
                          ? const Color(0xFF06100C)
                          : const Color(0xFFF5F0E8))
                      .withValues(alpha: 0.90),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.35),
                  ),
                ),
                child: const Text(
                  '▲',
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontSize: 11,
                    height: 1.0,
                  ),
                ),
              ),
            ),

          // Center hub – app logo / alignment check
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: aligned
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF43A047), Color(0xFF1B5E20)],
                    )
                  : const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.secondary, AppColors.accent],
                    ),
              boxShadow: [
                BoxShadow(
                  color: (aligned ? Colors.greenAccent : AppColors.secondary)
                      .withValues(
                    alpha: aligned ? 0.55 * glowIntensity : 0.42,
                  ),
                  blurRadius: 16,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: aligned
                ? const Icon(
                    Icons.done_all_rounded,
                    color: Colors.white,
                    size: 30,
                  )
                : ClipOval(
                    child: Padding(
                      padding: const EdgeInsets.all(11),
                      child: Builder(
                        builder: (context) {
                          final isDark = Theme.of(context).brightness ==
                              Brightness.dark;
                          return Image.asset(
                            isDark
                                ? 'assets/logo/files/transparent/Splash_dark_transparent.png'
                                : 'assets/logo/files/transparent/splash_light_transparent.png',
                            fit: BoxFit.contain,
                          );
                        },
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  COMPASS FACE PAINTER
//  Draws the rotating rose: N/E/S/W labels + tick marks.
//  Labels naturally rotate with the compass face (standard compass UX).
// ─────────────────────────────────────────────────────────────────────────────

class _IslamicCompassFacePainter extends CustomPainter {
  final bool isDark;
  const _IslamicCompassFacePainter({required this.isDark});

  static void _drawText(Canvas canvas, String text, Offset center,
      TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final R = size.width / 2 - 1.0;

    // Background circle
    canvas.drawCircle(
      c,
      R,
      Paint()
        ..shader = RadialGradient(
          colors: isDark
              ? const [Color(0xFF162E24), Color(0xFF0C1C16)]
              : const [Color(0xFFEDE8DA), Color(0xFFDDD5C0)],
          radius: 0.75,
        ).createShader(Rect.fromCircle(center: c, radius: R)),
    );

    // Tick marks (every 5°)
    for (var deg = 0; deg < 360; deg += 5) {
      if (deg % 90 == 0) continue; // cardinals handled via labels
      final isMajor = deg % 30 == 0;
      final tickLen = isMajor ? 15.0 : 8.0;
      final rad = (deg - 90) * math.pi / 180;

      canvas.drawLine(
        Offset(c.dx + (R - tickLen) * math.cos(rad),
            c.dy + (R - tickLen) * math.sin(rad)),
        Offset(c.dx + (R - 0.5) * math.cos(rad),
            c.dy + (R - 0.5) * math.sin(rad)),
        Paint()
          ..color = isMajor
              ? AppColors.secondary.withValues(alpha: 0.65)
              : AppColors.secondary.withValues(alpha: 0.28)
          ..strokeWidth = isMajor ? 2.0 : 1.0
          ..strokeCap = StrokeCap.round,
      );
    }

    // Cardinal & intercardinal labels
    const labels = [
      (0, 'N', true),
      (45, 'NE', false),
      (90, 'E', true),
      (135, 'SE', false),
      (180, 'S', true),
      (225, 'SW', false),
      (270, 'W', true),
      (315, 'NW', false),
    ];

    for (final (deg, label, isCard) in labels) {
      final rad = (deg - 90.0) * math.pi / 180;
      final dist = isCard ? 28.0 : 24.0;
      final pos = Offset(
        c.dx + (R - dist) * math.cos(rad),
        c.dy + (R - dist) * math.sin(rad),
      );

      if (isCard) {
        final isNorth = label == 'N';
        canvas.drawCircle(
          pos,
          13,
          Paint()
            ..color = isNorth
                ? const Color(0xFFB71C1C).withValues(alpha: 0.20)
                : AppColors.secondary.withValues(alpha: 0.09),
        );
        _drawText(
          canvas,
          label,
          pos,
          TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: isNorth ? const Color(0xFFEF5350) : AppColors.secondary,
            shadows: const [Shadow(blurRadius: 5, color: Colors.black54)],
          ),
        );
      } else {
        _drawText(
          canvas,
          label,
          pos,
          TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w500,
            color: AppColors.secondary.withValues(alpha: 0.38),
          ),
        );
      }
    }

    // Degree labels at 30° intervals (skip cardinals)
    for (var deg = 30; deg < 360; deg += 30) {
      if (deg % 90 == 0) continue;
      final rad = (deg - 90.0) * math.pi / 180;
      final pos = Offset(
        c.dx + (R - 46) * math.cos(rad),
        c.dy + (R - 46) * math.sin(rad),
      );
      _drawText(
        canvas,
        '$deg',
        pos,
        TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w400,
          color: AppColors.secondary.withValues(alpha: 0.28),
        ),
      );
    }

    // Inner ring decorator
    canvas.drawCircle(
      c,
      R - 54,
      Paint()
        ..color = AppColors.secondary.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant _IslamicCompassFacePainter old) =>
      old.isDark != isDark;
}

// ─────────────────────────────────────────────────────────────────────────────
//  QIBLA ARROW PAINTER
//  Elegant golden arrow; points UP in its natural state.
//  The parent Transform.rotate turns it toward Mecca.
// ─────────────────────────────────────────────────────────────────────────────

class _QiblahArrowPainter extends CustomPainter {
  final bool aligned;
  const _QiblahArrowPainter({required this.aligned});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxR = size.width / 2 - 14;

    final tipY = cy - maxR;
    const bodyW = 10.0;
    final tailY = cy + 24.0;

    // Arrow outline (Bézier curves for smooth edges)
    final arrow = Path()
      ..moveTo(cx, tipY)
      ..cubicTo(cx - bodyW, cy - maxR * 0.4, cx - bodyW * 0.9, cy - 8,
          cx - 4, tailY)
      ..lineTo(cx + 4, tailY)
      ..cubicTo(cx + bodyW * 0.9, cy - 8, cx + bodyW, cy - maxR * 0.4,
          cx, tipY)
      ..close();

    // Drop shadow
    canvas.drawPath(
      arrow,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.40)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );

    // Fill
    canvas.drawPath(
      arrow,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: aligned
              ? const [Color(0xFF81C784), Color(0xFF43A047), Color(0xFF1B5E20)]
              : const [Color(0xFFF9E87A), Color(0xFFD4AF37), Color(0xFFB8860B)],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCenter(
          center: Offset(cx, cy),
          width: size.width,
          height: size.height,
        )),
    );

    // White edge highlight
    canvas.drawPath(
      arrow,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Mini Kaaba near arrow tip
    _drawKaaba(canvas, Offset(cx, tipY + 19));

    // Counter-weight at tail
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, tailY + 5),
        width: 11,
        height: 7,
      ),
      Paint()
        ..color = aligned ? const Color(0xFF1B5E20) : AppColors.accent,
    );
  }

  void _drawKaaba(Canvas canvas, Offset center) {
    const sz = 11.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: sz, height: sz),
        const Radius.circular(2),
      ),
      Paint()..color = Colors.black87,
    );
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(center.dx, center.dy + 1), width: sz, height: 2),
      Paint()
        ..color = aligned
            ? Colors.greenAccent.shade400
            : const Color(0xFFD4AF37),
    );
  }

  @override
  bool shouldRepaint(covariant _QiblahArrowPainter old) =>
      old.aligned != aligned;
}

// ─────────────────────────────────────────────────────────────────────────────
//  INFO CARD
// ─────────────────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final bool highlight;
  final bool warning;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    this.highlight = false,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = warning
        ? Colors.amber
        : highlight
            ? AppColors.secondary
            : (isDark ? const Color(0xFF6FAF8E) : AppColors.primary);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 13),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0B1C14).withValues(alpha: 0.85)
            : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 12),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.65),
                    fontSize: 10,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.0,
            ),
          ),
          Text(
            sub,
            style: TextStyle(
              color: color.withValues(alpha: 0.55),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ALIGNMENT BANNER
// ─────────────────────────────────────────────────────────────────────────────

class _AlignmentBanner extends StatelessWidget {
  final bool aligned;
  final bool isAr;
  final double glowIntensity;

  const _AlignmentBanner({
    required this.aligned,
    required this.isAr,
    required this.glowIntensity,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
        decoration: BoxDecoration(
          gradient: aligned
              ? LinearGradient(
                  colors: [
                    Color.lerp(
                      const Color(0xFF2E7D32),
                      const Color(0xFF1B5E20),
                      1 - glowIntensity,
                    )!,
                    const Color(0xFF1B5E20),
                  ],
                )
              : LinearGradient(
                  colors: isDark
                      ? const [Color(0xFF15322A), Color(0xFF0D1F1A)]
                      : [AppColors.surface, AppColors.surfaceVariant],
                ),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: aligned
                ? Colors.greenAccent.withValues(alpha: 0.55 * glowIntensity)
                : AppColors.secondary.withValues(alpha: 0.18),
            width: 1.5,
          ),
          boxShadow: aligned
              ? [
                  BoxShadow(
                    color: Colors.greenAccent.withValues(
                      alpha: 0.28 * glowIntensity,
                    ),
                    blurRadius: 24,
                    spreadRadius: 3,
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              aligned
                  ? Icons.done_all_rounded
                  : Icons.screen_rotation_alt_rounded,
              color:
                  aligned
                      ? Colors.greenAccent
                      : (isDark ? AppColors.secondary : AppColors.primary),
              size: 22,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                aligned
                    ? (isAr
                        ? 'أنتَ تواجه القِبلة  ✓'
                        : 'You are facing Qiblah  ✓')
                    : (isAr
                        ? 'أدِر هاتفك حتى يُشير السهمُ للأعلى'
                        : 'Rotate until the arrow points up'),
                style: TextStyle(
                  color: aligned
                      ? Colors.greenAccent
                      : (isDark ? AppColors.secondary : AppColors.primary),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  LOCATION CARD  (replaces old _LocationChoiceButton)
// ─────────────────────────────────────────────────────────────────────────────

class _LocationCard extends StatelessWidget {
  final IconData icon;
  final String labelText;
  final String title;
  final String subtitle;
  final bool isPrimary;
  final VoidCallback onTap;

  const _LocationCard({
    required this.icon,
    required this.labelText,
    required this.title,
    required this.subtitle,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
        decoration: BoxDecoration(
          gradient: isPrimary
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.secondary, Color(0xFFB8860B)],
                )
              : isDark
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF152B1E), Color(0xFF0E1D14)],
                    )
                  : const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.white, Color(0xFFF8F5EE)],
                    ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isPrimary
                ? AppColors.secondary.withValues(alpha: 0.0)
                : (isDark
                    ? AppColors.secondary.withValues(alpha: 0.22)
                    : AppColors.primary.withValues(alpha: 0.20)),
            width: 1.2,
          ),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: AppColors.secondary.withValues(alpha: 0.40),
                    blurRadius: 22,
                    spreadRadius: 0,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.30)
                        : Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Badge label ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isPrimary
                    ? Colors.black.withValues(alpha: 0.18)
                    : (isDark
                        ? AppColors.secondary.withValues(alpha: 0.12)
                        : AppColors.primary.withValues(alpha: 0.10)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                labelText,
                style: TextStyle(
                  color: isPrimary
                      ? const Color(0xFF0A1C12)
                      : (isDark ? AppColors.secondary : AppColors.primary),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // ── Main row: text + icon ────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isPrimary
                              ? const Color(0xFF0A1C12)
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.90)
                                  : AppColors.textPrimary),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: isPrimary
                              ? const Color(0xFF0A1C12).withValues(alpha: 0.60)
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.38)
                                  : AppColors.textSecondary),
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                // Icon circle on right
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isPrimary
                        ? Colors.black.withValues(alpha: 0.15)
                        : (isDark
                            ? AppColors.secondary.withValues(alpha: 0.10)
                            : AppColors.primary.withValues(alpha: 0.08)),
                  ),
                  child: Icon(
                    icon,
                    color: isPrimary
                        ? const Color(0xFF0A1C12)
                        : (isDark ? AppColors.secondary : AppColors.primary),
                    size: 22,
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

// ─────────────────────────────────────────────────────────────────────────────
//  CALIB STEP CARD  – horizontal icon + text row for calibration page
// ─────────────────────────────────────────────────────────────────────────────

class _CalibStepCard extends StatelessWidget {
  final String num;
  final String text;
  final IconData icon;
  final bool isAr;
  final Color? iconColor;

  const _CalibStepCard({
    required this.num,
    required this.text,
    required this.icon,
    required this.isAr,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color col = iconColor ?? AppColors.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0E2218) : Colors.white.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: col.withValues(alpha: isDark ? 0.18 : 0.28),
          width: 1.0,
        ),
      ),
      child: Row(
        textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
        children: [
          // Number badge
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  col.withValues(alpha: 0.30),
                  col.withValues(alpha: 0.12),
                ],
              ),
              border: Border.all(color: col.withValues(alpha: 0.40), width: 1),
            ),
            child: Center(
              child: Text(
                num,
                style: TextStyle(
                  color: col,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Icon
          Icon(icon, color: col.withValues(alpha: 0.65), size: 20),
          const SizedBox(width: 12),
          // Text
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.72)
                    : AppColors.textPrimary.withValues(alpha: 0.82),
                fontSize: 13,
                height: 1.45,
              ),
              textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CALIBRATION CARD
//  Visible when compass accuracy is poor (>20°). Shows step-by-step
//  instructions with a figure-8 animation hint.
// ─────────────────────────────────────────────────────────────────────────────

class _CalibrationCard extends StatefulWidget {
  final bool isAr;
  const _CalibrationCard({required this.isAr});

  @override
  State<_CalibrationCard> createState() => _CalibrationCardState();
}

class _CalibrationCardState extends State<_CalibrationCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isAr = widget.isAr;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: GestureDetector(
        onTap: () => setState(() => _expanded = !_expanded),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.amber.withValues(alpha: 0.40),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─ Header row ─────────────────────────────────────────
              Row(
                children: [
                  const Icon(
                    Icons.sensors_off_rounded,
                    color: Colors.amber,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isAr
                          ? 'البوصلة تحتاج معايرة — اضغط لمعرفة كيف'
                          : 'Compass needs calibration — tap to see how',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.amber,
                    size: 20,
                  ),
                ],
              ),

              // ─ Steps (shown when expanded) ─────────────────────────
              if (_expanded) ...[
                const SizedBox(height: 14),
                const Divider(color: Colors.amber, thickness: 0.3, height: 1),
                const SizedBox(height: 14),

                // Figure-8 visual
                Center(
                  child: Text(
                    '∞',
                    style: TextStyle(
                      fontSize: 52,
                      color: Colors.amber.withValues(alpha: 0.80),
                      height: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Steps
                _CalibStep(
                  num: '1',
                  isAr: isAr,
                  text: isAr
                      ? 'أمسك الهاتف أمامك بشكل أفقي.'
                      : 'Hold the phone flat in front of you.',
                ),
                const SizedBox(height: 8),
                _CalibStep(
                  num: '2',
                  isAr: isAr,
                  text: isAr
                      ? 'حريك الهاتف في الهواء على شكل الرمز ∞ (رقم 8 على جنبه) 3–٥ مرات.'
                      : 'Move the phone slowly in a figure-8 (∞) pattern 3–5 times.',
                ),
                const SizedBox(height: 8),
                _CalibStep(
                  num: '3',
                  isAr: isAr,
                  text: isAr
                      ? 'ابتعد عن أي معدن أو مكبر صوت أثناء المعايرة.'
                      : 'Keep away from metal objects or speakers during calibration.',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CalibStep extends StatelessWidget {
  final String num;
  final String text;
  final bool isAr;
  const _CalibStep({
    required this.num,
    required this.text,
    required this.isAr,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.amber.withValues(alpha: 0.20),
          ),
          child: Center(
            child: Text(
              num,
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.amber.withValues(alpha: 0.80),
              fontSize: 12,
              height: 1.45,
            ),
            textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CALIBRATION DIALOG STEP  (used inside _showCalibrationDialog)
// ─────────────────────────────────────────────────────────────────────────────

class _CalibDialogStep extends StatelessWidget {
  final String n;
  final String text;
  const _CalibDialogStep({required this.n, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.amber.withValues(alpha: 0.20),
          ),
          child: Center(
            child: Text(
              n,
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.80),
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ISLAMIC ARCH PAINTER
//  Draws a decorative row of Islamic pointed arches at the top of the screen.
// ─────────────────────────────────────────────────────────────────────────────

class _IslamicArchPainter extends CustomPainter {
  final bool isDark;
  const _IslamicArchPainter({this.isDark = true});

  @override
  void paint(Canvas canvas, Size size) {
    final goldLight = AppColors.secondary.withValues(alpha: isDark ? 0.18 : 0.35);
    final goldMid   = AppColors.secondary.withValues(alpha: isDark ? 0.10 : 0.22);
    final bgPaint   = Paint()..color = goldMid;
    final strokePaint = Paint()
      ..color = goldLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const archCount = 5;
    final archW = size.width / archCount;
    final archH = size.height * 0.85;

    for (var i = 0; i < archCount; i++) {
      final left  = i * archW;
      final right = left + archW;
      final cx    = left + archW / 2;

      // Pointed (ogee-style) arch path
      final path = Path();
      path.moveTo(left, size.height);
      path.lineTo(left, archH * 0.45);

      // Left shoulder curve
      path.cubicTo(
        left, archH * 0.15,
        cx - archW * 0.22, 0,
        cx, 0,
      );
      // Right shoulder curve (mirror)
      path.cubicTo(
        cx + archW * 0.22, 0,
        right, archH * 0.15,
        right, archH * 0.45,
      );

      path.lineTo(right, size.height);
      path.close();

      canvas.drawPath(path, bgPaint);
      canvas.drawPath(path, strokePaint);

      // Small diamond ornament at arch tip
      final diamondPaint = Paint()
        ..color = AppColors.secondary.withValues(alpha: 0.22)
        ..style = PaintingStyle.fill;
      const ds = 5.0;
      final diamondPath = Path()
        ..moveTo(cx, -ds)
        ..lineTo(cx + ds, 0)
        ..lineTo(cx, ds)
        ..lineTo(cx - ds, 0)
        ..close();
      canvas.drawPath(diamondPath, diamondPaint);
    }

    // Horizontal baseline under arches
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      Paint()
        ..color = AppColors.secondary.withValues(alpha: 0.20)
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(covariant _IslamicArchPainter old) => old.isDark != isDark;
}

// ─────────────────────────────────────────────────────────────────────────────
//  MODE TAB  –  compass ↔ map segmented control segment
// ─────────────────────────────────────────────────────────────────────────────

class _ModeTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unselectedColor = isDark
        ? Colors.white.withValues(alpha: 0.45)
        : AppColors.textSecondary.withValues(alpha: 0.60);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: selected
                ? AppColors.primary.withValues(alpha: 0.90)
                : Colors.transparent,
            border: selected
                ? Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.50),
                    width: 1.0,
                  )
                : null,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.40),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? AppColors.secondary : unselectedColor,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? AppColors.secondary : unselectedColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
