import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تحسين البطارية'),
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
                            ? 'تحسين البطارية معطّل ✓'
                            : 'تحسين البطارية مفعّل ⚠️',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _batteryOptDisabled
                              ? (isDark ? Colors.green.shade300 : Colors.green.shade800)
                              : (isDark ? Colors.orange.shade300 : Colors.orange.shade800),
                        ),
                      ),
                      subtitle: Text(
                        _batteryOptDisabled
                            ? 'التطبيق مستثنى من تحسين البطارية — الأذان سيعمل بشكل طبيعي'
                            : 'قد يمنع النظام الأذان من العمل في الخلفية',
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
                      label: const Text('إلغاء تحسين البطارية'),
                    ),

                  const SizedBox(height: 24),

                  // OEM-specific section
                  Text(
                    'إعدادات الشركة المصنعة',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'الجهاز: ${_manufacturer.isNotEmpty ? _manufacturer : "غير معروف"}',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),

                  ..._buildOemInstructions(cs),

                  const SizedBox(height: 16),
                  // Open OEM settings button
                  OutlinedButton.icon(
                    onPressed: () async {
                      await _channel.invokeMethod('openOemBatterySettings');
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('فتح إعدادات البطارية المتقدمة'),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
      ),
    );
  }

  List<Widget> _buildOemInstructions(ColorScheme cs) {
    if (_manufacturer.contains('xiaomi') || _manufacturer.contains('redmi')) {
      return _instructionCards(cs, 'Xiaomi / Redmi', [
        'افتح "الأمان" (Security) ← "التشغيل التلقائي" (Autostart) ← فعّل التطبيق',
        'افتح "الإعدادات" ← "البطارية" ← "توفير الطاقة" ← استثنِ التطبيق',
        'افتح "الإعدادات" ← "التطبيقات" ← اختر التطبيق ← "توفير البطارية" ← "بلا قيود"',
      ]);
    } else if (_manufacturer.contains('huawei') ||
        _manufacturer.contains('honor')) {
      return _instructionCards(cs, 'Huawei / Honor', [
        'افتح "إدارة الهاتف" ← "تشغيل التطبيقات" ← فعّل "إدارة يدوية" ← فعّل الثلاث خيارات',
        'افتح "الإعدادات" ← "البطارية" ← "إطلاق التطبيقات" ← أوقف التطبيق من القائمة',
        'افتح "الإعدادات" ← "التطبيقات" ← اختر التطبيق ← "البطارية" ← "غير مقيد"',
      ]);
    } else if (_manufacturer.contains('samsung')) {
      return _instructionCards(cs, 'Samsung', [
        'افتح "الإعدادات" ← "العناية بالجهاز" ← "البطارية" ← "حدود الاستخدام في الخلفية"',
        'أضف التطبيق إلى قائمة "التطبيقات التي لا تنام أبداً"',
        'افتح "الإعدادات" ← "التطبيقات" ← اختر التطبيق ← "البطارية" ← "غير مقيد"',
      ]);
    } else if (_manufacturer.contains('oppo') ||
        _manufacturer.contains('realme')) {
      return _instructionCards(cs, 'OPPO / Realme', [
        'افتح "الإعدادات" ← "إدارة التطبيقات" ← اختر التطبيق ← "بدء تلقائي" ← فعّل',
        'افتح "الإعدادات" ← "البطارية" ← "توفير الطاقة" ← استثنِ التطبيق',
        'اسحب التطبيق من قائمة المهام ← اضغط القفل لمنع إغلاقه',
      ]);
    } else if (_manufacturer.contains('vivo')) {
      return _instructionCards(cs, 'Vivo', [
        'افتح "الإعدادات" ← "البطارية" ← "استهلاك الطاقة في الخلفية العالي" ← فعّل التطبيق',
        'افتح "i Manager" ← "إدارة التطبيقات" ← "بدء تلقائي" ← فعّل التطبيق',
      ]);
    } else if (_manufacturer.contains('oneplus')) {
      return _instructionCards(cs, 'OnePlus', [
        'افتح "الإعدادات" ← "البطارية" ← "تحسين البطارية" ← اختر "الكل" ← استثنِ التطبيق',
        'افتح "الإعدادات" ← "التطبيقات" ← اختر التطبيق ← "البطارية" ← "غير مقيد"',
      ]);
    }

    // Generic instructions
    return _instructionCards(cs, 'عام', [
      'افتح "الإعدادات" ← "البطارية" ← استثنِ التطبيق من تحسين البطارية',
      'افتح "الإعدادات" ← "التطبيقات" ← اختر التطبيق ← "البطارية" ← "غير مقيد"',
    ]);
  }

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
                'خطوات $brand',
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
