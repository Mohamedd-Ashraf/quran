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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('التشخيصات'),
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
                  _sectionTitle('حالة النظام', cs),
                  _diagCard(cs, [
                    _diagRow(
                      'تحسين البطارية',
                      _diag['batteryOptimizationDisabled'] == true
                          ? 'معطّل ✓'
                          : 'مفعّل ⚠️',
                      _diag['batteryOptimizationDisabled'] == true,
                    ),
                    _diagRow(
                      'إذن المنبهات الدقيقة',
                      _diag['canScheduleExactAlarms'] == true
                          ? 'مسموح ✓'
                          : 'ممنوع ⚠️',
                      _diag['canScheduleExactAlarms'] == true,
                    ),
                    _diagRow(
                      'فئة استخدام التطبيق',
                      _standbyBucketLabel(_diag['appStandbyBucket']),
                      (_diag['appStandbyBucket'] as int? ?? 50) <= 20,
                    ),
                    _diagRow(
                      'إصدار Android',
                      'API ${_diag['sdkVersion'] ?? '?'}',
                      true,
                    ),
                    _diagRow(
                      'الشركة المصنعة',
                      '${_diag['manufacturer'] ?? '?'}',
                      true,
                    ),
                  ]),
                  const SizedBox(height: 16),
                  _sectionTitle('حالة التشغيل', cs),
                  _diagCard(cs, [
                    _diagRow(
                      'الأذان يعمل الآن',
                      _diag['isAdhanPlaying'] == true ? 'نعم' : 'لا',
                      true,
                    ),
                  ]),
                  const SizedBox(height: 16),
                  _sectionTitle('الإعدادات', cs),
                  _diagCard(cs, [
                    _diagRow(
                      'الأذان',
                      _diag['adhanEnabled'] == true ? 'مفعّل' : 'معطّل',
                      _diag['adhanEnabled'] == true,
                    ),
                    _diagRow(
                      'الإقامة',
                      _diag['iqamaEnabled'] == true ? 'مفعّل' : 'معطّل',
                      true,
                    ),
                    _diagRow(
                      'تنبيه ما قبل الصلاة',
                      _diag['approachingEnabled'] == true ? 'مفعّل' : 'معطّل',
                      true,
                    ),
                    _diagRow(
                      'الصلاة على النبي',
                      _diag['salawatEnabled'] == true ? 'مفعّل' : 'معطّل',
                      true,
                    ),
                    _diagRow('الصوت', '${_diag['selectedSound'] ?? '?'}', true),
                    _diagRow(
                      'مسار الصوت',
                      '${_diag['audioStream'] ?? '?'}',
                      true,
                    ),
                    _diagRow(
                      'فرض السماعة',
                      _diag['forceSpeaker'] == true ? 'مفعّل' : 'معطّل',
                      true,
                    ),
                    _diagRow(
                      'الأذان المختصر',
                      _diag['shortMode'] == true ? 'مفعّل' : 'معطّل',
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
                        label: const Text('فتح إعدادات المنبهات الدقيقة'),
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
                        label: const Text('إلغاء تحسين البطارية'),
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

  String _standbyBucketLabel(dynamic bucket) {
    if (bucket == null || bucket == -1) return 'غير متاح';
    switch (bucket as int) {
      case 5:
        return 'نشط (ACTIVE)';
      case 10:
        return 'مجموعة العمل (WORKING_SET)';
      case 20:
        return 'متكرر (FREQUENT)';
      case 30:
        return 'نادر (RARE)';
      case 40:
        return 'مقيّد (RESTRICTED) ⚠️';
      case 50:
        return 'لم يُستخدم (NEVER) ⚠️';
      default:
        return 'فئة $bucket';
    }
  }
}
