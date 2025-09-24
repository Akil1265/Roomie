import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

enum GoogleSignInStatus { success, cancelled, popupClosed, error }

class GoogleSignInResult {
  final GoogleSignInStatus status;
  final User? user;
  final String? message;
  const GoogleSignInResult(this.status, {this.user, this.message});

  bool get isSuccess => status == GoogleSignInStatus.success;
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _signingIn = false; // prevent concurrent

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<GoogleSignInResult> signInWithGoogle() async {
    if (_signingIn) {
      return const GoogleSignInResult(
        GoogleSignInStatus.error,
        message: 'Sign-In already in progress',
      );
    }
    _signingIn = true;
    try {
      UserCredential userCredential;
      
      if (kIsWeb) {
        // For web, use Firebase Auth directly with Google provider
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        userCredential = await _auth.signInWithPopup(googleProvider);
      } else {
        // For mobile, use Google Sign-In package
        final GoogleSignIn googleSignIn = GoogleSignIn(
          scopes: ['email'],
        );
        
        // Sign out first to ensure fresh sign-in
        await googleSignIn.signOut();
        
        // Trigger the authentication flow
        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
        
        if (googleUser == null) {
          // User cancelled the sign-in
          return const GoogleSignInResult(GoogleSignInStatus.cancelled);
        }
        
        // Obtain the auth details from the request
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        
        // Create a new credential
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        
        // Sign in to Firebase with the Google credential
        userCredential = await _auth.signInWithCredential(credential);
      }
      
      final user = userCredential.user;
      
      if (user == null) {
        return const GoogleSignInResult(
          GoogleSignInStatus.error,
          message: 'Firebase user null after Google sign-in',
        );
      }
      
      // Save user details to Firestore
      await FirestoreService().saveUserDetails(
        user.uid,
        user.email ?? '',
        name: user.displayName,
      );
      
      return GoogleSignInResult(GoogleSignInStatus.success, user: user);
    } catch (e) {
      final msg = e.toString();
      print('🚨 Google Sign-In Error: $msg');
      
      // Handle different error types
      if (msg.contains('popup-blocked') || 
          msg.contains('popup-closed-by-user') ||
          msg.contains('cancelled-popup-request')) {
        return const GoogleSignInResult(GoogleSignInStatus.popupClosed);
      }
      if (msg.contains('user-cancelled') || 
          msg.contains('cancelled') ||
          msg.contains('auth/cancelled-popup-request') ||
          msg.contains('sign_in_canceled')) {
        return const GoogleSignInResult(GoogleSignInStatus.cancelled);
      }
      if (msg.contains('network') || msg.contains('connection')) {
        return const GoogleSignInResult(
          GoogleSignInStatus.error,
          message: 'Network error. Please check your internet connection.',
        );
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
        '', // Empty email for phone auth
        phone: userCred.user!.phoneNumber, // Store phone number in phone field
      );
      return userCred.user;
    } catch (e) {
      print('❌ OTP Sign-In Error: $e');
      return null;
    }
  }

  /// 🔗 Optionally link phone auth with Google (Now using Firebase Auth directly)
  Future<bool> linkWithGoogle() async {
    try {
      final GoogleAuthProvider googleProvider = GoogleAuthProvider();
      await _auth.currentUser?.linkWithProvider(googleProvider);
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

  ///  Sign out from Firebase Auth and Google Sign-In
  Future<void> signOut() async {
    try {
      // Sign out from Google Sign-In if not on web
      if (!kIsWeb) {
        final GoogleSignIn googleSignIn = GoogleSignIn();
        await googleSignIn.signOut();
      }
      
      // Sign out from Firebase Auth
      await _auth.signOut();
      print('✅ Successfully signed out');
    } catch (e) {
      print('❌ Sign-out Error: $e');
    }
  }
}
