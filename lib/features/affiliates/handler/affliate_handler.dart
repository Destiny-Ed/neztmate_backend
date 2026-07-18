import 'dart:convert';

import 'package:neztmate_backend/core/services/payment/paystack_service.dart';
import 'package:neztmate_backend/features/affiliates/repository/affiliate_repository.dart';
import 'package:neztmate_backend/features/payments/repository/payment_repo.dart';
import 'package:shelf/shelf.dart';
import 'package:neztmate_backend/core/error.dart';
import '../../auth_user/repositories/user_repository.dart';

class AffiliateHandler {
  final AffiliateRepository affiliateRepository;
  final UserRepository userRepository;
  final PaymentRepository paymentRepository;

  AffiliateHandler(this.affiliateRepository, this.userRepository, this.paymentRepository);

  final paystackService = PaystackService();

  /// GET /affiliates/me - Get referral stats
  Future<Response> getMyReferralStats(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      if (userId == null) return unauthorized("You are not authorized");

      final stats = await affiliateRepository.getReferralStats(userId);

      return Response.ok(
        jsonEncode({
          'referralCode': stats.referralCode,
          'totalReferrals': stats.totalReferrals,
          'successfulApplications': stats.successfulApplications,
          'totalEarnings': stats.totalEarnings,
          'pendingEarnings': stats.pendingEarnings,
        }),
      );
    } catch (e, stack) {
      print('Get referral stats error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  /// GET /affiliates/earnings - Get earnings history
  Future<Response> getEarnings(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      if (userId == null) return unauthorized('You are not authorized');

      final earnings = await affiliateRepository.getEarnings(userId);

      return Response.ok(jsonEncode({'earnings': earnings.map((e) => e.toMap()).toList()}));
    } catch (e, stack) {
      print('Get earnings error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  /// POST /affiliates/generate-link - Generate referral link for a property or unit
  Future<Response> generateReferralLink(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      if (userId == null) return unauthorized('You are not authorized');

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final unitId = body['unitId'] as String?; // Support unit
      final propertyId = body['propertyId'] as String?;

      if (unitId == null && propertyId == null) {
        return badRequest('unitId or propertyId is required');
      }

      final stats = await affiliateRepository.getReferralStats(userId);

      String referralLink;

      if (unitId != null) {
        referralLink = "https://neztmate.com/units/$unitId/apply?ref=${stats.referralCode}";
      } else {
        referralLink = "https://neztmate.com/properties/$propertyId?ref=${stats.referralCode}";
      }

      return Response.ok(
        jsonEncode({
          'referralLink': referralLink,
          'referralCode': stats.referralCode,
          'target': unitId != null ? 'unit' : 'property',
        }),
      );
    } catch (e, stack) {
      print('Generate referral link error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  //Payoute

  /// POST /affiliates/request-payout
  Future<Response> requestPayout(Request request) async {
    try {
      final affiliateId = request.context['userId'] as String?;
      if (affiliateId == null) return unauthorized('You are not authorized');

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final amount = (body['amount'] as num?)?.toDouble();

      if (amount == null || amount <= 0) {
        return badRequest('Valid amount is required');
      }

      final stats = await affiliateRepository.getReferralStats(affiliateId);

      if (amount > stats.pendingEarnings) {
        return Response(
          400,
          body: jsonEncode({
            'message':
                'Insufficient pending earnings. Available: ₦${stats.pendingEarnings.toStringAsFixed(2)}',
          }),
        );
      }

      // 1. Create payout request
      await affiliateRepository.requestPayout(affiliateId, amount);

      // 2. Update stats (mark as paid → reduce pending)
      await affiliateRepository.updateReferralStats(
        affiliateId,
        paidEarningsDelta: amount, // This reduces pendingEarnings
      );

      return Response.ok(
        jsonEncode({
          'message': 'Payout request submitted successfully',
          'amount': amount,
          'newPendingBalance': stats.pendingEarnings - amount,
        }),
      );
    } catch (e, stack) {
      print('Request payout error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to process payout request'}));
    }
  }

  /// POST /admin/affiliates/process-payout
  Future<Response> processManualPayout(Request request) async {
    try {
      final adminId = request.context['userId'] as String?;
      final adminRole = request.context['role'] as String?;
      if (adminId == null || adminRole != 'admin') return unauthorized('You are not authorized');

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final payoutId = body['payoutId'] as String?;

      if (payoutId == null) return badRequest('payoutId is required');

      final payout = await affiliateRepository.getPayoutById(payoutId);

      final affiliateAccount = await paymentRepository.getDefaultPayoutAccount(payout.affiliateId);

      if (affiliateAccount == null || affiliateAccount.paystackSubaccountId == null) {
        return badRequest('Affiliate does not have a default payment account');
      }

      final success = await paystackService.transferToSubaccount(
        amount: payout.amount,
        subaccountId: affiliateAccount.paystackSubaccountId!,
        reference: 'manual_${payout.id}',
        reason: 'Manual affiliate payout',
      );

      if (success) {
        await affiliateRepository.processPayout(payoutId, 'manual_${DateTime.now().millisecondsSinceEpoch}');
      }

      return Response.ok(jsonEncode({'message': 'Payout processed successfully'}));
    } catch (e, stack) {
      print('Manual payout error: $e\n$stack');
      return Response.internalServerError();
    }
  }
}
