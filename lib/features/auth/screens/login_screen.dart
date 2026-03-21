import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_validator/form_validator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  late final AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Show error message in a snackbar
  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating),
    );
  }

  // Handle authentication errors
  void _handleAuthError(dynamic error) {
    String errorMessage = 'An error occurred during login';

    if (error is AuthException) {
      final normalizedMessage = error.message.toLowerCase();

      if (normalizedMessage.contains('email not confirmed') ||
          normalizedMessage.contains('confirm your email') ||
          normalizedMessage.contains('not confirmed')) {
        errorMessage = 'Please verify your email before logging in.';
      } else {
        switch (error.statusCode) {
          case '400':
            errorMessage = 'Invalid email or password';
            break;
          case '422':
            errorMessage = 'Invalid email format';
            break;
          case '429':
            errorMessage = 'Too many attempts. Please try again later.';
            break;
          default:
            errorMessage = error.message;
        }
      }
    } else if (error is Exception) {
      errorMessage = error.toString().replaceAll('Exception: ', '');
    }

    _showErrorSnackBar(errorMessage);
  }

  bool _isEmailNotConfirmedError(AuthException error) {
    final normalizedMessage = error.message.toLowerCase();
    return normalizedMessage.contains('email not confirmed') ||
        normalizedMessage.contains('confirm your email') ||
        normalizedMessage.contains('not confirmed');
  }

  Future<void> _redirectToEmailVerification(String email) async {
    final supabase = Supabase.instance.client;

    try {
      await supabase.auth.resend(type: OtpType.signup, email: email);
    } catch (_) {
      // Even if resend fails, route user to verification so they can retry.
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please verify your email before logging in. A verification code has been sent.'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 6),
      ),
    );

    context.go('/verify-email?email=${Uri.encodeComponent(email)}');
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final email = _emailController.text.trim();

    try {
      final password = _passwordController.text;

      // Sign in with Supabase
      final response = await _authService.signIn(email: email, password: password);

      if (response.user == null) {
        throw Exception('Failed to sign in');
      }

      // Check email_verified field from database
      final supabase = Supabase.instance.client;
      final userData = await supabase
          .from('users')
          .select('email_verified, is_active, deletion_status')
          .eq('id', response.user!.id)
          .single();

      final isEmailVerified = userData['email_verified'] as bool? ?? false;
      final isActive = userData['is_active'] as bool? ?? true;
      final deletionStatus = (userData['deletion_status'] ?? 'active').toString();

      if (!isActive || deletionStatus != 'active') {
        await supabase.auth.signOut();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This account is deactivated due to a deletion request.'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      if (!isEmailVerified) {
        // Email not verified - resend verification code and redirect
        try {
          await supabase.auth.resend(type: OtpType.signup, email: email);
        } catch (resendError) {
          // If resend fails, continue with redirect anyway
          print('Failed to resend verification code: $resendError');
        }

        // Sign out the user
        await supabase.auth.signOut();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Please verify your email before logging in. A new verification code has been sent to your email.',
              ),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 6),
            ),
          );
          context.go('/verify-email?email=${Uri.encodeComponent(email)}');
        }
        return;
      }

      // Navigate based on user type
      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login successful!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Navigate based on user type
        if (mounted) {
          final userType = response.user?.userMetadata?['user_type'] ?? 'student';
          if (userType == 'teacher') {
            context.go('/teacher');
          } else {
            context.go('/student');
          }
        }
      }
    } catch (e) {
      if (e is AuthException && _isEmailNotConfirmedError(e)) {
        await _redirectToEmailVerification(email);
        return;
      }

      _handleAuthError(e);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log In'), backgroundColor: Colors.transparent, elevation: 0, centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo and welcome text
                Column(
                  children: [
                    Image.asset('assets/icons/LearnED_logo_horizontal.png', height: 60, fit: BoxFit.contain),
                    const SizedBox(height: 16),
                    Text('Welcome back!', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      'Please sign in to your account',
                      style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Email field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                  validator: ValidationBuilder()
                      .email('Please enter a valid email')
                      .required('Email is required')
                      .build(),
                ),
                const SizedBox(height: 16),
                // Password field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: ValidationBuilder()
                      .minLength(6, 'Password must be at least 6 characters')
                      .required('Password is required')
                      .build(),
                ),

                // Forgot password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading ? null : () => context.push('/forgot-password'),
                    child: Text('Forgot Password?', style: TextStyle(color: AppColors.primary)),
                  ),
                ),

                const SizedBox(height: 24),

                // Login button
                FilledButton(
                  onPressed: _isLoading ? null : _login,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Log In',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                ),

                const SizedBox(height: 16),

                // Sign up link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Don't have an account? ", style: TextStyle(color: Colors.grey[600])),
                    TextButton(
                      onPressed: _isLoading ? null : () => context.go('/register'),
                      style: TextButton.styleFrom(foregroundColor: AppColors.primary, padding: EdgeInsets.zero),
                      child: const Text('Sign Up', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
