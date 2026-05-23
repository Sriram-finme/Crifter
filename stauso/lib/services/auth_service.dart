import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/user_profile.dart';
import 'firebase_service.dart';

class AuthService {
  AuthService._();

  static final _googleSignIn = GoogleSignIn();

  // ── Google Sign-In ─────────────────────────────────────────────────────────

  static Future<UserCredential?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final result =
        await FirebaseService.auth.signInWithCredential(credential);
    if (result.user != null) await _ensureUserProfile(result.user!);
    return result;
  }

  // ── Phone OTP ──────────────────────────────────────────────────────────────

  static Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) codeSent,
    required void Function(String message) onError,
    required void Function() onAutoVerified,
  }) async {
    await FirebaseService.auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (credential) async {
        final result =
            await FirebaseService.auth.signInWithCredential(credential);
        if (result.user != null) await _ensureUserProfile(result.user!);
        onAutoVerified();
      },
      verificationFailed: (e) =>
          onError(e.message ?? 'Verification failed'),
      codeSent: codeSent,
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  static Future<void> signInWithOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final result =
        await FirebaseService.auth.signInWithCredential(credential);
    if (result.user != null) await _ensureUserProfile(result.user!);
  }

  // ── Session ────────────────────────────────────────────────────────────────

  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    await FirebaseService.auth.signOut();
  }

  static User? getCurrentUser() {
    if (!FirebaseService.isReady) return null;
    try {
      return FirebaseService.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  static Stream<User?> authStateChanges() {
    if (!FirebaseService.isReady) return Stream.value(null);
    try {
      return FirebaseService.auth.authStateChanges();
    } catch (_) {
      return Stream.value(null);
    }
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  static Future<void> _ensureUserProfile(User user) async {
    final docRef =
        FirebaseService.firestore.collection('users').doc(user.uid);
    final doc = await docRef.get();
    if (!doc.exists) {
      final profile = UserProfile(
        id: user.uid,
        displayName: user.displayName ?? 'Stauso User',
        phoneNumber: user.phoneNumber ?? '',
        photoUrl: user.photoURL,
        isPremium: false,
        createdAt: DateTime.now(),
        downloadCount: 0,
      );
      await docRef.set(profile.toJson());
    }
  }
}
