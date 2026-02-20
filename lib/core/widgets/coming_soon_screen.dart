import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../settings/app_settings_cubit.dart';

class ComingSoonScreen extends StatelessWidget {
  final String titleEn;
  final String titleAr;
  final IconData icon;

  const ComingSoonScreen({
    super.key,
    required this.titleEn,
    required this.titleAr,
    this.icon = Icons.hourglass_empty_rounded,
  });

  @override
  Widget build(BuildContext context) {
    // Check if the current locale is Arabic
    final isArabicUi = context
        .watch<AppSettingsCubit>()
        .state
        .appLanguageCode
        .toLowerCase()
        .startsWith('ar');
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isArabicUi ? titleAr : titleEn),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                isArabicUi ? 'قريباً' : 'Coming Soon',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                isArabicUi
                    ? 'ستتوفر هذه الميزة في التحديثات القادمة بإذن الله'
                    : 'This feature will be available in upcoming updates, Insha\'Allah',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 48),
              FilledButton.tonal(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(isArabicUi ? 'عودة' : 'Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
