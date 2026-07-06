import 'package:neztmate_backend/features/payments/datasource/remote_datasource.dart';
import 'package:neztmate_backend/features/payments/models/payment_disbursement_model.dart';
import 'package:neztmate_backend/features/payments/models/payments.dart';
import 'package:neztmate_backend/features/payments/models/payout_account_model.dart';
import 'package:neztmate_backend/features/payments/models/plaform_fee_record_model.dart';
import 'package:neztmate_backend/features/payments/models/withdrawal_model.dart';
import 'package:neztmate_backend/features/payments/repository/payment_repo.dart';

class PaymentRepositoryImpl implements PaymentRepository {
  final PaymentRemoteDataSource dataSource;

  PaymentRepositoryImpl(this.dataSource);

  @override
  Future<PaymentModel> createPayment(PaymentModel payment) => dataSource.createPayment(payment);

  @override
  Future<PaymentModel> getPaymentById(String id) => dataSource.getPaymentById(id);

  @override
  Future<List<PaymentModel>> getPaymentsByLease(String leaseId) => dataSource.getPaymentsByLease(leaseId);

  @override
  Future<List<PaymentModel>> getPaymentsByUser(String userId) => dataSource.getPaymentsByUser(userId);

  @override
  Future<List<PaymentModel>> getPaymentsByTask(String taskId) => dataSource.getPaymentsByTask(taskId);

  @override
  Future<void> markAsPaidByReference(String reference, String receiptUrl, String? transactionRef) async {
    // Find payment by transaction reference
    // You may need to add this method to your datasource if not present
    await dataSource.markAsPaidByReference(reference, receiptUrl, transactionRef);
  }

  @override
  Future<void> markAsPaid(String id, String receiptUrl, String? transactionRef) =>
      dataSource.markAsPaid(id, receiptUrl, transactionRef);

  @override
  Future<WithdrawalModel> createWithdrawal(WithdrawalModel withdrawal) =>
      dataSource.createWithdrawal(withdrawal);

  @override
  Future<WithdrawalModel> getWithdrawalById(String id) => dataSource.getWithdrawalById(id);

  @override
  Future<List<WithdrawalModel>> getWithdrawalsByUser(String userId) =>
      dataSource.getWithdrawalsByUser(userId);

  @override
  Future<void> updateWithdrawalStatus(String id, String status, String? processedBy) =>
      dataSource.updateWithdrawalStatus(id, status, processedBy);

  @override
  Future<PaymentModel> getPaymentByReference(String reference) => dataSource.getPaymentByReference(reference);

  @override
  Future<bool> isPaymentAlreadyProcessed(String reference) => dataSource.isPaymentAlreadyProcessed(reference);

  @override
  Future<void> markPaymentAsProcessed(String reference) => dataSource.markPaymentAsProcessed(reference);

  @override
  Future<void> approveWithdrawal(String withdrawalId, String processedBy) =>
      dataSource.approveWithdrawal(withdrawalId, processedBy);

  // @override
  // Future<Map<String, dynamic>> getPaymentSummary(String userId, String role) =>
  //     dataSource.getPaymentSummary(userId, role);

  @override
  Future<List<PaymentModel>> getPaymentsByProperty(String propertyId) =>
      dataSource.getPaymentsByProperty(propertyId);

  @override
  Future<List<PaymentModel>> getPaymentsByUnit(String unitId) => dataSource.getPaymentsByUnit(unitId);

  // @override
  // Future<Map<String, dynamic>> getPropertyPaymentSummary(String propertyId) =>
  //     dataSource.getPropertyPaymentSummary(propertyId);
  @override
  Future<void> rejectWithdrawal(String withdrawalId, String processedBy, String? reason) =>
      dataSource.rejectWithdrawal(withdrawalId, processedBy, reason);

  @override
  Future<List<WithdrawalModel>> getWithdrawalsByProperty(String propertyId) =>
      dataSource.getWithdrawalsByProperty(propertyId);

  @override
  Future<PayoutAccountModel?> getDefaultPayoutAccount(String userId, {String? propertyId}) =>
      dataSource.getDefaultPayoutAccount(userId);

  @override
  Future<List<PayoutAccountModel>> getPayoutAccounts(String userId, {String? propertyId}) =>
      dataSource.getPayoutAccounts(userId);
  @override
  Future<void> removePayoutAccount(String accountId) => dataSource.removePayoutAccount(accountId);

  @override
  Future<void> setDefaultPayoutAccount(String accountId, String userId) =>
      dataSource.setDefaultPayoutAccount(accountId, userId);

  @override
  Future<PayoutAccountModel> savePayoutAccount(PayoutAccountModel account) =>
      dataSource.savePayoutAccount(account);

  @override
  Future<void> deductFromPropertyBalance({
    required String propertyId,
    required double amount,
    required String reason,
    required String reference,
  }) => dataSource.deductFromPropertyBalance(
    propertyId: propertyId,
    amount: amount,
    reason: reason,
    reference: reference,
  );

  @override
  Future<double> getPropertyAvailableBalance(String propertyId) =>
      dataSource.getPropertyAvailableBalance(propertyId);

  @override
  Future<void> createDisbursement(PaymentDisbursementModel disbursement) =>
      dataSource.createDisbursement(disbursement);

  @override
  Future<void> createWithdrawalAsFallback(PaymentDisbursementModel disbursement) =>
      dataSource.createWithdrawalAsFallback(disbursement);

  @override
  Future<List<PaymentDisbursementModel>> getPendingDisbursements() => dataSource.getPendingDisbursements();

  @override
  Future<void> markDisbursementAsCompleted(String disbursementId, String transferReference) =>
      dataSource.markDisbursementAsCompleted(disbursementId, transferReference);

  @override
  Future<void> markDisbursementAsFailed(String disbursementId, String reason) =>
      dataSource.markDisbursementAsFailed(disbursementId, reason);

  @override
  Future<void> recordPlatformFee(String paymentId, double amount, String paymentType) =>
      dataSource.recordPlatformFee(paymentId, amount, paymentType);

  @override
  Future<PayoutAccountModel?> getPayoutAccountById(String id) => dataSource.getPayoutAccountById(id);

  @override
  Future<void> updatePayoutAccount(PayoutAccountModel account) => dataSource.updatePayoutAccount(account);

  @override
  Future<List<PlatformFeeRecord>> getPlatformFeeHistory() => dataSource.getPlatformFeeHistory();

  @override
  Future<double> getTotalUnwithdrawnPlatformFees() => dataSource.getTotalUnwithdrawnPlatformFees();

  @override
  Future<void> markPlatformFeesAsWithdrawn(String withdrawalReference) =>
      dataSource.markPlatformFeesAsWithdrawn(withdrawalReference);
}
