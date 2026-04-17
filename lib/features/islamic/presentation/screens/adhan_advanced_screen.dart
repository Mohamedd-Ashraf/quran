import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import 'adhan_diagnostics_screen.dart';
import 'adhan_reliability_test_screen.dart';
import 'oem_battery_optimization_screen.dart';

class AdhanAdvancedScreen extends StatelessWidget {
  const AdhanAdvancedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'أدوات متقدمة' : 'Advanced Tools'),
        centerTitle: true,
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _AdvancedTile(
            icon: Icons.battery_saver_rounded,
            color: Colors.amber,
            titleAr: 'إعدادات بطارية الشركة المصنّعة',
            titleEn: 'OEM Battery Settings',
            subtitleAr: 'خطوات للتأكد من عمل الأذان في الخلفية',
            subtitleEn: 'Steps to ensure adhan works in background',
            isAr: isAr,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const OemBatteryOptimizationScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _AdvancedTile(
            icon: Icons.bug_report_rounded,
            color: Colors.teal,
            titleAr: 'التشخيص',
            titleEn: 'Diagnostics',
            subtitleAr: 'تحقق من حالة النظام والصلاحيات',
            subtitleEn: 'Check system status and permissions',
            isAr: isAr,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdhanDiagnosticsScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _AdvancedTile(
            icon: Icons.science_outlined,
            color: Colors.deepPurple,
            titleAr: 'اختبار موثوقية الأذان',
            titleEn: 'Adhan Reliability Test',
            subtitleAr: 'اختبر الأذان بسيناريوهات حقيقية',
            subtitleEn: 'Test adhan with real-world scenarios',
            isAr: isAr,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdhanReliabilityTestScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdvancedTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String titleAr;
  final String titleEn;
  final String subtitleAr;
  final String subtitleEn;
  final bool isAr;
  final VoidCallback onTap;

  const _AdvancedTile({
    required this.icon,
    required this.color,
    required this.titleAr,
    required this.titleEn,
    required this.subtitleAr,
    required this.subtitleEn,
    required this.isAr,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAr ? titleAr : titleEn,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isAr ? subtitleAr : subtitleEn,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
          ]),
        ),
      ),
    );
  }
}
