import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../features/debug/helpers/user_type_fix_helper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _statusText = 'Loading...';

  @override
  void initState() {
    super.initState();
    // Check authentication state and navigate accordingly
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Update status
    setState(() {
      _statusText = 'Checking authentication...';
    });

    // Wait for 2 seconds to show the splash screen
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Check if user is already authenticated
    final user = Supabase.instance.client.auth.currentUser;
    final session = Supabase.instance.client.auth.currentSession;

    // Debug print to see authentication state

    if (user != null && session != null) {
      // Block access for deletion-requested or inactive accounts.
      try {
        final userRow = await Supabase.instance.client
            .from('users')
            .select('is_active, deletion_status')
            .eq('id', user.id)
            .maybeSingle();

        final isActive = userRow?['is_active'] as bool? ?? true;
        final deletionStatus = (userRow?['deletion_status'] ?? 'active').toString();

        if (!isActive || deletionStatus != 'active') {
          await Supabase.instance.client.auth.signOut();
          if (mounted) {
            context.go('/welcome');
          }
          return;
        }
      } catch (_) {
        await Supabase.instance.client.auth.signOut();
        if (mounted) {
          context.go('/welcome');
        }
        return;
      }

      // In debug mode, print current user info and try to fix user type
      if (const bool.fromEnvironment('dart.vm.product') == false) {
        await UserTypeFixHelper.printCurrentUserInfo();
        await UserTypeFixHelper.fixCurrentUserType();
      }

      // User is authenticated, determine user type
      String userType = await _determineUserType(user);

      setState(() {
        _statusText = 'Welcome back!';
      });
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        if (userType == 'teacher') {
          context.go('/teacher');
        } else {
          context.go('/student');
        }
      }
    } else {
      // User not authenticated, go to welcome screen
      setState(() {
        _statusText = 'Welcome to LearnED';
      });
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) context.go('/welcome');
    }
  }

  Future<String> _determineUserType(User user) async {
    // First, check user metadata
    final metadataUserType = user.userMetadata?['user_type'];
    if (metadataUserType != null) {
      return metadataUserType;
    }

    // Fallback: Check database tables to determine user type
    try {
      // Check if user exists in teachers table
      final teacherResponse = await Supabase.instance.client
          .from('teachers')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (teacherResponse != null) {
        return 'teacher';
      }

      // Check if user exists in students table
      final studentResponse = await Supabase.instance.client
          .from('students')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (studentResponse != null) {
        return 'student';
      }

      return 'student';
    } catch (e) {
      return 'student'; // Default to student on error
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Horizontal logo
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Image.asset('assets/icons/LearnED_logo_horizontal.png', fit: BoxFit.contain, height: 80),
            ),
            const SizedBox(height: 40),
            // Status text
            Text(
              _statusText,
              style: GoogleFonts.poppins(fontSize: 14, color: isDarkMode ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(height: 16),
            // Loading indicator
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                isDarkMode ? Colors.white : Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
