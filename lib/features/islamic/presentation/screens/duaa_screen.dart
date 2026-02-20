import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/widgets/coming_soon_screen.dart'; // Import the new screen (adjust path if needed)
import '../../../../core/settings/app_settings_cubit.dart';

class DuaaScreen extends StatelessWidget {
  const DuaaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonScreen(
      titleEn: 'Duaa',
      titleAr: 'الأدعية',
      icon: Icons.volunteer_activism_rounded, // Choose a suitable icon
    );
  }
}
