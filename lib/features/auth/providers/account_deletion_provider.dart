import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/account_deletion_service.dart';

final accountDeletionServiceProvider = Provider<AccountDeletionService>((ref) {
  return AccountDeletionService();
});
