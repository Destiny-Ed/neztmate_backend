import 'package:neztmate_backend/features/payments/models/payments.dart';
import 'package:neztmate_backend/features/payments/models/withdrawal_model.dart';

abstract class PaymentRemoteDataSource {
  // Payments
  Future<PaymentModel> createPayment(PaymentModel payment);
  Future<PaymentModel> getPaymentById(String id);
  Future<List<PaymentModel>> getPaymentsByLease(String leaseId);
  Future<List<PaymentModel>> getPaymentsByUser(String userId);
  Future<List<PaymentModel>> getPaymentsByTask(String taskId);
  Future<void> markAsPaid(String id, String receiptUrl, String? transactionRef);

  // Withdrawals
  Future<WithdrawalModel> createWithdrawal(WithdrawalModel withdrawal);
  Future<WithdrawalModel> getWithdrawalById(String id);
  Future<List<WithdrawalModel>> getWithdrawalsByUser(String userId);
  Future<void> updateWithdrawalStatus(String id, String status, String? processedBy);
}
