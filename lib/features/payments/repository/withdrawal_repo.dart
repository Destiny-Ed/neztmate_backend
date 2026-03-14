import 'package:neztmate_backend/features/payments/models/withdrawal_model.dart';

abstract class WithdrawalRepository {
  Future<WithdrawalModel> createWithdrawal(WithdrawalModel withdrawal);
  Future<WithdrawalModel> getWithdrawalById(String id);
  Future<List<WithdrawalModel>> getWithdrawalsByUser(String userId);
  Future<void> updateWithdrawalStatus(String id, String status, String? processedBy);
}
