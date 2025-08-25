import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 🔑 Google Sign-In instance
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
    // Ensure we're requesting the right scope
  );

  /// ✅ Google Sign-In (Login or Sign Up)
  Future<bool> signInWithGoogle() async {
    try {
      print('🔄 Starting Google Sign-In...');

      // Force sign out first to ensure clean state
      await _googleSignIn.signOut();
      print('🔄 Cleared previous Google Sign-In state');

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      print('📱 Google Sign-In dialog result: ${googleUser?.email ?? "null"}');

      if (googleUser == null) {
        print('❌ Google Sign-In cancelled by user');
        return false;
      }

      print('🔑 Getting authentication credentials...');
      final googleAuth = await googleUser.authentication;

      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        print('❌ Failed to get authentication tokens');
        return false;
      }

      print('🔑 Creating Firebase credential...');
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print('🔥 Signing in with Firebase...');
      final userCred = await _auth.signInWithCredential(credential);

      if (userCred.user == null) {
        print('❌ Firebase authentication failed - no user returned');
        return false;
      }

      print('💾 Saving user details to Firestore...');
      await FirestoreService().saveUserDetails(
        userCred.user!.uid,
        userCred.user!.email ?? '',
      );

      print('✅ Google Sign-In completed successfully');
      return true;
    } catch (e) {
      print('❌ Google Sign-In Error: $e');
      print('❌ Error type: ${e.runtimeType}');
      if (e is FirebaseAuthException) {
        print('❌ Firebase Auth Error Code: ${e.code}');
        print('❌ Firebase Auth Error Message: ${e.message}');
      }
      return false;
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
      final query =
          await FirebaseFirestore.instance
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
    print(
      'Auth: Current user: ${user?.uid} - ${user?.email} - ${user?.displayName}',
    ); // Debug log
    return user;
  }
}
