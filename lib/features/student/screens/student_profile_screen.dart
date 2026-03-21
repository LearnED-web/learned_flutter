import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learned_flutter/core/theme/app_colors.dart';
import 'package:learned_flutter/routes/app_routes.dart';
import 'package:learned_flutter/features/student/providers/student_profile_provider.dart';

class StudentProfileScreen extends ConsumerWidget {
  const StudentProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentProfileAsync = ref.watch(currentStudentProfileProvider);

    return Scaffold(
      body: studentProfileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text('Failed to load profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(currentStudentProfileProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (studentProfile) {
          if (studentProfile == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_off, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No student profile found', style: TextStyle(fontSize: 16)),
                  SizedBox(height: 8),
                  Text('Please contact support if this issue persists', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          // Extract data from the profile
          final userInfo = studentProfile['users'] as Map<String, dynamic>;
          final studentName = '${userInfo['first_name']} ${userInfo['last_name']}';
          final email = userInfo['email'] as String;
          final profileImageUrl = userInfo['profile_image_url'] as String?;
          final joinDate = _formatDate(userInfo['created_at'] as String?);

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Page Title
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                    child: Text(
                      'My Profile',
                      style: Theme.of(
                        context,
                      ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),

                  // Profile Header
                  _buildProfileHeader(studentName, email, joinDate, profileImageUrl),
                  const SizedBox(height: 24),

                  // Student-specific Information
                  _buildStudentInfo(studentProfile),
                  const SizedBox(height: 24),

                  // Account Settings
                  _buildSectionTitle('Account Settings'),
                  _buildSettingItem(
                    icon: Icons.edit_outlined,
                    title: 'Edit Profile',
                    onTap: () {
                      context.push(AppRoutes.studentProfileEdit);
                    },
                  ),
                  _buildSettingItem(
                    icon: Icons.person_outline,
                    title: 'Personal Information',
                    onTap: () {
                      // Navigate to personal info screen
                      context.push(AppRoutes.studentPersonalInfo);
                    },
                  ),
                  _buildSettingItem(
                    icon: Icons.lock_outline,
                    title: 'Change Password',
                    onTap: () {
                      // Navigate to change password screen
                      context.push(AppRoutes.studentChangePassword);
                    },
                  ),
                  _buildSettingItem(
                    icon: Icons.delete_forever_outlined,
                    title: 'Delete Account',
                    titleColor: Colors.red,
                    iconColor: Colors.red,
                    onTap: () {
                      context.push(AppRoutes.studentDeleteAccount);
                    },
                  ),
                  // _buildSettingItem(
                  //   icon: Icons.notifications_none,
                  //   title: 'Notification Settings',
                  //   onTap: () {
                  //     // Navigate to notification settings
                  //   },
                  // ),
                  // const SizedBox(height: 16),

                  // // Support
                  // _buildSectionTitle('Support'),
                  // _buildSettingItem(
                  //   icon: Icons.help_outline,
                  //   title: 'Help Center',
                  //   onTap: () {
                  //     // Navigate to help center
                  //   },
                  // ),
                  // _buildSettingItem(
                  //   icon: Icons.email_outlined,
                  //   title: 'Contact Support',
                  //   onTap: () {
                  //     // Navigate to contact support
                  //   },
                  // ),
                  const SizedBox(height: 24),

                  // Logout Button
                  // Center(
                  //   child: ElevatedButton.icon(
                  //     onPressed: () async {
                  //       try {
                  //         // Show confirmation dialog
                  //         final shouldLogout = await showDialog<bool>(
                  //           context: context,
                  //           builder: (context) => AlertDialog(
                  //             title: const Text('Logout'),
                  //             content: const Text('Are you sure you want to logout?'),
                  //             actions: [
                  //               TextButton(
                  //                 onPressed: () => Navigator.of(context).pop(false),
                  //                 child: const Text('Cancel'),
                  //               ),
                  //               TextButton(
                  //                 onPressed: () => Navigator.of(context).pop(true),
                  //                 style: TextButton.styleFrom(foregroundColor: Colors.red),
                  //                 child: const Text('Logout'),
                  //               ),
                  //             ],
                  //           ),
                  //         );

                  //         if (shouldLogout == true) {
                  //           // Sign out from Supabase (clears session and persistent data)
                  //           await Supabase.instance.client.auth.signOut();

                  //           if (context.mounted) {
                  //             // Navigate to login screen
                  //             context.go(AppRoutes.login);

                  //             // Show success message
                  //             ScaffoldMessenger.of(context).showSnackBar(
                  //               const SnackBar(content: Text('Logged out successfully'), backgroundColor: Colors.green),
                  //             );
                  //           }
                  //         }
                  //       } catch (e) {
                  //         if (context.mounted) {
                  //           ScaffoldMessenger.of(context).showSnackBar(
                  //             SnackBar(content: Text('Error logging out: $e'), backgroundColor: Colors.red),
                  //           );
                  //         }
                  //       }
                  //     },
                  //     style: ElevatedButton.styleFrom(
                  //       backgroundColor: Colors.red.shade50,
                  //       foregroundColor: Colors.red,
                  //       padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  //     ),
                  //     icon: const Icon(Icons.logout, size: 18),
                  //     label: const Text('Logout'),
                  //   ),
                  // ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(String name, String email, String joinDate, String? profileImageUrl) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Profile Picture
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withOpacity(0.1)),
          child: ClipOval(
            child: profileImageUrl != null && profileImageUrl.isNotEmpty
                ? Image.network(
                    profileImageUrl,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback to icon if image fails to load
                      return const Icon(Icons.person, size: 40, color: AppColors.primary);
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                    },
                  )
                : const Icon(Icons.person, size: 40, color: AppColors.primary),
          ),
        ),
        const SizedBox(width: 16),
        // Profile Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(email, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              const SizedBox(height: 4),
              Text('Member since $joinDate', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
    Color? titleColor,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: iconColor ?? AppColors.primary),
      ),
      title: Text(title, style: TextStyle(color: titleColor)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  /// Format a date string for display
  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown';

    try {
      final date = DateTime.parse(dateString);
      final months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }

  /// Build student-specific information section
  Widget _buildStudentInfo(Map<String, dynamic> studentProfile) {
    final gradeLevel = studentProfile['grade_level'];
    final schoolName = studentProfile['school_name'];
    final board = studentProfile['board'];
    final studentId = studentProfile['student_id'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Student Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (studentId != null) ...[_buildInfoRow('Student ID', studentId), const SizedBox(height: 8)],
          if (gradeLevel != null) ...[_buildInfoRow('Grade Level', 'Grade $gradeLevel'), const SizedBox(height: 8)],
          if (board != null) ...[_buildInfoRow('Board', board), const SizedBox(height: 8)],
          if (schoolName != null) ...[_buildInfoRow('School', schoolName)],
          if (gradeLevel == null && board == null && schoolName == null) ...[
            Text(
              'Complete your profile to see more information here.',
              style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  /// Build an information row
  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text('$label:', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}
