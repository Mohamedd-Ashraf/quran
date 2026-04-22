import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../constants/app_colors.dart';
import '../di/injection_container.dart' as di;
import '../services/adhan_notification_service.dart';
import '../services/prayer_times_cache_service.dart';
import '../services/reverse_geocoding_service.dart';
import '../services/settings_service.dart';
import '../settings/app_settings_cubit.dart';

enum _Step {
  offerLocationChoice,
  enterCityManually,
  checkingGpsService,
  gpsServiceDisabled,
  requestingLocation,
  locationDeniedRationale,
  locationDeniedForever,
  requestingNotification,
  notificationDeniedRationale,
  notificationDeniedForever,
  done,
}

class PermissionFlowScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const PermissionFlowScreen({super.key, required this.onComplete});

  @override
  State<PermissionFlowScreen> createState() => _PermissionFlowScreenState();
}

class _PermissionFlowScreenState extends State<PermissionFlowScreen>
    with WidgetsBindingObserver {
  _Step _step = _Step.offerLocationChoice;
  bool _waitingForGpsSettings = false;
  bool _locationRationaleShown = false;
  bool _notificationRationaleShown = false;

  // Manual city entry state
  final TextEditingController _cityController = TextEditingController();
  List<CitySearchResult> _cityResults = [];
  bool _citySearching = false;
  String? _cityError;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Start with the choice screen
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _cityController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waitingForGpsSettings) {
      _waitingForGpsSettings = false;
      _checkGpsAndProceed();
    }
  }

  bool get _isArabic {
    try {
      return context
          .read<AppSettingsCubit>()
          .state
          .appLanguageCode
          .toLowerCase()
          .startsWith('ar');
    } catch (_) {
      return false;
    }
  }

  // ── Step 0: Location choice ───────────────────────────────────────────────

  void _goToManualCity() {
    setState(() {
      _step = _Step.enterCityManually;
      _cityResults = [];
      _cityError = null;
    });
    _cityController.clear();
  }

  void _skipToGpsLocation() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkGpsAndProceed());
    setState(() => _step = _Step.checkingGpsService);
  }

  void _onCityQueryChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() { _cityResults = []; _cityError = null; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600), () => _searchCity(query));
  }

  Future<void> _searchCity(String query) async {
    setState(() { _citySearching = true; _cityError = null; });
    final results = await ReverseGeocodingService.searchCity(query);
    if (!mounted) return;
    setState(() {
      _citySearching = false;
      _cityResults = results;
      if (results.isEmpty) _cityError = _isArabic ? 'لم يُعثر على نتائج' : 'No results found';
    });
  }

  Future<void> _selectCity(CitySearchResult city) async {
    final settings = di.sl<SettingsService>();
    await settings.setLastKnownCoordinates(city.lat, city.lng);
    await di.sl<PrayerTimesCacheService>().cachePrayerTimes(
      city.lat, city.lng, locationName: city.name,
    );
    if (!mounted) return;
    await _requestNotification();
  }

  // ── Step 1: GPS service ───────────────────────────────────────────────────

  Future<void> _checkGpsAndProceed() async {
    if (!mounted) return;
    setState(() => _step = _Step.checkingGpsService);

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!mounted) return;

    if (serviceEnabled) {
      await _requestLocation();
    } else {
      setState(() => _step = _Step.gpsServiceDisabled);
    }
  }

  Future<void> _openGpsSettings() async {
    _waitingForGpsSettings = true;
    await Geolocator.openLocationSettings();
    // didChangeAppLifecycleState will re-check GPS on resume.
  }

  void _skipLocation() {
    unawaited(_requestNotification());
  }

  // ── Step 2: Location permission ───────────────────────────────────────────

  Future<void> _requestLocation() async {
    if (!mounted) return;
    setState(() => _step = _Step.requestingLocation);

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (!mounted) return;

    switch (permission) {
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        // Fetch and save coordinates immediately so prayer times screen
        // can use the cached value and won't re-prompt for location.
        try {
          Position? pos;
          try {
            pos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.low,
              timeLimit: const Duration(seconds: 12),
            );
          } catch (_) {
            pos = await Geolocator.getLastKnownPosition();
          }
          if (pos != null) {
            final settings = di.sl<SettingsService>();
            await settings.setLastKnownCoordinates(pos.latitude, pos.longitude);
            await di.sl<PrayerTimesCacheService>().cachePrayerTimes(
              pos.latitude, pos.longitude, locationName: null,
            );
          }
        } catch (_) {
          // Position unavailable – prayer times screen will handle it gracefully
        }
        await _requestNotification();
      case LocationPermission.deniedForever:
        setState(() => _step = _Step.locationDeniedForever);
      case LocationPermission.denied:
        if (_locationRationaleShown) {
          // Already shown rationale once; skip location, move to notifications.
          await _requestNotification();
        } else {
          setState(() => _step = _Step.locationDeniedRationale);
        }
      case LocationPermission.unableToDetermine:
        await _requestNotification();
    }
  }

  void _onLocationRationaleAllow() {
    _locationRationaleShown = true;
    unawaited(_requestLocation());
  }

  void _onLocationRationaleIgnore() {
    unawaited(_requestNotification());
  }

  Future<void> _openAppSettingsForLocation() async {
    await Geolocator.openAppSettings();
    if (mounted) await _requestNotification();
  }

  // ── Step 3: Notification permission ──────────────────────────────────────

  Future<void> _requestNotification() async {
    if (!mounted) return;
    setState(() => _step = _Step.requestingNotification);

    // Check current notification permission status first
    final status = await ph.Permission.notification.status;
    
    if (status.isGranted) {
      // Already granted, just ensure channels are set up
      final adhan = di.sl<AdhanNotificationService>();
      await adhan.requestPermissions();
      _finish();
      return;
    }

    if (status.isPermanentlyDenied) {
      // Permanently denied - show settings screen
      if (!mounted) return;
      setState(() => _step = _Step.notificationDeniedForever);
      return;
    }

    // Request permission
    final adhan = di.sl<AdhanNotificationService>();
    final granted = await adhan.requestPermissions();
    if (!mounted) return;

    if (granted) {
      _finish();
    } else {
      // Check if permanently denied after request
      final newStatus = await ph.Permission.notification.status;
      if (newStatus.isPermanentlyDenied) {
        setState(() => _step = _Step.notificationDeniedForever);
      } else if (_notificationRationaleShown) {
        // Already shown rationale once; finish regardless.
        _finish();
      } else {
        setState(() => _step = _Step.notificationDeniedRationale);
      }
    }
  }

  void _onNotificationRationaleAllow() {
    _notificationRationaleShown = true;
    unawaited(_requestNotification());
  }

  void _onNotificationRationaleIgnore() {
    _finish();
  }

  Future<void> _openAppSettingsForNotification() async {
    await ph.openAppSettings();
    // After returning from settings, re-check notification status
    if (!mounted) return;
    final status = await ph.Permission.notification.status;
    if (status.isGranted) {
      // Ensure channels are set up
      final adhan = di.sl<AdhanNotificationService>();
      await adhan.requestPermissions();
      _finish();
    } else {
      // User didn't enable, finish anyway
      _finish();
    }
  }

  void _finish() {
    if (!mounted || _step == _Step.done) return;
    setState(() => _step = _Step.done);
    widget.onComplete();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = _isArabic;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      body: SafeArea(child: _buildStep(isDark, isAr)),
    );
  }

  Widget _buildStep(bool isDark, bool isAr) {
    switch (_step) {
      case _Step.checkingGpsService:
      case _Step.requestingLocation:
      case _Step.requestingNotification:
      case _Step.done:
        return const Center(child: CircularProgressIndicator());

      case _Step.offerLocationChoice:
        return _buildLocationChoice(isDark, isAr);

      case _Step.enterCityManually:
        return _buildCityEntry(isDark, isAr);

      case _Step.gpsServiceDisabled:
        return _PermissionCard(
          isDark: isDark,
          icon: Icons.location_off_rounded,
          iconColor: AppColors.warning,
          title: isAr ? 'خدمة الموقع معطّلة' : 'Location Service Disabled',
          description: isAr
              ? 'يحتاج التطبيق إلى تفعيل خدمة الموقع (GPS) لتحديد مواقيت الأذان بدقة حسب منطقتك الجغرافية.'
              : 'The app needs Location Services (GPS) enabled to accurately calculate prayer times for your area.',
          primaryLabel: isAr ? 'فتح إعدادات الموقع' : 'Open Location Settings',
          secondaryLabel: isAr ? 'متابعة بدون موقع' : 'Continue Without Location',
          onPrimary: _openGpsSettings,
          onSecondary: _skipLocation,
        );

      case _Step.locationDeniedRationale:
        return _PermissionCard(
          isDark: isDark,
          icon: Icons.location_on_rounded,
          iconColor: AppColors.primary,
          title: isAr ? 'إذن الموقع مهم' : 'Location Permission Needed',
          description: isAr
              ? 'إذن الموقع ضروري لحساب مواقيت الصلاة بدقة بناءً على موقعك. بدونه لن تتمكن من الحصول على أوقات دقيقة.'
              : 'Location permission is needed to calculate accurate prayer times based on your location. Without it you won\'t get precise times.',
          primaryLabel: isAr ? 'موافق' : 'Allow',
          secondaryLabel: isAr ? 'تجاهل' : 'Ignore',
          onPrimary: _onLocationRationaleAllow,
          onSecondary: _onLocationRationaleIgnore,
        );

      case _Step.locationDeniedForever:
        return _PermissionCard(
          isDark: isDark,
          icon: Icons.location_disabled_rounded,
          iconColor: AppColors.error,
          title: isAr ? 'إذن الموقع محجوب' : 'Location Permission Blocked',
          description: isAr
              ? 'تم رفض إذن الموقع بشكل دائم. يمكنك تفعيله يدوياً من إعدادات التطبيق للحصول على مواقيت صلاة دقيقة.'
              : 'Location permission was permanently denied. You can enable it manually from App Settings to get accurate prayer times.',
          primaryLabel: isAr ? 'فتح إعدادات التطبيق' : 'App Settings',
          secondaryLabel: isAr ? 'تجاهل' : 'Ignore',
          onPrimary: _openAppSettingsForLocation,
          onSecondary: _onLocationRationaleIgnore,
        );

      case _Step.notificationDeniedRationale:
        return _PermissionCard(
          isDark: isDark,
          icon: Icons.notifications_active_rounded,
          iconColor: AppColors.primary,
          title: isAr ? 'الإشعارات مطلوبة للأذان' : 'Notifications Needed for Adhan',
          description: isAr
              ? 'يحتاج التطبيق إلى إذن الإشعارات حتى يُنبّهك بالأذان في أوقات الصلاة. بدون هذا الإذن لن تصلك تنبيهات الأذان.'
              : 'The app needs notification permission to alert you at prayer times. Without it you won\'t receive Adhan notifications.',
          primaryLabel: isAr ? 'موافق' : 'Allow',
          secondaryLabel: isAr ? 'تجاهل' : 'Ignore',
          onPrimary: _onNotificationRationaleAllow,
          onSecondary: _onNotificationRationaleIgnore,
        );

      case _Step.notificationDeniedForever:
        return _PermissionCard(
          isDark: isDark,
          icon: Icons.notifications_off_rounded,
          iconColor: AppColors.error,
          title: isAr ? 'إذن الإشعارات محجوب' : 'Notification Permission Blocked',
          description: isAr
              ? 'تم رفض إذن الإشعارات بشكل دائم. يمكنك تفعيله يدوياً من إعدادات التطبيق حتى تصلك تنبيهات الأذان.'
              : 'Notification permission was permanently denied. You can enable it manually from App Settings to receive Adhan alerts.',
          primaryLabel: isAr ? 'فتح إعدادات التطبيق' : 'App Settings',
          secondaryLabel: isAr ? 'تجاهل' : 'Ignore',
          onPrimary: _openAppSettingsForNotification,
          onSecondary: _onNotificationRationaleIgnore,
        );
    }
  }
  Widget _buildLocationChoice(bool isDark, bool isAr) {
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.background;
    final cardColor = isDark ? AppColors.darkCard : Colors.white;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.location_on_rounded, size: 52, color: AppColors.primary),
            ),
            const SizedBox(height: 28),
            Text(
              isAr ? 'تحديد موقعك' : 'Set Your Location',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: textPrimary, fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              isAr
                  ? 'نحتاج معرفة مدينتك لعرض مواقيت الصلاة بدقة.\nيمكنك إدخال اسم المدينة يدوياً أو السماح للتطبيق باستخدام موقعك التقريبي.'
                  : 'We need your city to show accurate prayer times.\nYou can enter your city name manually or allow the app to use your approximate location.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: textSecondary, height: 1.65,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 36),
            // Manual city entry button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.edit_location_alt_rounded),
                label: Text(isAr ? 'أدخل اسم مدينتك' : 'Enter City Name'),
                onPressed: _goToManualCity,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Use approximate location button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.my_location_rounded),
                label: Text(isAr ? 'استخدام موقعي التقريبي' : 'Use My Approximate Location'),
                onPressed: _skipToGpsLocation,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildCityEntry(bool isDark, bool isAr) {
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final cardColor = isDark ? AppColors.darkCard : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.divider;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
                onPressed: () => setState(() => _step = _Step.offerLocationChoice),
              ),
              const SizedBox(width: 8),
              Text(
                isAr ? 'ابحث عن مدينتك' : 'Search for your city',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: textPrimary, fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isAr
                ? 'اكتب اسم مدينتك لعرض مواقيت الصلاة بدقة'
                : 'Type your city name for accurate prayer times',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: textSecondary),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _cityController,
            autofocus: true,
            onChanged: _onCityQueryChanged,
            textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
            decoration: InputDecoration(
              hintText: isAr ? 'مثال: القاهرة أو Riyadh' : 'e.g. Cairo or الرياض',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _citySearching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: cardColor,
            ),
          ),
          if (_cityError != null) ...[
            const SizedBox(height: 12),
            Text(_cityError!, style: TextStyle(color: AppColors.error), textAlign: TextAlign.center),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: _cityResults.length,
              separatorBuilder: (_, __) => Divider(color: borderColor, height: 1),
              itemBuilder: (context, i) {
                final city = _cityResults[i];
                return ListTile(
                  leading: const Icon(Icons.location_city_rounded, color: AppColors.primary),
                  title: Text(city.name, style: TextStyle(color: textPrimary)),
                  onTap: () => _selectCity(city),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _skipToGpsLocation,
            child: Text(
              isAr ? 'استخدم موقعي التقريبي بدلاً من ذلك' : 'Use my approximate location instead',
              style: const TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable card UI ──────────────────────────────────────────────────────────

class _PermissionCard extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final String primaryLabel;
  final String secondaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

  const _PermissionCard({
    required this.isDark,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.onPrimary,
    required this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.divider;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),

          // Icon circle
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 56, color: iconColor),
          ),
          const SizedBox(height: 36),

          // Title
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: textPrimary,
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Description
          Text(
            description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: textSecondary,
                  height: 1.65,
                ),
            textAlign: TextAlign.center,
          ),

          const Spacer(),

          // Primary button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: onPrimary,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: Text(
                primaryLabel,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Secondary button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: OutlinedButton(
              onPressed: onSecondary,
              style: OutlinedButton.styleFrom(
                foregroundColor: textSecondary,
                side: BorderSide(color: borderColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                secondaryLabel,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
