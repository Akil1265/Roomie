import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // Added for web clientId logic

enum GoogleSignInStatus { success, cancelled, popupClosed, error }

class GoogleSignInResult {
  final GoogleSignInStatus status;
  final User? user;
  final String? message;
  const GoogleSignInResult(this.status, {this.user, this.message});

  bool get isSuccess => status == GoogleSignInStatus.success;
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _signingIn = false; // prevent concurrent

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb
        ? '1066645245892-jl9q6rnv07bp58vsgun50fb096rsehn3.apps.googleusercontent.com'
        : null,
    scopes: const ['email'],
  );

  Future<GoogleSignInResult> signInWithGoogle() async {
    if (_signingIn) {
      return const GoogleSignInResult(
        GoogleSignInStatus.error,
        message: 'Sign-In already in progress',
      );
    }
    _signingIn = true;
    try {
      GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();
      googleUser ??= await _googleSignIn.signIn();
      if (googleUser == null) {
        return const GoogleSignInResult(GoogleSignInStatus.cancelled);
      }

      final googleAuth = await googleUser.authentication; // API still asynchronous in 7.x
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken; // may be null on web

      if (idToken == null) {
        return const GoogleSignInResult(
          GoogleSignInStatus.error,
          message: 'Missing idToken from Google',
        );
      }

      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: accessToken,
      );

      final userCred = await _auth.signInWithCredential(credential);
      final user = userCred.user;
      if (user == null) {
        return const GoogleSignInResult(
          GoogleSignInStatus.error,
          message: 'Firebase user null after credential sign-in',
        );
      }
      await FirestoreService().saveUserDetails(
        user.uid,
        user.email ?? '',
      );
      return GoogleSignInResult(GoogleSignInStatus.success, user: user);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('popup_closed')) {
        return const GoogleSignInResult(GoogleSignInStatus.popupClosed);
      }
      if (msg.contains('User closed the popup')) {
        return const GoogleSignInResult(GoogleSignInStatus.cancelled);
      }
      return GoogleSignInResult(
        GoogleSignInStatus.error,
        message: msg,
      );
    } finally {
      _signingIn = false;
    }
  }

  Future<void> sendOTP({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(FirebaseAuthException e) onFailed,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // You can auto-login here if needed
        },
        verificationFailed: (FirebaseAuthException e) {
          print('❌ OTP Failed: ${e.message}');
          onFailed(e);
        },
        codeSent: (String verificationId, int? resendToken) {
          print('📨 OTP Code Sent: $verificationId');
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          print('⏳ Auto-retrieval timeout: $verificationId');
        },
      );
    } catch (e) {
      print('❌ sendOTP Error: $e');
      if (e is FirebaseAuthException) {
        onFailed(e); // ✅ Notify the UI of failure
      } else {
        onFailed(
          FirebaseAuthException(
            code: 'unexpected-error',
            message: e.toString(),
          ),
        );
      }
    }
  }

  /// 🔐 Step 2: Sign in using received OTP (from SMS)
  Future<User?> signInWithOTP({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final userCred = await _auth.signInWithCredential(credential);
      // Save user details after successful OTP sign-in
      await FirestoreService().saveUserDetails(
        userCred.user!.uid,
        userCred.user!.phoneNumber ?? '', // Use phone number for OTP sign-in
      );
      return userCred.user;
    } catch (e) {
      print('❌ OTP Sign-In Error: $e');
      return null;
    }
  }

  /// 🔗 Optionally link phone auth with Google
  Future<bool> linkWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return false;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.currentUser?.linkWithCredential(credential);

      return true;
    } catch (e) {
      print('❌ Link with Google Error: $e');
      return false;
    }
  }

  /// ❓ Check if phone number exists in Firestore
  Future<bool> doesPhoneExist(String phoneNumber) async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: phoneNumber)
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      print('❌ Firestore Phone Check Error: $e');
      return false;
    }
  }

  ///  Sign out from both
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// 👤 Current User
  User? get currentUser {
    final user = _auth.currentUser;
    print('Auth: Current user: ${user?.uid} - ${user?.email} - ${user?.displayName}'); // Debug log
    return user;
  }
}
