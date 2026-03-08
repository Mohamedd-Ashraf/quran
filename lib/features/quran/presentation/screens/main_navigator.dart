import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
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
  }

  @override
  Widget build(BuildContext context) {
    final isArabicUi = context.watch<AppSettingsCubit>().state.appLanguageCode.toLowerCase().startsWith('ar');
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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });

            if (index == 0) {
              _homeKey.currentState?.reload();
            }
            if (index == 1) {
              _bookmarksKey.currentState?.reload();
            }
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_outlined),
              activeIcon: const Icon(Icons.home),
              label: isArabicUi ? 'الرئيسية' : 'Home',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.bookmark_border),
              activeIcon: const Icon(Icons.bookmark),
              label: isArabicUi ? 'الإشارات' : 'Bookmarks',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.auto_stories_outlined),
              activeIcon: const Icon(Icons.auto_stories),
              label: isArabicUi ? 'الورد' : 'Wird',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.grid_view_outlined),
              activeIcon: const Icon(Icons.grid_view),
              label: isArabicUi ? 'المزيد' : 'More',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.settings_outlined),
              activeIcon: const Icon(Icons.settings),
              label: isArabicUi ? 'الإعدادات' : 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
