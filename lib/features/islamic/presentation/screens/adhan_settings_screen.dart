import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/adhan_sounds.dart';
import '../../../../core/constants/prayer_calculation_constants.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/services/settings_service.dart';
import '../../../../core/services/adhan_notification_service.dart';
import '../../../../core/services/prayer_foreground_service.dart';
import '../../../../core/settings/app_settings_cubit.dart';
import 'adhan_diagnostics_screen.dart';
import 'adhan_reliability_test_screen.dart';
import 'oem_battery_optimization_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Cache state for each online sound
// ─────────────────────────────────────────────────────────────────────────────
enum _CacheState { none, caching, cached, error }

// ─────────────────────────────────────────────────────────────────────────────

class AdhanSettingsScreen extends StatefulWidget {
  const AdhanSettingsScreen({super.key});
  @override
  State<AdhanSettingsScreen> createState() => _AdhanSettingsScreenState();
}

class _AdhanSettingsScreenState extends State<AdhanSettingsScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  static const MethodChannel _adhanChannel = MethodChannel('quraan/adhan_player');
    static final Uri _kPreviewArtUri =
      Uri.parse('android.resource://com.nooraliman.quran/drawable/adhan_art');

  late final SettingsService _settings;
  late final AdhanNotificationService _adhanService;

  // ── Theme-aware color helpers (initialised in build()) ─────────────────
  late ColorScheme _cs;
  Color get _textSecondary => _cs.onSurfaceVariant;
  Color get _textPrimary   => _cs.onSurface;
  Color get _cardSurface   => _cs.surface;
  Color get _cardBorder    => _cs.outlineVariant;

  // ── Core settings ──────────────────────────────────────────────────────
  String _selectedSoundId = AdhanSounds.defaultId;
  String _selectedMethodId = 'egyptian';
  String _selectedAsrMethod = 'standard';
  bool _notificationsEnabled = true;
  bool _includeFajr = true;
  bool _methodAutoDetected = true;
  double _adhanVolume = 1.0;

  // ── New settings ───────────────────────────────────────────────────────
  bool _shortMode = false;
  bool _reminderEnabled = false;
  int _reminderMinutes = 10;
  bool _iqamaEnabled = false;
  int _iqamaMinutes = 15;             // global fallback (kept for backward-compat)
  bool _salawatEnabled = false;
  int _salawatMinutes = 30;
  bool _salawatSleepEnabled = false;
  int  _salawatSleepStartH  = 22;   // 22:00 default
  int  _salawatSleepEndH    = 6;    // 06:00 default

  // ── Per-prayer adhan enable ────────────────────────────────────────────
  bool _enableDhuhr   = true;
  bool _enableAsr     = true;
  bool _enableMaghrib = true;
  bool _enableIsha    = true;

  // ── Per-prayer iqama minutes ───────────────────────────────────────────
  int _iqamaMinutesFajr    = 20;
  int _iqamaMinutesDhuhr   = 15;
  int _iqamaMinutesAsr     = 15;
  int _iqamaMinutesMaghrib = 10;
  int _iqamaMinutesIsha    = 15;

  // ── Salawat sound selection ────────────────────────────────────────────
  String _salawatSoundId = SalawatSounds.defaultId;

  // ── Reminder sound volumes ─────────────────────────────────────────────
  double _salawatVolume     = 0.8;
  double _iqamaVolume       = 0.8;
  double _approachingVolume = 0.8;

  // ── Audio stream setting ───────────────────────────────────────────────
  /// 'ringtone' → ring stream. 'alarm' → bypasses silent mode (default).
  String _adhanAudioStream = 'alarm';

  // ── Silent mode during prayer ──────────────────────────────────────────
  bool _silentDuringPrayer    = false;
  int  _silentDelayMinutes    = 0;
  int  _silentDurationMinutes = 20;
  bool _dndPermissionGranted  = true;

  // ── Force speaker ─────────────────────────────────────────────────────
  bool _forceSpeaker = false;

  // ── Persistent prayer notification ────────────────────────────────────
  bool _persistentNotification = false;

  // ── Permission states ──────────────────────────────────────────────────
  bool _notificationPermissionGranted = true;
  bool _locationPermissionGranted = true;

  // ── Time jump for testing ──────────────────────────────────────────────
  int _jumpMinutes = 2;
  bool _timeJumpActive = false;
  bool _isSettingTime = false;
  String? _nextPrayerName;
  DateTime? _nextPrayerTime;
  final TextEditingController _customMinutesCtrl = TextEditingController();

  // ── System alarm info ──────────────────────────────────────────────────
  int _systemAlarmCurrent = -1;
  int _systemAlarmMax = 15;

  // ── Preview state ──────────────────────────────────────────────────────
  bool _isPreviewPlaying = false;
  String? _previewingId;
  AudioPlayer? _onlinePlayer;
  StreamSubscription<PlayerState>? _onlinePlayerSub;
  Timer? _shortModeTimer;

  // ── Per-sound cache state ──────────────────────────────────────────────
  final Map<String, _CacheState> _cacheState = {};
  final Map<String, double> _cacheProgress = {};

  // ── UI flags ───────────────────────────────────────────────────────────
  bool _isSaving = false;
  bool _isTesting = false;
  bool _schedulingTest = false;
  bool _batteryUnrestricted = false;
  bool _showAdhanTestButtons = false;
  final Map<String, bool> _testingPrayer = {};  // Track loading state per prayer
  Timer? _debounce;
  late TabController _tabController;
  /// Show the "جديد / New" badge next to Short Adhan only for version 1.0.7.
  bool _showNewBadge = false;

  // ═══════════════════════════════════════════════════════════════════════
  // Lifecycle
  // ═══════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addObserver(this);
    _settings = di.sl<SettingsService>();
    _adhanService = di.sl<AdhanNotificationService>();
    _load();
    _checkBatteryStatus();
    _fetchAlarmVolume();
    _checkCachedOnlineSounds();
    _adhanChannel.setMethodCallHandler(_handleNativeCallback);
    _loadNextPrayer();
    _checkDndPermission();
    _checkPermissions();
    // Show the "جديد" badge only for version 1.0.7
    PackageInfo.fromPlatform().then((info) {
      if (mounted) {
        setState(() => _showNewBadge = info.version == '1.0.7');
      }
    });
  }

  /// Check notification and location permissions to show appropriate warnings.
  Future<void> _checkPermissions() async {
    if (kIsWeb) return;
    
    try {
      final notifStatus = await ph.Permission.notification.status;
      final locStatus = await Geolocator.checkPermission();
      
      if (!mounted) return;
      setState(() {
        _notificationPermissionGranted = notifStatus.isGranted;
        _locationPermissionGranted = locStatus == LocationPermission.always ||
            locStatus == LocationPermission.whileInUse;
      });
    } catch (_) {
      // If we can't check, assume granted to avoid false negatives.
    }
  }

  /// Best-effort notification permission flow.
  ///
  /// - Try runtime request first (Android 13+).
  /// - If not granted, offer app settings as an optional next step.
  Future<bool> _ensureNotificationPermission({required bool isAr}) async {
    if (kIsWeb) return true;

    try {
      final current = await ph.Permission.notification.status;
      if (current.isGranted) {
        if (mounted) setState(() => _notificationPermissionGranted = true);
        return true;
      }

      final requested = await ph.Permission.notification.request();
      await _checkPermissions();
      if (requested.isGranted || _notificationPermissionGranted) {
        return true;
      }

      if (!mounted) return false;
      final shouldOpenSettings = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(
                isAr ? 'صلاحية الإشعارات غير مفعلة' : 'Notification Permission Not Granted',
              ),
              content: Text(
                isAr
                    ? 'يمكنك المتابعة بدونها، لكن الأذان والإشعارات لن تظهر بشكل موثوق حتى يتم السماح بها.'
                      '\n\nهل تريد فتح إعدادات التطبيق الآن؟'
                    : 'You can continue without it, but Adhan alerts may not be delivered reliably until notification permission is granted.'
                      '\n\nOpen app settings now?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(isAr ? 'لاحقاً' : 'Later'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(isAr ? 'فتح الإعدادات' : 'Open Settings'),
                ),
              ],
            ),
          ) ??
          false;

      if (shouldOpenSettings) {
        await ph.openAppSettings();
        await Future.delayed(const Duration(seconds: 1));
        await _checkPermissions();
      }

      return _notificationPermissionGranted;
    } catch (_) {
      return _notificationPermissionGranted;
    }
  }

  Future<dynamic> _handleNativeCallback(MethodCall call) async {
    if (call.method == 'previewCompleted' && mounted) {
      setState(() {
        _isPreviewPlaying = false;
        _previewingId = null;
      });
    }
  }

  void _load() {
    setState(() {
      _selectedSoundId  = _settings.getSelectedAdhanSound();
      _selectedMethodId = _settings.getPrayerCalculationMethod();
      _selectedAsrMethod = _settings.getPrayerAsrMethod();
      _notificationsEnabled = _settings.getAdhanNotificationsEnabled();
      _includeFajr       = _settings.getAdhanIncludeFajr();
      _methodAutoDetected = _settings.getPrayerMethodAutoDetected();
      _adhanVolume       = _settings.getAdhanVolume();
      _shortMode         = _settings.getAdhanShortMode();
      _reminderEnabled   = _settings.getPrayerReminderEnabled();
      _reminderMinutes   = _settings.getPrayerReminderMinutes();
      _iqamaEnabled      = _settings.getIqamaEnabled();
      _iqamaMinutes      = _settings.getIqamaMinutes();
      _salawatEnabled    = _settings.getSalawatEnabled();
      _salawatMinutes    = _settings.getSalawatMinutes();
      _salawatSleepEnabled = _settings.getSalawatSleepEnabled();
      _salawatSleepStartH  = _settings.getSalawatSleepStartH();
      _salawatSleepEndH    = _settings.getSalawatSleepEndH();
      _adhanAudioStream  = _settings.getAdhanAudioStream();
      // Silent mode during prayer
      _silentDuringPrayer    = _settings.getSilentDuringPrayer();
      _silentDelayMinutes    = _settings.getSilentDelayMinutes();
      _silentDurationMinutes = _settings.getSilentDurationMinutes();
      // Per-prayer adhan enable      _enableDhuhr   = _settings.getAdhanEnableDhuhr();
      _enableAsr     = _settings.getAdhanEnableAsr();
      _enableMaghrib = _settings.getAdhanEnableMaghrib();
      _enableIsha    = _settings.getAdhanEnableIsha();
      // Per-prayer iqama minutes
      _iqamaMinutesFajr    = _settings.getIqamaMinutesFajr();
      _iqamaMinutesDhuhr   = _settings.getIqamaMinutesDhuhr();
      _iqamaMinutesAsr     = _settings.getIqamaMinutesAsr();
      _iqamaMinutesMaghrib = _settings.getIqamaMinutesMaghrib();
      _iqamaMinutesIsha    = _settings.getIqamaMinutesIsha();
      // Salawat sound
      _salawatSoundId = _settings.getSalawatSound();
      // Reminder volumes
      _salawatVolume     = _settings.getSalawatVolume();
      _iqamaVolume       = _settings.getIqamaVolume();
      _approachingVolume = _settings.getApproachingVolume();
      // Test buttons visibility
      _showAdhanTestButtons = _settings.getShowAdhanTestButtons();
      // Force speaker
      _forceSpeaker = _settings.getBool('adhan_force_speaker');
      // Persistent prayer notification
      _persistentNotification = _settings.getPersistentPrayerNotification();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      _checkBatteryStatus();
      _fetchAlarmVolume();
      _loadNextPrayer();
      _checkDndPermission();
      _checkPermissions();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _shortModeTimer?.cancel();
    _shortModeTimer = null;
    WidgetsBinding.instance.removeObserver(this);
    _adhanChannel.setMethodCallHandler(null);
    // Cancel subscription synchronously so the listener never fires again.
    _onlinePlayerSub?.cancel();
    _onlinePlayerSub = null;
    // Pause before dispose so ExoPlayer doesn't flush the codec during release.
    // Flushing from PLAYING state causes FLUSHING→RESUMING→dead thread crash.
    final playerToDispose = _onlinePlayer;
    _onlinePlayer = null;
    playerToDispose?.pause().ignore();
    playerToDispose?.dispose().ignore();
    // Stop the native adhan player fire-and-forget.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _adhanChannel.invokeMethod<void>('stopAdhan').ignore();
    }
    _customMinutesCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Native / System helpers
  // ═══════════════════════════════════════════════════════════════════════

  // ── Time jump helpers ────────────────────────────────────────────────────

  void _loadNextPrayer() {
    final json = _settings.getAdhanSchedulePreview();
    if (json == null) return;
    try {
      final list = jsonDecode(json) as List;
      final now = DateTime.now();
      for (final item in list) {
        final timeMs = (item['timeMs'] as num?)?.toInt();
        if (timeMs == null) continue;
        final dt = DateTime.fromMillisecondsSinceEpoch(timeMs);
        if (!dt.isAfter(now)) continue;
        if (mounted) {
          setState(() {
            _nextPrayerName = item['arabicName'] as String? ?? '';
            _nextPrayerTime = dt;
          });
        }
        return;
      }
    } catch (_) {}
  }

  Future<void> _setSystemTime() async {
    if (_nextPrayerTime == null) return;
    // Custom field takes priority if it has a valid value
    final customVal = int.tryParse(_customMinutesCtrl.text.trim());
    final minutes = (customVal != null && customVal > 0) ? customVal : _jumpMinutes;
    final target = _nextPrayerTime!.subtract(Duration(minutes: minutes));
    setState(() => _isSettingTime = true);
    try {
      await _adhanChannel.invokeMethod('setSystemTime', {
        'timeMs': target.millisecondsSinceEpoch,
      });
      setState(() {
        _timeJumpActive = true;
        _jumpMinutes = minutes;
      });
      _showSnack(
        _isAr
            ? 'تم ضبط الوقت لما قبل $minutes دقيقة من أذان ${_nextPrayerName ?? ""}'
            : 'Time set to $minutes min before ${_nextPrayerName ?? "prayer"} ✔️',
        AppColors.success,
      );
    } on PlatformException catch (e) {
      _showSnack(
        _isAr ? 'فشل: ${e.message}' : 'Failed: ${e.message}',
        AppColors.error,
      );
    } finally {
      if (mounted) setState(() => _isSettingTime = false);
    }
  }

  Future<void> _restoreSystemTime() async {
    setState(() => _isSettingTime = true);
    try {
      await _adhanChannel.invokeMethod('restoreSystemTime');
      setState(() => _timeJumpActive = false);
      _showSnack(
        _isAr ? 'تم استعادة الوقت الصحيح ✔️' : 'System time restored ✔️',
        AppColors.success,
      );
    } on PlatformException catch (e) {
      _showSnack(
        _isAr ? 'فشل الاستعادة: ${e.message}' : 'Restore failed: ${e.message}',
        AppColors.error,
      );
    } finally {
      if (mounted) setState(() => _isSettingTime = false);
    }
  }

  Future<void> _fetchAlarmVolume() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      // Returns a map with int 'current', int 'max', and String 'streamType'.
      final res = await _adhanChannel.invokeMethod<Object>('getAlarmVolume');
      if (res is Map && mounted) {
        setState(() {
          _systemAlarmCurrent = (res['current'] as int?) ?? -1;
          _systemAlarmMax     = (res['max'] as int?) ?? 15;
        });
      }
    } catch (_) {}
  }

  Future<void> _openSoundSettings() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _adhanChannel.invokeMethod('openSoundSettings');
    } catch (_) {}
  }

  Future<void> _checkBatteryStatus() async {
    if (defaultTargetPlatform != TargetPlatform.android || kIsWeb) {
      if (mounted) setState(() => _batteryUnrestricted = true);
      return;
    }
    try {
      final disabled = await _adhanChannel
              .invokeMethod<bool>('isBatteryOptimizationDisabled') ??
          false;
      if (mounted) setState(() => _batteryUnrestricted = disabled);
    } catch (_) {}
  }

  Future<void> _checkDndPermission() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      if (mounted) setState(() => _dndPermissionGranted = true);
      return;
    }
    try {
      final granted = await _adhanChannel.invokeMethod<bool>('checkDndPermission') ?? true;
      if (mounted) setState(() => _dndPermissionGranted = granted);
    } catch (_) {
      if (mounted) setState(() => _dndPermissionGranted = true);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Online sound cache helpers
  // ═══════════════════════════════════════════════════════════════════════

  Future<Directory> _cacheDir() async {
    // Use getApplicationSupportDirectory() which maps to filesDir on Android.
    // This MUST match the path that AdhanPlayerService.kt reads from (filesDir/adhan_cache).
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/adhan_cache');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<File> _cachedFile(AdhanSoundInfo sound) async {
    final dir = await _cacheDir();
    return File('${dir.path}/${sound.id}.mp3');
  }

  Future<void> _checkCachedOnlineSounds() async {
    for (final s in AdhanSounds.online) {
      try {
        final f = await _cachedFile(s);
        if (f.existsSync() && f.lengthSync() > 1024) {
          if (mounted) setState(() => _cacheState[s.id] = _CacheState.cached);
        }
      } catch (_) {}
    }
  }

  /// Fetches and caches an online sound silently in the background.
  /// Called automatically when the user selects an online sound.
  Future<void> _cacheOnlineSound(AdhanSoundInfo sound) async {
    if (sound.url == null) return;
    if (_cacheState[sound.id] == _CacheState.caching) return;
    if (_cacheState[sound.id] == _CacheState.cached) return;

    if (mounted) {
      setState(() {
        _cacheState[sound.id] = _CacheState.caching;
        _cacheProgress[sound.id] = 0.0;
      });
    }

    try {
      final file = await _cachedFile(sound);
      final request = http.Request('GET', Uri.parse(sound.url!));
      final response = await request.send();
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final total = response.contentLength ?? 0;
      var received = 0;
      final sink = file.openWrite();
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0 && mounted) {
          setState(() => _cacheProgress[sound.id] = received / total);
        }
      }
      await sink.close();
      if (mounted) {
        setState(() {
          _cacheState[sound.id] = _CacheState.cached;
          _cacheProgress[sound.id] = 1.0;
        });
      }
    } catch (e) {
      debugPrint('[AdhanCache] Error: $e');
      if (mounted) {
        setState(() => _cacheState[sound.id] = _CacheState.error);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Cache helpers (delete)
  // ═══════════════════════════════════════════════════════════════════════

  /// Delete a locally-cached online adhan file to free storage.
  Future<void> _deleteCachedSound(AdhanSoundInfo sound) async {
    try {
      final f = await _cachedFile(sound);
      if (await f.exists()) await f.delete();
      if (mounted) {
        setState(() {
          _cacheState[sound.id] = _CacheState.none;
          _cacheProgress[sound.id] = 0.0;
          // If the deleted sound was the active selection → fall back to default
          if (_selectedSoundId == sound.id) {
            _selectedSoundId = AdhanSounds.defaultId;
          }
        });
        // Persist the new selection immediately (bypass debounce)
        _save();
      }
    } catch (e) {
      debugPrint('⚠️ [AdhanCache] Cannot delete: $e');
    }
  }

  /// Confirm dialog before deleting a cached sound file.
  Future<void> _showDeleteConfirm(AdhanSoundInfo sound, bool isAr) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAr ? 'حذف الصوت المحمَّل' : 'Delete downloaded audio'),
        content: Text(
          isAr
              ? 'سيتم حذف «${sound.nameAr}». لاستخدامه مجدداً ستحتاج لتحميله من الإنترنت.'
              : 'Delete «${sound.nameEn}» from storage? You will need to re-download it to use it again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isAr ? 'إلغاء' : 'Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isAr ? 'حذف' : 'Delete'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) await _deleteCachedSound(sound);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Salawat sleep time picker
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildSalawatSleepTimePicker(bool isAr) {
    String fmt(int h) {
      final ampm = h < 12 ? (isAr ? 'ص' : 'AM') : (isAr ? 'م' : 'PM');
      final h12  = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      return '$h12:00 $ampm';
    }

    Future<void> pick(bool isStart) async {
      final initial = TimeOfDay(
          hour: isStart ? _salawatSleepStartH : _salawatSleepEndH, minute: 0);
      final picked = await showTimePicker(
        context: context, initialTime: initial,
        helpText: isAr
            ? (isStart ? 'بداية وقت الهدوء' : 'نهاية وقت الهدوء')
            : (isStart ? 'Sleep start' : 'Wake-up time'),
        builder: (ctx, child) => Directionality(
          textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
          child: child!,
        ),
      );
      if (picked != null && mounted) {
        setState(() {
          if (isStart) _salawatSleepStartH = picked.hour;
          else         _salawatSleepEndH   = picked.hour;
        });
        _autoSave();
      }
    }

    const indigo = Color(0xFF5C6BC0);
    const teal   = Color(0xFF26A69A);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Expanded(child: GestureDetector(
          onTap: () => pick(true),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: indigo.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: indigo.withValues(alpha: 0.30)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Text(isAr ? 'بداية النوم' : 'Sleep start',
                style: TextStyle(fontSize: 10, color: indigo, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.bedtime_rounded, size: 14, color: indigo),
                const SizedBox(width: 4),
                Text(fmt(_salawatSleepStartH),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: indigo)),
              ]),
            ]),
          ),
        )),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(isAr ? 'حتى' : 'to',
            style: TextStyle(fontSize: 13, color: _textSecondary)),
        ),
        Expanded(child: GestureDetector(
          onTap: () => pick(false),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: teal.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: teal.withValues(alpha: 0.30)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Text(isAr ? 'نهاية النوم' : 'Wake up',
                style: const TextStyle(fontSize: 10, color: teal, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.wb_sunny_rounded, size: 14, color: teal),
                const SizedBox(width: 4),
                Text(fmt(_salawatSleepEndH),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: teal)),
              ]),
            ]),
          ),
        )),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Preview
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _previewSound(AdhanSoundInfo sound) async {
    if (_isPreviewPlaying) {
      await _stopPreview();
      if (_previewingId == sound.id) return;
    }

    setState(() {
      _isPreviewPlaying = true;
      _previewingId = sound.id;
    });

    try {
      if (sound.isOnline) {
        _onlinePlayer = AudioPlayer();
        final previewItem = MediaItem(
          id: sound.id,
          title: 'اختبار الأذان',
          album: sound.nameAr,
          artist: 'القرآن الكريم',
          displayTitle: 'اختبار الأذان',
          displaySubtitle: sound.nameAr,
          artUri: _kPreviewArtUri,
        );
        final state = _cacheState[sound.id];
        if (state == _CacheState.cached) {
          final f = await _cachedFile(sound);
          await _onlinePlayer!.setAudioSource(AudioSource.uri(
            Uri.file(f.path),
            tag: previewItem,
          ));
        } else if (sound.url != null) {
          await _onlinePlayer!.setAudioSource(AudioSource.uri(
            Uri.parse(sound.url!),
            tag: previewItem,
          ));
        } else {
          throw Exception('No URL available');
        }
        // Apply clip BEFORE play — position-based, works for both cached files
        // and streaming URLs regardless of buffer state.
        if (_shortMode) {
          await _onlinePlayer!.setClip(
            end: Duration(seconds: sound.shortDurationSeconds),
          );
        }
        _onlinePlayerSub = _onlinePlayer!.playerStateStream.listen((s) {
          if (s.processingState == ProcessingState.completed && mounted) {
            setState(() {
              _isPreviewPlaying = false;
              _previewingId = null;
            });
          }
        });
        await _onlinePlayer!.play();
      } else {
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
          // Native prepare() is synchronous — invokeMethod returns only after
          // player.start() has been called, so a Dart timer here tracks audio
          // position accurately without any init-overhead offset.
          await _adhanChannel.invokeMethod(
            'playAdhan',
            {
              'soundName': sound.id,
              'volume': _adhanVolume,
            },
          );
          if (_shortMode && mounted) {
            _shortModeTimer?.cancel();
            _shortModeTimer = Timer(
              Duration(seconds: sound.shortDurationSeconds),
              () => _stopPreview(),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Preview error: $e');
      if (mounted) {
        setState(() {
          _isPreviewPlaying = false;
          _previewingId = null;
        });
        _showSnack(
          _isAr ? 'تعذّر تشغيل الأذان' : 'Could not play adhan',
          Colors.red,
        );
      }
    }
  }

  Future<void> _stopPreview() async {
    _shortModeTimer?.cancel();
    _shortModeTimer = null;
    try {
      await _onlinePlayerSub?.cancel();
      _onlinePlayerSub = null;
      await _onlinePlayer?.stop();
      await _onlinePlayer?.dispose();
      _onlinePlayer = null;
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await _adhanChannel.invokeMethod('stopAdhan');
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _isPreviewPlaying = false;
        _previewingId = null;
      });
    }
  }

  void _selectSound(AdhanSoundInfo sound) {
    setState(() => _selectedSoundId = sound.id);
    HapticFeedback.selectionClick();
    _autoSave();
    if (sound.isOnline) _cacheOnlineSound(sound); // auto-cache in background
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Save
  // ═══════════════════════════════════════════════════════════════════════

  void _autoSave({Duration delay = const Duration(milliseconds: 600)}) {
    _debounce?.cancel();
    _debounce = Timer(delay, _save);
  }

  Future<void> _saveReminderVolumesOnly() async {
    _debounce?.cancel();
    await Future.wait<bool>([
      _settings.setSalawatVolume(_salawatVolume),
      _settings.setIqamaVolume(_iqamaVolume),
      _settings.setApproachingVolume(_approachingVolume),
    ]);
  }

  Future<void> _save() async {
    if (!mounted) return;
    setState(() => _isSaving = true);
    await Future.wait<bool>([
      _settings.setSelectedAdhanSound(_selectedSoundId),
      _settings.setPrayerCalculationMethod(_selectedMethodId),
      _settings.setPrayerAsrMethod(_selectedAsrMethod),
      _settings.setAdhanIncludeFajr(_includeFajr),
      _settings.setAdhanVolume(_adhanVolume),
      _settings.setPrayerMethodAutoDetected(_methodAutoDetected),
      _settings.setAdhanShortMode(_shortMode),
      _settings.setPrayerReminderEnabled(_reminderEnabled),
      _settings.setPrayerReminderMinutes(_reminderMinutes),
      _settings.setIqamaEnabled(_iqamaEnabled),
      _settings.setIqamaMinutes(_iqamaMinutes),
      _settings.setSalawatEnabled(_salawatEnabled),
      _settings.setSalawatMinutes(_salawatMinutes),
      _settings.setSalawatSleepEnabled(_salawatSleepEnabled),
      _settings.setSalawatSleepStartH(_salawatSleepStartH),
      _settings.setSalawatSleepEndH(_salawatSleepEndH),
      _settings.setAdhanAudioStream(_adhanAudioStream),
      // Per-prayer adhan enable
      _settings.setAdhanEnableDhuhr(_enableDhuhr),
      _settings.setAdhanEnableAsr(_enableAsr),
      _settings.setAdhanEnableMaghrib(_enableMaghrib),
      _settings.setAdhanEnableIsha(_enableIsha),
      // Per-prayer iqama minutes
      _settings.setIqamaMinutesFajr(_iqamaMinutesFajr),
      _settings.setIqamaMinutesDhuhr(_iqamaMinutesDhuhr),
      _settings.setIqamaMinutesAsr(_iqamaMinutesAsr),
      _settings.setIqamaMinutesMaghrib(_iqamaMinutesMaghrib),
      _settings.setIqamaMinutesIsha(_iqamaMinutesIsha),
      // Salawat sound
      _settings.setSalawatSound(_salawatSoundId),
      // Reminder volumes
      _settings.setSalawatVolume(_salawatVolume),
      _settings.setIqamaVolume(_iqamaVolume),
      _settings.setApproachingVolume(_approachingVolume),
      // Silent mode during prayer
      _settings.setSilentDuringPrayer(_silentDuringPrayer),
      _settings.setSilentDelayMinutes(_silentDelayMinutes),
      _settings.setSilentDurationMinutes(_silentDurationMinutes),
    ]);
    if (_notificationsEnabled) {
      await _adhanService.enableAndSchedule();
    } else {
      await _adhanService.disable();
    }
    if (mounted) setState(() => _isSaving = false);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════════════════════════════════

  bool get _isAr {
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

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ));
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    _cs = Theme.of(context).colorScheme;
    final isAr = _isAr;
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (ctx, innerBoxIsScrolled) => [
          _buildAppBar(isAr, innerBoxIsScrolled),
        ],
        body: TabBarView(
          controller: _tabController,
          physics: const ClampingScrollPhysics(),
          children: [
            _buildAdhanTab(isAr),
            _buildRemindersTab(isAr),
            _buildPrayerTimesTab(isAr),
          ],
        ),
      ),
    );
  }

  // ─── Tab 1: الأذان ────────────────────────────────────────────────────────

  Widget _buildAdhanTab(bool isAr) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        // Show notification permission warning (critical - adhan won't work)
        if (!_notificationPermissionGranted) ...[
          _NotificationPermissionBanner(
            isAr: isAr,
            onTap: () async {
              await _ensureNotificationPermission(isAr: isAr);
            },
          ),
          const SizedBox(height: 12),
        ],
        // Show location warning (less critical - will use default location)
        if (!_locationPermissionGranted && _notificationPermissionGranted) ...[
          _LocationWarningBanner(
            isAr: isAr,
            onTap: () async {
              await Geolocator.openAppSettings();
              await Future.delayed(const Duration(seconds: 1));
              _checkPermissions();
            },
          ),
          const SizedBox(height: 12),
        ],
        if (!_notificationsEnabled) ...[
          _DisabledBanner(isAr: isAr),
          const SizedBox(height: 12),
        ],
        if (!_batteryUnrestricted) ...[
          _BatteryWarningCard(
            isAr: isAr,
            onTap: () async {
              try {
                await _adhanChannel.invokeMethod('openBatterySettings');
                await Future.delayed(const Duration(seconds: 1));
                _checkBatteryStatus();
              } catch (_) {}
            },
          ),
          const SizedBox(height: 12),
        ],
        // الأذان والإشعارات
        _buildSection(
          icon: Icons.notifications_active_rounded,
          titleAr: 'الأذان والإشعارات',
          titleEn: 'Adhan & Notifications',
          isAr: isAr,
          children: [
            _buildSwitchRow(
              icon: _notificationsEnabled
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_off_rounded,
              iconColor: _notificationsEnabled && _notificationPermissionGranted 
                  ? AppColors.primary 
                  : Colors.grey,
              titleAr: 'تفعيل الأذان',
              titleEn: 'Enable Adhan',
              subtitleAr: _notificationPermissionGranted
                  ? 'تشغيل الأذان تلقائياً عند كل وقت صلاة'
                  : 'يتطلب صلاحية الإشعارات أولاً',
              subtitleEn: _notificationPermissionGranted
                  ? 'Auto-play adhan at each prayer time'
                  : 'Requires notification permission first',
              value: _notificationsEnabled,
              onChanged: (v) async {
                if (v && !_notificationPermissionGranted) {
                  final granted = await _ensureNotificationPermission(isAr: isAr);
                  if (!granted) {
                    return;
                  }
                }
                setState(() => _notificationsEnabled = v);
                _autoSave();
              },
              isAr: isAr,
            ),
            _buildDivider(),
            _buildSwitchRow(
              icon: Icons.compress_rounded,
              iconColor: _shortMode ? AppColors.secondary : Colors.grey,
              titleAr: 'الأذان المختصر',
              titleEn: 'Short Adhan (2 Takbeers)',
              subtitleAr: 'تكبيرتان فقط بدلاً من الأذان الكامل',
              subtitleEn: 'Only two Takbeers instead of the full Adhan',
              value: _shortMode,
              onChanged: _notificationsEnabled
                  ? (v) {
                      setState(() => _shortMode = v);
                      _autoSave();
                    }
                  : null,
              isAr: isAr,
              badge: _showNewBadge ? (isAr ? 'جديد' : 'New') : null,
            ),
            if (_shortMode) ...[
              _buildDivider(),
              _buildShortModeExplanation(isAr),
            ],
            _buildDivider(),
            _buildStreamPickerRow(isAr),
            _buildDivider(),
            _buildSwitchRow(
              icon: _persistentNotification
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_paused_outlined,
              iconColor: _persistentNotification ? AppColors.primary : Colors.grey,
              titleAr: 'إشعار مواقيت الصلاة الثابت',
              titleEn: 'Persistent Prayer Times',
              subtitleAr: 'يعرض الصلاة القادمة والوقت المتبقي، ويمكن إيقافه من الإشعار أو الإعدادات',
              subtitleEn: 'Shows next prayer and remaining time; can be stopped from notification or settings',
              value: _persistentNotification,
              onChanged: (v) async {
                setState(() => _persistentNotification = v);
                await _settings.setPersistentPrayerNotification(v);
                if (v) {
                  PrayerForegroundService.start();
                } else {
                  PrayerForegroundService.stop();
                }
              },
              isAr: isAr,
            ),
          ],
        ),
        const SizedBox(height: 16),
        // الصلوات المُفَعَّلة
        _buildSection(
          icon: Icons.mosque_rounded,
          titleAr: 'الصلوات المُفَعَّلة',
          titleEn: 'Enabled Prayers',
          isAr: isAr,
          children: [_buildPerPrayerToggles(isAr)],
        ),
        const SizedBox(height: 16),
        // صوت الأذان
        _buildSoundSection(isAr),
        const SizedBox(height: 16),
        // مستوى الصوت
        _buildSection(
          icon: Icons.volume_up_rounded,
          titleAr: 'مستوى الصوت',
          titleEn: 'Volume',
          isAr: isAr,
          children: [_buildVolumeCard(isAr)],
        ),
        const SizedBox(height: 16),
        // أدوات متقدمة
        _buildSection(
          icon: Icons.tune_rounded,
          titleAr: 'أدوات متقدمة',
          titleEn: 'Advanced Tools',
          isAr: isAr,
          children: [
            _buildSwitchRow(
              icon: Icons.speaker_rounded,
              iconColor: _forceSpeaker ? AppColors.primary : Colors.grey,
              titleAr: 'إخراج الصوت من سماعة الجهاز',
              titleEn: 'Force Device Speaker',
              subtitleAr: 'تشغيل الأذان دائماً من سماعة الهاتف حتى لو كانت سماعة بلوتوث متصلة',
              subtitleEn: 'Always play adhan from phone speaker even when Bluetooth is connected',
              value: _forceSpeaker,
              onChanged: (v) async {
                setState(() => _forceSpeaker = v);
                try {
                  await _adhanChannel.invokeMethod('setForceSpeaker', {'enabled': v});
                } catch (_) {}
                _autoSave();
              },
              isAr: isAr,
            ),
            _buildDivider(),
            ListTile(
              leading: const Icon(Icons.battery_saver_rounded, color: AppColors.primary),
              title: Text(isAr ? 'إعدادات بطارية الشركة المصنّعة' : 'OEM Battery Settings'),
              subtitle: Text(isAr ? 'خطوات للتأكد من عمل الأذان في الخلفية' : 'Steps to ensure adhan works in background'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const OemBatteryOptimizationScreen()),
              ),
            ),
            _buildDivider(),
            ListTile(
              leading: const Icon(Icons.bug_report_rounded, color: AppColors.primary),
              title: Text(isAr ? 'التشخيص' : 'Diagnostics'),
              subtitle: Text(isAr ? 'تحقق من حالة النظام والصلاحيات' : 'Check system status and permissions'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdhanDiagnosticsScreen()),
              ),
            ),
            _buildDivider(),
            ListTile(
              leading: const Icon(Icons.science_outlined, color: AppColors.primary),
              title: Text(isAr ? 'اختبار موثوقية الأذان' : 'Adhan Reliability Test'),
              subtitle: Text(isAr ? 'اختبر الأذان بسيناريوهات حقيقية' : 'Test adhan with real-world scenarios'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdhanReliabilityTestScreen()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Compact volume slider for reminder sounds ───────────────────────────

  Widget _buildReminderVolumeSlider({
    required double value,
    required ValueChanged<double> onChanged,
    ValueChanged<double>? onChangeEnd,
    required bool isAr,
    required Color color,
    required String labelAr,
    required String labelEn,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          Icon(Icons.volume_down_rounded, color: color, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAr ? labelAr : labelEn,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: color,
                    thumbColor: color,
                    overlayColor: color.withOpacity(0.18),
                    inactiveTrackColor: color.withOpacity(0.2),
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  ),
                  child: Slider(
                    value: value,
                    min: 0.0,
                    max: 1.0,
                    divisions: 10,
                    label: '${(value * 100).round()}%',
                    onChanged: onChanged,
                    onChangeEnd: onChangeEnd,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.volume_up_rounded, color: color, size: 20),
        ],
      ),
    );
  }

  // ─── Tab 2: التذكيرات ─────────────────────────────────────────────────────

  Widget _buildRemindersTab(bool isAr) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        _buildSection(
          icon: Icons.alarm_rounded,
          titleAr: 'التذكيرات',
          titleEn: 'Reminders',
          isAr: isAr,
          children: [
            _buildSwitchRow(
              icon: Icons.timer_rounded,
              iconColor: _reminderEnabled ? Colors.orange : Colors.grey,
              titleAr: 'تذكير قبل موعد الصلاة',
              titleEn: 'Pre-Prayer Reminder',
              subtitleAr: 'تنبيه قبل وقت الصلاة بعدة دقائق',
              subtitleEn: 'Notify you a few minutes before prayer time',
              value: _reminderEnabled,
              onChanged: _notificationsEnabled
                  ? (v) {
                      setState(() => _reminderEnabled = v);
                      if (v) _previewRawSound('prayer_reminder_fajr', cutoffSeconds: 5, volume: _approachingVolume);
                      _autoSave();
                    }
                  : null,
              isAr: isAr,
            ),
            if (_reminderEnabled) ...[
              _buildDivider(),
              _buildMinutesPicker(
                icon: Icons.timer_outlined,
                labelAr: 'وقت التذكير قبل الصلاة',
                labelEn: 'Reminder before prayer',
                value: _reminderMinutes,
                options: const [5, 10, 15, 20, 30],
                isAr: isAr,
                onChanged: (v) {
                  setState(() => _reminderMinutes = v);
                  _autoSave();
                },
              ),
              _buildDivider(),
              _buildReminderVolumeSlider(
                value: _approachingVolume,
                onChanged: (v) {
                  setState(() => _approachingVolume = v);
                },
                onChangeEnd: (_) async {
                  await _saveReminderVolumesOnly();
                },
                isAr: isAr,
                color: Colors.orange,
                labelAr: 'صوت تذكير اقتراب الصلاة',
                labelEn: 'Pre-prayer reminder volume',
              ),
            ],
            _buildDivider(),
            _buildSwitchRow(
              icon: Icons.access_alarm_rounded,
              iconColor: _iqamaEnabled ? Colors.teal : Colors.grey,
              titleAr: 'تنبيه وقت الإقامة',
              titleEn: 'Iqama Notification',
              subtitleAr: 'تنبيه عند موعد إقامة الصلاة',
              subtitleEn: 'Alert when it\'s time to start the prayer',
              value: _iqamaEnabled,
              onChanged: _notificationsEnabled
                  ? (v) {
                      setState(() => _iqamaEnabled = v);
                      if (v) _previewRawSound('iqama_sound_new', cutoffSeconds: 9, volume: _iqamaVolume);
                      _autoSave();
                    }
                  : null,
              isAr: isAr,
            ),
            if (_iqamaEnabled) ...[
              _buildDivider(),
              _buildPerPrayerIqamaGrid(isAr),
              _buildDivider(),
              _buildReminderVolumeSlider(
                value: _iqamaVolume,
                onChanged: (v) {
                  setState(() => _iqamaVolume = v);
                },
                onChangeEnd: (_) async {
                  await _saveReminderVolumesOnly();
                },
                isAr: isAr,
                color: Colors.teal,
                labelAr: 'صوت تنبيه الإقامة',
                labelEn: 'Iqama notification volume',
              ),
            ],
            _buildDivider(),
            _buildSwitchRow(
              icon: Icons.favorite_rounded,
              iconColor: _salawatEnabled ? Colors.pink : Colors.grey,
              titleAr: 'الصلاة على النبي ﷺ',
              titleEn: 'Salawat / Durood Reminder',
              subtitleAr: 'اللهم صلِّ وسلم وبارك على نبينا محمد ﷺ',
              subtitleEn: 'Reminder to send blessings on the Prophet ﷺ',
              value: _salawatEnabled,
              onChanged: (v) {
                setState(() => _salawatEnabled = v);
                if (v) _previewRawSound(_salawatSoundId, cutoffSeconds: 8, volume: _salawatVolume);
                _autoSave();
              },
              isAr: isAr,
            ),
            if (_salawatEnabled) ...[
              _buildDivider(),
              _buildMinutesPicker(
                icon: Icons.schedule_rounded,
                labelAr: 'كل كم دقيقة؟',
                labelEn: 'Every (minutes)',
                value: _salawatMinutes,
                options: const [5, 15, 30, 60, 120],
                isAr: isAr,
                onChanged: (v) {
                  setState(() => _salawatMinutes = v);
                  _autoSave();
                },
              ),
                _buildDivider(),
              _buildSwitchRow(
                icon: Icons.bedtime_rounded,
                iconColor: _salawatSleepEnabled ? const Color(0xFF5C6BC0) : Colors.grey,
                titleAr: 'ساعات الهدوء (وقت النوم)',
                titleEn: 'Quiet Hours (Sleep Time)',
                subtitleAr: 'إيقاف التذكير أثناء فترة النوم',
                subtitleEn: 'Pause reminders during your sleep window',
                value: _salawatSleepEnabled,
                onChanged: (v) { setState(() => _salawatSleepEnabled = v); _autoSave(); },
                isAr: isAr,
              ),
              if (_salawatSleepEnabled) ...[                _buildDivider(),
                _buildSalawatSleepTimePicker(isAr),
              ],
              _buildDivider(),
              _buildSalawatSoundPicker(isAr),
              _buildDivider(),
              _buildReminderVolumeSlider(
                value: _salawatVolume,
                onChanged: (v) {
                  setState(() => _salawatVolume = v);
                },
                onChangeEnd: (_) async {
                  await _saveReminderVolumesOnly();
                },
                isAr: isAr,
                color: Colors.pink,
                labelAr: 'صوت الصلاة على النبي ﷺ',
                labelEn: 'Salawat reminder volume',
              ),
            
            ],
          ],
        ),
        const SizedBox(height: 16),
        // الصمت أثناء الصلاة
        _buildSilentDuringPrayerSection(isAr),
      ],
    );
  }

  // ─── Silent during prayer section ────────────────────────────────────────

  Widget _buildSilentDuringPrayerSection(bool isAr) {
    const Color accentColor = Color(0xFF5E35B1); // deep purple

    return _buildSection(
      icon: Icons.volume_off_rounded,
      titleAr: 'الصمت أثناء الصلاة',
      titleEn: 'Silent During Prayer',
      isAr: isAr,
      children: [
        _buildSwitchRow(
          icon: Icons.volume_off_rounded,
          iconColor: _silentDuringPrayer ? accentColor : Colors.grey,
          titleAr: 'تصميت الهاتف وقت الصلاة',
          titleEn: 'Silence phone during prayer',
          subtitleAr: 'يُصمَّت الهاتف تلقائياً فور الأذان ثم يُعاد إلى وضعه الأصلي',
          subtitleEn: 'Phone silences automatically at prayer time and restores after',
          value: _silentDuringPrayer,
          onChanged: _notificationsEnabled
              ? (v) async {
                  if (v && !_dndPermissionGranted) {
                    // DND permission is required only for this optional feature.
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(isAr ? 'صلاحية عدم الإزعاج لهذه الميزة' : 'DND Access for This Feature'),
                        content: Text(isAr
                            ? 'ميزة تصميت الهاتف أثناء الصلاة اختيارية.\n'
                              'إذا رغبت في تفعيلها، امنح صلاحية "عدم الإزعاج" من الإعدادات.'
                            : 'Silent-during-prayer is optional.\n'
                              'If you want to use it, grant Do Not Disturb access in settings.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(isAr ? 'لاحقاً' : 'Later'),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(foregroundColor: accentColor),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(isAr ? 'فتح الإعدادات' : 'Open Settings'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true && mounted) {
                      await _adhanChannel.invokeMethod('requestDndPermission');
                    }
                    return; // Don't enable yet — user must come back after granting.
                  }
                  setState(() => _silentDuringPrayer = v);
                  _autoSave();
                }
              : null,
          isAr: isAr,
        ),
        // DND permission warning when needed.
        if (_silentDuringPrayer && !_dndPermissionGranted) ...[
          _buildDivider(),
          _DndPermissionBanner(
            isAr: isAr,
            onTap: () async {
              await _adhanChannel.invokeMethod('requestDndPermission');
            },
          ),
        ],
        if (_silentDuringPrayer && _dndPermissionGranted) ...[
          _buildDivider(),
          // Delay slider
          _buildMinutesPicker(
            icon: Icons.timer_outlined,
            labelAr: 'التأخير بعد الأذان',
            labelEn: 'Delay after adhan',
            value: _silentDelayMinutes,
            options: const [0, 2, 5, 10, 15],
            isAr: isAr,
            customLabel: (v) => v == 0
                ? (isAr ? 'فور الأذان' : 'At adhan time')
                : (isAr ? 'بعد $v دقيقة' : '$v min after'),
            onChanged: (v) {
              setState(() => _silentDelayMinutes = v);
              _autoSave();
            },
          ),
          _buildDivider(),
          // Duration slider
          _buildMinutesPicker(
            icon: Icons.hourglass_bottom_rounded,
            labelAr: 'مدة الصمت',
            labelEn: 'Silence duration',
            value: _silentDurationMinutes,
            options: const [5, 10, 15, 20, 30, 45, 60],
            isAr: isAr,
            customLabel: (v) => isAr ? '$v دقيقة' : '$v min',
            onChanged: (v) {
              setState(() => _silentDurationMinutes = v);
              _autoSave();
            },
          ),
          _buildDivider(),
          // Summary chip
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accentColor.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 17, color: accentColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _silentDelayMinutes == 0
                          ? (isAr
                              ? 'الهاتف سيُصمَّت فور الأذان لمدة $_silentDurationMinutes دقيقة'
                              : 'Phone will be silenced at adhan time for $_silentDurationMinutes min')
                          : (isAr
                              ? 'الهاتف سيُصمَّت بعد $_silentDelayMinutes دقيقة من الأذان لمدة $_silentDurationMinutes دقيقة'
                              : 'Phone will be silenced $_silentDelayMinutes min after adhan for $_silentDurationMinutes min'),
                      style: TextStyle(
                        fontSize: 12,
                        color: accentColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ─── Tab 3: المواقيت ──────────────────────────────────────────────────────

  Widget _buildPrayerTimesTab(bool isAr) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        _buildSection(
          icon: Icons.calculate_rounded,
          titleAr: 'طريقة حساب المواقيت',
          titleEn: 'Prayer Calculation Method',
          isAr: isAr,
          children: [_buildMethodCard(isAr)],
        ),
        const SizedBox(height: 16),
        _buildSection(
          icon: Icons.calendar_month_rounded,
          titleAr: 'جدول الأذان',
          titleEn: 'Adhan Schedule',
          isAr: isAr,
          children: [_buildScheduleCard(isAr)],
        ),
        const SizedBox(height: 16),
        _buildSection(
          icon: Icons.science_rounded,
          titleAr: 'اختبار الأذان',
          titleEn: 'Test Adhan',
          isAr: isAr,
          children: [_buildTestCard(isAr)],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // AppBar
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildAppBar(bool isAr, bool innerBoxIsScrolled) {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      forceElevated: innerBoxIsScrolled,
      // Full gradient fills the toolbar + tabbar area
      backgroundColor: const Color(0xFF064428),
      automaticallyImplyLeading: false,
      toolbarHeight: 60,
      // ── flexibleSpace: gradient background covering toolbar + tabbar ─
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF064428),
              Color(0xFF0D5E3A),
              Color(0xFF1B7A4A),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
      ),
      // ── Toolbar content ───────────────────────────────────────────────
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isAr ? 'الأذان والصلاة' : 'Adhan & Prayer',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.2,
              letterSpacing: 0,
            ),
          ),
          Text(
            isAr ? 'خصّص الأذان والتذكيرات' : 'Customize adhan & reminders',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 11,
              height: 1.3,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
      leading: IconButton(
        icon: Icon(
          isAr ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_rounded,
          color: Colors.white,
          size: 19,
        ),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      actions: [
        if (_isSaving)
          const Padding(
            padding: EdgeInsets.all(16),
            child: SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Tooltip(
              message: isAr ? 'الحفظ تلقائي' : 'Auto-saved',
              child: const Icon(Icons.cloud_done_rounded, color: Colors.white60, size: 21),
            ),
          ),
      ],
      // ── Tab bar with pill indicator ───────────────────────────────────
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          // Match exact AppBar gradient so TabBar blends seamlessly
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF064428),
                Color(0xFF0D5E3A),
                Color(0xFF1B7A4A),
              ],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
          child: TabBar(
            controller: _tabController,
            dividerColor: Colors.transparent,
            indicator: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1.0,
              ),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            splashBorderRadius: BorderRadius.circular(30),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 13),
            tabs: [
              Tab(text: isAr ? '🕌  الأذان' : '🕌  Adhan'),
              Tab(text: isAr ? '🔔  التذكيرات' : '🔔  Reminders'),
              Tab(text: isAr ? '🕐  المواقيت' : '🕐  Times'),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Section builder
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildSection({
    required IconData icon,
    required String titleAr,
    required String titleEn,
    required bool isAr,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.gradientStart, AppColors.gradientEnd]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 16),
              ),
              SizedBox(width: 10),
              Text(
                isAr ? titleAr : titleEn,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: 0.3),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: _cardSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _cardBorder),
            boxShadow: [
              BoxShadow(color: AppColors.primary.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() => Divider(
        height: 1, thickness: 1, color: _cardBorder, indent: 16, endIndent: 16);

  // ─── Switch row ──────────────────────────────────────────────────────────

  Widget _buildSwitchRow({
    required IconData icon,
    required Color iconColor,
    required String titleAr,
    required String titleEn,
    required String subtitleAr,
    required String subtitleEn,
    required bool value,
    required ValueChanged<bool>? onChanged,
    required bool isAr,
    String? badge,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        isAr ? titleAr : titleEn,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600,
                          color: onChanged == null ? _textSecondary : _textPrimary,
                        ),
                      ),
                    ),
                    if (badge != null) ...[
                      SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [AppColors.secondary, Color(0xFFF4D03F)]),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(badge, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(isAr ? subtitleAr : subtitleEn,
                    style: TextStyle(fontSize: 12, color: _textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(value: value, activeColor: AppColors.primary, onChanged: onChanged),
        ],
      ),
    );
  }

  // ─── Minutes picker ──────────────────────────────────────────────────────

  Widget _buildMinutesPicker({
    required IconData icon,
    required String labelAr,
    required String labelEn,
    required int value,
    required List<int> options,
    required bool isAr,
    required ValueChanged<int> onChanged,
    String Function(int)? customLabel,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: _textSecondary),
            SizedBox(width: 8),
            Text(isAr ? labelAr : labelEn,
                style: TextStyle(fontSize: 13, color: _textSecondary, fontWeight: FontWeight.w500)),
          ]),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: options.map((opt) {
              final selected = opt == value;
              final label = customLabel != null
                  ? customLabel(opt)
                  : (isAr ? '$opt د' : '${opt}m');
              return GestureDetector(
                onTap: () => onChanged(opt),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : AppColors.primary.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: selected ? AppColors.primary : _cardBorder),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : AppColors.primary),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── Volume card ─────────────────────────────────────────────────────────

  Widget _buildVolumeCard(bool isAr) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(
        children: [
          Row(children: [
            Icon(
              _adhanVolume == 0 ? Icons.volume_off_rounded : _adhanVolume < 0.5 ? Icons.volume_down_rounded : Icons.volume_up_rounded,
              color: _notificationsEnabled ? AppColors.primary : Colors.grey, size: 22,
            ),
            SizedBox(width: 14),
            Expanded(child: Text(isAr ? 'مستوى صوت الأذان' : 'Adhan Volume',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                gradient: _notificationsEnabled
                    ? const LinearGradient(colors: [AppColors.gradientStart, AppColors.gradientEnd])
                    : null,
                color: _notificationsEnabled ? null : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('${(_adhanVolume * 100).round()}%',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                      color: _notificationsEnabled ? Colors.white : _textSecondary)),
            ),
          ]),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.primary.withValues(alpha: 0.15),
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withValues(alpha: 0.1),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              trackHeight: 5,
            ),
            child: Slider(
              value: _adhanVolume, min: 0.0, max: 1.0, divisions: 10,
              onChanged: _notificationsEnabled ? (v) => setState(() => _adhanVolume = v) : null,
              onChangeEnd: _notificationsEnabled
                  ? (_) => _autoSave(delay: const Duration(milliseconds: 800)) : null,
            ),
          ),
          if (_systemAlarmCurrent >= 0) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
              ),
              child: Row(children: [
                Icon(Icons.phone_android_rounded, size: 16, color: _textSecondary),
                SizedBox(width: 8),
                Expanded(child: Text.rich(TextSpan(
                  style: TextStyle(fontSize: 12, color: _textSecondary),
                  children: [
                    TextSpan(
                      text: isAr
                          ? (_adhanAudioStream == 'alarm' ? 'صوت المنبهات في الجهاز: ' : 'صوت الرنين في الجهاز: ')
                          : (_adhanAudioStream == 'alarm' ? 'System alarm volume: ' : 'System ring volume: '),
                    ),
                    TextSpan(text: '$_systemAlarmCurrent / $_systemAlarmMax',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ],
                ))),
                GestureDetector(
                  onTap: _openSoundSettings,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.gradientStart, AppColors.gradientEnd]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(isAr ? 'تعديل' : 'Adjust',
                        style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Audio stream picker row ───────────────────────────────────────────────────────

  Widget _buildStreamPickerRow(bool isAr) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.tune_rounded, color: Colors.deepPurple, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              isAr ? 'نوع تدفّق الصوت' : 'Audio Stream Type',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _textPrimary),
            ),
            SizedBox(height: 3),
            Text(
              isAr ? 'رنين: يكتم في الصامت • منبه: يتجاوز وضع الصامت' : 'Ring: muted in silent • Alarm: bypasses silent mode',
              style: TextStyle(fontSize: 12, color: _textSecondary),
            ),
          ])),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _buildStreamChip(
            isAr: isAr, icon: Icons.ring_volume_rounded,
            labelAr: 'رنين 🔔', labelEn: 'Ring 🔔',
            selected: _adhanAudioStream == 'ringtone',
            onTap: () async {
              if (_adhanAudioStream == 'ringtone') return;
              setState(() => _adhanAudioStream = 'ringtone');
              await _settings.setAdhanAudioStream('ringtone');
              _fetchAlarmVolume(); _autoSave();
            },
          )),
          const SizedBox(width: 10),
          Expanded(child: _buildStreamChip(
            isAr: isAr, icon: Icons.alarm_rounded,
            labelAr: 'منبه ⏰', labelEn: 'Alarm ⏰',
            selected: _adhanAudioStream == 'alarm',
            onTap: () async {
              if (_adhanAudioStream == 'alarm') return;
              setState(() => _adhanAudioStream = 'alarm');
              await _settings.setAdhanAudioStream('alarm');
              _fetchAlarmVolume(); _autoSave();
            },
          )),
        ]),
        // ── Warning banner when user picks ringtone ─────────────────────
        if (_adhanAudioStream == 'ringtone') ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.shade300, width: 1),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(
                isAr
                    ? 'تحذير: وضع الرنين يكتم الأذان لو التليفون على الصامت أو DND. يُنصح باستخدام «منبه» لضمان سماع الأذان دائماً.'
                    : 'Warning: Ring mode will silence the adhan if your phone is on Silent or DND. Use «Alarm» to always hear the adhan.',
                style: TextStyle(fontSize: 12, color: Colors.orange.shade800, height: 1.4),
              )),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _buildStreamChip({
    required bool isAr, required IconData icon,
    required String labelAr, required String labelEn,
    required bool selected, required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : _cardBorder,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 18, color: selected ? Colors.white : AppColors.primary),
          const SizedBox(width: 7),
          Text(
            isAr ? labelAr : labelEn,
            style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.primary,
            ),
          ),
        ]),
      ),
    );
  }

  // ─── Short Adhan explanation ──────────────────────────────────────────────

  Widget _buildShortModeExplanation(bool isAr) {
    final sound = AdhanSounds.findById(_selectedSoundId);
    final seconds = sound.shortDurationSeconds;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.info_outline_rounded, color: AppColors.secondary, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isAr ? 'كيف يعمل الأذان المختصر؟' : 'How does Short Adhan work?',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          // Step-by-step explanation
          _ShortModeStep(
            number: '١',
            isAr: isAr,
            ar: 'يبدأ الأذان بـ "الله أكبر" أربع مرات',
            en: 'Adhan starts with 4 Takbeers: "Allahu Akbar"',
          ),
          _ShortModeStep(
            number: '٢',
            isAr: isAr,
            ar: 'التطبيق يوقف الصوت بعد التكبيرتين الأوليين (~$seconds ثانية)',
            en: 'App stops after the first 2 Takbeers (~$seconds seconds)',
          ),
          _ShortModeStep(
            number: '٣',
            isAr: isAr,
            ar: 'نتيجة: تنبيه خفيف وسريع بدل الأذان الكامل (~3 دقائق)',
            en: 'Result: a brief alert instead of the full adhan (~3 minutes)',
          ),
          const SizedBox(height: 10),
          // Pronunciation illustration
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
            ),
            child: Row(children: [
              const Icon(Icons.graphic_eq_rounded, size: 18, color: AppColors.secondary),
              const SizedBox(width: 10),
              Expanded(child: Text(
                isAr
                    ? '🔊  الله أكبر ×٢  →  ⏹  (يقف)'
                    : '🔊  Allahu Akbar ×2  →  ⏹  (stops)',
                style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: AppColors.primary, letterSpacing: 0.5,
                ),
              )),
            ]),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              const Icon(Icons.play_circle_outline_rounded, size: 14, color: AppColors.secondary),
              const SizedBox(width: 6),
              Expanded(child: Text(
                isAr
                    ? 'عند الضغط على استماع في القائمة أدناه سيشتغل الأذان بنفس الطريقة المختصرة'
                    : 'Preview buttons below will also use short mode',
                style: TextStyle(fontSize: 11, color: _textSecondary, height: 1.4),
              )),
            ]),
          ),
        ],
      ),
    );
  }

  // ─── Preview helper: play any raw-resource sound file ───────────────────
  /// Preview a raw resource (res/raw) sound file by name — stops after [cutoffSeconds].
  /// Also auto-stops when the native player signals completion via [_handleNativeCallback].
  Future<void> _previewRawSound(String rawName, {int cutoffSeconds = 8, double? volume}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (_isPreviewPlaying) {
      await _stopPreview();
      if (_previewingId == 'raw_$rawName') return;
    }
    setState(() {
      _isPreviewPlaying = true;
      _previewingId = 'raw_$rawName';
    });
    try {
      await _adhanChannel.invokeMethod('playAdhan', {
        'soundName': rawName,
        'volume': volume ?? _adhanVolume,
      });
      _shortModeTimer?.cancel();
      _shortModeTimer = Timer(Duration(seconds: cutoffSeconds), _stopPreview);
    } catch (e) {
      debugPrint('Raw preview error: $e');
      if (mounted) setState(() { _isPreviewPlaying = false; _previewingId = null; });
    }
  }

  // ─── Per-prayer adhan toggles ─────────────────────────────────────────────
  Widget _buildPerPrayerToggles(bool isAr) {
    final prayers = [
      (nameAr: 'الفجر',  nameEn: 'Fajr',    icon: Icons.wb_twilight_rounded,   color: const Color(0xFF5C8BE8)),
      (nameAr: 'الظهر',  nameEn: 'Dhuhr',   icon: Icons.wb_sunny_rounded,      color: const Color(0xFFE8A534)),
      (nameAr: 'العصر',  nameEn: 'Asr',     icon: Icons.wb_cloudy_rounded,     color: const Color(0xFF4CAF50)),
      (nameAr: 'المغرب', nameEn: 'Maghrib', icon: Icons.nights_stay_rounded,   color: const Color(0xFFFF7043)),
      (nameAr: 'العشاء', nameEn: 'Isha',    icon: Icons.nightlight_round,      color: const Color(0xFF7B61FF)),
    ];
    final enabled = [_includeFajr, _enableDhuhr, _enableAsr, _enableMaghrib, _enableIsha];
    final setters = [
      (bool v) { setState(() => _includeFajr   = v); },
      (bool v) { setState(() => _enableDhuhr   = v); },
      (bool v) { setState(() => _enableAsr     = v); },
      (bool v) { setState(() => _enableMaghrib = v); },
      (bool v) { setState(() => _enableIsha    = v); },
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
            child: Text(
              isAr
                  ? 'اختر الصلوات التي تريد أذاناً لكل منها:'
                  : 'Select prayers you want adhan notifications for:',
              style: TextStyle(fontSize: 13, color: _textSecondary, height: 1.4),
            ),
          ),
          Row(
            children: List.generate(prayers.length, (i) {
              final on = enabled[i];
              final p = prayers[i];
              return Expanded(
                child: GestureDetector(
                  onTap: _notificationsEnabled
                      ? () {
                          setters[i](!on);
                          _autoSave();
                        }
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    margin: EdgeInsetsDirectional.only(
                      end: i < prayers.length - 1 ? 8 : 0,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: on
                          ? p.color.withValues(alpha: 0.13)
                          : Colors.grey.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: on
                            ? p.color.withValues(alpha: 0.7)
                            : Colors.grey.withValues(alpha: 0.25),
                        width: on ? 1.8 : 1.0,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: on
                                ? p.color.withValues(alpha: 0.18)
                                : Colors.grey.withValues(alpha: 0.10),
                          ),
                          child: Icon(
                            p.icon,
                            size: 18,
                            color: on ? p.color : Colors.grey.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isAr ? p.nameAr : p.nameEn,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: on ? FontWeight.w700 : FontWeight.w400,
                            color: on ? p.color : Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Icon(
                          on ? Icons.check_circle_rounded : Icons.circle_outlined,
                          size: 13,
                          color: on ? p.color : Colors.grey.withValues(alpha: 0.4),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ─── Per-prayer iqama minutes grid ────────────────────────────────────────
  Widget _buildPerPrayerIqamaGrid(bool isAr) {
    final rows = [
      (nameAr: 'فجر',   nameEn: 'Fajr',    icon: Icons.wb_twilight_rounded, color: const Color(0xFF5C8BE8),
       get: () => _iqamaMinutesFajr,    set: (int v) { setState(() => _iqamaMinutesFajr = v); }),
      (nameAr: 'ظهر',   nameEn: 'Dhuhr',   icon: Icons.wb_sunny_rounded,    color: const Color(0xFFE8A534),
       get: () => _iqamaMinutesDhuhr,   set: (int v) { setState(() => _iqamaMinutesDhuhr = v); }),
      (nameAr: 'عصر',   nameEn: 'Asr',     icon: Icons.wb_cloudy_rounded,   color: const Color(0xFF4CAF50),
       get: () => _iqamaMinutesAsr,     set: (int v) { setState(() => _iqamaMinutesAsr = v); }),
      (nameAr: 'مغرب',  nameEn: 'Maghrib', icon: Icons.nights_stay_rounded, color: const Color(0xFFFF7043),
       get: () => _iqamaMinutesMaghrib, set: (int v) { setState(() => _iqamaMinutesMaghrib = v); }),
      (nameAr: 'عشاء',  nameEn: 'Isha',    icon: Icons.nightlight_round,    color: const Color(0xFF7B61FF),
       get: () => _iqamaMinutesIsha,    set: (int v) { setState(() => _iqamaMinutesIsha = v); }),
    ];
    const options = [5, 10, 15, 20, 25, 30];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10, left: 4),
            child: Text(
              isAr
                  ? 'الإقامة بعد الأذان بـ (دقيقة) — لكل صلاة:'
                  : 'Iqama after adhan (minutes) — per prayer:',
              style: TextStyle(fontSize: 13, color: _textSecondary),
            ),
          ),
          ...rows.map((r) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(r.icon, size: 16, color: r.color),
                const SizedBox(width: 6),
                SizedBox(
                  width: 44,
                  child: Text(
                    isAr ? r.nameAr : r.nameEn,
                    style: TextStyle(fontSize: 13, color: r.color, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    children: options.map((opt) {
                      final selected = r.get() == opt;
                      return GestureDetector(
                        onTap: () {
                          r.set(opt);
                          _autoSave();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 36,
                          height: 32,
                          decoration: BoxDecoration(
                            color: selected ? r.color.withValues(alpha: 0.2) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selected ? r.color : Colors.grey.withValues(alpha: 0.3),
                              width: selected ? 1.5 : 1.0,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$opt',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                              color: selected ? r.color : _textSecondary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  // ─── Salawat sound picker ─────────────────────────────────────────────────
  Widget _buildSalawatSoundPicker(bool isAr) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10, left: 4),
            child: Text(
              isAr ? 'اختر صوت التذكير:' : 'Choose reminder sound:',
              style: TextStyle(fontSize: 13, color: _textSecondary),
            ),
          ),
          ...SalawatSounds.all.map((s) {
            final selected = _salawatSoundId == s.id;
            final isPlaying = _isPreviewPlaying && _previewingId == 'raw_${s.id}';
            return GestureDetector(
              onTap: () {
                setState(() => _salawatSoundId = s.id);
                _autoSave();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.pink.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? Colors.pink.withValues(alpha: 0.6)
                        : Colors.grey.withValues(alpha: 0.25),
                    width: selected ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      selected ? Icons.radio_button_on_rounded : Icons.radio_button_off_rounded,
                      color: selected ? Colors.pink : Colors.grey,
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: isAr
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          Text(
                            isAr ? s.nameAr : s.nameEn,
                            textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                              color: selected ? Colors.pink : _textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        isPlaying ? Icons.stop_circle_rounded : Icons.play_circle_outline_rounded,
                        color: Colors.pink,
                        size: 26,
                      ),
                      onPressed: () => _previewRawSound(s.id, cutoffSeconds: 10, volume: _salawatVolume),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── Sound section (unified, streaming, no tabs) ─────────────────────────

  Widget _buildSoundSection(bool isAr) {
    final allSounds = [...AdhanSounds.local, ...AdhanSounds.online];
    final selected = AdhanSounds.findById(_selectedSoundId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.gradientStart, AppColors.gradientEnd]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.music_note_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(
              isAr ? 'صوت الأذان والمؤذن' : 'Adhan Sound & Muezzin',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary),
            )),
          ]),
        ),

        // Selected sound card (gold-bordered hero)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              AppColors.secondary.withValues(alpha: 0.12),
              AppColors.primary.withValues(alpha: 0.06),
            ]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.secondary.withValues(alpha: 0.45), width: 1.5),
            boxShadow: [BoxShadow(color: AppColors.secondary.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.gradientStart, AppColors.gradientEnd]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.mosque_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isAr ? selected.nameAr : selected.nameEn,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
              const SizedBox(height: 2),
              Text(
                '${isAr ? "المؤذن: " : "Muezzin: "}${selected.muezzinDisplay(isAr)}',
                style: TextStyle(fontSize: 11, color: _textSecondary),
              ),
              Text(
                '${isAr ? "المسجد: " : "Mosque: "}${selected.mosqueDisplay(isAr)}',
                style: TextStyle(fontSize: 11, color: _textSecondary),
              ),
            ])),
            Icon(Icons.check_circle_rounded, color: AppColors.secondary, size: 22),
          ]),
        ),

        // Offline note
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
          ),
          child: Row(children: [
            Icon(Icons.wifi_off_rounded, size: 14, color: _textSecondary),
            SizedBox(width: 8),
            Expanded(child: Text(
              isAr
                  ? 'الأصوات الأونلاين تُحمَّل تلقائياً على جهازك عند اختيارها، وتعمل بدون إنترنت وقت الأذان. عند فشل التحميل يُستخدم أذان مكة المكرمة احتياطياً.'
                  : 'Online sounds are downloaded automatically when selected and work offline at prayer time. If download fails, Makkah adhan is used as fallback.',
              style: TextStyle(fontSize: 11, color: _textSecondary, height: 1.4),
            )),
          ]),
        ),

        // Unified sound list
        Container(
          decoration: BoxDecoration(
            color: _cardSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _cardBorder),
            boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: allSounds.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: _cardBorder, indent: 16, endIndent: 16),
              itemBuilder: (_, i) {
                final s = allSounds[i];
                final cs = s.isOnline ? (_cacheState[s.id] ?? _CacheState.none) : _CacheState.cached;
                final cp = s.isOnline ? (_cacheProgress[s.id] ?? 0.0) : 1.0;
                return _SoundTile(
                  sound: s,
                  isSelected: _selectedSoundId == s.id,
                  isPlaying: _previewingId == s.id && _isPreviewPlaying,
                  cacheState: cs,
                  cacheProgress: cp,
                  isAr: isAr,
                  onSelect: () => _selectSound(s),
                  onPreview: () => _previewSound(s),
                  onStop: _stopPreview,
                  onDelete: s.isOnline ? () => _showDeleteConfirm(s, isAr) : null,
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // ─── Prayer method card ──────────────────────────────────────────────────

  Widget _buildMethodCard(bool isAr) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          activeColor: AppColors.primary,
          value: _methodAutoDetected,
          title: Text(
            isAr ? 'تحديد الطريقة تلقائياً حسب الموقع' : 'Auto-detect method from location',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            isAr ? 'يعتمد على الدولة المكتشفة من GPS' : 'Based on GPS-detected country',
            style: TextStyle(fontSize: 12, color: _textSecondary),
          ),
          onChanged: (v) { setState(() => _methodAutoDetected = v); _autoSave(); },
        ),
        Divider(height: 1, color: _cardBorder),
        SizedBox(height: 8),
        Text(isAr ? 'أو اختر يدوياً:' : 'Or select manually:',
            style: TextStyle(fontSize: 12, color: _textSecondary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        ...PrayerCalculationConstants.calculationMethods.entries.map((entry) {
          final id = entry.key;
          final info = entry.value;
          final isEgyptian = id == 'egyptian';
          final isSelected = _selectedMethodId == id;
          return Container(
            margin: const EdgeInsets.only(bottom: 4),
            decoration: isSelected
                ? BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  )
                : null,
            child: RadioListTile<String>(
              value: id, groupValue: _selectedMethodId,
              activeColor: AppColors.primary,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              dense: true,
              title: Row(children: [
                Flexible(child: Text(isAr ? info.nameAr : info.nameEn,
                    style: TextStyle(fontSize: 13,
                        fontWeight: isEgyptian || isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? AppColors.primary : _textPrimary))),
                if (isEgyptian) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text(isAr ? 'الافتراضي' : 'Default',
                        style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ),
                ],
              ]),
              onChanged: _methodAutoDetected ? null : (v) {
                if (v != null) { setState(() => _selectedMethodId = v); _autoSave(); }
              },
            ),
          );
        }),
      ]),
    );
  }

  // ─── Schedule card ───────────────────────────────────────────────────────

  Widget _buildScheduleCard(bool isAr) {
    final days = _adhanService.computeDaysAhead();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.gradientStart, AppColors.gradientEnd]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.event_available_rounded, size: 14, color: Colors.white),
              const SizedBox(width: 5),
              Text(isAr ? 'مُجدوَل: $days يوماً قادمة' : '$days days scheduled ahead',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Text(
          isAr ? 'يُجدَّل الأذان تلقائياً لـ $days يوماً حسب التذكيرات المُفعَّلة.\nيعمل حتى عند إغلاق التطبيق.'
              : 'Adhan auto-schedules $days days based on your active reminders.\nWorks even when the app is closed.',
          style: TextStyle(fontSize: 12, color: _textSecondary, height: 1.6),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              final raw = _settings.getAdhanSchedulePreview();
              if (!context.mounted) return;
              await _showScheduleDialog(isAr: isAr, raw: raw, days: days, notificationsEnabled: _notificationsEnabled);
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.calendar_view_week_rounded, size: 18),
            label: Text(isAr ? 'عرض الجدول الحالي' : 'View Current Schedule',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ),
        ),
      ]),
    );
  }

  // ─── Test card ───────────────────────────────────────────────────────────

  Widget _buildTestCard(bool isAr) {
    final selectedSound = AdhanSounds.findById(_selectedSoundId);
    final needsDownload = selectedSound.isOnline &&
        (_cacheState[_selectedSoundId] ?? _CacheState.none) != _CacheState.cached;
    final isDownloading = _cacheState[_selectedSoundId] == _CacheState.caching;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          isAr
              ? 'تحقق من عمل الأذان. "بعد دقيقة" يختبر التشغيل في الخلفية — جرّب إغلاق التطبيق.'
              : 'Verify Adhan works. "In 1 min" tests background playback — try closing the app.',
          style: TextStyle(fontSize: 12, color: _textSecondary, height: 1.5),
        ),
        // Warning banner when online sound isn't cached yet
        if (needsDownload) ...[               const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              if (isDownloading)
                const SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange))
              else
                const Icon(Icons.download_rounded, size: 16, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(child: Text(
                isAr
                    ? (isDownloading
                        ? 'يُحمَّل الصوت... سيتم التشغيل تلقائيًا عند الاكتمال'
                        : 'الصوت الأونلاين لم يُحمَّل بعد. اضغط استماع في قائمة الأصوات لتحميله، تم تشغيل أذان مكة احتياطيًا')
                    : (isDownloading
                        ? 'Downloading sound... will switch automatically when ready'
                        : 'Online sound not cached. Press ▶ in the sound list to download. Makkah adhan used as fallback.'),
                style: const TextStyle(fontSize: 11, color: Colors.orange, height: 1.4),
              )),
            ]),
          ),
        ],
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _GradientButton(
            loading: _isTesting,
            icon: Icons.volume_up_rounded,
            label: isAr ? 'اختبار الآن' : 'Test Now',
            onPressed: () async {
              final sel = AdhanSounds.findById(_selectedSoundId);
              if (sel.isOnline) {
                // Online sounds: stream via Dart AudioPlayer (from cache or URL)
                // This works correctly even when the file isn't downloaded yet
                await _previewSound(sel);
                _showSnack(isAr ? 'يعمل الأذان الآن 🔊' : 'Adhan playing now 🔊', AppColors.success);
              } else {
                // Offline sounds: use native service (shows foreground notification too)
                setState(() => _isTesting = true);
                try {
                  await _adhanService.testNow();
                  _showSnack(isAr ? 'يعمل الأذان الآن 🔊' : 'Adhan playing now 🔊', AppColors.success);
                } finally {
                  if (mounted) setState(() => _isTesting = false);
                }
              }
            },
          )),
          const SizedBox(width: 10),
          Expanded(child: _OutlineButton(
            loading: _schedulingTest,
            icon: Icons.access_alarm_rounded,
            label: isAr ? 'بعد دقيقة' : 'In 1 Minute',
            onPressed: () async {
              setState(() => _schedulingTest = true);
              try {
                await _adhanService.scheduleTestIn(const Duration(minutes: 1));
                _showSnack(isAr ? 'سيعمل الأذان بعد دقيقة ✔️' : 'Adhan in 1 min ✔️', AppColors.success);
              } finally {
                if (mounted) setState(() => _schedulingTest = false);
              }
            },
          )),
        ]),
        // ── Show/Hide individual prayer test buttons toggle ──────────────────
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: Text(
            isAr ? 'اختبار كل أذان على حدة' : 'Test Individual Prayers',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _textPrimary),
          )),
          Switch.adaptive(
            value: _showAdhanTestButtons,
            onChanged: (v) async {
              setState(() => _showAdhanTestButtons = v);
              await _settings.setShowAdhanTestButtons(v);
            },
          ),
        ]),
        // ── Individual prayer test buttons ──────────────────────────────────
        if (_showAdhanTestButtons) ...[
          const SizedBox(height: 12),
          Text(
            isAr ? 'اختبر الأذان لكل صلاة كأنها جاءت الآن' : 'Test adhan for each prayer as if it just arrived',
            style: TextStyle(fontSize: 11, color: _textSecondary, height: 1.4),
          ),
          const SizedBox(height: 10),
          _buildPrayerTestButton(isAr, 'fajr', 'الفجر', Icons.nights_stay_rounded, const Color(0xFF6A5ACD)),
          const SizedBox(height: 8),
          _buildPrayerTestButton(isAr, 'dhuhr', 'الظهر', Icons.wb_sunny_rounded, const Color(0xFFF4B400)),
          const SizedBox(height: 8),
          _buildPrayerTestButton(isAr, 'asr', 'العصر', Icons.wb_cloudy_rounded, AppColors.primary),
          const SizedBox(height: 8),
          _buildPrayerTestButton(isAr, 'maghrib', 'المغرب', Icons.wb_twilight_rounded, const Color(0xFFFF7043)),
          const SizedBox(height: 8),
          _buildPrayerTestButton(isAr, 'isha', 'العشاء', Icons.bedtime_rounded, const Color(0xFF1565C0)),
        ],
        const SizedBox(height: 16),
        _buildTimeJumpCard(isAr),
      ]),
    );
  }

  // ─── Time-jump test card ─────────────────────────────────────────────────

  Widget _buildTimeJumpCard(bool isAr) {
    final hasPrayer = _nextPrayerTime != null;
    final presets = [1, 2, 5];

    String fmtPrayer(DateTime dt) {
      final h = dt.hour;
      final m = dt.minute;
      final period = h >= 12 ? 'م' : 'ص';
      final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
      return '$h12:${m.toString().padLeft(2, '0')} $period';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _timeJumpActive
            ? Colors.orange.withValues(alpha: 0.08)
            : Colors.deepPurple.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _timeJumpActive
              ? Colors.orange.withValues(alpha: 0.5)
              : Colors.deepPurple.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Row(children: [
            Icon(
              _timeJumpActive ? Icons.warning_amber_rounded : Icons.manage_history_rounded,
              color: _timeJumpActive ? Colors.orange.shade700 : Colors.deepPurple,
              size: 18,
            ),
            const SizedBox(width: 7),
            Text(
              isAr
                  ? (_timeJumpActive ? '⚠️ وقت الجهاز مُعدَّل للاختبار' : 'ضبط وقت الجهاز للاختبار')
                  : (_timeJumpActive ? '⚠️ Device time modified' : 'Set device time for testing'),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: _timeJumpActive ? Colors.orange.shade800 : Colors.deepPurple,
              ),
            ),
          ]),

          if (_timeJumpActive) ...[
            // ── Active state ─────────────────────────────────────────────
            const SizedBox(height: 10),
            Text(
              isAr
                  ? 'الوقت مضبوط على ما قبل $_jumpMinutes د من أذان ${_nextPrayerName ?? ""}.\nأغلق التطبيق أو أقفل الشاشة وانتظر ${_jumpMinutes} د.'
                  : 'Time set to $_jumpMinutes min before ${_nextPrayerName ?? "prayer"} adhan.\nClose the app or lock screen and wait $_jumpMinutes min.',
              style: TextStyle(fontSize: 12, height: 1.5, color: Colors.orange.shade900),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSettingTime ? null : _restoreSystemTime,
                icon: _isSettingTime
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.restore_rounded, size: 18),
                label: Text(isAr ? 'استعادة الوقت الأصلي' : 'Restore system time'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ] else ...[
            // ── Setup state ──────────────────────────────────────────────
            const SizedBox(height: 10),

            // Next prayer chip
            if (hasPrayer)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.mosque_rounded, size: 14, color: Colors.deepPurple),
                  const SizedBox(width: 6),
                  Text(
                    isAr
                        ? 'الأذان القادم: ${_nextPrayerName ?? ""} — ${fmtPrayer(_nextPrayerTime!)}'
                        : 'Next: ${_nextPrayerName ?? ""} at ${fmtPrayer(_nextPrayerTime!)}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600, color: Colors.deepPurple),
                  ),
                ]),
              )
            else
              Text(
                isAr ? 'تأكد من تفعيل الأذان لعرض الوقت القادم.' : 'Enable adhan to see next prayer time.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),

            const SizedBox(height: 12),

            // Minutes label
            Text(
              isAr ? 'ضبط الوقت قبل الأذان بـ:' : 'Jump to N minutes before adhan:',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),

            // Preset chips + custom field
            Row(children: [
              for (final min in presets) ...[
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      _customMinutesCtrl.clear();
                      setState(() => _jumpMinutes = min);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: (_jumpMinutes == min && _customMinutesCtrl.text.isEmpty)
                            ? Colors.deepPurple
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: (_jumpMinutes == min && _customMinutesCtrl.text.isEmpty)
                              ? Colors.deepPurple
                              : Colors.grey.shade400,
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          isAr ? '$min د' : '${min}m',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: (_jumpMinutes == min && _customMinutesCtrl.text.isEmpty)
                                ? Colors.white
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              // Custom minute field
              Expanded(
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: _customMinutesCtrl.text.isNotEmpty
                        ? Colors.deepPurple.withValues(alpha: 0.08)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _customMinutesCtrl.text.isNotEmpty
                          ? Colors.deepPurple
                          : Colors.grey.shade400,
                      width: 1.5,
                    ),
                  ),
                  child: TextField(
                    controller: _customMinutesCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: isAr ? 'مخصص' : 'custom',
                      hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    onChanged: (v) {
                      final parsed = int.tryParse(v.trim());
                      if (parsed != null && parsed > 0) {
                        setState(() => _jumpMinutes = parsed);
                      } else {
                        setState(() {}); // refresh border color
                      }
                    },
                  ),
                ),
              ),
            ]),

            const SizedBox(height: 12),

            // Action button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: (hasPrayer && !_isSettingTime) ? _setSystemTime : null,
                icon: _isSettingTime
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.schedule_send_rounded, size: 18),
                label: Text(isAr ? 'اضبط وقت الجهاز' : 'Set device time'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),

            const SizedBox(height: 6),
            Text(
              isAr
                  ? '⚠️ يتطلب صلاحية SET_TIME (روت أو ADB).\nبعد الاختبار اضغط "استعادة الوقت".'
                  : '⚠️ Requires SET_TIME permission (root or ADB).\nPress "Restore" after testing.',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }

  /// Build a test button for a specific prayer
  Widget _buildPrayerTestButton(
    bool isAr,
    String prayerKey,
    String prayerArabic,
    IconData icon,
    Color color,
  ) {
    final isLoading = _testingPrayer[prayerKey] ?? false;
    final prayerEnglish = {
      'fajr': 'Fajr',
      'dhuhr': 'Dhuhr',
      'asr': 'Asr',
      'maghrib': 'Maghrib',
      'isha': 'Isha',
    }[prayerKey] ?? prayerKey;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _cardBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        color: _cardSurface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: isLoading
              ? null
              : () async {
                  setState(() => _testingPrayer[prayerKey] = true);
                  try {
                    await _adhanService.testAdhanForPrayer(prayerKey);
                    _showSnack(
                      isAr
                          ? 'يعمل أذان $prayerArabic الآن 🔊'
                          : 'Testing $prayerEnglish adhan now 🔊',
                      AppColors.success,
                    );
                  } catch (e) {
                    _showSnack(
                      isAr ? 'خطأ في التشغيل' : 'Playback error',
                      AppColors.error,
                    );
                  } finally {
                    if (mounted) {
                      setState(() => _testingPrayer[prayerKey] = false);
                    }
                  }
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 10),
              Expanded(child: Text(
                isAr ? prayerArabic : prayerEnglish,
                style: TextStyle(fontSize: 13, color: _textPrimary, fontWeight: FontWeight.w500),
              )),
              if (isLoading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
              else
                Icon(Icons.play_arrow_rounded, size: 18, color: color),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _showScheduleDialog({
    required bool isAr,
    String? raw,
    int days = 21,
    bool notificationsEnabled = true,
  }) async {
    List<Map<String, dynamic>> items = [];
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          items = decoded.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
        }
      } catch (_) {}
    }
    String localizePrayer(String label) {
      if (!isAr) return label;
      switch (label.toLowerCase()) {
        case 'fajr': return 'الفجر';
        case 'dhuhr': return 'الظهر';
        case 'asr': return 'العصر';
        case 'maghrib': return 'المغرب';
        case 'isha': return 'العشاء';
        default: return label;
      }
    }
    IconData prayerIcon(String label) {
      switch (label.toLowerCase()) {
        case 'fajr': return Icons.nights_stay_rounded;
        case 'dhuhr': return Icons.wb_sunny_rounded;
        case 'asr': return Icons.wb_cloudy_rounded;
        case 'maghrib': return Icons.wb_twilight_rounded;
        case 'isha': return Icons.bedtime_rounded;
        default: return Icons.access_time_rounded;
      }
    }
    Color prayerColor(String label) {
      switch (label.toLowerCase()) {
        case 'fajr': return const Color(0xFF6A5ACD);
        case 'dhuhr': return const Color(0xFFF4B400);
        case 'asr': return AppColors.primary;
        case 'maghrib': return const Color(0xFFFF7043);
        case 'isha': return const Color(0xFF1565C0);
        default: return AppColors.primary;
      }
    }
    final parsed = <({String label, DateTime time})>[];
    for (final it in items) {
      final label = (it['label'] as String?) ?? '';
      final timeStr = it['time'] as String?;
      final dt = timeStr == null ? null : DateTime.tryParse(timeStr);
      if (dt == null) continue;
      parsed.add((label: label, time: dt));
    }
    parsed.sort((a, b) => a.time.compareTo(b.time));
    final now = DateTime.now();
    final byDate = <String, List<({String label, DateTime time})>>{};
    for (final item in parsed) {
      final key = '${item.time.year}-${item.time.month.toString().padLeft(2, '0')}-${item.time.day.toString().padLeft(2, '0')}';
      byDate.putIfAbsent(key, () => []).add(item);
    }
    ({String label, DateTime time})? nextPrayer;
    for (final item in parsed) { if (item.time.isAfter(now)) { nextPrayer = item; break; } }
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        String fmtTime(DateTime dt) {
          final tod = TimeOfDay.fromDateTime(dt.toLocal());
          final h = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
          final m = tod.minute.toString().padLeft(2, '0');
          return '$h:$m ${tod.period == DayPeriod.am ? "AM" : "PM"}';
        }
        String fmtDate(DateTime dt) {
          final months = isAr
              ? ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر']
              : ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
          return '${dt.day} ${months[dt.month - 1]}';
        }
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          contentPadding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            Container(padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.gradientStart, AppColors.gradientEnd]), borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.calendar_month_rounded, color: Colors.white, size: 20)),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isAr ? 'جدول الأذان' : 'Adhan Schedule',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text('${parsed.length} ${isAr ? "صلاة · $days يوماً" : "prayers · $days days"}',
                  style: TextStyle(fontSize: 12, color: _textSecondary, fontWeight: FontWeight.normal)),
            ]),
          ]),
          content: SizedBox(width: double.maxFinite, height: 480, child: parsed.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(notificationsEnabled ? Icons.event_busy_rounded : Icons.notifications_off_rounded,
                    size: 56, color: _textSecondary.withValues(alpha: 0.3)),
                SizedBox(height: 16),
                Text(
                  notificationsEnabled
                      ? (isAr ? 'لا يوجد جدول بعد.\nاحفظ الإعدادات أولاً.' : 'No schedule yet.\nSave settings first.')
                      : (isAr ? 'إشعارات الأذان معطّلة.' : 'Adhan notifications are off.'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _textSecondary, fontSize: 14)),
              ]))
            : Column(children: [
                if (nextPrayer != null) ...[
                  Container(margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: prayerColor(nextPrayer.label).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: prayerColor(nextPrayer.label).withValues(alpha: 0.4)),
                    ),
                    child: Row(children: [
                      Icon(prayerIcon(nextPrayer.label), size: 20, color: prayerColor(nextPrayer.label)),
                      const SizedBox(width: 10),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${isAr ? "التالي: " : "Next: "}${localizePrayer(nextPrayer.label)}',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: prayerColor(nextPrayer.label))),
                        Text('${fmtDate(nextPrayer.time)} — ${fmtTime(nextPrayer.time)}',
                            style: TextStyle(fontSize: 12, color: prayerColor(nextPrayer.label).withValues(alpha: 0.8))),
                      ]),
                    ])),
                  const SizedBox(height: 6),
                ],
                Expanded(child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  itemCount: byDate.length,
                  itemBuilder: (ctx2, index) {
                    final dateKey = byDate.keys.elementAt(index);
                    final dayItems = byDate[dateKey]!;
                    final dt = dayItems.first.time;
                    final today = DateTime(now.year, now.month, now.day);
                    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
                    final isTomorrow = DateTime(dt.year, dt.month, dt.day).difference(today).inDays == 1;
                    String dayLabel = fmtDate(dt);
                    if (isToday) dayLabel = isAr ? 'اليوم' : 'Today';
                    if (isTomorrow) dayLabel = isAr ? 'غداً' : 'Tomorrow';
                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Padding(padding: const EdgeInsets.fromLTRB(6, 10, 6, 6), child: Row(children: [
                        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: isToday ? AppColors.primary : AppColors.primary.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(8)),
                          child: Text(dayLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: isToday ? Colors.white : _textSecondary))),
                        const SizedBox(width: 6),
                        const Expanded(child: Divider(color: AppColors.divider, height: 1)),
                      ])),
                      Wrap(spacing: 6, runSpacing: 6, children: dayItems.map((item) {
                        final color = prayerColor(item.label);
                        final isPast = item.time.isBefore(now);
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isPast ? Colors.transparent : color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isPast ? AppColors.divider : color.withValues(alpha: 0.35)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(prayerIcon(item.label), size: 14, color: isPast ? _textSecondary : color),
                            SizedBox(width: 5),
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(localizePrayer(item.label), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                                  color: isPast ? _textSecondary : color)),
                              Text(fmtTime(item.time), style: TextStyle(fontSize: 11,
                                  color: isPast ? _textSecondary : color.withValues(alpha: 0.8))),
                            ]),
                          ]),
                        );
                      }).toList()),
                      const SizedBox(height: 4),
                    ]);
                  },
                )),
              ])),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          actions: [TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(isAr ? 'إغلاق' : 'Close',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)))],
        );
      },
    );
  }
}

// =============================================================================
// HELPER WIDGETS
// =============================================================================

class _DisabledBanner extends StatelessWidget {
  final bool isAr;
  const _DisabledBanner({required this.isAr});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.notifications_off_rounded, color: Colors.orange, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Text(
          isAr ? 'الأذان معطَّل حالياً — فعِّله من الإعداد أدناه' : 'Adhan is currently disabled — enable it below',
          style: const TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.w600),
        )),
      ]),
    );
  }
}

// ─── Notification Permission Warning Banner ─────────────────────────────────────

class _NotificationPermissionBanner extends StatelessWidget {
  final bool isAr;
  final VoidCallback onTap;
  const _NotificationPermissionBanner({required this.isAr, required this.onTap});
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.red.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.notifications_off_rounded, color: Colors.red, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAr ? 'صلاحية الإشعارات مطلوبة' : 'Notification Permission Required',
                  style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  isAr 
                      ? 'الأذان لن يعمل بدون صلاحية الإشعارات. اضغط هنا لفتح الإعدادات.'
                      : 'Adhan won\'t work without notification permission. Tap to open settings.',
                  style: TextStyle(color: Colors.red.withValues(alpha: 0.8), fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward_ios_rounded, color: Colors.red.withValues(alpha: 0.6), size: 16),
        ]),
      ),
    );
  }
}

// ─── Location Warning Banner ─────────────────────────────────────────────────────

class _LocationWarningBanner extends StatelessWidget {
  final bool isAr;
  final VoidCallback onTap;
  const _LocationWarningBanner({required this.isAr, required this.onTap});
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.location_off_rounded, color: Colors.amber, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAr ? 'صلاحية الموقع غير مفعلة' : 'Location Permission Not Granted',
                  style: TextStyle(color: Colors.amber.shade800, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  isAr 
                      ? 'يتم استخدام موقع افتراضي — قد لا تكون المواعيد دقيقة لمنطقتك.'
                      : 'Using default location — times may not be accurate for your area.',
                  style: TextStyle(color: Colors.amber.shade700, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward_ios_rounded, color: Colors.amber.withValues(alpha: 0.6), size: 16),
        ]),
      ),
    );
  }
}

// ─── Sound tile ───────────────────────────────────────────────────────────────

class _SoundTile extends StatelessWidget {
  final AdhanSoundInfo sound;
  final bool isSelected;
  final bool isPlaying;
  final _CacheState cacheState;
  final double cacheProgress;
  final bool isAr;
  final VoidCallback onSelect;
  final VoidCallback onPreview;
  final VoidCallback onStop;
  final VoidCallback? onDelete;

  const _SoundTile({
    required this.sound, required this.isSelected, required this.isPlaying,
    required this.cacheState, required this.cacheProgress, required this.isAr,
    required this.onSelect, required this.onPreview, required this.onStop,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: isSelected ? AppColors.primary.withValues(alpha: 0.06) : Colors.transparent,
      child: InkWell(
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(children: [
            Row(children: [
              // Radio circle
              AnimatedContainer(duration: const Duration(milliseconds: 200),
                width: 22, height: 22,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  border: Border.all(color: isSelected ? AppColors.primary : AppColors.divider, width: 2),
                  color: isSelected ? AppColors.primary : Colors.transparent),
                child: isSelected ? Icon(Icons.check, color: Colors.white, size: 14) : null),
              const SizedBox(width: 12),
              // Mosque icon
              Container(width: 44, height: 44,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.mosque_rounded,
                  color: isSelected ? AppColors.primary : Theme.of(context).colorScheme.onSurfaceVariant, size: 22)),
              SizedBox(width: 12),
              // Name & metadata
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(isAr ? sound.nameAr : sound.nameEn,
                    style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? AppColors.primary : Theme.of(context).colorScheme.onSurface),
                    overflow: TextOverflow.ellipsis)),
                  if (sound.isOfflineFallback) ...[
                    SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                      ),
                      child: Text(isAr ? 'احتياطي' : 'Fallback',
                        style: const TextStyle(fontSize: 9, color: AppColors.primary, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ]),
                const SizedBox(height: 2),
                Row(children: [
                  Icon(Icons.person_outline_rounded, size: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  SizedBox(width: 3),
                  Flexible(child: Text(sound.muezzinDisplay(isAr),
                    style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis)),
                ]),
                SizedBox(height: 1),
                Row(children: [
                  Icon(Icons.location_on_outlined, size: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  SizedBox(width: 3),
                  Flexible(child: Text(sound.mosqueDisplay(isAr),
                    style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis)),
                ]),
              ])),
              const SizedBox(width: 4),
              // Cache indicator (online sounds only)
              if (sound.isOnline) ...[
                _CacheIndicator(state: cacheState, progress: cacheProgress),
                const SizedBox(width: 2),
              ],
              // Delete cached file button (only when fully downloaded)
              if (sound.isOnline && cacheState == _CacheState.cached && onDelete != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.delete_outline_rounded, size: 17, color: Colors.red),
                  tooltip: isAr ? 'حذف الملف المحمَّل' : 'Delete downloaded file',
                  onPressed: onDelete,
                ),
              // Play / Stop button — always enabled (streams if online)
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: isPlaying
                  ? const Icon(Icons.stop_circle_rounded, key: ValueKey('stop'), color: Colors.red, size: 26)
                  : Icon(Icons.play_circle_rounded, key: const ValueKey('play'),
                      color: AppColors.primary, size: 26)),
                tooltip: isPlaying ? (isAr ? 'إيقاف' : 'Stop') : (isAr ? 'استماع' : 'Preview'),
                onPressed: isPlaying ? onStop : onPreview),
            ]),
            // Cache progress bar (while caching)
            if (sound.isOnline && cacheState == _CacheState.caching && cacheProgress > 0) ...[
              const SizedBox(height: 8),
              ClipRRect(borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: cacheProgress, minHeight: 3,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12), color: AppColors.secondary)),
            ],
          ]),
        ),
      ),
    );
  }
}

// ─── Cache indicator ──────────────────────────────────────────────────────────

class _CacheIndicator extends StatelessWidget {
  final _CacheState state;
  final double progress;
  const _CacheIndicator({required this.state, required this.progress});

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case _CacheState.caching:
        return SizedBox(
          width: 22, height: 22,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: progress > 0 ? progress : null,
                strokeWidth: 2, color: AppColors.secondary),
              Icon(Icons.download_rounded, size: 9, color: AppColors.secondary),
            ],
          ),
        );
      case _CacheState.cached:
        return const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.secondary);
      case _CacheState.error:
        return const Icon(Icons.cloud_off_rounded, size: 18, color: Colors.red);
      case _CacheState.none:
        return Icon(Icons.wifi_rounded, size: 18, color: AppColors.primary.withValues(alpha: 0.45));
    }
  }
}

// ─── Battery warning ──────────────────────────────────────────────────────────

// ─── DND Permission Banner ────────────────────────────────────────────────────

class _DndPermissionBanner extends StatelessWidget {
  final bool isAr;
  final VoidCallback onTap;
  const _DndPermissionBanner({required this.isAr, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final cardBg     = isDark ? const Color(0xFF1A0A2E) : const Color(0xFFF3E5F5);
    const accent     = Color(0xFF5E35B1);
    final iconColor  = isDark ? const Color(0xFF9575CD) : accent;
    final btnColor   = isDark ? const Color(0xFF7E57C2) : accent;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: isDark ? 0.35 : 0.3), width: 1.2),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Icon(Icons.do_not_disturb_on_rounded, color: iconColor, size: 24),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            isAr ? 'صلاحية عدم الإزعاج مطلوبة' : 'DND Access Required',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: iconColor),
          ),
          const SizedBox(height: 3),
          Text(
            isAr
                ? 'امنح التطبيق صلاحية التحكم في وضع الصمت ثم ارجع'
                : 'Grant the app Do Not Disturb access, then come back',
            style: TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4),
          ),
        ])),
        const SizedBox(width: 10),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: btnColor,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(isAr ? 'منح' : 'Grant', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}

class _BatteryWarningCard extends StatelessWidget {
  final bool isAr;
  final VoidCallback onTap;
  const _BatteryWarningCard({required this.isAr, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg     = isDark ? const Color(0xFF2A1F00) : Colors.amber.shade50;
    final titleColor = isDark ? Colors.amber.shade200   : null; // null = inherit from theme
    final iconColor  = isDark ? Colors.amber.shade300   : Colors.amber;
    final btnBg      = isDark ? Colors.amber.shade800   : Colors.amber.shade700;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withValues(alpha: isDark ? 0.35 : 0.4), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.amber.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.amber.withValues(alpha: isDark ? 0.15 : 0.2), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.battery_alert_rounded, color: iconColor, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isAr ? 'تحسين استهلاك البطارية' : 'Battery Optimization',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: titleColor)),
            const SizedBox(height: 4),
            Text(
              isAr ? 'اختياري: لتحسين ثبات التنبيهات على بعض الأجهزة، افتح إعدادات البطارية واختر "غير مقيَّد" إن رغبت.'
                : 'Optional: to improve reliability on some devices, open battery settings and choose "Unrestricted" if desired.',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5),
            ),
          ])),
        ]),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: btnBg, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 11), elevation: 0),
          icon: const Icon(Icons.battery_charging_full_rounded, size: 18),
          label: Text(isAr ? 'افتح إعدادات البطارية (اختياري)' : 'Open Battery Settings (Optional)',
              style: const TextStyle(fontWeight: FontWeight.bold)))),
      ]),
    );
  }
}

// ─── Gradient button ──────────────────────────────────────────────────────────

class _GradientButton extends StatelessWidget {
  final bool loading;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  const _GradientButton({required this.loading, required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          gradient: loading ? null : const LinearGradient(colors: [AppColors.gradientStart, AppColors.gradientEnd]),
          color: loading ? Colors.grey.shade300 : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (loading)
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          else
            Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: loading ? Colors.grey : Colors.white, fontSize: 13)),
        ]),
      ),
    );
  }
}

// ─── Outline button ───────────────────────────────────────────────────────────

class _OutlineButton extends StatelessWidget {
  final bool loading;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  const _OutlineButton({required this.loading, required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: loading ? Colors.grey : AppColors.primary, width: 1.5),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (loading)
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
          else
            Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: loading ? Colors.grey : AppColors.primary, fontSize: 13)),
        ]),
      ),
    );
  }
}
// ─── Short mode step ──────────────────────────────────────────────────────────

class _ShortModeStep extends StatelessWidget {
  final String number;
  final bool isAr;
  final String ar;
  final String en;
  const _ShortModeStep({required this.number, required this.isAr, required this.ar, required this.en});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 22, height: 22,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.gradientStart, AppColors.gradientEnd]),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(number, style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            isAr ? ar : en,
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4),
          ),
        ),
      ]),
    );
  }
}
