import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'otp_s.dart';
import 'user_details_s.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _phoneController = TextEditingController();
  bool _loading = false;

  void _sendOTP() async {
    String phone = _phoneController.text.trim();
    if (!phone.startsWith('+91')) {
      phone = '+91$phone';
    }

    setState(() => _loading = true);

    /// ✅ Send OTP for all users (new or existing)
    await AuthService().sendOTP(
      phoneNumber: phone,
      onCodeSent: (verificationId) {
        setState(() => _loading = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtpScreen(verificationId: verificationId),
            settings: RouteSettings(arguments: phone), // Pass phone number here
          ),
        );
      },
      onFailed: (e) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Phone Auth Error: ${e.message}')),
        );
      },
    );
  }

  Future<void> _googleSignIn() async {
    setState(() => _loading = true);
    final authService = AuthService();

    try {
      print('🔄 Login: Starting Google Sign-In process...');
      final result = await authService.signInWithGoogle();
      setState(() => _loading = false);

      if (!mounted) return;

      switch (result.status) {
        case GoogleSignInStatus.success:
          await _handleGoogleAuthSuccess(result.user, isSignUp: false);
          break;
        case GoogleSignInStatus.cancelled:
        case GoogleSignInStatus.popupClosed:
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Sign-In cancelled.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          break;
        case GoogleSignInStatus.error:
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result.message ?? 'Google Sign-In failed.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          break;
      }
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign-in error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _googleSignUp() async {
    setState(() => _loading = true);
    final authService = AuthService();

    try {
      print('🔄 Login: Starting Google Sign-Up process...');
      final result = await authService.signInWithGoogle();
      setState(() => _loading = false);

      if (!mounted) return;

      switch (result.status) {
        case GoogleSignInStatus.success:
          await _handleGoogleAuthSuccess(result.user, isSignUp: true);
          break;
        case GoogleSignInStatus.cancelled:
        case GoogleSignInStatus.popupClosed:
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Sign-Up cancelled.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          break;
        case GoogleSignInStatus.error:
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result.message ?? 'Google Sign-Up failed.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          break;
      }
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign-up error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleGoogleAuthSuccess(user, {required bool isSignUp}) async {
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Authentication error: No user returned'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final userDetails = await FirestoreService().getUserDetails(user.uid);
    if (!mounted) return;

    if (userDetails == null ||
        userDetails['username'] == null ||
        userDetails['username'].toString().isEmpty) {
      // New user or incomplete profile - go to user details
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => UserDetailsScreen(isFromPhoneSignup: isSignUp),
        ),
      );
    } else {
      // Existing user with complete profile - go to home
      if (isSignUp) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Welcome back! You already have an account.'),
            backgroundColor: Colors.blue,
          ),
        );
      }
      Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.only(
                          top: 20,
                          left: 50,
                          right: 8,
                          bottom: 8,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Welcome To Roomie',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: const Color(0xFF101418),
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.015,
                                  fontSize: 35,
                                ),
                              ),
                            ),
                            SizedBox(width: 48), // To balance the back button
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Phone input
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                style: const TextStyle(
                                  color: Color(0xFF101418),
                                  fontSize: 16,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Phone number',
                                  filled: true,
                                  fillColor: const Color(0xFFEAEDF1),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 18,
                                    horizontal: 16,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  hintStyle: const TextStyle(
                                    color: Color(0xFF5C728A),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 0,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _sendOTP,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDCE7F3),
                              foregroundColor: const Color(0xFF101418),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(32),
                              ),
                              elevation: 0,
                            ),
                            child:
                                _loading
                                    ? const CircularProgressIndicator(
                                      color: Color(0xFF101418),
                                    )
                                    : const Text(
                                      'Sign up with Phone',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        letterSpacing: 0.015,
                                      ),
                                    ),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 0,
                        ),
                        child: SizedBox(height: 8),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 0,
                        ),
                        child: Text(
                          'Or continue with Google',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF5C728A),
                            fontSize: 14,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ),
                      // Google Sign-Up Button
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _loading ? null : _googleSignUp,
                            icon: const Icon(
                              Icons.g_mobiledata,
                              color: Color(0xFF101418),
                              size: 28,
                            ),
                            label: const Text(
                              'Sign up with Google',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 0.015,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEAEDF1),
                              foregroundColor: const Color(0xFF101418),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(32),
                              ),
                              elevation: 0,
                              padding: const EdgeInsets.only(left: 0),
                            ),
                          ),
                        ),
                      ),
                      // Google Sign-In Button
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: _loading ? null : _googleSignIn,
                            icon: const Icon(
                              Icons.g_mobiledata,
                              color: Color(0xFF4285F4),
                              size: 28,
                            ),
                            label: const Text(
                              'Sign in with Google',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 0.015,
                                color: Color(0xFF4285F4),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              side: const BorderSide(
                                color: Color(0xFF4285F4),
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(32),
                              ),
                              elevation: 0,
                              padding: const EdgeInsets.only(left: 0),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Terms and bottom padding
                  Column(
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 0,
                        ),
                        child: Text(
                          'By continuing, you agree to our Terms of Service and Privacy Policy',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF5C728A),
                            fontSize: 14,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
