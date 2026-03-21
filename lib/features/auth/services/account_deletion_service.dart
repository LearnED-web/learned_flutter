import 'package:supabase_flutter/supabase_flutter.dart';

class AccountDeletionResult {
  final bool success;
  final String code;
  final String message;
  final DateTime? retentionUntil;

  const AccountDeletionResult({required this.success, required this.code, required this.message, this.retentionUntil});

  factory AccountDeletionResult.fromMap(Map<String, dynamic> map) {
    return AccountDeletionResult(
      success: map['success'] == true,
      code: (map['code'] ?? 'unknown').toString(),
      message: (map['message'] ?? 'Unknown response').toString(),
      retentionUntil: map['retention_until'] != null ? DateTime.tryParse(map['retention_until'].toString()) : null,
    );
  }
}

class AccountDeletionService {
  final SupabaseClient _supabase;

  AccountDeletionService() : _supabase = Supabase.instance.client;

  Future<AccountDeletionResult> requestDeletion({String? reason}) async {
    try {
      final response = await _supabase.rpc(
        'request_account_deletion',
        params: {'p_reason': reason?.trim().isEmpty == true ? null : reason?.trim()},
      );

      if (response is Map<String, dynamic>) {
        return AccountDeletionResult.fromMap(response);
      }

      return const AccountDeletionResult(
        success: false,
        code: 'invalid_response',
        message: 'Invalid server response while requesting account deletion.',
      );
    } catch (_) {
      return const AccountDeletionResult(
        success: false,
        code: 'network_or_server_error',
        message: 'Unable to request account deletion right now. Please try again.',
      );
    }
  }
}
