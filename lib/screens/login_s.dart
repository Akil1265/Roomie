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

  Future<void> _googleLogin() async {
    setState(() => _loading = true);
    final authService = AuthService(); // Instantiate AuthService

    try {
      print('🔄 Login: Starting Google Sign-In process...');
      bool success = await authService.signInWithGoogle();
      setState(() => _loading = false);

      if (success) {
        print('✅ Login: Google Sign-In successful');
        final user = authService.currentUser; // Access currentUser
        if (user != null) {
          print('✅ Login: User authenticated: ${user.email}');
          // Check if user profile is complete
          final userDetails = await FirestoreService().getUserDetails(user.uid);

          // If user doesn't have username, redirect to user details screen
          if (userDetails == null ||
              userDetails['username'] == null ||
              userDetails['username'].toString().isEmpty) {
            print('🔄 Login: Redirecting to user details screen');
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => const UserDetailsScreen(isFromPhoneSignup: false),
                ),
              );
            }
          } else {
            // User profile is complete, go to home
            print('🔄 Login: Redirecting to home screen');
            if (mounted) {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/home',
                (route) => false,
              );
            }
          }
        } else {
          print('❌ Login: No user found after successful sign-in');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Authentication error: No user found'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        print('❌ Login: Google Sign-In failed');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Google Sign-In failed. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Login: Exception during Google Sign-In: $e');
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign-in error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
                          'Or',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF5C728A),
                            fontSize: 14,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _loading ? null : _googleLogin,
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
