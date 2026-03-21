import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../routes/app_routes.dart';
import '../services/teacher_service.dart';
import 'edit_teacher_profile_screen.dart';
import 'change_password_screen.dart';

class TeacherProfileContent extends StatefulWidget {
  const TeacherProfileContent({super.key});

  @override
  State<TeacherProfileContent> createState() => _TeacherProfileContentState();
}

class _TeacherProfileContentState extends State<TeacherProfileContent> {
  final TeacherService _teacherService = TeacherService();

  Map<String, dynamic>? _teacherData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTeacherProfile();
  }

  Future<void> _loadTeacherProfile() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final teacherId = await _teacherService.getCurrentTeacherId();
      if (teacherId == null) {
        throw Exception('Teacher not found');
      }

      // Load teacher data only
      await _loadTeacherData(teacherId);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTeacherData(String teacherId) async {
    final response = await Supabase.instance.client
        .from('teachers')
        .select('*, users!inner(*)')
        .eq('id', teacherId)
        .single();

    setState(() {
      _teacherData = response;
    });
  }

  Future<void> _navigateToEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditTeacherProfileScreen(teacherData: _teacherData!)),
    );

    if (result == true) {
      _loadTeacherProfile(); // Reload profile if edited
    }
  }

  Future<void> _navigateToChangePassword() async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => const ChangePasswordScreen()));
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            const Text('Failed to load profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadTeacherProfile, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_teacherData == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('No teacher profile found', style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            Text('Please contact support if this issue persists', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    final userData = _teacherData!['users'];
    final firstName = userData['first_name'] ?? '';
    final lastName = userData['last_name'] ?? '';
    final fullName = '$firstName $lastName'.trim();
    final displayName = fullName.isNotEmpty ? fullName : 'Teacher';
    final email = userData['email'] ?? '';
    final joinDate = _formatDate(_teacherData!['created_at'] as String?);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadTeacherProfile,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          physics: const AlwaysScrollableScrollPhysics(),
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
              _buildProfileHeader(displayName, email, joinDate),
              const SizedBox(height: 24),

              // Teacher Information
              _buildTeacherInfo(),
              const SizedBox(height: 24),

              // Account Settings
              _buildSectionTitle('Account Settings'),
              _buildSettingItem(icon: Icons.edit_outlined, title: 'Edit Profile', onTap: _navigateToEditProfile),
              _buildSettingItem(icon: Icons.lock_outline, title: 'Change Password', onTap: _navigateToChangePassword),
              _buildSettingItem(
                icon: Icons.delete_forever_outlined,
                title: 'Delete Account',
                iconColor: Colors.red,
                titleColor: Colors.red,
                onTap: () => context.push(AppRoutes.teacherDeleteAccount),
              ),
              // _buildSettingItem(
              //   icon: Icons.notifications_none,
              //   title: 'Notification Settings',
              //   onTap: () {
              //     // TODO: Navigate to notification settings
              //   },
              // ),
              const SizedBox(height: 16),

              // Support
              // _buildSectionTitle('Support'),
              // _buildSettingItem(
              //   icon: Icons.help_outline,
              //   title: 'Help Center',
              //   onTap: () {
              //     // TODO: Navigate to help center
              //   },
              // ),
              // _buildSettingItem(
              //   icon: Icons.email_outlined,
              //   title: 'Contact Support',
              //   onTap: () {
              //     // TODO: Navigate to contact support
              //   },
              // ),
              // const SizedBox(height: 24),

              // Logout Button
              // Center(
              //   child: ElevatedButton.icon(
              //     onPressed: _handleLogout,
              //     style: ElevatedButton.styleFrom(
              //       backgroundColor: Colors.red.shade50,
              //       foregroundColor: Colors.red,
              //       padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              //     ),
              //     icon: const Icon(Icons.logout, size: 18),
              //     label: const Text('Logout'),
              //   ),
              // ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(String name, String email, String joinDate) {
    final profileImage = _teacherData!['users']['profile_image_url'];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Profile Picture
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withOpacity(0.1),
            image: profileImage != null ? DecorationImage(image: NetworkImage(profileImage), fit: BoxFit.cover) : null,
          ),
          child: profileImage == null ? const Icon(Icons.person, size: 40, color: AppColors.primary) : null,
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

  Widget _buildTeacherInfo() {
    final qualifications = _teacherData!['qualifications'] as String?;
    final specialization = _teacherData!['specialization'] as String?;
    final experience = _teacherData!['years_of_experience'] as int?;
    final bio = _teacherData!['bio'] as String?;
    final phone = _teacherData!['users']['phone_number'] as String?;

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
          const Text('Teacher Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          if (bio != null && bio.isNotEmpty) ...[_buildInfoRow('Bio', bio), const SizedBox(height: 8)],

          if (qualifications != null && qualifications.isNotEmpty) ...[
            _buildInfoRow('Qualifications', qualifications),
            const SizedBox(height: 8),
          ],

          if (specialization != null && specialization.isNotEmpty) ...[
            _buildInfoRow('Specialization', specialization),
            const SizedBox(height: 8),
          ],

          if (experience != null) ...[_buildInfoRow('Experience', '$experience years'), const SizedBox(height: 8)],

          if (phone != null && phone.isNotEmpty) ...[_buildInfoRow('Phone', phone)],

          if ((bio == null || bio.isEmpty) &&
              (qualifications == null || qualifications.isEmpty) &&
              (specialization == null || specialization.isEmpty) &&
              experience == null &&
              (phone == null || phone.isEmpty)) ...[
            Text(
              'Complete your profile to see more information here.',
              style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text('$label:', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
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
}
