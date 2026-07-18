import 'package:dart_firebase_admin/firestore.dart';
import 'package:neztmate_backend/features/affiliates/model/affiliate_earning_model.dart';
import 'package:neztmate_backend/features/affiliates/model/affiliate_payout_model.dart';
import 'package:neztmate_backend/features/affiliates/model/referral_stats_model.dart';
import 'package:neztmate_backend/features/affiliates/repository/affiliate_repository.dart';

class FirestoreAffiliateRepository implements AffiliateRepository {
  final Firestore firestore;

  FirestoreAffiliateRepository(this.firestore);

  CollectionReference get _stats => firestore.collection('referral_stats');
  CollectionReference get _earnings => firestore.collection('affiliate_earnings');

  @override
  Future<ReferralStatsModel> getReferralStats(String userId) async {
    final doc = await _stats.doc(userId).get();

    if (!doc.exists) {
      // Create default stats if not exists
      final defaultStats = ReferralStatsModel(userId: userId, referralCode: _generateReferralCode(userId));
      await _stats.doc(userId).set(defaultStats.toMap());
      return defaultStats;
    }

    return ReferralStatsModel.fromMap(doc.data() as Map<String, dynamic>);
  }

  @override
  Future<List<AffiliateEarningModel>> getEarnings(String affiliateId, {int limit = 20}) async {
    final snapshot = await _earnings
        .where('affiliateId', WhereFilter.equal, affiliateId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => AffiliateEarningModel.fromMap(doc.data() as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> recordEarning(AffiliateEarningModel earning) async {
    final docRef = _earnings.doc();

    final newEarning = earning.copyWith(id: docRef.id);

    docRef.set(newEarning.toMap());
  }

  @override
  Future<void> updateReferralStats(
    String userId, {
    int? incrementReferrals,
    double? totalEarningsDelta, // Can be positive or negative
    double? paidEarningsDelta, // Can be positive or negative
  }) async {
    final docRef = _stats.doc(userId);

    final updates = <String, dynamic>{};

    if (incrementReferrals != null) {
      updates['totalReferrals'] = FieldValue.increment(incrementReferrals);
    }

    if (totalEarningsDelta != null) {
      updates['totalEarnings'] = FieldValue.increment(totalEarningsDelta);
    }

    if (paidEarningsDelta != null) {
      updates['paidEarnings'] = FieldValue.increment(paidEarningsDelta);
    }

    if (updates.isNotEmpty) {
      // await docRef.set(updates, SetOptions(merge: true));
      await docRef.set(updates);
    }
  }

  //Payout
  @override
  Future<void> requestPayout(String affiliateId, double amount) async {
    final docRef = firestore.collection('affiliate_payouts').doc();

    final payout = AffiliatePayoutModel(
      id: docRef.id,
      affiliateId: affiliateId,
      amount: amount,
      requestedAt: DateTime.now(),
    );

    await docRef.set(payout.toMap());
  }

  @override
  Future<List<AffiliatePayoutModel>> getPayoutHistory(String affiliateId) async {
    final snap = await firestore
        .collection('affiliate_payouts')
        .where('affiliateId', WhereFilter.equal, affiliateId)
        .orderBy('requestedAt', descending: true)
        .get();

    return snap.docs.map((doc) => AffiliatePayoutModel.fromMap(doc.data() as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> processPayout(String payoutId, String transferRef) async {
    await firestore.collection('affiliate_payouts').doc(payoutId).update({
      'status': 'paid',
      'paystackTransferRef': transferRef,
      'processedAt': DateTime.now().toIso8601String(),
    });
  }

  String _generateReferralCode(String userId) {
    return userId.substring(0, 6).toUpperCase();
  }

  @override
  Future<AffiliatePayoutModel> getPayoutById(String payoutId) async {
    final snap = await firestore
        .collection('affiliate_payouts')
        .where('id', WhereFilter.equal, payoutId)
        .get();

    return AffiliatePayoutModel.fromMap(snap as Map<String, dynamic>);
  }

  @override
  Future<List<AffiliatePayoutModel>> getPendingPayouts({int olderThanDays = 3}) async {
    final threshold = DateTime.now().subtract(Duration(days: olderThanDays));

    final snap = await firestore
        .collection('affiliate_payouts')
        .where('status', WhereFilter.equal, 'pending')
        .where('requestedAt', WhereFilter.lessThanOrEqual, threshold.toIso8601String())
        .get();

    return snap.docs.map((doc) => AffiliatePayoutModel.fromMap(doc.data() as Map<String, dynamic>)).toList();
  }
}
