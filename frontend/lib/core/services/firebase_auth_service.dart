import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Wraps [FirebaseAuth] for phone and anonymous sign-in.
///
/// Handles platform differences:
///   - **Web**: Uses `signInWithPhoneNumber()` + invisible reCAPTCHA
///   - **Mobile**: Uses `verifyPhoneNumber()` with auto-retrieval support
class FirebaseAuthService {
  final FirebaseAuth _auth;
  FirebaseAuthService([FirebaseAuth? auth]) : _auth = auth ?? FirebaseAuth.instance;

  // ── Web-specific state ──────────────────────────────────────────────────
  ConfirmationResult? _webConfirmationResult;

  // ── Phone Verification ──────────────────────────────────────────────────

  /// Starts phone verification.
  ///
  /// [phone] should be a 10-digit Indian number (without +91).
  /// Returns a [Completer] whose future resolves with the verificationId
  /// once Firebase sends the SMS code.
  ///
  /// On Android, if auto-verification succeeds, [onAutoVerified] is called
  /// with the signed-in [UserCredential] instead.
  Future<String?> verifyPhoneNumber(
    String phone, {
    Function(UserCredential)? onAutoVerified,
  }) async {
    final fullPhone = '+91$phone';

    if (kIsWeb) {
      // Web: invisible reCAPTCHA → signInWithPhoneNumber
      _webConfirmationResult = await _auth.signInWithPhoneNumber(fullPhone);
      // On web, the "verificationId" is managed internally by ConfirmationResult.
      // Return a sentinel so the caller knows OTP was sent.
      return '__web__';
    }

    // Mobile: standard verifyPhoneNumber flow
    final completer = Completer<String?>();

    await _auth.verifyPhoneNumber(
      phoneNumber: fullPhone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Android auto-verification (SMS Retriever API)
        final userCred = await _auth.signInWithCredential(credential);
        onAutoVerified?.call(userCred);
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!completer.isCompleted) {
          completer.completeError(e.message ?? 'Phone verification failed');
        }
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!completer.isCompleted) {
          completer.complete(verificationId);
        }
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        // No-op: auto-retrieval timed out, user enters code manually
      },
    );

    return completer.future;
  }

  /// Confirms the OTP code entered by the user.
  ///
  /// [verificationId] is the ID from [verifyPhoneNumber] (mobile)
  /// or `'__web__'` (web).
  Future<UserCredential> verifyOtp(String verificationId, String smsCode) async {
    if (kIsWeb) {
      if (_webConfirmationResult == null) {
        throw Exception('No pending web verification. Call verifyPhoneNumber first.');
      }
      final result = await _webConfirmationResult!.confirm(smsCode);
      _webConfirmationResult = null;
      return result;
    }

    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return _auth.signInWithCredential(credential);
  }

  // ── Anonymous Auth ──────────────────────────────────────────────────────

  /// Signs in anonymously.
  Future<UserCredential> signInAnonymously() {
    return _auth.signInAnonymously();
  }

  // ── Token & Session ─────────────────────────────────────────────────────

  /// Returns a Firebase ID token for the currently signed-in user.
  /// Returns null if no user is signed in.
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    return _auth.currentUser?.getIdToken(forceRefresh);
  }

  /// Signs out of Firebase.
  Future<void> signOut() => _auth.signOut();

  /// Currently signed-in Firebase user (may be null).
  User? get currentUser => _auth.currentUser;

  /// Whether the current Firebase user is anonymous.
  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? false;
}
