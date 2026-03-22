import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_design_system.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/services/adhan_notification_service.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../core/settings/app_settings_cubit.dart';
import '../widgets/islamic_audio_player.dart';
import 'home_screen.dart';
import 'bookmarks_screen.dart';
import 'settings_screen.dart';
import '../../../wird/presentation/screens/wird_screen.dart';
import '../../../wird/services/wird_notification_service.dart';
import '../../../islamic/presentation/screens/more_screen.dart';

class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _currentIndex = 0;

  final GlobalKey<BookmarksScreenState> _bookmarksKey = GlobalKey<BookmarksScreenState>();
  final GlobalKey<HomeScreenState> _homeKey = GlobalKey<HomeScreenState>();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(key: _homeKey),
      BookmarksScreen(
        key: _bookmarksKey,
        onNavigateToHome: () {
          setState(() {
            _currentIndex = 0;
          });
          _homeKey.currentState?.reload();
        },
      ),
      const WirdScreen(),
      const MoreScreen(),
      const SettingsScreen(),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) => _showAdhanBannerIfNeeded());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(Future.delayed(const Duration(seconds: 5), () async {
        if (!mounted) return;
        final adhan = di.sl<AdhanNotificationService>();
        await adhan.requestPermissions();
        await di.sl<WirdNotificationService>().requestPermissions();
        if (!mounted) return;
        unawaited(adhan.requestLocationIfNeeded());
      }));
    });
  }

  Future<void> _showAdhanBannerIfNeeded() async {
    final settings = di.sl<SettingsService>();
    if (settings.hasAdhanBannerShown()) return;
    await settings.setAdhanBannerShown();
    if (!mounted) return;

    final isAr = context.read<AppSettingsCubit>().state.appLanguageCode.toLowerCase().startsWith('ar');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          isAr
              ? '🕌 تم تفعيل إشعارات أوقات الصلاة تلقائياً'
              : '🕌 Prayer time notifications enabled automatically',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ),
    );
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
    if (index == 0) _homeKey.currentState?.reload();
    if (index == 1) _bookmarksKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final isArabicUi = context.watch<AppSettingsCubit>().state.appLanguageCode.toLowerCase().startsWith('ar');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IslamicAudioPlayer(isArabicUi: isArabicUi),
          ),
        ],
      ),
      bottomNavigationBar: _AppBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        isArabicUi: isArabicUi,
        isDark: isDark,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom Bottom Navigation Bar
// ─────────────────────────────────────────────────────────────────────────────

class _AppBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isArabicUi;
  final bool isDark;

  const _AppBottomNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.isArabicUi,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? AppColors.darkSurface : AppColors.surface;
    final borderColor = isDark ? AppColors.darkDivider : AppColors.cardBorder;

    final items = [
      _NavItem(Icons.home_outlined, Icons.home_rounded, isArabicUi ? 'الرئيسية' : 'Home'),
      _NavItem(Icons.bookmark_border_rounded, Icons.bookmark_rounded, isArabicUi ? 'الإشارات' : 'Bookmarks'),
      _NavItem(Icons.auto_stories_outlined, Icons.auto_stories_rounded, isArabicUi ? 'الورد' : 'Wird'),
      _NavItem(Icons.grid_view_outlined, Icons.grid_view_rounded, isArabicUi ? 'المزيد' : 'More'),
      _NavItem(Icons.settings_outlined, Icons.settings_rounded, isArabicUi ? 'الإعدادات' : 'Settings'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          top: BorderSide(color: borderColor, width: 0.8),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: AppDesignSystem.bottomNavHeight,
          child: Row(
            children: List.generate(items.length, (i) {
              final item = items[i];
              final isSelected = i == currentIndex;
              return Expanded(
                child: _NavBarItem(
                  icon: isSelected ? item.activeIcon : item.icon,
                  label: item.label,
                  isSelected: isSelected,
                  isDark: isDark,
                  onTap: () => onTap(i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(this.icon, this.activeIcon, this.label);
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = isDark ? AppColors.primaryLight : AppColors.primary;
    final inactiveColor = isDark ? AppColors.darkTextSecondary : AppColors.textHint;
    final color = isSelected ? activeColor : inactiveColor;

    return InkWell(
      onTap: onTap,
      splashColor: activeColor.withValues(alpha: 0.08),
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Active indicator pill
          AnimatedContainer(
            duration: AppDesignSystem.durationNormal,
            curve: Curves.easeOutCubic,
            width: isSelected ? 32 : 0,
            height: 3,
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: isSelected ? activeColor : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          AnimatedScale(
            scale: isSelected ? 1.1 : 1.0,
            duration: AppDesignSystem.durationFast,
            child: Icon(
              icon,
              size: AppDesignSystem.bottomNavIconSize,
              color: color,
            ),
          ),
          const SizedBox(height: 3),
          AnimatedDefaultTextStyle(
            duration: AppDesignSystem.durationFast,
            style: TextStyle(
              fontSize: AppDesignSystem.bottomNavFontSize,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
