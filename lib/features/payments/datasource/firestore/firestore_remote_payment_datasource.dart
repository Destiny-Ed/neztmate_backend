import 'package:dart_firebase_admin/firestore.dart';
import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/features/payments/datasource/remote_datasource.dart';
import 'package:neztmate_backend/features/payments/models/payments.dart';
import 'package:neztmate_backend/features/payments/models/withdrawal_model.dart';

class FirestorePaymentDataSource implements PaymentRemoteDataSource {
  final Firestore firestore;

  FirestorePaymentDataSource(this.firestore);

  @override
  Future<PaymentModel> createPayment(PaymentModel payment) async {
    final docRef = firestore.collection('payments').doc();
    final newPayment = payment.copyWith(id: docRef.id);
    await docRef.set(newPayment.toMap());
    return newPayment;
  }

  @override
  Future<PaymentModel> getPaymentById(String id) async {
    final doc = await firestore.collection('payments').doc(id).get();
    if (!doc.exists) throw NotFoundException('Payment', id);
    return PaymentModel.fromMap(doc.data() as Map<String, dynamic>, id);
  }

  @override
  Future<List<PaymentModel>> getPaymentsByLease(String leaseId) async {
    final snap = await firestore.collection('payments').where('leaseId', WhereFilter.equal, leaseId).get();
    return snap.docs.map((d) => PaymentModel.fromMap(d.data(), d.id)).toList();
  }

  @override
  Future<List<PaymentModel>> getPaymentsByUser(String userId) async {
    final snap = await firestore.collection('payments').where('payerId', WhereFilter.equal, userId).get();
    return snap.docs.map((d) => PaymentModel.fromMap(d.data(), d.id)).toList();
  }

  @override
  Future<List<PaymentModel>> getPaymentsByTask(String taskId) async {
    final snap = await firestore.collection('payments').where('taskId', WhereFilter.equal, taskId).get();
    return snap.docs.map((d) => PaymentModel.fromMap(d.data(), d.id)).toList();
  }

  @override
  Future<PaymentModel> getPaymentByReference(String reference) async {
    final snap = await firestore
        .collection('payments')
        .where('transactionRef', WhereFilter.equal, reference)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) throw NotFoundException('Payment', reference);
    return PaymentModel.fromMap(snap.docs.first.data(), snap.docs.first.id);
  }

  @override
  Future<void> markAsPaid(String id, String receiptUrl, String? transactionRef) async {
    await firestore.collection('payments').doc(id).update({
      'status': 'Paid',
      'receiptUrl': receiptUrl,
      'transactionRef': transactionRef,
      'paidDate': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> markAsPaidByReference(String reference, String receiptUrl, String? transactionRef) async {
    final snap = await firestore
        .collection('payments')
        .where('transactionRef', WhereFilter.equal, reference)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) {
      print('No payment found for reference: $reference');
      return;
    }

    final doc = snap.docs.first;
    final paymentId = doc.id;

    await firestore.collection('payments').doc(paymentId).update({
      'status': 'Paid',
      'receiptUrl': receiptUrl,
      'transactionRef': transactionRef,
      'paidDate': DateTime.now().toIso8601String(),
    });

    // Log to history for both tenant and landowner
    final paymentData = doc.data() as Map<String, dynamic>;
    final payerId = paymentData['payerId'] as String;
    final leaseId = paymentData['leaseId'] as String?;

    // await historyRepository.createHistoryEntry(
    //   HistoryEntryModel(
    //     id: '',
    //     userId: payerId,
    //     type: 'payment_made',
    //     title: 'Rent payment completed',
    //     description: '₦${paymentData['amount']} paid successfully',
    //     relatedId: paymentId,
    //     relatedCollection: 'payments',
    //     timestamp: DateTime.now(),
    //     metadata: {'leaseId': leaseId},
    //   ),
    // );

    // You can also log for the landowner if needed
  }

  // Withdrawals
  @override
  Future<WithdrawalModel> createWithdrawal(WithdrawalModel withdrawal) async {
    final docRef = firestore.collection('withdrawals').doc();
    final newWithdrawal = withdrawal.copyWith(id: docRef.id);
    await docRef.set(newWithdrawal.toMap());
    return newWithdrawal;
  }

  @override
  Future<WithdrawalModel> getWithdrawalById(String id) async {
    final doc = await firestore.collection('withdrawals').doc(id).get();
    if (!doc.exists) throw NotFoundException('Withdrawal', id);
    return WithdrawalModel.fromMap(doc.data() as Map<String, dynamic>, id);
  }

  @override
  Future<List<WithdrawalModel>> getWithdrawalsByUser(String userId) async {
    final snap = await firestore.collection('withdrawals').where('userId', WhereFilter.equal, userId).get();
    return snap.docs.map((d) => WithdrawalModel.fromMap(d.data(), d.id)).toList();
  }

  @override
  Future<void> updateWithdrawalStatus(String id, String status, String? processedBy) async {
    await firestore.collection('withdrawals').doc(id).update({
      'status': status,
      'processedAt': DateTime.now().toIso8601String(),
      'processedBy': processedBy,
    });
  }

  @override
  Future<bool> isPaymentAlreadyProcessed(String reference) async {
    final snap = await firestore
        .collection('processed_payments')
        .where('reference', WhereFilter.equal, reference)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  @override
  Future<void> markPaymentAsProcessed(String reference) async {
    await firestore.collection('processed_payments').doc(reference).set({
      'reference': reference,
      'processedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<Map<String, dynamic>> getPaymentSummary(String userId, String role) async {
    try {
      double totalReceived = 0.0;
      double totalWithdrawn = 0.0;
      int totalTransactions = 0;
      double avgRent = 0.0;

      // Get all payments where user is receiver (for landowners/managers)
      if (['landowner', 'manager'].contains(role)) {
        final receivedSnap = await firestore
            .collection('payments')
            .where('receiverId', WhereFilter.equal, userId)
            .where('status', WhereFilter.equal, 'Paid')
            .get();

        totalReceived = receivedSnap.docs.fold(0.0, (sum, doc) {
          final data = doc.data() as Map<String, dynamic>;
          return sum + (data['amount'] as num).toDouble();
        });

        totalTransactions = receivedSnap.docs.length;
      }

      // Get withdrawals
      final withdrawalSnap = await firestore
          .collection('withdrawals')
          .where('userId', WhereFilter.equal, userId)
          .get();

      totalWithdrawn = withdrawalSnap.docs.fold(0.0, (sum, doc) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['status'].toString().toLowerCase() == 'completed') {
          return sum + (data['amount'] as num).toDouble();
        }
        return sum;
      });

      // Calculate average rent (only for paid rent payments)
      if (totalTransactions > 0) {
        avgRent = totalReceived / totalTransactions;
      }

      return {
        'totalReceived': totalReceived,
        'totalWithdrawn': totalWithdrawn,
        'balance': totalReceived - totalWithdrawn,
        'totalTransactions': totalTransactions,
        'avgRent': avgRent,
        'withdrawableAmount': totalReceived - totalWithdrawn,
      };
    } catch (e) {
      print('Error getting payment summary: $e');
      return {
        'totalReceived': 0.0,
        'totalWithdrawn': 0.0,
        'balance': 0.0,
        'totalTransactions': 0,
        'avgRent': 0.0,
        'withdrawableAmount': 0.0,
      };
    }
  }

  @override
  Future<List<PaymentModel>> getPaymentsByProperty(String propertyId) async {
    try {
      final snap = await firestore
          .collection('payments')
          .where('propertyId', WhereFilter.equal, propertyId)
          .orderBy('createdAt', descending: true)
          .get();

      return snap.docs.map((d) => PaymentModel.fromMap(d.data() as Map<String, dynamic>, d.id)).toList();
    } catch (e) {
      print('Error fetching payments by property: $e');
      return [];
    }
  }

  @override
  Future<List<PaymentModel>> getPaymentsByUnit(String unitId) async {
    try {
      final snap = await firestore
          .collection('payments')
          .where('unitId', WhereFilter.equal, unitId)
          .orderBy('createdAt', descending: true)
          .get();

      return snap.docs.map((d) => PaymentModel.fromMap(d.data() as Map<String, dynamic>, d.id)).toList();
    } catch (e) {
      print('Error fetching payments by unit: $e');
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>> getPropertyPaymentSummary(String propertyId) async {
    try {
      final paymentsSnap = await firestore
          .collection('payments')
          .where('propertyId', WhereFilter.equal, propertyId)
          .where('status', WhereFilter.equal, 'Paid')
          .get();

      double totalRevenue = 0.0;
      int totalPayments = paymentsSnap.docs.length;

      for (var doc in paymentsSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        totalRevenue += (data['amount'] as num).toDouble();
      }

      return {
        'propertyId': propertyId,
        'totalRevenue': totalRevenue,
        'totalPayments': totalPayments,
        'avgPayment': totalPayments > 0 ? totalRevenue / totalPayments : 0.0,
      };
    } catch (e) {
      print('Error getting property payment summary: $e');
      return {'propertyId': propertyId, 'totalRevenue': 0.0, 'totalPayments': 0, 'avgPayment': 0.0};
    }
  }

  @override
  Future<void> approveWithdrawal(String withdrawalId, String processedBy) async {
    await firestore.collection('withdrawals').doc(withdrawalId).update({
      'status': 'Completed',
      'processedAt': DateTime.now().toIso8601String(),
      'processedBy': processedBy,
    });
  }

  @override
  Future<void> rejectWithdrawal(String withdrawalId, String processedBy, String? reason) async {
    await firestore.collection('withdrawals').doc(withdrawalId).update({
      'status': 'Rejected',
      'processedAt': DateTime.now().toIso8601String(),
      'processedBy': processedBy,
      'rejectionReason': reason,
    });
  }
}
