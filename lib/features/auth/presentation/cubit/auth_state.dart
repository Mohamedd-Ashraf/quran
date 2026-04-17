import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum AuthStatus {
  /// Initial state before the auth check has completed.
  unknown,

  /// User is authenticated (Google or email/password).
  authenticated,

  /// User chose guest mode (anonymous Firebase auth succeeded).
  guest,

  /// User chose guest mode but had no internet — Firebase auth was not called.
  /// The app works in read-only/local mode. Clears on next app restart once
  /// internet is available and the user signs in properly.
  offlineGuest,

  /// User is not authenticated at all.
  unauthenticated,
}

class AuthState extends Equatable {
  final AuthStatus status;
  final User? user;
  final String? errorMessage;
  final bool isLoading;
  /// True while cloud sync is running in the background after sign-in.
  final bool isSyncing;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.errorMessage,
    this.isLoading = false,
    this.isSyncing = false,
  });

  /// Display name: Google/email name, or guest fallback.
  String get displayName {
    if (status == AuthStatus.offlineGuest) return 'زائر';
    if (user == null) return '';
    if (user!.isAnonymous) return 'زائر';
    return user!.displayName ?? user!.email?.split('@').first ?? '';
  }

  /// Email address (empty for guests).
  String get email => user?.email ?? '';

  /// Whether user has a real account (not anonymous).
  bool get hasAccount => status == AuthStatus.authenticated;

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? errorMessage,
    bool? isLoading,
    bool? isSyncing,
    bool clearError = false,
    bool clearUser = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
    );
  }

  @override
  List<Object?> get props => [status, user?.uid, user?.displayName, errorMessage, isLoading, isSyncing];
}
