import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';

/// Wraps Firebase Authentication and Google Sign-In into a single service.
class AuthService {
  static const String _googleServerClientId =
      '1039427063284-md9k0adeefljpu1rr0vg8sksboq7el7u.apps.googleusercontent.com';

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  Future<void>? _androidGoogleInitFuture;

  AuthService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ??
            GoogleSignIn(
              // Web client ID (client_type: 3) from google-services.json.
              // Required by google_sign_in_android 6.2+ to obtain idToken
              // via the Credential Manager API on Android 14+.
              serverClientId: _googleServerClientId,
            ) {
    unawaited(_warmUpGoogleSignIn());
  }

  /// Current Firebase user (null when signed out or guest).
  User? get currentUser => _auth.currentUser;

  /// Whether the user is currently authenticated (not anonymous).
  bool get isAuthenticated {
    final user = currentUser;
    return user != null && !user.isAnonymous;
  }

  /// Whether the user is in guest mode (anonymous auth).
  bool get isGuest {
    final user = currentUser;
    return user != null && user.isAnonymous;
  }

  /// Real-time auth state stream.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Google Sign-In ──────────────────────────────────────────────────────

  Future<void> _warmUpGoogleSignIn() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _ensureAndroidGoogleSignInInitialized();
      } catch (e) {
        debugPrint('Google sign-in warm-up failed: $e');
      }
    }
  }

  Future<void> _ensureAndroidGoogleSignInInitialized() {
    return _androidGoogleInitFuture ??=
        GoogleSignInPlatform.instance.initWithParams(
          SignInInitParameters(
            signInOption: SignInOption.standard,
            scopes: const <String>[],
            serverClientId: _googleServerClientId,
          ),
        );
  }

  /// Signs in with Google. Returns the [UserCredential] on success.
  Future<UserCredential> signInWithGoogle() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return _signInWithGoogleOnAndroid();
    }

    GoogleSignInAccount? googleUser;
    try {
      googleUser = await _googleSignIn.signIn();
    } on PlatformException catch (e, st) {
      debugPrint(
        'GoogleSignIn.signIn() PlatformException — '
        'code: ${e.code} | message: ${e.message} | details: ${e.details}',
      );
      debugPrint('Stack trace: $st');
      rethrow;
    }
    if (googleUser == null) {
      throw AuthCancelledException(
        code: 'sign-in-cancelled',
        message: 'Google sign-in was cancelled by the user.',
      );
    }

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) {
      await _googleSignIn.signOut();
      throw AuthCancelledException(
        code: 'missing-id-token',
        message: 'Google sign-in did not return an ID token. '
            'Ensure the serverClientId is correct and the SHA-1 '
            'fingerprint is registered in Firebase Console.',
      );
    }
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: idToken,
    );

    // If already signed in anonymously, link the Google credential.
    final user = _auth.currentUser;
    if (user != null && user.isAnonymous) {
      try {
        return await user.linkWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use') {
          // Another account already uses this Google credential.
          // Sign out anonymous, sign in with Google directly.
          await _auth.signOut();
          return await _auth.signInWithCredential(credential);
        }
        rethrow;
      }
    }

    return await _auth.signInWithCredential(credential);
  }

  Future<UserCredential> _signInWithGoogleOnAndroid() async {
    await _ensureAndroidGoogleSignInInitialized();

    final googleUser = await GoogleSignInPlatform.instance.signIn();
    if (googleUser == null) {
      throw AuthCancelledException(
        code: 'sign-in-cancelled',
        message: 'Google sign-in was cancelled by the user.',
      );
    }

    final idToken = googleUser.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw AuthCancelledException(
        code: 'missing-id-token',
        message: 'Google sign-in completed without an ID token.',
      );
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final user = _auth.currentUser;
    if (user != null && user.isAnonymous) {
      try {
        return await user.linkWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use') {
          await _auth.signOut();
          return await _auth.signInWithCredential(credential);
        }
        rethrow;
      }
    }

    return await _auth.signInWithCredential(credential);
  }

  // ── Email / Password ────────────────────────────────────────────────────

  /// Creates a new account with email & password, then sets [displayName].
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    // If already signed in anonymously, link email credential.
    final user = _auth.currentUser;
    if (user != null && user.isAnonymous) {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      try {
        final result = await user.linkWithCredential(credential);
        await result.user?.updateDisplayName(displayName);
        return result;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          await _auth.signOut();
          return await _auth.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
        }
        rethrow;
      }
    }

    final result = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await result.user?.updateDisplayName(displayName);
    return result;
  }

  /// Signs in with an existing email & password.
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Sends a password-reset email.
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // ── Guest (anonymous) ───────────────────────────────────────────────────

  /// Signs in anonymously (guest mode).
  Future<UserCredential> signInAsGuest() async {
    return await _auth.signInAnonymously();
  }

  // ── Sign Out ────────────────────────────────────────────────────────────

  /// Signs out of Firebase and Google.
  Future<void> signOut() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await GoogleSignInPlatform.instance.signOut();
      } catch (e) {
        debugPrint('GoogleSignInPlatform.signOut failed: $e');
      }
    } else {
      try {
        await _googleSignIn.signOut();
      } catch (e) {
        debugPrint('GoogleSignIn.signOut failed: $e');
      }
    }
    await _auth.signOut();
  }

  // ── Account Deletion ────────────────────────────────────────────────────

  /// Deletes the current user account and returns the UID for Firestore cleanup.
  /// Throws [FirebaseAuthException] with code 'requires-recent-login' if
  /// re-authentication is needed.
  Future<String> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'no-user');
    final uid = user.uid;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await GoogleSignInPlatform.instance.signOut();
      } catch (_) {}
    } else {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
    }
    await user.delete();
    return uid;
  }
}

/// Custom exception for auth-cancelled scenarios.
class AuthCancelledException implements Exception {
  final String code;
  final String message;
  const AuthCancelledException({required this.code, required this.message});

  @override
  String toString() => 'AuthCancelledException($code): $message';
}
