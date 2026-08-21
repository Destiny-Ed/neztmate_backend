import 'package:neztmate_backend/features/affiliates/model/affiliate_earning_model.dart';
import 'package:neztmate_backend/features/affiliates/model/affiliate_payout_model.dart';
import 'package:neztmate_backend/features/affiliates/model/referral_stats_model.dart';

abstract class AffiliateRepository {
  Future<ReferralStatsModel> getReferralStats(String userId, {required String partnerId});

  Future<List<AffiliateEarningModel>> getEarnings(
    String affiliateId, {
    required String partnerId,
    int limit = 20,
  });

  Future<void> recordEarning(AffiliateEarningModel earning);

  Future<void> updateReferralStats(
    String userId, {
    required String partnerId,
    int? incrementReferrals,
    int? incrementSuccessfulApplications,
    double? totalEarningsDelta,
    double? paidEarningsDelta,
  });

  Future<AffiliatePayoutModel> requestPayout({
    required String affiliateId,
    required String partnerId,
    required double amount,
  });

  Future<AffiliatePayoutModel> getPayoutById(String payoutId);

  Future<List<AffiliatePayoutModel>> getPayoutHistory(String affiliateId, {required String partnerId});

  Future<void> processPayout(String payoutId, String transferRef);

  Future<List<AffiliatePayoutModel>> getPendingPayouts({int olderThanDays = 3, String? partnerId});
}
