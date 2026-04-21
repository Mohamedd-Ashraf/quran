import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../features/islamic/presentation/screens/prayer_times_screen.dart';
import '../../features/quiz/presentation/screens/quiz_screen.dart';
import '../../features/quiz/presentation/widgets/quiz_sign_in_sheet.dart';

/// Global [NavigatorKey] shared across the entire app.
/// Passed to [MaterialApp.navigatorKey] so every part of the codebase
/// can push/pop routes without a [BuildContext].
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Route identifiers carried in notification payloads.
class NotificationRoute {
  static const String quiz = 'quiz';
  static const String prayerTimes = 'prayer_times';
}

/// Pending route for cold-start scenario (app was killed when notification was tapped).
/// Set before [runApp] and consumed by [MainNavigator.initState].
String? _pendingNotificationRoute;

/// Called to set the pending route before the widget tree is built.
void setPendingNotificationRoute(String route) {
  _pendingNotificationRoute = route;
}

/// Called from [MainNavigator.initState] to handle any pending notification
/// route that was set during a cold start.
void consumePendingNotificationRoute() {
  final route = _pendingNotificationRoute;
  _pendingNotificationRoute = null;
  if (route == null) return;
  // Defer until after first frame so [appNavigatorKey] is attached.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    navigateFromNotification(route);
  });
}

/// Core routing function. Works regardless of current app state —
/// works when app is in foreground, background, or freshly launched.
void navigateFromNotification(String route) {
  final nav = appNavigatorKey.currentState;
  if (nav == null) {
    // Navigator not yet mounted — store for deferred consumption.
    _pendingNotificationRoute = route;
    return;
  }

  if (route == NotificationRoute.quiz) {
    _openQuiz(nav);
  } else if (route == NotificationRoute.prayerTimes) {
    _openPrayerTimes(nav);
  }
}

void _openQuiz(NavigatorState nav) {
  // Check auth: show sign-in sheet for anonymous/unauthenticated users,
  // then proceed to QuizScreen. The QuizScreen itself starts with the
  // landing view so the timer never runs on the user's back.
  final user = FirebaseAuth.instance.currentUser;
  if (user == null || user.isAnonymous) {
    final context = appNavigatorKey.currentContext;
    if (context == null) return;
    final isArabic = Localizations.localeOf(context).languageCode.startsWith('ar');
    showQuizSignInSheet(
      context,
      isArabic: isArabic,
      onAuthenticated: () => nav.push(
        MaterialPageRoute(builder: (_) => const QuizScreen(fromNotification: true)),
      ),
    );
  } else {
    nav.push(MaterialPageRoute(builder: (_) => const QuizScreen(fromNotification: true)));
  }
}

void _openPrayerTimes(NavigatorState nav) {
  // Pop to root first so we don't stack duplicate screens.
  nav.popUntil((route) => route.isFirst);
  nav.push(MaterialPageRoute(builder: (_) => const PrayerTimesScreen()));
}
