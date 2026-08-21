import 'package:neztmate_backend/features/payments/models/manager_commission_model.dart';
import 'package:neztmate_backend/features/payments/models/payment_disbursement_model.dart';
import 'package:neztmate_backend/features/payments/models/payments.dart';
import 'package:neztmate_backend/features/payments/models/payout_account_model.dart';
import 'package:neztmate_backend/features/payments/models/plaform_fee_record_model.dart';
import 'package:neztmate_backend/features/payments/models/withdrawal_model.dart';

abstract class PaymentRemoteDataSource {
  Future<PaymentModel> createPayment(PaymentModel payment);
  Future<PaymentModel> getPaymentById(String id);
  Future<PaymentModel> getPaymentByReference(String reference);
  Future<List<PaymentModel>> getPaymentsByLease(String leaseId);
  Future<List<PaymentModel>> getPaymentsByUser(String userId, {String? partnerId});

  Future<List<PaymentModel>> getPaymentsByTask(String taskId);

  Future<List<PaymentModel>> getPaymentsByProperty(String propertyId);
  Future<List<PaymentModel>> getPaymentsByUnit(String unitId);

  // Summary & Analytics
  // Future<Map<String, dynamic>> getPaymentSummary(String userId, String role);
  // Future<Map<String, dynamic>> getPropertyPaymentSummary(String propertyId);

  // Withdrawal / Release Funds
  Future<void> approveWithdrawal(String withdrawalId, String processedBy);
  Future<void> rejectWithdrawal(String withdrawalId, String processedBy, String? reason);

  Future<void> markAsPaid(String id, String receiptUrl, String? transactionRef);

  Future<void> markAsPaidByReference(String reference, String receiptUrl, String? transactionRef);

  Future<WithdrawalModel> createWithdrawal(WithdrawalModel withdrawal);
  Future<WithdrawalModel> getWithdrawalById(String id);
  Future<List<PayoutAccountModel>> getPayoutAccounts(String userId, {String? propertyId, String? partnerId});
  Future<List<WithdrawalModel>> getWithdrawalsByProperty(String propertyId);
  Future<void> updateWithdrawalStatus(String id, String status, String? processedBy);
  Future<bool> isPaymentAlreadyProcessed(String reference);
  Future<void> markPaymentAsProcessed(String reference);

  Future<PayoutAccountModel> savePayoutAccount(PayoutAccountModel account);
  Future<void> removePayoutAccount(String accountId);
  Future<void> setDefaultPayoutAccount(String accountId, String userId);
  Future<List<WithdrawalModel>> getWithdrawalsByUser(String userId, {String? partnerId});

  Future<PayoutAccountModel?> getDefaultPayoutAccount(String userId, {String? propertyId, String? partnerId});
  Future<PayoutAccountModel?> getPayoutAccountById(String id);
  Future<void> updatePayoutAccount(PayoutAccountModel account);

  /// Deduct amount from property's available balance (for wallet payments)
  Future<void> deductFromPropertyBalance({
    required String propertyId,
    required double amount,
    required String reason,
    required String reference,
  });

  /// Get current available balance for a property
  Future<double> getPropertyAvailableBalance(String propertyId);

  //

  Future<void> createDisbursement(PaymentDisbursementModel disbursement);
  Future<List<PaymentDisbursementModel>> getPendingDisbursements({String? partnerId});
  Future<void> markDisbursementAsCompleted(String disbursementId, String transferReference);
  Future<void> markDisbursementAsFailed(String disbursementId, String reason);

  Future<void> recordPlatformFee(String paymentId, double amount, String paymentType, {String? partnerId});
  Future<void> createWithdrawalAsFallback(PaymentDisbursementModel disbursement);

  Future<double> getTotalUnwithdrawnPlatformFees({String? partnerId});
  Future<void> markPlatformFeesAsWithdrawn(String withdrawalReference, {String? partnerId});
  Future<List<PlatformFeeRecord>> getPlatformFeeHistory({String? partnerId});

  Future<void> recordManagerCommission(ManagerCommissionModel commission);
  Future<double> getTotalPendingCommission(String managerId, {String? partnerId});

  Future<List<ManagerCommissionModel>> getManagerCommissions(String managerId, {String? partnerId});
  Future<void> markCommissionAsPaid(String commissionId, String payoutReference);
  Future<List<ManagerCommissionModel>> getManagersCommissions({String? partnerId});
}
