import 'package:neztmate_backend/features/payments/models/payments.dart';
import 'package:neztmate_backend/features/payments/models/withdrawal_model.dart';

abstract class PaymentRepository {
  Future<PaymentModel> createPayment(PaymentModel payment);
  Future<PaymentModel> getPaymentById(String id);
  Future<PaymentModel> getPaymentByReference(String reference);
  Future<List<PaymentModel>> getPaymentsByLease(String leaseId);
  Future<List<PaymentModel>> getPaymentsByUser(String userId);
  Future<List<PaymentModel>> getPaymentsByTask(String taskId);

  Future<List<PaymentModel>> getPaymentsByProperty(String propertyId);
  Future<List<PaymentModel>> getPaymentsByUnit(String unitId);

  // Summary & Analytics
  Future<Map<String, dynamic>> getPaymentSummary(String userId, String role);
  Future<Map<String, dynamic>> getPropertyPaymentSummary(String propertyId);

  // Withdrawal / Release Funds
  Future<void> approveWithdrawal(String withdrawalId, String processedBy);
  Future<void> rejectWithdrawal(String withdrawalId, String processedBy, String? reason);

  Future<void> markAsPaid(String id, String receiptUrl, String? transactionRef);

  Future<void> markAsPaidByReference(String reference, String receiptUrl, String? transactionRef);

  Future<WithdrawalModel> createWithdrawal(WithdrawalModel withdrawal);
  Future<WithdrawalModel> getWithdrawalById(String id);
  Future<List<WithdrawalModel>> getWithdrawalsByUser(String userId);
  Future<void> updateWithdrawalStatus(String id, String status, String? processedBy);
  Future<bool> isPaymentAlreadyProcessed(String reference);
  Future<void> markPaymentAsProcessed(String reference);
}
