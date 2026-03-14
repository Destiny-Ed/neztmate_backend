import 'package:neztmate_backend/features/payments/models/payments.dart';

abstract class PaymentRepository {
  Future<PaymentModel> createPayment(PaymentModel payment);
  Future<PaymentModel> getPaymentById(String id);
  Future<List<PaymentModel>> getPaymentsByLease(String leaseId);
  Future<List<PaymentModel>> getPaymentsByUser(String userId);
  Future<void> updatePaymentStatus(String id, String status);
}
