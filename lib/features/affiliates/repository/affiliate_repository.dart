import 'package:neztmate_backend/features/affiliates/model/affiliate_earning_model.dart';
import 'package:neztmate_backend/features/affiliates/model/affiliate_payout_model.dart';
import 'package:neztmate_backend/features/affiliates/model/referral_stats_model.dart';

abstract class AffiliateRepository {
  Future<ReferralStatsModel> getReferralStats(String userId);
  Future<List<AffiliateEarningModel>> getEarnings(String affiliateId, {int limit = 20});
  Future<void> recordEarning(AffiliateEarningModel earning);
  Future<void> updateReferralStats(
    String userId, {
    int? incrementReferrals,
    double? totalEarningsDelta, // Can be positive or negative. for new earnings
    double? paidEarningsDelta, // Can be positive or negative. when payout is requested
  });

  Future<void> requestPayout(String affiliateId, double amount);
  Future<AffiliatePayoutModel> getPayoutById(String payoutId);
  Future<List<AffiliatePayoutModel>> getPayoutHistory(String affiliateId);
  Future<void> processPayout(String payoutId, String transferRef);

  Future<List<AffiliatePayoutModel>> getPendingPayouts({int olderThanDays = 3});
}
