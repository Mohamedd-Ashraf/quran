import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/services/settings_service.dart';
import '../../../../core/di/injection_container.dart' as di;

/// Diagnostic screen showing active alarm state, permissions, and system health.
class AdhanDiagnosticsScreen extends StatefulWidget {
  const AdhanDiagnosticsScreen({super.key});

  @override
  State<AdhanDiagnosticsScreen> createState() => _AdhanDiagnosticsScreenState();
}

class _AdhanDiagnosticsScreenState extends State<AdhanDiagnosticsScreen> {
  static const MethodChannel _channel = MethodChannel('quraan/adhan_player');

  Map<String, dynamic> _diag = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDiagnostics();
  }

  Future<void> _loadDiagnostics() async {
    try {
      final result = await _channel.invokeMethod<Map>('getDiagnostics');
      final settings = di.sl<SettingsService>();

      final diagMap = <String, dynamic>{};
      result?.forEach((k, v) => diagMap[k.toString()] = v);

      // Add Dart-side info
      diagMap['adhanEnabled'] =
          settings.getBool('adhan_notifications_enabled', defaultValue: true);
      diagMap['iqamaEnabled'] =
          settings.getBool('iqama_enabled', defaultValue: false);
      diagMap['approachingEnabled'] =
          settings.getBool('approaching_enabled', defaultValue: false);
      diagMap['salawatEnabled'] =
          settings.getBool('salawat_enabled', defaultValue: false);
      diagMap['selectedSound'] =
          settings.getString('selected_adhan_sound', defaultValue: 'adhan_1');
      diagMap['audioStream'] =
          settings.getString('adhan_audio_stream', defaultValue: 'alarm');
      diagMap['forceSpeaker'] =
          settings.getBool('adhan_force_speaker', defaultValue: false);
      diagMap['shortMode'] =
          settings.getBool('adhan_short_mode', defaultValue: false);

      if (mounted) {
        setState(() {
          _diag = diagMap;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _diag = {'error': e.toString()};
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final _e = isAr ? 'مفعّل' : 'Enabled';
    final _d = isAr ? 'معطّل' : 'Disabled';
    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isAr ? 'التشخيصات' : 'Diagnostics'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() => _loading = true);
                _loadDiagnostics();
              },
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _sectionTitle(isAr ? 'حالة النظام' : 'System Status', cs),
                  _diagCard(cs, [
                    _diagRow(
                      isAr ? 'تحسين البطارية' : 'Battery Optimization',
                      _diag['batteryOptimizationDisabled'] == true
                          ? '$_d ✓'
                          : '$_e ⚠️',
                      _diag['batteryOptimizationDisabled'] == true,
                    ),
                    _diagRow(
                      isAr ? 'إذن المنبهات الدقيقة' : 'Exact Alarms Permission',
                      _diag['canScheduleExactAlarms'] == true
                          ? (isAr ? 'مسموح ✓' : 'Allowed ✓')
                          : (isAr ? 'ممنوع ⚠️' : 'Denied ⚠️'),
                      _diag['canScheduleExactAlarms'] == true,
                    ),
                    _diagRow(
                      isAr ? 'فئة استخدام التطبيق' : 'App Standby Bucket',
                      _standbyBucketLabel(_diag['appStandbyBucket'], isAr),
                      (_diag['appStandbyBucket'] as int? ?? 50) <= 20,
                    ),
                    _diagRow(
                      isAr ? 'إصدار Android' : 'Android Version',
                      'API ${_diag['sdkVersion'] ?? '?'}',
                      true,
                    ),
                    _diagRow(
                      isAr ? 'الشركة المصنعة' : 'Manufacturer',
                      '${_diag['manufacturer'] ?? '?'}',
                      true,
                    ),
                  ]),
                  const SizedBox(height: 16),
                  _sectionTitle(isAr ? 'حالة التشغيل' : 'Playback Status', cs),
                  _diagCard(cs, [
                    _diagRow(
                      isAr ? 'الأذان يعمل الآن' : 'Adhan Playing Now',
                      _diag['isAdhanPlaying'] == true
                          ? (isAr ? 'نعم' : 'Yes')
                          : (isAr ? 'لا' : 'No'),
                      true,
                    ),
                  ]),
                  const SizedBox(height: 16),
                  _sectionTitle(isAr ? 'الإعدادات' : 'Settings', cs),
                  _diagCard(cs, [
                    _diagRow(
                      isAr ? 'الأذان' : 'Adhan',
                      _diag['adhanEnabled'] == true ? _e : _d,
                      _diag['adhanEnabled'] == true,
                    ),
                    _diagRow(
                      isAr ? 'الإقامة' : 'Iqama',
                      _diag['iqamaEnabled'] == true ? _e : _d,
                      true,
                    ),
                    _diagRow(
                      isAr ? 'تنبيه ما قبل الصلاة' : 'Pre-Prayer Alert',
                      _diag['approachingEnabled'] == true ? _e : _d,
                      true,
                    ),
                    _diagRow(
                      isAr ? 'الصلاة على النبي' : 'Salawat',
                      _diag['salawatEnabled'] == true ? _e : _d,
                      true,
                    ),
                    _diagRow(isAr ? 'الصوت' : 'Sound', '${_diag['selectedSound'] ?? '?'}', true),
                    _diagRow(
                      isAr ? 'مسار الصوت' : 'Audio Stream',
                      '${_diag['audioStream'] ?? '?'}',
                      true,
                    ),
                    _diagRow(
                      isAr ? 'فرض السماعة' : 'Force Speaker',
                      _diag['forceSpeaker'] == true ? _e : _d,
                      true,
                    ),
                    _diagRow(
                      isAr ? 'الأذان المختصر' : 'Short Adhan',
                      _diag['shortMode'] == true ? _e : _d,
                      true,
                    ),
                  ]),
                  const SizedBox(height: 16),
                  // Actions
                  if (_diag['canScheduleExactAlarms'] != true)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: FilledButton.icon(
                        onPressed: () async {
                          await _channel.invokeMethod('openExactAlarmSettings');
                        },
                        icon: const Icon(Icons.alarm),
                        label: Text(isAr
                            ? 'فتح إعدادات المنبهات الدقيقة (مهم للأذان)'
                            : 'Open Exact Alarm Settings (required for Adhan)'),
                      ),
                    ),
                  if (_diag['batteryOptimizationDisabled'] != true)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: FilledButton.icon(
                        onPressed: () async {
                          await _channel.invokeMethod('openBatterySettings');
                          Future.delayed(
                            const Duration(seconds: 1),
                            _loadDiagnostics,
                          );
                        },
                        icon: const Icon(Icons.battery_saver),
                        label: Text(isAr
                            ? 'فتح إعدادات البطارية (اختياري)'
                            : 'Open Battery Settings (optional)'),
                      ),
                    ),
                  const SizedBox(height: 32),
                ],
              ),
      ),
    );
  }

  Widget _sectionTitle(String title, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: cs.primary,
        ),
      ),
    );
  }

  Widget _diagCard(ColorScheme cs, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Column(children: children),
      ),
    );
  }

  Widget _diagRow(String label, String value, bool ok) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_outline : Icons.error_outline,
            size: 18,
            color: ok ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 14)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: ok ? null : Colors.orange.shade800,
            ),
          ),
        ],
      ),
    );
  }

  String _standbyBucketLabel(dynamic bucket, bool isAr) {
    if (bucket == null || bucket == -1) return isAr ? 'غير متاح' : 'N/A';
    switch (bucket as int) {
      case 5:
        return isAr ? 'نشط (ACTIVE)' : 'Active';
      case 10:
        return isAr ? 'مجموعة العمل (WORKING_SET)' : 'Working Set';
      case 20:
        return isAr ? 'متكرر (FREQUENT)' : 'Frequent';
      case 30:
        return isAr ? 'نادر (RARE)' : 'Rare';
      case 40:
        return isAr ? 'مقيّد (RESTRICTED) ⚠️' : 'Restricted ⚠️';
      case 50:
        return isAr ? 'لم يُستخدم (NEVER) ⚠️' : 'Never Used ⚠️';
      default:
        return isAr ? 'فئة $bucket' : 'Bucket $bucket';
    }
  }
}
