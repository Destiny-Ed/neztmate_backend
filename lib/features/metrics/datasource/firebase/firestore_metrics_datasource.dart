import 'package:dart_firebase_admin/firestore.dart';
import 'package:neztmate_backend/features/metrics/datasource/metric_remote_datasource.dart';

class FirestoreMetricsDataSource implements MetricsRemoteDataSource {
  final Firestore firestore;
  FirestoreMetricsDataSource(this.firestore);

  @override
  Future<Map<String, dynamic>> getRevenueMetrics({String? partnerId}) async {
    double totalPaidVolume = 0;
    double subscriptionRevenue = 0;
    double applicationFeeRevenue = 0;
    double platformFeeRevenue = 0;
    double rentRevenue = 0;
    double taskPaymentRevenue = 0;

    Query paymentsQuery = firestore.collection('payments').where('status', WhereFilter.equal, 'Paid');

    // If you store partnerId on payments:
    if (partnerId != null && partnerId.isNotEmpty) {
      paymentsQuery = firestore
          .collection('payments')
          .where('status', WhereFilter.equal, 'Paid')
          .where('partnerId', WhereFilter.equal, partnerId);
    }

    final paySnap = await paymentsQuery.get();
    for (final doc in paySnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
      final type = (data['type'] as String?)?.toLowerCase() ?? '';

      totalPaidVolume += amount;
      switch (type) {
        case 'subscription':
          subscriptionRevenue += amount;
          break;
        case 'application_fee':
          applicationFeeRevenue += amount;
          break;
        case 'platform_fee':
          platformFeeRevenue += amount;
          break;
        case 'rent':
        case 'rent-renewal':
          rentRevenue += amount;
          break;
        case 'task':
        case 'maintenance':
          taskPaymentRevenue += amount;
          break;
      }
    }

    // Platform fees collection (optional)
    double heldPlatformFees = 0;
    try {
      Query feeQ = firestore.collection('platform_fees');
      if (partnerId != null && partnerId.isNotEmpty) {
        feeQ = feeQ.where('partnerId', WhereFilter.equal, partnerId);
      }
      final feeSnap = await feeQ.get();
      for (final doc in feeSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        heldPlatformFees += (data['amount'] as num?)?.toDouble() ?? 0.0;
      }
      if (platformFeeRevenue == 0) platformFeeRevenue = heldPlatformFees;
    } catch (_) {}

    // Withdrawals
    double pendingWithdrawals = 0;
    double completedWithdrawals = 0;
    try {
      Query wQ = firestore.collection('withdrawals');
      if (partnerId != null && partnerId.isNotEmpty) {
        wQ = wQ.where('partnerId', WhereFilter.equal, partnerId);
      }
      final wSnap = await wQ.get();
      for (final doc in wSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
        final st = (data['status'] as String?)?.toLowerCase() ?? '';
        if (st == 'pending' || st == 'processing') {
          pendingWithdrawals += amount;
        } else if (st == 'completed' || st == 'paid') {
          completedWithdrawals += amount;
        }
      }
    } catch (_) {}

    // Active subscriptions
    int activeSubscriptions = 0;
    try {
      Query sQ = firestore.collection('user_subscriptions').where('status', WhereFilter.equal, 'active');
      if (partnerId != null && partnerId.isNotEmpty) {
        sQ = firestore
            .collection('user_subscriptions')
            .where('status', WhereFilter.equal, 'active')
            .where('partnerId', WhereFilter.equal, partnerId);
      }
      final sSnap = await sQ.get();
      activeSubscriptions = sSnap.docs.length;
    } catch (_) {}

    // Affiliate payouts (optional)
    double affiliatePayouts = 0;
    try {
      final aSnap = await firestore
          .collection('affiliate_payouts')
          .where('status', WhereFilter.equal, 'paid')
          .get();
      for (final doc in aSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (partnerId != null &&
            partnerId.isNotEmpty &&
            data['partnerId'] != null &&
            data['partnerId'] != partnerId) {
          continue;
        }
        affiliatePayouts += (data['amount'] as num?)?.toDouble() ?? 0.0;
      }
    } catch (_) {}

    return {
      'totalPaidVolume': totalPaidVolume,
      'subscriptionRevenue': subscriptionRevenue,
      'applicationFeeRevenue': applicationFeeRevenue,
      'platformFeeRevenue': platformFeeRevenue,
      'rentRevenue': rentRevenue,
      'taskPaymentRevenue': taskPaymentRevenue,
      'pendingWithdrawals': pendingWithdrawals,
      'completedWithdrawals': completedWithdrawals,
      'activeSubscriptions': activeSubscriptions,
      'affiliatePayouts': affiliatePayouts,
    };
  }
}
