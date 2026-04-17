import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/auth_service.dart';
import '../../data/cloud_sync_service.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthService _authService;
  final CloudSyncService _syncService;
  StreamSubscription<User?>? _authSub;

  AuthCubit(this._authService, this._syncService)
      : super(const AuthState()) {
    _authSub = _authService.authStateChanges.listen(_onAuthChanged);
  }

  void _onAuthChanged(User? user) {
    if (user == null) {
      emit(state.copyWith(
        status: AuthStatus.unauthenticated,
        clearUser: true,
        clearError: true,
        isLoading: false,
      ));
    } else if (user.isAnonymous) {
      emit(state.copyWith(
        status: AuthStatus.guest,
        user: user,
        clearError: true,
        isLoading: false,
      ));
    } else {
      emit(state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        clearError: true,
        isLoading: false,
      ));
      // Sync data in background after authentication
      _syncInBackground(user);
    }
  }

  Future<void> _syncInBackground(User user) async {
    emit(state.copyWith(isSyncing: true));
    try {
      await _syncService.syncAll(user);
    } catch (e) {
      debugPrint('AuthCubit: background sync failed: $e');
    } finally {
      emit(state.copyWith(isSyncing: false));
    }
  }

  // ── Google Sign-In ──────────────────────────────────────────────────────

  Future<void> signInWithGoogle() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      await _authService.signInWithGoogle();
      // State update happens via _onAuthChanged
    } catch (e, st) {
      debugPrint('AuthCubit: signInWithGoogle error: $e\n$st');
      emit(state.copyWith(
        isLoading: false,
        errorMessage: _mapError(e),
      ));
    }
  }

  // ── Email / Password ────────────────────────────────────────────────────

  Future<void> signUpWithEmail(String email, String password, String displayName) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      await _authService.signUpWithEmail(email: email, password: password, displayName: displayName);
      // updateDisplayName completes after authStateChanges fires, so re-emit with fresh user
      final updatedUser = _authService.currentUser;
      if (updatedUser != null && !updatedUser.isAnonymous) {
        emit(state.copyWith(
          status: AuthStatus.authenticated,
          user: updatedUser,
          clearError: true,
          isLoading: false,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: _mapError(e),
      ));
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      await _authService.signInWithEmail(email: email, password: password);
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: _mapError(e),
      ));
    }
  }

  Future<void> sendPasswordReset(String email) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      await _authService.sendPasswordResetEmail(email);
      emit(state.copyWith(isLoading: false));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: _mapError(e),
      ));
    }
  }

  // ── Guest ───────────────────────────────────────────────────────────────

  Future<void> continueAsGuest() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      // Check connectivity before hitting Firebase — avoids a hanging request
      // and gives instant feedback on the offline path.
      final connectivity = await Connectivity().checkConnectivity();
      final isOffline = connectivity.every((r) => r == ConnectivityResult.none);
      if (isOffline) {
        emit(state.copyWith(
          status: AuthStatus.offlineGuest,
          isLoading: false,
          clearError: true,
        ));
        return;
      }
      await _authService.signInAsGuest();
      // Success → state update happens via _onAuthChanged stream.
    } catch (e) {
      // Network failure during Firebase call → treat as offline guest.
      if (e is FirebaseAuthException && e.code == 'network-request-failed') {
        emit(state.copyWith(
          status: AuthStatus.offlineGuest,
          isLoading: false,
          clearError: true,
        ));
        return;
      }
      emit(state.copyWith(
        isLoading: false,
        errorMessage: _mapError(e),
      ));
    }
  }

  // ── Sign Out ────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    // Offline guest has no Firebase session — just reset state locally.
    if (state.status == AuthStatus.offlineGuest) {
      emit(state.copyWith(
        status: AuthStatus.unauthenticated,
        clearUser: true,
        clearError: true,
        isLoading: false,
      ));
      return;
    }
    // Upload data before signing out (if authenticated)
    final user = _authService.currentUser;
    if (user != null && !user.isAnonymous) {
      try {
        await _syncService.uploadAll(user);
      } catch (_) {}
    }
    await _authService.signOut();
  }

  // ── Manual Sync ─────────────────────────────────────────────────────────

  Future<void> manualSync() async {
    final user = _authService.currentUser;
    if (user == null || user.isAnonymous) return;
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      await _syncService.uploadAll(user);
      emit(state.copyWith(isLoading: false));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: _mapError(e),
      ));
    }
  }

  // ── Delete Account ──────────────────────────────────────────────────────

  Future<void> deleteAccount() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final uid = await _authService.deleteAccount();
      // Delete Firestore data after the auth account is removed.
      await _syncService.deleteUserData(uid);
      // _onAuthChanged(null) fires automatically via authStateChanges,
      // which transitions us to unauthenticated. No extra emit needed.
    } catch (e) {
      final isFbException = e is FirebaseAuthException;
      final needsReauth = isFbException && e.code == 'requires-recent-login';
      emit(state.copyWith(
        isLoading: false,
        errorMessage: needsReauth
            ? 'يرجى تسجيل الخروج ثم تسجيل الدخول مجدداً قبل حذف الحساب'
            : _mapError(e),
      ));
    }
  }

  // ── Clear Error ─────────────────────────────────────────────────────────

  void clearError() {
    emit(state.copyWith(clearError: true));
  }

  // ── Error Mapping ───────────────────────────────────────────────────────

  String _mapError(Object e) {
    if (e is AuthCancelledException) {
      return 'تم إلغاء تسجيل الدخول';
    }
    if (e is FirebaseException) {
      switch (e.code) {
        case 'user-not-found':
          return 'لا يوجد حساب بهذا البريد الإلكتروني';
        case 'wrong-password':
          return 'كلمة المرور غير صحيحة';
        case 'email-already-in-use':
          return 'البريد الإلكتروني مستخدم بالفعل';
        case 'weak-password':
          return 'كلمة المرور ضعيفة جداً';
        case 'invalid-email':
          return 'البريد الإلكتروني غير صالح';
        case 'too-many-requests':
          return 'محاولات كثيرة، حاول لاحقاً';
        case 'network-request-failed':
          return 'خطأ في الاتصال بالإنترنت';
        case 'invalid-credential':
          return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
        default:
          return 'حدث خطأ: ${e.message ?? e.code}';
      }
    }
    debugPrint('AuthCubit: unexpected error (${e.runtimeType}): $e');
    return 'حدث خطأ غير متوقع: $e';
  }

  @override
  Future<void> close() {
    _authSub?.cancel();
    return super.close();
  }
}
