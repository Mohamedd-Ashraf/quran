import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import '../../../../core/constants/app_colors.dart';
import '../../../../core/navigation/notification_router.dart';
import '../../../../core/theme/app_design_system.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/services/font_download_manager.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../core/services/tutorial_service.dart';
import '../../../../core/settings/app_settings_cubit.dart';
import '../widgets/islamic_audio_player.dart';
import 'home_screen.dart';
import 'bookmarks_screen.dart';
import 'settings_screen.dart';
import '../../../wird/presentation/screens/wird_screen.dart';
import '../../../islamic/presentation/screens/more_screen.dart';

class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator>
    with WidgetsBindingObserver {
  int _currentIndex = 0;

  final GlobalKey<BookmarksScreenState> _bookmarksKey =
      GlobalKey<BookmarksScreenState>();
  final GlobalKey<HomeScreenState> _homeKey = GlobalKey<HomeScreenState>();

  /// MethodChannel used to pull pending navigation events from native Android
  /// (e.g. when the user taps the Adhan foreground-service notification).
  static const _navChannel = MethodChannel('quraan/navigation');

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    setInAppNotificationRouteHandler(_handleNotificationRouteInTabs);
    _screens = [
      HomeScreen(key: _homeKey),
      BookmarksScreen(
        key: _bookmarksKey,
        onNavigateToHome: () {
          setState(() => _currentIndex = 0);
          _homeKey.currentState?.reload();
        },
      ),
      const WirdScreen(),
      const MoreScreen(),
      const SettingsScreen(),
    ];

    // ── Native navigation channel ──────────────────────────────────────────
    // Handles two scenarios:
    // 1) Push ("navigateTo"): app is already in foreground when notification
    //    is tapped — Kotlin invokes this directly via onNewIntent.
    // 2) Pull ("getPendingNavigation"): cold-start or background-to-foreground —
    //    Flutter calls this in initState postFrameCallback and on resume.
    _navChannel.setMethodCallHandler((call) async {
      if (call.method == 'navigateTo') {
        final route = call.arguments as String?;
        if (route != null && route.isNotEmpty && mounted) {
          navigateFromNotification(route);
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Consume any notification route stored during cold-start via
      // flutter_local_notifications (quiz reminders, iOS adhan fallback).
      consumePendingNotificationRoute();

      // Pull any native Android adhan notification pending route from Kotlin.
      // This covers both cold-start (Kotlin stored it in onCreate) and the
      // first-frame case. Warm-start is handled in didChangeAppLifecycleState.
      await _checkNativePendingNavigation();

      _showAdhanBannerIfNeeded();
      // Show mobile-data consent dialog if font download is waiting.
      _checkFontMobileConsent();
    });

    // Note: Permission requests for notifications and location are now handled
    // in PermissionFlowScreen before reaching MainNavigator.
    // We only need to mark the app as ready for tutorials after a short delay.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(Future.delayed(const Duration(seconds: 2), () async {
        if (!mounted) return;
        di.sl<TutorialService>().markAppReady();
      }));
    });

    // Listen for mobile data consent so we can show the dialog after init.
    FontDownloadManager.instance.addListener(_onFontManagerChanged);
  }

  /// Called when the app transitions between foreground/background.
  /// When the user taps an Adhan notification and the app is brought from
  /// background, [AppLifecycleState.resumed] fires — we pull any pending
  /// native navigation route from Kotlin at this point.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkNativePendingNavigation();
    }
  }

  /// Asks Kotlin if there is a pending navigation destination (set when the
  /// user tapped a native Adhan notification). If one exists, Kotlin returns
  /// the route string and clears it so it is only consumed once.
  Future<void> _checkNativePendingNavigation() async {
    try {
      final route =
          await _navChannel.invokeMethod<String?>('getPendingNavigation');
      if (route != null && route.isNotEmpty && mounted) {
        navigateFromNotification(route);
      }
    } catch (_) {
      // Non-fatal: channel may not be set up on non-Android platforms.
    }
  }

  @override
  void dispose() {
    setInAppNotificationRouteHandler(null);
    WidgetsBinding.instance.removeObserver(this);
    FontDownloadManager.instance.removeListener(_onFontManagerChanged);
    super.dispose();
  }

  bool _handleNotificationRouteInTabs(String route) {
    if (route == NotificationRoute.wird) {
      if (!mounted) return true;
      setState(() => _currentIndex = 2);
      di.sl<TutorialService>().activeTabIndex.value = 2;
      return true;
    }
    return false;
  }

  void _onFontManagerChanged() {
    if (!mounted) return;
    if (FontDownloadManager.instance.awaitingMobileDataConsent) {
      _showMobileDataConsentDialog();
    }
  }

  void _checkFontMobileConsent() {
    if (FontDownloadManager.instance.awaitingMobileDataConsent) {
      _showMobileDataConsentDialog();
    }
  }

  Future<void> _showMobileDataConsentDialog() async {
    final isAr = context
        .read<AppSettingsCubit>()
        .state
        .appLanguageCode
        .toLowerCase()
        .startsWith('ar');

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _MobileDataConsentDialog(isAr: isAr),
    );

    if (!mounted) return;
    if (confirmed == true) {
      await FontDownloadManager.instance
          .allowMobileDataDownload(remember: true);
    } else {
      FontDownloadManager.instance.denyMobileDataDownload();
    }
  }

  Future<void> _showAdhanBannerIfNeeded() async {
    final settings = di.sl<SettingsService>();
    if (settings.hasAdhanBannerShown()) return;
    
    // Check notification permission before showing the snackbar.
    // Don't show "notifications enabled" message if permission is actually denied.
    bool hasNotificationPermission = true;
    if (!kIsWeb) {
      try {
        final status = await ph.Permission.notification.status;
        hasNotificationPermission = status.isGranted;
      } catch (_) {
        // If we can't check, assume granted to avoid false negatives.
      }
    }
    
    // Mark as shown regardless, so we don't keep checking.
    await settings.setAdhanBannerShown();
    
    // Only show success snackbar if permission is actually granted.
    if (!hasNotificationPermission) return;
    if (!mounted) return;

    final isAr = context
        .read<AppSettingsCubit>()
        .state
        .appLanguageCode
        .toLowerCase()
        .startsWith('ar');

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
    di.sl<TutorialService>().activeTabIndex.value = index;
  }

  @override
  Widget build(BuildContext context) {
    final isArabicUi = context
        .watch<AppSettingsCubit>()
        .state
        .appLanguageCode
        .toLowerCase()
        .startsWith('ar');
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
// Mobile data consent dialog
// ─────────────────────────────────────────────────────────────────────────────

class _MobileDataConsentDialog extends StatelessWidget {
  final bool isAr;
  const _MobileDataConsentDialog({required this.isAr});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.signal_cellular_alt_rounded,
                  color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isAr ? 'تحميل خطوط المصحف' : 'Download Mushaf Fonts',
                style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w700, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isAr
                  ? 'أنت متصل حالياً ببيانات الجوال.\n\nخطوط المصحف تحميل لمرة واحدة فقط (٦٥ ميجابايت). هل تريد التحميل الآن؟'
                  : 'You\'re on mobile data.\n\nMushaf fonts are a one-time download (65 MB). Download now?',
              style: GoogleFonts.cairo(fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 14),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 15,
                      color: AppColors.primary.withValues(alpha: 0.8)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isAr
                          ? 'بعد التحميل لن تحتاج إنترنت لعرض المصحف'
                          : 'After download, no internet needed for Mushaf',
                      style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              isAr ? 'لاحقاً' : 'Later',
              style: GoogleFonts.cairo(color: Colors.grey.shade600),
            ),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.download_rounded, size: 18),
            label: Text(
              isAr ? 'تحميل الآن' : 'Download Now',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
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
      _NavItem(Icons.home_outlined, Icons.home_rounded,
          isArabicUi ? 'الرئيسية' : 'Home'),
      _NavItem(Icons.bookmark_border_rounded, Icons.bookmark_rounded,
          isArabicUi ? 'الإشارات' : 'Bookmarks'),
      _NavItem(Icons.auto_stories_outlined, Icons.auto_stories_rounded,
          isArabicUi ? 'الورد' : 'Wird'),
      _NavItem(Icons.grid_view_outlined, Icons.grid_view_rounded,
          isArabicUi ? 'المزيد' : 'More'),
      _NavItem(Icons.settings_outlined, Icons.settings_rounded,
          isArabicUi ? 'الإعدادات' : 'Settings'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(top: BorderSide(color: borderColor, width: 0.8)),
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
    final activeColor =
        isDark ? AppColors.primaryLight : AppColors.primary;
    final inactiveColor =
        isDark ? AppColors.darkTextSecondary : AppColors.textHint;
    final color = isSelected ? activeColor : inactiveColor;

    return InkWell(
      onTap: onTap,
      splashColor: activeColor.withValues(alpha: 0.10),
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: AppDesignSystem.durationNormal,
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? activeColor.withValues(alpha: isDark ? 0.18 : 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: AnimatedScale(
              scale: isSelected ? 1.12 : 1.0,
              duration: AppDesignSystem.durationFast,
              child: Icon(
                icon,
                size: AppDesignSystem.bottomNavIconSize,
                color: color,
              ),
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
