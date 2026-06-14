import 'package:dart_firebase_admin/firestore.dart';
import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/features/payments/datasource/remote_datasource.dart';
import 'package:neztmate_backend/features/payments/models/payments.dart';
import 'package:neztmate_backend/features/payments/models/withdrawal_model.dart';

class FirestorePaymentDataSource implements PaymentRemoteDataSource {
  final Firestore firestore;

  FirestorePaymentDataSource(this.firestore);

  // PAYMENTS

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
    return PaymentModel.fromMap(doc.data() as Map<String, dynamic>);
  }

  @override
  Future<PaymentModel> getPaymentByReference(String reference) async {
    final snap = await firestore
        .collection('payments')
        .where('transactionRef', WhereFilter.equal, reference)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) throw NotFoundException('Payment with reference', reference);
    final doc = snap.docs.first;
    return PaymentModel.fromMap(doc.data() as Map<String, dynamic>);
  }

  @override
  Future<List<PaymentModel>> getPaymentsByLease(String leaseId) async {
    final snap = await firestore
        .collection('payments')
        .where('leaseId', WhereFilter.equal, leaseId)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => PaymentModel.fromMap(d.data() as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<PaymentModel>> getPaymentsByUser(String userId) async {
    final snap = await firestore
        .collection('payments')
        .where('payerId', WhereFilter.equal, userId)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => PaymentModel.fromMap(d.data() as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<PaymentModel>> getPaymentsByTask(String taskId) async {
    final snap = await firestore
        .collection('payments')
        .where('taskId', WhereFilter.equal, taskId)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => PaymentModel.fromMap(d.data() as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<PaymentModel>> getPaymentsByProperty(String propertyId) async {
    final snap = await firestore
        .collection('payments')
        .where('propertyId', WhereFilter.equal, propertyId)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => PaymentModel.fromMap(d.data() as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<PaymentModel>> getPaymentsByUnit(String unitId) async {
    final snap = await firestore
        .collection('payments')
        .where('unitId', WhereFilter.equal, unitId)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => PaymentModel.fromMap(d.data() as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> markAsPaid(String id, String receiptUrl, String? transactionRef) async {
    await firestore.collection('payments').doc(id).update({
      'status': 'Paid',
      'receiptUrl': receiptUrl,
      'transactionRef': transactionRef,
      'paidDate': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
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
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  // SUMMARY & ANALYTICS

  // @override
  // Future<Map<String, dynamic>> getPaymentSummary(String userId, String role) async {
  //   try {
  //     double totalReceived = 0.0;
  //     double totalWithdrawn = 0.0;
  //     int totalTransactions = 0;
  //     double avgRent = 0.0;
  //     int pendingPayments = 0;

  //     if (['landowner', 'manager'].contains(role)) {
  //       final receivedSnap = await firestore
  //           .collection('payments')
  //           .where('receiverId', WhereFilter.equal, userId)
  //           .get();

  //       for (var doc in receivedSnap.docs) {
  //         final data = doc.data() as Map<String, dynamic>;
  //         final amount = (data['amount'] as num).toDouble();
  //         final status = data['status'] as String?;

  //         if (status == 'Paid') {
  //           totalReceived += amount;
  //           totalTransactions++;
  //         } else if (status == 'Pending') {
  //           pendingPayments++;
  //         }
  //       }

  //       if (totalTransactions > 0) {
  //         avgRent = totalReceived / totalTransactions;
  //       }
  //     }

  //     // Withdrawals
  //     final withdrawalSnap = await firestore
  //         .collection('withdrawals')
  //         .where('userId', WhereFilter.equal, userId)
  //         .get();

  //     totalWithdrawn = withdrawalSnap.docs.fold(0.0, (sum, doc) {
  //       final data = doc.data() as Map<String, dynamic>;
  //       if (data['status'] == 'Completed') {
  //         return sum + (data['amount'] as num).toDouble();
  //       }
  //       return sum;
  //     });

  //     return {
  //       'totalReceived': totalReceived,
  //       'totalWithdrawn': totalWithdrawn,
  //       'balance': totalReceived - totalWithdrawn,
  //       'totalTransactions': totalTransactions,
  //       'pendingPayments': pendingPayments,
  //       'avgRent': avgRent,
  //       'withdrawableAmount': totalReceived - totalWithdrawn,
  //     };
  //   } catch (e) {
  //     print('Error getting payment summary: $e');
  //     return {
  //       'totalReceived': 0.0,
  //       'totalWithdrawn': 0.0,
  //       'balance': 0.0,
  //       'totalTransactions': 0,
  //       'pendingPayments': 0,
  //       'avgRent': 0.0,
  //       'withdrawableAmount': 0.0,
  //     };
  //   }
  // }

  @override
  Future<Map<String, dynamic>> getPropertyPaymentSummary(String propertyId) async {
    try {
      final paymentsSnap = await firestore
          .collection('payments')
          .where('propertyId', WhereFilter.equal, propertyId)
          .get();

      double totalRevenue = 0.0;
      int totalPayments = 0;
      int pendingCount = 0;

      for (var doc in paymentsSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final amount = (data['amount'] as num).toDouble();
        final status = data['status'] as String?;

        if (status == 'Paid') {
          totalRevenue += amount;
          totalPayments++;
        } else if (status == 'Pending') {
          pendingCount++;
        }
      }

      return {
        'propertyId': propertyId,
        'totalRevenue': totalRevenue,
        'totalPayments': totalPayments,
        'pendingPayments': pendingCount,
        'avgPayment': totalPayments > 0 ? totalRevenue / totalPayments : 0.0,
      };
    } catch (e) {
      print('Error getting property payment summary: $e');
      return {
        'propertyId': propertyId,
        'totalRevenue': 0.0,
        'totalPayments': 0,
        'pendingPayments': 0,
        'avgPayment': 0.0,
      };
    }
  }

  // WITHDRAWALS

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
    return WithdrawalModel.fromMap(doc.data() as Map<String, dynamic>);
  }

  @override
  Future<List<WithdrawalModel>> getWithdrawalsByUser(String userId) async {
    final snap = await firestore
        .collection('withdrawals')
        .where('userId', WhereFilter.equal, userId)
        .orderBy('requestedAt', descending: true)
        .get();
    return snap.docs.map((d) => WithdrawalModel.fromMap(d.data() as Map<String, dynamic>)).toList();
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
  Future<void> approveWithdrawal(String withdrawalId, String processedBy) async {
    await updateWithdrawalStatus(withdrawalId, 'Completed', processedBy);
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
  Future<List<WithdrawalModel>> getWithdrawalsByProperty(String propertyId) async {
    final snap = await firestore
        .collection('withdrawals')
        .where('propertyId', WhereFilter.equal, propertyId)
        .orderBy('requestedAt', descending: true)
        .get();

    return snap.docs.map((d) => WithdrawalModel.fromMap(d.data() as Map<String, dynamic>)).toList();
  }
}
