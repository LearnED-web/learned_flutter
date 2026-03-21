import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learned_flutter/core/theme/app_colors.dart';
import 'package:learned_flutter/features/auth/providers/account_deletion_provider.dart';
import 'package:learned_flutter/routes/app_routes.dart';

class DeleteAccountConfirmationScreen extends ConsumerStatefulWidget {
  const DeleteAccountConfirmationScreen({super.key});

  @override
  ConsumerState<DeleteAccountConfirmationScreen> createState() => _DeleteAccountConfirmationScreenState();
}

class _DeleteAccountConfirmationScreenState extends ConsumerState<DeleteAccountConfirmationScreen> {
  final TextEditingController _confirmController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _confirmController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submitDeletionRequest() async {
    if (_confirmController.text.trim().toUpperCase() != 'DELETE') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please type DELETE to confirm account deletion.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final service = ref.read(accountDeletionServiceProvider);
    final result = await service.requestDeletion(reason: _reasonController.text);

    if (!mounted) return;

    if (result.success) {
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;

      final retentionText = result.retentionUntil != null
          ? '\n\nLegal and financial records are retained until ${result.retentionUntil!.toLocal().toString().split(' ').first}.'
          : '';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Account deletion request submitted successfully.$retentionText'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );
      context.go(AppRoutes.login);
      return;
    }

    String message = result.message;
    if (result.code == 'teacher_has_active_students') {
      message =
          'Deletion blocked: active student enrollments exist. Contact support to transfer or close classes first.';
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));

    setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delete Account'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: const Text(
                'This action disables your LearnED account immediately and starts deletion processing. It cannot be undone from the app.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 16),
            const Text('What happens next', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('1. You will be signed out immediately.'),
            const Text('2. Your profile data will be removed from active app use.'),
            const Text('3. Legal, tax, and payment records are retained for up to 7 years.'),
            const SizedBox(height: 20),
            TextField(
              controller: _reasonController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'Tell us why you are leaving',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Type DELETE to confirm', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitDeletionRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: _isSubmitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.delete_forever),
                label: Text(_isSubmitting ? 'Submitting...' : 'Request Account Deletion'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isSubmitting ? null : () => context.pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
