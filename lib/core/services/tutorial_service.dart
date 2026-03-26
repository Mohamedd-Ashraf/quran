import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/tutorial_config.dart';
import 'settings_service.dart';

class TutorialService {
  final SharedPreferences _prefs;

  static const String _prefix = 'tutorial_';

  // Screen keys
  static const String homeScreen = 'home';
  static const String bookmarksScreen = 'bookmarks';
  static const String wirdScreen = 'wird';
  static const String moreScreen = 'more';
  static const String settingsScreen = 'settings';
  static const String surahDetailScreen = 'surah_detail';
  static const String prayerTimesScreen = 'prayer_times';
  static const String adhkarScreen = 'adhkar';
  static const String tasbeehScreen = 'tasbeeh';
  static const String searchScreen = 'search';
  static const String mushafScreen = 'mushaf';

  static const List<String> allScreenKeys = [
    homeScreen,
    bookmarksScreen,
    wirdScreen,
    moreScreen,
    settingsScreen,
    surahDetailScreen,
    prayerTimesScreen,
    adhkarScreen,
    tasbeehScreen,
    searchScreen,
    mushafScreen,
  ];

  TutorialService(this._prefs);

  // ── Active tab tracking ─────────────────────────────────────────────────
  final ValueNotifier<int> activeTabIndex = ValueNotifier<int>(0);

  // ── App-ready gate ──────────────────────────────────────────────────────
  /// Completes once permission dialogs, banners, and other startup overlays
  /// have finished so tutorials never appear underneath them.
  /// [MainNavigator] calls [markAppReady] after the startup sequence ends.
  final Completer<void> _appReadyCompleter = Completer<void>();

  /// Future that resolves when the app is ready for tutorial overlays.
  Future<void> get appReady => _appReadyCompleter.future;

  /// Whether [markAppReady] has already been called.
  bool get isAppReady => _appReadyCompleter.isCompleted;

  /// Signal that permission requests, banners, and feedback dialogs are done.
  void markAppReady() {
    if (!_appReadyCompleter.isCompleted) _appReadyCompleter.complete();
  }

  String _key(String screenKey) => '$_prefix$screenKey';

  bool isTutorialComplete(String screenKey) {
    // If tutorials feature is disabled, treat all as complete (don't show).
    if (!SettingsService.enableTutorialsFeature) return true;
    // When force-show is on, always treat every tutorial as "not yet seen".
    if (TutorialConfig.kAlwaysShowTutorial) return false;
    return _prefs.getBool(_key(screenKey)) ?? false;
  }

  Future<void> markComplete(String screenKey) async {
    await _prefs.setBool(_key(screenKey), true);
  }

  Future<void> resetScreen(String screenKey) async {
    await _prefs.remove(_key(screenKey));
  }

  Future<void> resetAll() async {
    for (final key in allScreenKeys) {
      await _prefs.remove(_key(key));
    }
  }
}
