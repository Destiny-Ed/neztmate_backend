import 'dart:convert';

import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/core/services/payment/paystack_service.dart';
import 'package:neztmate_backend/features/auth_user/repositories/user_repository.dart';
import 'package:neztmate_backend/features/billing/repository/billing_repository.dart';
import 'package:neztmate_backend/features/payments/repository/payment_repo.dart';
import 'package:shelf/shelf.dart';

class BillingHandler {
  final BillingRepository billingRepository;
  final PaymentRepository paymentRepository;
  final UserRepository userRepository;

  BillingHandler(this.billingRepository, this.paymentRepository, this.userRepository);

  /// POST /billing/application-fee - Charge ₦2,000 before application submission
  Future<Response> chargeApplicationFee(Request request) async {
    try {
      final tenantId = request.context['userId'] as String?;
      if (tenantId == null) return unauthorized("Unauthorized");

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final propertyId = body['propertyId'] as String?;
      final unitId = body['unitId'] as String?;

      if (propertyId == null || unitId == null) {
        return badRequest('propertyId and unitId are required');
      }

      // Check if already paid
      final alreadyPaid = await billingRepository.hasPaidApplicationFee(tenantId, unitId);
      if (alreadyPaid) {
        return Response.ok(jsonEncode({'message': 'Application fee already paid for this unit'}));
      }

      final reference = 'appfee_${DateTime.now().millisecondsSinceEpoch}';

      final paystackService = PaystackService();

      final user = await userRepository.getUserById(tenantId);

      final initData = await paystackService.initializeTransaction(
        email: user.email,
        amount: 2000,
        reference: reference,
        metadata: {},
      );

      return Response.ok(
        jsonEncode({
          'message': 'Application fee payment initialized',
          'authorization_url': initData['authorization_url'],
          'reference': reference,
          'amount': 2000,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError();
    }
  }

  /// POST /billing/subscribe - Subscribe to plan
  Future<Response> subscribe(Request request) async {
    // Implementation for subscription plans
    // Can be expanded later
    return Response.ok(jsonEncode({'message': 'Subscription endpoint ready'}));
  }
}
