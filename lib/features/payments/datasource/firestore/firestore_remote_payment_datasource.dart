import 'package:dart_firebase_admin/firestore.dart';
import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/features/payments/datasource/remote_datasource.dart';
import 'package:neztmate_backend/features/payments/models/manager_commission_model.dart';
import 'package:neztmate_backend/features/payments/models/payment_disbursement_model.dart';
import 'package:neztmate_backend/features/payments/models/payments.dart';
import 'package:neztmate_backend/features/payments/models/payout_account_model.dart';
import 'package:neztmate_backend/features/payments/models/plaform_fee_record_model.dart';
import 'package:neztmate_backend/features/payments/models/withdrawal_model.dart';

Query _withPartner(Query q, String? partnerId) {
  if (partnerId != null && partnerId.isNotEmpty) {
    return q.where('partnerId', WhereFilter.equal, partnerId);
  }
  return q;
}

class FirestorePaymentDataSource implements PaymentRemoteDataSource {
  final Firestore firestore;

  FirestorePaymentDataSource(this.firestore);

  // PAYMENTS

  CollectionReference get _disbursements => firestore.collection('payment_disbursements');
  CollectionReference get _platformFees => firestore.collection('platform_fees');

  @override
  Future<void> createDisbursement(PaymentDisbursementModel disbursement) async {
    final docRef = _disbursements.doc();
    final newDisbursement = disbursement.copyWith(id: docRef.id);
    await docRef.set(newDisbursement.toMap());
  }

  @override
  Future<List<PaymentDisbursementModel>> getPendingDisbursements({String? partnerId}) async {
    var q = _disbursements
        .where('status', WhereFilter.equal, 'held')
        .where('scheduledDate', WhereFilter.lessThanOrEqual, DateTime.now().toIso8601String());
    q = _withPartner(q, partnerId);
    final snap = await q.get();
    return snap.docs
        .map((doc) => PaymentDisbursementModel.fromMap(doc.data() as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> markDisbursementAsCompleted(String disbursementId, String transferReference) async {
    await _disbursements.doc(disbursementId).update({
      'status': 'completed',
      'disbursedAt': DateTime.now().toIso8601String(),
      'paystackTransferReference': transferReference,
    });
  }

  @override
  Future<void> markDisbursementAsFailed(String disbursementId, String reason) async {
    await _disbursements.doc(disbursementId).update({
      'status': 'failed',
      'failureReason': reason,
      'disbursedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> createWithdrawalAsFallback(PaymentDisbursementModel disbursement) async {
    // Fallback: Create a manual withdrawal request
    await firestore.collection('withdrawals').add({
      'userId': disbursement.recipientId,
      'amount': disbursement.netAmount,
      'reason': 'Auto-payout fallback for payment ${disbursement.paymentId}',
      'status': 'pending',
      'createdAt': DateTime.now().toIso8601String(),
      'type': 'fallback',
    });
  }

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
  Future<List<PaymentModel>> getPaymentsByUser(String userId, {String? partnerId}) async {
    Query q = firestore.collection('payments').where('payerId', WhereFilter.equal, userId);
    q = _withPartner(q, partnerId);
    final snap = await q.orderBy('createdAt', descending: true).get();
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
      'status': 'paid',
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
      'status': 'paid',
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

  //         if (status == 'paid') {
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

        if (status == 'paid') {
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
  Future<List<WithdrawalModel>> getWithdrawalsByUser(String userId, {String? partnerId}) async {
    Query q = firestore.collection('withdrawals').where('userId', WhereFilter.equal, userId);
    q = _withPartner(q, partnerId);
    final snap = await q.orderBy('requestedAt', descending: true).get();
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
    await updateWithdrawalStatus(withdrawalId, 'completed', processedBy);
  }

  @override
  Future<void> rejectWithdrawal(String withdrawalId, String processedBy, String? reason) async {
    await firestore.collection('withdrawals').doc(withdrawalId).update({
      'status': 'rejected',
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

  @override
  Future<PayoutAccountModel> savePayoutAccount(PayoutAccountModel account) async {
    final docRef = firestore.collection('payout_accounts').doc();
    final newAccount = account.copyWith(id: docRef.id);
    await docRef.set(newAccount.toMap());
    return newAccount;
  }

  @override
  Future<void> removePayoutAccount(String accountId) async {
    await firestore.collection('payout_accounts').doc(accountId).delete();
  }

  @override
  Future<List<PayoutAccountModel>> getPayoutAccounts(
    String userId, {
    String? propertyId,
    String? partnerId,
  }) async {
    Query query = firestore.collection('payout_accounts').where('userId', WhereFilter.equal, userId);
    query = _withPartner(query, partnerId);
    if (propertyId != null) {
      query = query.where('propertyId', WhereFilter.equal, propertyId);
    }
    final snap = await query.orderBy('createdAt', descending: true).get();
    return snap.docs.map((d) => PayoutAccountModel.fromMap(d.data() as Map<String, dynamic>)).toList();
  }

  @override
  Future<PayoutAccountModel?> getDefaultPayoutAccount(
    String userId, {
    String? propertyId,
    String? partnerId,
  }) async {
    Query query = firestore
        .collection('payout_accounts')
        .where('userId', WhereFilter.equal, userId)
        .where('isDefault', WhereFilter.equal, true);
    query = _withPartner(query, partnerId);
    if (propertyId != null) {
      query = query.where('propertyId', WhereFilter.equal, propertyId);
    }
    final snap = await query.limit(1).get();
    if (snap.docs.isEmpty) return null;
    return PayoutAccountModel.fromMap(snap.docs.first.data() as Map<String, dynamic>);
  }

  @override
  Future<void> setDefaultPayoutAccount(String accountId, String userId) async {
    final snap = await firestore
        .collection('payout_accounts')
        .where('userId', WhereFilter.equal, userId)
        .get();

    if (snap.docs.isEmpty) return;

    // Update all accounts
    final updateFutures = snap.docs.map((doc) {
      final isDefault = doc.id == accountId;
      return firestore.collection('payout_accounts').doc(doc.id).update({
        'isDefault': isDefault,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    }).toList();

    await Future.wait(updateFutures);
  }

  //  WALLET DEDUCTION (No balance field)

  @override
  Future<void> deductFromPropertyBalance({
    required String propertyId,
    required double amount,
    required String reason,
    required String reference,
  }) async {
    // We don't store a balance field. We just log the deduction as a transaction.
    await firestore.collection('balance_transactions').add({
      'propertyId': propertyId,
      'amount': amount,
      'type': 'deduction',
      'reason': reason,
      'reference': reference,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<double> getPropertyAvailableBalance(String propertyId) async {
    try {
      // Calculate from payments - withdrawals
      final paymentsSnap = await firestore
          .collection('payments')
          .where('propertyId', WhereFilter.equal, propertyId)
          .where('status', WhereFilter.equal, 'paid')
          .get();

      double totalReceived = 0.0;
      for (var doc in paymentsSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        totalReceived += (data['amount'] as num).toDouble();
      }

      final withdrawalsSnap = await firestore
          .collection('withdrawals')
          .where('propertyId', WhereFilter.equal, propertyId)
          .where('status', WhereFilter.equal, 'completed')
          .get();

      double totalWithdrawn = 0.0;
      for (var doc in withdrawalsSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        totalWithdrawn += (data['amount'] as num).toDouble();
      }

      return totalReceived - totalWithdrawn;
    } catch (e) {
      print('Error calculating property balance: $e');
      return 0.0;
    }
  }

  @override
  Future<PayoutAccountModel?> getPayoutAccountById(String id) async {
    final snap = await firestore.collection('payout_accounts').doc(id).get();
    if (!snap.exists) return null;
    return PayoutAccountModel.fromMap(snap.data() as Map<String, dynamic>);
  }

  @override
  Future<void> updatePayoutAccount(PayoutAccountModel account) async {
    await firestore.collection('payout_accounts').doc(account.id).update(account.toMap());
  }

  @override
  Future<void> recordPlatformFee(
    String paymentId,
    double amount,
    String paymentType, {
    String? partnerId,
  }) async {
    await _platformFees.add({
      'paymentId': paymentId,
      'amount': amount,
      'paymentType': paymentType,
      'partnerId': partnerId ?? 'neztmate',
      'status': 'collected',
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<List<PlatformFeeRecord>> getPlatformFeeHistory({String? partnerId}) async {
    var q = _platformFees.orderBy('collectedAt', descending: true);
    q = _withPartner(q, partnerId);
    final snap = await q.get();
    return snap.docs.map((doc) {
      return PlatformFeeRecord.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }).toList();
  }

  @override
  Future<double> getTotalUnwithdrawnPlatformFees({String? partnerId}) async {
    var q = _platformFees.where('status', WhereFilter.equal, 'collected');
    q = _withPartner(q, partnerId);
    final snap = await q.get();
    double total = 0.0;
    for (final doc in snap.docs) {
      total += ((doc.data() as Map)['amount'] as num).toDouble();
    }
    return total;
  }

  @override
  Future<void> markPlatformFeesAsWithdrawn(String withdrawalReference, {String? partnerId}) async {
    var q = _platformFees.where('status', WhereFilter.equal, 'collected');
    q = _withPartner(q, partnerId);
    final snap = await q.get();
    for (final doc in snap.docs) {
      await doc.ref.update({
        'status': 'withdrawn',
        'withdrawnAt': DateTime.now().toIso8601String(),
        'withdrawalReference': withdrawalReference,
      });
    }
  }

  //  MANAGER COMMISSION

  @override
  Future<void> recordManagerCommission(ManagerCommissionModel commission) async {
    try {
      final docRef = firestore.collection('manager_commissions').doc();
      final newCommission = commission.copyWith(id: docRef.id);

      await docRef.set(newCommission.toMap());

      print(
        '💰 Manager commission recorded: ₦${commission.commissionAmount} for manager ${commission.managerId}',
      );
    } catch (e) {
      print('Error recording manager commission: $e');
      rethrow;
    }
  }

  @override
  Future<double> getTotalPendingCommission(String managerId, {String? partnerId}) async {
    Query q = firestore
        .collection('manager_commissions')
        .where('managerId', WhereFilter.equal, managerId)
        .where('status', WhereFilter.equal, 'pending');
    q = _withPartner(q, partnerId);
    final snap = await q.get();
    double total = 0.0;
    for (final doc in snap.docs) {
      total += ((doc.data() as Map)['commissionAmount'] as num).toDouble();
    }
    return total;
  }

  @override
  Future<List<ManagerCommissionModel>> getManagerCommissions(String managerId, {String? partnerId}) async {
    Query q = firestore.collection('manager_commissions').where('managerId', WhereFilter.equal, managerId);
    q = _withPartner(q, partnerId);
    final snap = await q.orderBy('createdAt', descending: true).get();
    return snap.docs
        .map((doc) => ManagerCommissionModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  @override
  Future<List<ManagerCommissionModel>> getManagersCommissions({String? partnerId}) async {
    Query q = firestore.collection('manager_commissions').where('status', WhereFilter.equal, 'pending')
      ..where(
        'createdAt',
        WhereFilter.lessThan,
        DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
      );
    q = _withPartner(q, partnerId);
    final snap = await q.orderBy('createdAt', descending: true).get();
    return snap.docs
        .map((doc) => ManagerCommissionModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  @override
  Future<void> markCommissionAsPaid(String commissionId, String payoutReference) async {
    await firestore.collection('manager_commissions').doc(commissionId).update({
      'status': 'paid',
      'paidAt': DateTime.now().toIso8601String(),
      'payoutReference': payoutReference,
    });
  }
}
