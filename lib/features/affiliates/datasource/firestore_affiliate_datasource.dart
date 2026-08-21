import 'package:dart_firebase_admin/firestore.dart';
import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/features/affiliates/model/affiliate_earning_model.dart';
import 'package:neztmate_backend/features/affiliates/model/affiliate_payout_model.dart';
import 'package:neztmate_backend/features/affiliates/model/referral_stats_model.dart';
import 'package:neztmate_backend/features/affiliates/repository/affiliate_repository.dart';

class FirestoreAffiliateRepository implements AffiliateRepository {
  final Firestore firestore;

  FirestoreAffiliateRepository(this.firestore);

  CollectionReference get _stats => firestore.collection('referral_stats');
  CollectionReference get _earnings => firestore.collection('affiliate_earnings');
  CollectionReference get _payouts => firestore.collection('affiliate_payouts');

  @override
  Future<ReferralStatsModel> getReferralStats(String userId, {required String partnerId}) async {
    final id = ReferralStatsModel.docId(userId, partnerId);
    final doc = await _stats.doc(id).get();

    if (!doc.exists) {
      final defaultStats = ReferralStatsModel(
        userId: userId,
        partnerId: partnerId,
        referralCode: _generateReferralCode(userId, partnerId),
      );
      await _stats.doc(id).set(defaultStats.toMap());
      return defaultStats;
    }

    final data = doc.data() as Map<String, dynamic>;
    return ReferralStatsModel.fromMap({...data, 'userId': data['userId'] ?? userId});
  }

  @override
  Future<List<AffiliateEarningModel>> getEarnings(
    String affiliateId, {
    required String partnerId,
    int limit = 20,
  }) async {
    final snapshot = await _earnings
        .where('affiliateId', WhereFilter.equal, affiliateId)
        .where('partnerId', WhereFilter.equal, partnerId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return AffiliateEarningModel.fromMap({...data, 'id': data['id'] ?? doc.id});
    }).toList();
  }

  @override
  Future<void> recordEarning(AffiliateEarningModel earning) async {
    final docRef = _earnings.doc();
    final newEarning = earning.copyWith(id: docRef.id);
    await docRef.set(newEarning.toMap());
  }

  @override
  Future<void> updateReferralStats(
    String userId, {
    required String partnerId,
    int? incrementReferrals,
    int? incrementSuccessfulApplications,
    double? totalEarningsDelta,
    double? paidEarningsDelta,
  }) async {
    final id = ReferralStatsModel.docId(userId, partnerId);
    final docRef = _stats.doc(id);

    // Ensure doc exists
    final existing = await docRef.get();
    if (!existing.exists) {
      await getReferralStats(userId, partnerId: partnerId);
    }

    final updates = <String, dynamic>{
      'userId': userId,
      'partnerId': partnerId,
      'updatedAt': DateTime.now().toIso8601String(),
    };

    if (incrementReferrals != null) {
      updates['totalReferrals'] = FieldValue.increment(incrementReferrals);
    }
    if (incrementSuccessfulApplications != null) {
      updates['successfulApplications'] = FieldValue.increment(incrementSuccessfulApplications);
    }
    if (totalEarningsDelta != null) {
      updates['totalEarnings'] = FieldValue.increment(totalEarningsDelta);
    }
    if (paidEarningsDelta != null) {
      updates['paidEarnings'] = FieldValue.increment(paidEarningsDelta);
    }

    await docRef.set(updates);
  }

  @override
  Future<AffiliatePayoutModel> requestPayout({
    required String affiliateId,
    required String partnerId,
    required double amount,
  }) async {
    final docRef = _payouts.doc();
    final payout = AffiliatePayoutModel(
      id: docRef.id,
      affiliateId: affiliateId,
      partnerId: partnerId,
      amount: amount,
      status: 'pending',
      requestedAt: DateTime.now(),
    );
    await docRef.set(payout.toMap());
    return payout;
  }

  @override
  Future<List<AffiliatePayoutModel>> getPayoutHistory(String affiliateId, {required String partnerId}) async {
    final snap = await _payouts
        .where('affiliateId', WhereFilter.equal, affiliateId)
        .where('partnerId', WhereFilter.equal, partnerId)
        .orderBy('requestedAt', descending: true)
        .get();

    return snap.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return AffiliatePayoutModel.fromMap({...data, 'id': data['id'] ?? doc.id});
    }).toList();
  }

  @override
  Future<void> processPayout(String payoutId, String transferRef) async {
    await _payouts.doc(payoutId).update({
      'status': 'paid',
      'paystackTransferRef': transferRef,
      'processedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<AffiliatePayoutModel> getPayoutById(String payoutId) async {
    final doc = await _payouts.doc(payoutId).get();
    if (!doc.exists) throw NotFoundException('AffiliatePayout', payoutId);
    final data = doc.data() as Map<String, dynamic>;
    return AffiliatePayoutModel.fromMap({...data, 'id': data['id'] ?? doc.id});
  }

  @override
  Future<List<AffiliatePayoutModel>> getPendingPayouts({int olderThanDays = 3, String? partnerId}) async {
    final threshold = DateTime.now().subtract(Duration(days: olderThanDays));

    var query = _payouts
        .where('status', WhereFilter.equal, 'pending')
        .where('requestedAt', WhereFilter.lessThanOrEqual, threshold.toIso8601String());

    if (partnerId != null && partnerId.isNotEmpty) {
      query = query.where('partnerId', WhereFilter.equal, partnerId);
    }

    final snap = await query.get();
    return snap.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return AffiliatePayoutModel.fromMap({...data, 'id': data['id'] ?? doc.id});
    }).toList();
  }

  String _generateReferralCode(String userId, String partnerId) {
    final shortUser = userId.replaceAll('-', '');
    final prefix = shortUser.length >= 6 ? shortUser.substring(0, 6) : shortUser;
    final p = partnerId.length >= 3 ? partnerId.substring(0, 3) : partnerId;
    return '${p.toUpperCase()}${prefix.toUpperCase()}';
  }
}
