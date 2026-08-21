import 'dart:convert';

import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/core/services/payment/paystack_service.dart';
import 'package:neztmate_backend/features/affiliates/repository/affiliate_repository.dart';
import 'package:neztmate_backend/features/auth_user/repositories/user_repository.dart';
import 'package:neztmate_backend/features/payments/repository/payment_repo.dart';
import 'package:shelf/shelf.dart';

class AffiliateHandler {
  final AffiliateRepository affiliateRepository;
  final UserRepository userRepository;
  final PaymentRepository paymentRepository;

  AffiliateHandler(this.affiliateRepository, this.userRepository, this.paymentRepository);

  final paystackService = PaystackService();

  String? _partnerId(Request request) => request.context['partnerId'] as String?;

  /// GET /affiliates/me
  Future<Response> getMyReferralStats(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final partnerId = _partnerId(request);

      if (userId == null || partnerId == null) return unauthorized('You are not authorized');

      final stats = await affiliateRepository.getReferralStats(userId, partnerId: partnerId);

      return Response.ok(
        jsonEncode({
          'referralCode': stats.referralCode,
          'partnerId': stats.partnerId,
          'totalReferrals': stats.totalReferrals,
          'successfulApplications': stats.successfulApplications,
          'totalEarnings': stats.totalEarnings,
          'paidEarnings': stats.paidEarnings,
          'pendingEarnings': stats.pendingEarnings,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Get referral stats error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  /// GET /affiliates/earnings
  Future<Response> getEarnings(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final partnerId = _partnerId(request);

      if (userId == null || partnerId == null) return unauthorized('You are not authorized');

      final earnings = await affiliateRepository.getEarnings(userId, partnerId: partnerId);

      return Response.ok(
        jsonEncode({'earnings': earnings.map((e) => e.toMap()).toList()}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Get earnings error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  /// GET /affiliates/payouts
  Future<Response> getPayoutHistory(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final partnerId = _partnerId(request);

      if (userId == null || partnerId == null) return unauthorized('You are not authorized');

      final payouts = await affiliateRepository.getPayoutHistory(userId, partnerId: partnerId);

      return Response.ok(
        jsonEncode({'payouts': payouts.map((p) => p.toMap()).toList()}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Get payout history error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  /// POST /affiliates/generate-link
  Future<Response> generateReferralLink(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final partnerId = _partnerId(request);

      if (userId == null || partnerId == null) return unauthorized('You are not authorized');

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final unitId = body['unitId'] as String?;
      final propertyId = body['propertyId'] as String?;

      if (unitId == null && propertyId == null) {
        return badRequest('unitId or propertyId is required');
      }

      final stats = await affiliateRepository.getReferralStats(userId, partnerId: partnerId);

      // White-label: use partner slug in path later if needed
      final String referralLink;
      if (unitId != null) {
        referralLink =
            'https://neztmate.com/units/$unitId/apply?ref=${stats.referralCode}&partner=$partnerId';
      } else {
        referralLink =
            'https://neztmate.com/properties/$propertyId?ref=${stats.referralCode}&partner=$partnerId';
      }

      return Response.ok(
        jsonEncode({
          'referralLink': referralLink,
          'referralCode': stats.referralCode,
          'partnerId': partnerId,
          'target': unitId != null ? 'unit' : 'property',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Generate referral link error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  /// POST /affiliates/request-payout
  Future<Response> requestPayout(Request request) async {
    try {
      final affiliateId = request.context['userId'] as String?;
      final partnerId = _partnerId(request);

      if (affiliateId == null || partnerId == null) return unauthorized('You are not authorized');

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final amount = (body['amount'] as num?)?.toDouble();

      if (amount == null || amount <= 0) {
        return badRequest('Valid amount is required');
      }

      final stats = await affiliateRepository.getReferralStats(affiliateId, partnerId: partnerId);

      if (amount > stats.pendingEarnings) {
        return Response(
          400,
          body: jsonEncode({
            'message':
                'Insufficient pending earnings. Available: ₦${stats.pendingEarnings.toStringAsFixed(2)}',
          }),
        );
      }

      final payout = await affiliateRepository.requestPayout(
        affiliateId: affiliateId,
        partnerId: partnerId,
        amount: amount,
      );

      // Move amount from pending → paid bucket (prevents double request)
      await affiliateRepository.updateReferralStats(
        affiliateId,
        partnerId: partnerId,
        paidEarningsDelta: amount,
      );

      return Response.ok(
        jsonEncode({
          'message': 'Payout request submitted successfully',
          'payout': payout.toMap(),
          'amount': amount,
          'newPendingBalance': stats.pendingEarnings - amount,
        }),
        headers: {'Content-Type': 'application/json'},
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
      if (adminId == null || adminRole != 'admin') {
        return unauthorized('You are not authorized');
      }

      final partnerId = _partnerId(request);
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final payoutId = body['payoutId'] as String?;

      if (payoutId == null) return badRequest('payoutId is required');

      final payout = await affiliateRepository.getPayoutById(payoutId);

      if (payout.partnerId != partnerId && partnerId != 'neztmate') {
        // Optional: platform admin can process any; partner admin only own partner
        return Response(403, body: jsonEncode({'message': 'Payout belongs to another partner'}));
      }

      if (payout.status.toLowerCase() != 'pending') {
        return badRequest('Payout is not pending');
      }

      final affiliateAccount = await paymentRepository.getDefaultPayoutAccount(payout.affiliateId);
      if (affiliateAccount == null || affiliateAccount.paystackSubaccountId == null) {
        return badRequest('Affiliate does not have a default payment account');
      }

      final transferRef = 'aff_${payout.id}_${DateTime.now().millisecondsSinceEpoch}';

      final success = await paystackService.transferToSubaccount(
        amount: payout.amount,
        subaccountId: affiliateAccount.paystackSubaccountId!,
        reference: transferRef,
        reason: 'Affiliate payout',
      );

      if (success) {
        await affiliateRepository.processPayout(payoutId, transferRef);
        return Response.ok(
          jsonEncode({'message': 'Payout processed successfully', 'transferRef': transferRef}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      return Response.internalServerError(body: jsonEncode({'message': 'Transfer failed'}));
    } catch (e, stack) {
      print('Manual payout error: $e\n$stack');
      return Response.internalServerError();
    }
  }
}
