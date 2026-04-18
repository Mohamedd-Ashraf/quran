import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/services/settings_service.dart';

/// OEM-specific battery optimization guidance screen.
///
/// Detects the device manufacturer and shows step-by-step instructions
/// for whitelisting the app from aggressive battery management.
class OemBatteryOptimizationScreen extends StatefulWidget {
  const OemBatteryOptimizationScreen({super.key});

  @override
  State<OemBatteryOptimizationScreen> createState() =>
      _OemBatteryOptimizationScreenState();
}

class _OemBatteryOptimizationScreenState
    extends State<OemBatteryOptimizationScreen> {
  static const MethodChannel _channel = MethodChannel('quraan/adhan_player');

  String _manufacturer = '';
  bool _batteryOptDisabled = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    try {
      final mfr = await _channel.invokeMethod<String>('getManufacturer') ?? '';
      final battOpt =
          await _channel.invokeMethod<bool>('isBatteryOptimizationDisabled') ??
              false;
      if (mounted) {
        setState(() {
          _manufacturer = mfr.toLowerCase();
          _batteryOptDisabled = battOpt;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isAr ? 'تحسين البطارية' : 'Battery Optimization'),
          centerTitle: true,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Status card — colors adapt to dark/light theme
                  Card(
                    color: _batteryOptDisabled
                        ? (isDark ? Colors.green.shade900 : Colors.green.shade50)
                        : (isDark ? Colors.orange.shade900 : Colors.orange.shade50),
                    child: ListTile(
                      leading: Icon(
                        _batteryOptDisabled
                            ? Icons.check_circle
                            : Icons.warning_rounded,
                        color: _batteryOptDisabled
                            ? (isDark ? Colors.green.shade300 : Colors.green.shade700)
                            : (isDark ? Colors.orange.shade300 : Colors.orange.shade700),
                        size: 32,
                      ),
                      title: Text(
                        _batteryOptDisabled
                            ? (isAr ? 'تحسين البطارية معطّل ✓' : 'Battery Optimization Disabled ✓')
                            : (isAr ? 'تحسين البطارية مفعّل ⚠️' : 'Battery Optimization Enabled ⚠️'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _batteryOptDisabled
                              ? (isDark ? Colors.green.shade300 : Colors.green.shade800)
                              : (isDark ? Colors.orange.shade300 : Colors.orange.shade800),
                        ),
                      ),
                      subtitle: Text(
                        _batteryOptDisabled
                            ? (isAr ? 'التطبيق مستثنى من تحسين البطارية — الأذان سيعمل بشكل طبيعي' : 'App is exempt from battery optimization — Adhan will work normally')
                            : (isAr ? 'قد يمنع النظام الأذان من العمل في الخلفية' : 'System may prevent Adhan from working in the background'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Standard battery optimization button
                  if (!_batteryOptDisabled)
                    FilledButton.icon(
                      onPressed: () async {
                        await _channel.invokeMethod('openBatterySettings');
                        // Refresh status after returning
                        Future.delayed(
                          const Duration(seconds: 1),
                          _loadInfo,
                        );
                      },
                      icon: const Icon(Icons.battery_saver),
                      label: Text(isAr ? 'إلغاء تحسين البطارية' : 'Disable Battery Optimization'),
                    ),

                  const SizedBox(height: 24),

                  // OEM-specific section
                  Text(
                    isAr ? 'إعدادات الشركة المصنعة' : 'Manufacturer Settings',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isAr
                        ? 'الجهاز: ${_manufacturer.isNotEmpty ? _manufacturer : "غير معروف"}'
                        : 'Device: ${_manufacturer.isNotEmpty ? _manufacturer : "Unknown"}',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),

                  ..._buildOemInstructions(cs, isAr),

                  const SizedBox(height: 16),
                  // Open OEM settings button
                  OutlinedButton.icon(
                    onPressed: () async {
                      await _channel.invokeMethod('openOemBatterySettings');
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: Text(isAr ? 'فتح إعدادات البطارية المتقدمة' : 'Open Advanced Battery Settings'),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
      ),
    );
  }

  List<Widget> _buildOemInstructions(ColorScheme cs, bool isAr) {
    if (_manufacturer.contains('xiaomi') || _manufacturer.contains('redmi')) {
      return _instructionCards(cs, 'Xiaomi / Redmi', isAr
          ? [
              'افتح "الأمان" (Security) ← "التشغيل التلقائي" (Autostart) ← فعّل التطبيق',
              'افتح "الإعدادات" ← "البطارية" ← "توفير الطاقة" ← استثنِ التطبيق',
              'افتح "الإعدادات" ← "التطبيقات" ← اختر التطبيق ← "توفير البطارية" ← "بلا قيود"',
            ]
          : [
              'Open "Security" → "Autostart" → Enable the app',
              'Open "Settings" → "Battery" → "Battery Saver" → Exclude the app',
              'Open "Settings" → "Apps" → Select the app → "Battery Saver" → "No Restrictions"',
            ]);
    } else if (_manufacturer.contains('huawei') ||
        _manufacturer.contains('honor')) {
      return _instructionCards(cs, 'Huawei / Honor', isAr
          ? [
              'افتح "إدارة الهاتف" ← "تشغيل التطبيقات" ← فعّل "إدارة يدوية" ← فعّل الثلاث خيارات',
              'افتح "الإعدادات" ← "البطارية" ← "إطلاق التطبيقات" ← أوقف التطبيق من القائمة',
              'افتح "الإعدادات" ← "التطبيقات" ← اختر التطبيق ← "البطارية" ← "غير مقيد"',
            ]
          : [
              'Open "Phone Manager" → "App Launch" → Enable "Manage Manually" → Enable all three options',
              'Open "Settings" → "Battery" → "App Launch" → Disable the app from the list',
              'Open "Settings" → "Apps" → Select the app → "Battery" → "Unrestricted"',
            ]);
    } else if (_manufacturer.contains('samsung')) {
      return _instructionCards(cs, 'Samsung', isAr
          ? [
              'افتح "الإعدادات" ← "العناية بالجهاز" ← "البطارية" ← "حدود الاستخدام في الخلفية"',
              'أضف التطبيق إلى قائمة "التطبيقات التي لا تنام أبداً"',
              'افتح "الإعدادات" ← "التطبيقات" ← اختر التطبيق ← "البطارية" ← "غير مقيد"',
            ]
          : [
              'Open "Settings" → "Device Care" → "Battery" → "Background Usage Limits"',
              'Add the app to the "Never Sleeping Apps" list',
              'Open "Settings" → "Apps" → Select the app → "Battery" → "Unrestricted"',
            ]);
    } else if (_manufacturer.contains('oppo') ||
        _manufacturer.contains('realme')) {
      return _instructionCards(cs, 'OPPO / Realme', isAr
          ? [
              'افتح "الإعدادات" ← "إدارة التطبيقات" ← اختر التطبيق ← "بدء تلقائي" ← فعّل',
              'افتح "الإعدادات" ← "البطارية" ← "توفير الطاقة" ← استثنِ التطبيق',
              'اسحب التطبيق من قائمة المهام ← اضغط القفل لمنع إغلاقه',
            ]
          : [
              'Open "Settings" → "App Management" → Select the app → "Auto-start" → Enable',
              'Open "Settings" → "Battery" → "Power Saver" → Exclude the app',
              'Swipe the app in recent tasks → Tap the lock to prevent closing',
            ]);
    } else if (_manufacturer.contains('vivo')) {
      return _instructionCards(cs, 'Vivo', isAr
          ? [
              'افتح "الإعدادات" ← "البطارية" ← "استهلاك الطاقة في الخلفية العالي" ← فعّل التطبيق',
              'افتح "i Manager" ← "إدارة التطبيقات" ← "بدء تلقائي" ← فعّل التطبيق',
            ]
          : [
              'Open "Settings" → "Battery" → "High Background Power Consumption" → Enable the app',
              'Open "i Manager" → "App Management" → "Auto-start" → Enable the app',
            ]);
    } else if (_manufacturer.contains('oneplus')) {
      return _instructionCards(cs, 'OnePlus', isAr
          ? [
              'افتح "الإعدادات" ← "البطارية" ← "تحسين البطارية" ← اختر "الكل" ← استثنِ التطبيق',
              'افتح "الإعدادات" ← "التطبيقات" ← اختر التطبيق ← "البطارية" ← "غير مقيد"',
            ]
          : [
              'Open "Settings" → "Battery" → "Battery Optimization" → Select "All" → Exclude the app',
              'Open "Settings" → "Apps" → Select the app → "Battery" → "Unrestricted"',
            ]);
    }

    // Generic instructions
    return _instructionCards(cs, isAr ? 'عام' : 'General', isAr
        ? [
            'افتح "الإعدادات" ← "البطارية" ← استثنِ التطبيق من تحسين البطارية',
            'افتح "الإعدادات" ← "التطبيقات" ← اختر التطبيق ← "البطارية" ← "غير مقيد"',
          ]
        : [
            'Open "Settings" → "Battery" → Exclude the app from battery optimization',
            'Open "Settings" → "Apps" → Select the app → "Battery" → "Unrestricted"',
          ]);
  }

  bool get _isAr => di.sl<SettingsService>().getAppLanguage() == 'ar';

  List<Widget> _instructionCards(
    ColorScheme cs,
    String brand,
    List<String> steps,
  ) {
    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isAr ? 'خطوات $brand' : '$brand Steps',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: cs.primary,
                ),
              ),
              const SizedBox(height: 8),
              ...steps.asMap().entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: cs.primaryContainer,
                            child: Text(
                              '${e.key + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              e.value,
                              style: const TextStyle(fontSize: 14),
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
    ];
  }
}
