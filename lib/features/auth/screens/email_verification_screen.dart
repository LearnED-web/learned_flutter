import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  final String email;

  const EmailVerificationScreen({super.key, required this.email});

  @override
  ConsumerState<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends ConsumerState<EmailVerificationScreen> {
  bool _isLoading = false;
  bool _isResending = false;
  bool _hasResent = false;
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _resendVerification() async {
    setState(() => _isResending = true);

    try {
      final supabase = Supabase.instance.client;
      await supabase.auth.resend(type: OtpType.signup, email: widget.email);

      if (mounted) {
        setState(() => _hasResent = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification code resent! Please check your email.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to resend: ${e.toString()}'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  Future<void> _verifyOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.auth.verifyOTP(
        email: widget.email,
        token: _otpController.text.trim(),
        type: OtpType.signup,
      );

      if (mounted) {
        if (response.session != null) {
          // Success - navigate to success screen
          context.go('/email-verified');
        } else {
          throw Exception('Verification failed');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid or expired code. Please try again.'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          // Show dialog asking if user wants to logout
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Cancel Verification?'),
              content: const Text('You need to verify your email to continue.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Stay Here')),
              ],
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Verify Email'), automaticallyImplyLeading: false),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  // Header
                  Icon(Icons.mark_email_read_outlined, size: 80, color: Colors.red.shade600),
                  const SizedBox(height: 24),
                  Text(
                    'Verify Your Email',
                    style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.red.shade700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'We\'ve sent a verification code to:',
                    style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey.shade700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.email,
                    style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.blue.shade700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Instructions
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Enter the 6-digit code from your email to verify your account',
                            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // OTP Input
                  TextFormField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Enter 6-digit code',
                      hintText: '000000',
                      counterText: '',
                      prefixIcon: const Icon(Icons.pin),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.red.shade600, width: 2),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the verification code';
                      }
                      if (value.length != 6) {
                        return 'Code must be 6 digits';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 24),

                  // Verify Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _verifyOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text('Verify Email', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),

                  const SizedBox(height: 16),

                  // Resend Code Button
                  TextButton(
                    onPressed: _isResending || _hasResent ? null : _resendVerification,
                    child: _isResending
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(
                            _hasResent ? 'Code Resent! Check your email' : 'Didn\'t receive code? Resend',
                            style: GoogleFonts.poppins(
                              color: _hasResent ? Colors.green.shade700 : Colors.red.shade600,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                  ),

                  const SizedBox(height: 8),

                  // Help Text
                  Text(
                    'Check your spam folder if you don\'t see the email',
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
