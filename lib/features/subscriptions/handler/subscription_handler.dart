import 'dart:convert';
import 'package:neztmate_backend/features/subscriptions/model/user_subscription_model.dart';
import 'package:neztmate_backend/features/subscriptions/repository/subscription_repository.dart';
import 'package:shelf/shelf.dart';
import 'package:neztmate_backend/core/error.dart';
import '../../auth_user/repositories/user_repository.dart';

class SubscriptionHandler {
  final SubscriptionRepository subscriptionRepository;
  final UserRepository userRepository;

  SubscriptionHandler(this.subscriptionRepository, this.userRepository);

  /// GET /subscriptions/plans - Get all available plans
  Future<Response> getPlans(Request request) async {
    try {
      final plans = await subscriptionRepository.getAllPlans();

      return Response.ok(jsonEncode({'plans': plans.map((p) => p.toMap()).toList()}));
    } catch (e, stack) {
      print('Get plans error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  /// GET /subscriptions/me - Get current subscription
  Future<Response> getMySubscription(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      if (userId == null) return unauthorized('You are not authorized');

      final subscription = await subscriptionRepository.getActiveSubscription(userId);

      if (subscription == null) {
        return Response.ok(jsonEncode({'message': 'No active subscription', 'status': 'free'}));
      }

      return Response.ok(jsonEncode({'subscription': subscription.toMap()}));
    } catch (e, stack) {
      print('Get subscription error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  /// POST /subscriptions/subscribe - Subscribe to a plan
  Future<Response> subscribe(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      if (userId == null) return unauthorized('You are not authorized');

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final planId = body['planId'] as String?;
      final billingCycle = body['billingCycle'] as String? ?? 'monthly';

      if (planId == null) return badRequest('planId is required');

      // Create subscription record
      final subscription = UserSubscriptionModel(
        id: '',
        userId: userId,
        planId: planId,
        status: 'active',
        startDate: DateTime.now(),
        endDate: billingCycle == 'yearly'
            ? DateTime.now().add(Duration(days: 365))
            : DateTime.now().add(Duration(days: 30)),
        billingCycle: billingCycle,
        amountPaid: 0.0, // Will be updated after payment
      );

      await subscriptionRepository.createSubscription(subscription);

      return Response.ok(
        jsonEncode({'message': 'Subscription activated successfully', 'subscription': subscription.toMap()}),
      );
    } catch (e, stack) {
      print('Subscribe error: $e\n$stack');
      return Response.internalServerError();
    }
  }
}
