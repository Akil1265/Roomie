import 'package:flutter/material.dart';
import 'dart:async';
import 'package:roomie/services/auth_service.dart';
import 'package:roomie/services/firestore_service.dart';
import 'package:roomie/widgets/roomie_loading_widget.dart';
import 'package:roomie/screens/user_details_s.dart';

class OtpScreen extends StatefulWidget {
  final String verificationId;

  const OtpScreen({super.key, required this.verificationId});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otpController = TextEditingController();
  final List<TextEditingController> _digitControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _loading = false;
  int _secondsRemaining = 30;
  late final Timer _timer;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _secondsRemaining = 30;
    _canResend = false;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        setState(() {
          _canResend = true;
        });
        _timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _resendOTP() {
    _startTimer();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('OTP resent!')));
  }

  void _verifyOTP() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 6-digit OTP')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final user = await AuthService().signInWithOTP(
        verificationId: widget.verificationId,
        smsCode: otp,
      );

      if (user != null) {
        final userDetails = await FirestoreService().getUserDetails(user.uid);
        if (mounted) {
          if (userDetails == null ||
              userDetails['username'] == null ||
              userDetails['username'].toString().isEmpty) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder:
                    (_) => const UserDetailsScreen(isFromPhoneSignup: true),
              ),
            );
          } else {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/home',
              (route) => false,
            );
          }
        }
      } else {
        throw Exception('Failed to sign in with OTP.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OTP Verification Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final phoneNumber = ModalRoute.of(context)?.settings.arguments as String?;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // Header with back button
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        size: 18,
                        color: Color(0xFF101418),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // Title and description
              const Text(
                'Enter verification code',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF101418),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                phoneNumber != null
                    ? 'We\'ve sent a code to $phoneNumber'
                    : 'We\'ve sent a verification code to your phone',
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF5C728A),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 60),

              // OTP input boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (index) {
                  return Container(
                    width: 45,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAEDF1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _digitControllers[index],
                      focusNode: _focusNodes[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF101418),
                      ),
                      decoration: const InputDecoration(
                        counterText: '',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          if (index < 5) {
                            _focusNodes[index + 1].requestFocus();
                          } else {
                            _focusNodes[index].unfocus();
                          }
                        } else if (value.isEmpty && index > 0) {
                          _focusNodes[index - 1].requestFocus();
                        }
                        // Update the main OTP controller
                        String otp =
                            _digitControllers.map((c) => c.text).join();
                        _otpController.text = otp;
                        setState(() {});
                      },
                      onTap: () {
                        _focusNodes[index].requestFocus();
                      },
                    ),
                  );
                }),
              ),

              const Spacer(),

              // Resend code section
              Center(
                child:
                    _canResend
                        ? TextButton(
                          onPressed: _resendOTP,
                          child: const Text(
                            'Resend code',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF101418),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                        : Text(
                          'Resend code in 00:${_secondsRemaining.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF5C728A),
                          ),
                        ),
              ),

              const SizedBox(height: 32),

              // Verify button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : _verifyOTP,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDCE7F3),
                    foregroundColor: const Color(0xFF101418),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child:
                      _loading
                          ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: RoomieLoadingSmall(size: 24),
                          )
                          : const Text(
                            'Verify',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
