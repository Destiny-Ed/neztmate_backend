import 'package:neztmate_backend/features/payments/datasource/remote_datasource.dart';
import 'package:neztmate_backend/features/payments/models/payments.dart';
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
}
