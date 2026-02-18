import 'package:flutter/material.dart';
import 'package:quraan/core/services/app_update_service.dart';
import 'package:quraan/core/utils/update_checker.dart';
import 'package:quraan/core/di/injection_container.dart' as di;

/// Example of how to add "Check for Updates" button in your settings screen
/// 
/// Usage:
/// 1. Import this file or copy the code below
/// 2. Add the ListTile to your settings screen
/// 3. The button will manually trigger an update check

class UpdateSettingsTile extends StatelessWidget {
  final String languageCode;

  const UpdateSettingsTile({
    super.key,
    this.languageCode = 'ar',
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = languageCode.startsWith('ar');

    return ListTile(
      leading: const Icon(Icons.system_update_rounded),
      title: Text(
        isArabic ? 'فحص التحديثات' : 'Check for Updates',
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        isArabic ? 'البحث عن إصدار جديد من التطبيق' : 'Look for a new version of the app',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        final updateService = di.sl<AppUpdateService>();
        
        await UpdateChecker.manualCheck(
          context: context,
          updateService: updateService,
          languageCode: languageCode,
          showLoading: true,
        );
      },
    );
  }
}

/// Alternative: Simple button version
class CheckUpdateButton extends StatelessWidget {
  final String languageCode;

  const CheckUpdateButton({
    super.key,
    this.languageCode = 'ar',
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = languageCode.startsWith('ar');

    return ElevatedButton.icon(
      onPressed: () async {
        final updateService = di.sl<AppUpdateService>();
        
        await UpdateChecker.manualCheck(
          context: context,
          updateService: updateService,
          languageCode: languageCode,
        );
      },
      icon: const Icon(Icons.system_update_rounded),
      label: Text(isArabic ? 'فحص التحديثات' : 'Check for Updates'),
    );
  }
}

/// Example of how to integrate into an existing settings screen:
/// 
/// ```dart
/// class SettingsScreen extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     return Scaffold(
///       appBar: AppBar(title: Text('الإعدادات')),
///       body: ListView(
///         children: [
///           // ... other settings ...
///           
///           // Add this section
///           const SizedBox(height: 16),
///           Padding(
///             padding: const EdgeInsets.symmetric(horizontal: 16),
///             child: Text(
///               'التطبيق',
///               style: TextStyle(
///                 fontSize: 14,
///                 fontWeight: FontWeight.bold,
///                 color: Colors.grey,
///               ),
///             ),
///           ),
///           UpdateSettingsTile(languageCode: 'ar'),
///           
///           // ... more settings ...
///         ],
///       ),
///     );
///   }
/// }
/// ```
