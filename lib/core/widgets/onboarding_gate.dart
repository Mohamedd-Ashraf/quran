import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../di/injection_container.dart' as di;
import '../services/settings_service.dart';
import '../services/whats_new_service.dart';
import '../services/feedback_service.dart';
import '../services/font_download_manager.dart';
import '../settings/app_settings_cubit.dart';
import '../widgets/whats_new_screen.dart';
import '../widgets/feedback_dialog.dart';
import '../widgets/permission_flow_screen.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/auth/presentation/cubit/auth_state.dart';
import '../../features/auth/presentation/screens/auth_screen.dart';
import '../../features/islamic/presentation/screens/onboarding_screen.dart';
import '../../features/islamic/presentation/screens/splash_page.dart';
import '../../features/quran/presentation/screens/main_navigator.dart';

class OnboardingGate extends StatefulWidget {
  const OnboardingGate({super.key});

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  late final SettingsService _settings;
  late final WhatsNewService _whatsNewService;

  bool _showSplash = true;
  bool? _onboardingComplete;
  // Whether auth has been completed (or user is already signed in).
  bool _authComplete = false;
  // Whether permission flow has been completed.
  bool? _permissionFlowComplete;
  // null = not yet checked, true = show, false = skip
  bool? _showWhatsNew;
  String _appVersion = '';
  String? _lastSeenVersion;
  // Guard: feedback prompt shown at most once per app session.
  bool _feedbackCheckDone = false;
  // null = checking, false = done (background download handles it)
  bool? _showFontReminder;

  @override
  void initState() {
    super.initState();
    _settings = di.sl<SettingsService>();
    _whatsNewService = di.sl<WhatsNewService>();
    _onboardingComplete = _settings.getOnboardingComplete();
    _permissionFlowComplete = _settings.getPermissionFlowComplete();
  }

  // Called when the splash animation completes.
  void _finishSplash() {
    if (!mounted) return;
    setState(() {
      _showSplash = false;
    });
    // If onboarding is already done, check auth status.
    if (_onboardingComplete == true) {
      _checkAuthAndProceed();
    }
  }

  // Called when the user taps "Get Started" on the onboarding screen.
  Future<void> _markOnboardingComplete() async {
    await _settings.setOnboardingComplete(true);
    if (!mounted) return;
    setState(() {
      _onboardingComplete = true;
    });
    // After onboarding, check if user is already authenticated.
    _checkAuthAndProceed();
  }

  // Checks whether the user is already authenticated.
  // If yes, skip the auth screen. If no, it will be shown in build().
  void _checkAuthAndProceed() {
    final authState = context.read<AuthCubit>().state;
    if (authState.status == AuthStatus.authenticated ||
        authState.status == AuthStatus.guest) {
      _authComplete = true;
      _checkPermissionFlowAndProceed();
    }
    // Otherwise, build() will show the AuthScreen.
  }

  // Called when auth completes (sign-in, sign-up, or guest).
  void _onAuthComplete() {
    if (!mounted) return;
    setState(() {
      _authComplete = true;
    });
    _checkPermissionFlowAndProceed();
  }

  // Check if permission flow was completed before.
  void _checkPermissionFlowAndProceed() {
    if (_permissionFlowComplete == true) {
      // Permission flow already completed, skip to What's New.
      _checkWhatsNew();
    }
    // Otherwise, build() will show the PermissionFlowScreen.
  }

  // Called when permission flow completes.
  Future<void> _onPermissionFlowComplete() async {
    await _settings.setPermissionFlowComplete(true);
    if (!mounted) return;
    setState(() {
      _permissionFlowComplete = true;
    });
    _checkWhatsNew();
  }

  // Async check – runs after onboarding is confirmed complete.
  Future<void> _checkWhatsNew() async {
    final shouldShow = await _whatsNewService.shouldShow();
    final version = await _whatsNewService.currentVersion();
    final lastSeen = await _whatsNewService.lastSeenVersion();
    if (!mounted) return;
    setState(() {
      _showWhatsNew = shouldShow;
      _appVersion = version;
      _lastSeenVersion = lastSeen;
    });
    // No What's New to show → check font reminder, then feedback.
    if (!shouldShow) {
      _checkFontReminder();
    }
  }

  // Starts the background font download if needed and proceeds to the app
  // immediately — no blocking screen shown to the user.
  Future<void> _checkFontReminder() async {
    if (!mounted) return;
    // Never block — go to main app right away.
    setState(() => _showFontReminder = false);
    // Kick off download in background (no await).
    unawaited(FontDownloadManager.instance.startIfNeeded());
    _maybeShowFeedback();
  }

  // Called when the user dismisses the What's New screen.
  void _dismissWhatsNew() {
    if (!mounted) return;
    setState(() {
      _showWhatsNew = false;
    });
    // Check font reminder next, then feedback.
    _checkFontReminder();
  }

  // Shows the feedback dialog only once per session, and only when appropriate.
  Future<void> _maybeShowFeedback() async {
    if (_feedbackCheckDone || !mounted) return;
    _feedbackCheckDone = true;

    final feedbackService = di.sl<FeedbackService>();
    if (!feedbackService.shouldShow()) return;

    // Brief pause so the main navigator settles before the dialog appears.
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    final languageCode =
        context.read<AppSettingsCubit>().state.appLanguageCode;
    await showFeedbackDialog(
      context: context,
      feedbackService: feedbackService,
      languageCode: languageCode,
    );
  }

  @override
  Widget build(BuildContext context) {
    // ── 1. Splash ──────────────────────────────────────────────────────────
    if (_showSplash) {
      return SplashPage(onFinish: _finishSplash);
    }

    // ── 2. Onboarding ──────────────────────────────────────────────────────
    if (_onboardingComplete != true) {
      return OnboardingScreen(onContinue: _markOnboardingComplete);
    }

    // ── 3. Authentication ──────────────────────────────────────────────────
    // Listen to auth state so that when the user signs out we reset _authComplete.
    return BlocListener<AuthCubit, AuthState>(
      listenWhen: (prev, curr) => prev.status != curr.status,
      listener: (context, state) {
        if (state.status == AuthStatus.unauthenticated) {
          setState(() {
            _authComplete = false;
            _showWhatsNew = null;
          });
        } else if ((state.status == AuthStatus.authenticated ||
                state.status == AuthStatus.guest) &&
            !_authComplete) {
          // Firebase stream fired after splash — skip auth screen
          _onAuthComplete();
        }
      },
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    // ── 3. Authentication ──────────────────────────────────────────────────
    if (!_authComplete) {
      final authStatus = context.read<AuthCubit>().state.status;
      if (authStatus == AuthStatus.unknown) {
        // Firebase hasn't responded yet — show loading.
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }
      if (authStatus == AuthStatus.authenticated ||
          authStatus == AuthStatus.guest) {
        // Firebase already authenticated but BlocListener missed it
        // (state changed while SplashPage was showing).
        // Schedule the auth-complete transition safely outside build.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_authComplete) _onAuthComplete();
        });
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }
      return AuthScreen(onAuthComplete: _onAuthComplete);
    }

    // ── 4. Permission Flow (Location & Notifications) ──────────────────────
    if (_permissionFlowComplete != true) {
      return PermissionFlowScreen(onComplete: _onPermissionFlowComplete);
    }

    // ── 5. What's New check loading ────────────────────────────────────────
    if (_showWhatsNew == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // ── 6. What's New screen ───────────────────────────────────────────────
    if (_showWhatsNew == true) {
      return WhatsNewScreen(
        whatsNewService: _whatsNewService,
        onDismiss: _dismissWhatsNew,
        version: _appVersion,
        lastSeenVersion: _lastSeenVersion,
      );
    }

    // ── 6b. Font download runs in background — no blocking screen ─────────
    // _showFontReminder is always false here; the download manager handles it.
    if (_showFontReminder == null) {
      // Brief async gap before _checkFontReminder fires — show spinner.
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // ── 7. Main app ────────────────────────────────────────────────────────
    return BlocBuilder<AuthCubit, AuthState>(
      buildWhen: (prev, curr) => prev.isSyncing != curr.isSyncing,
      builder: (context, authState) {
        return Stack(
          children: [
            const MainNavigator(),
            if (authState.isSyncing)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(minHeight: 2),
              ),
          ],
        );
      },
    );
  }
}
