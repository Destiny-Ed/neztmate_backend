import 'dart:convert';
import 'package:neztmate_backend/features/history/model/user_history_model.dart';
import 'package:neztmate_backend/features/history/repository/user_history_repo.dart';
import 'package:neztmate_backend/features/notifications/models/notification_model.dart';
import 'package:neztmate_backend/features/notifications/repository/notification_repo.dart';
import 'package:neztmate_backend/features/subscriptions/model/user_subscription_model.dart';
import 'package:neztmate_backend/features/subscriptions/repository/subscription_repository.dart';
import 'package:shelf/shelf.dart';
import 'package:neztmate_backend/core/error.dart';
import '../../auth_user/repositories/user_repository.dart';

class SubscriptionHandler {
  final SubscriptionRepository subscriptionRepository;
  final UserRepository userRepository;
  final NotificationRepository notificationRepository;
  final HistoryRepository historyRepository;

  SubscriptionHandler(
    this.subscriptionRepository,
    this.userRepository,
    this.notificationRepository,
    this.historyRepository,
  );

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

      final plan = await subscriptionRepository.getPlanById(planId);
      if (plan == null) return badRequest('Invalid plan');

      // Create subscription record
      final subscription = UserSubscriptionModel(
        id: '',
        userId: userId,
        planId: planId,
        status: 'active',
        startDate: DateTime.now(),
        endDate: billingCycle == 'yearly'
            ? DateTime.now().add(const Duration(days: 365))
            : DateTime.now().add(const Duration(days: 30)),
        billingCycle: billingCycle,
        amountPaid: 0.0, // Updated after actual payment
      );

      final created = await subscriptionRepository.createSubscription(subscription);

      // Log History
      await historyRepository.createHistoryEntry(
        HistoryEntryModel(
          userId: userId,
          type: 'subscription_activated',
          title: '${plan.name} Subscription Activated',
          description: 'You subscribed to ${plan.name} plan (${billingCycle}).',
          relatedId: created.id,
          relatedCollection: 'subscriptions',
          timestamp: DateTime.now(),
          id: '',
        ),
      );

      // Send Notification
      await notificationRepository.create(
        NotificationModel(
          id: '',
          userId: userId,
          type: 'subscription_activated',
          title: 'Subscription Activated',
          body: 'Your ${plan.name} subscription is now active. Enjoy premium features!',
          relatedId: created.id,
          relatedCollection: 'subscriptions',
          createdAt: DateTime.now(),
        ),
      );

      return Response.ok(
        jsonEncode({'message': 'Subscription activated successfully', 'subscription': created.toMap()}),
      );
    } catch (e, stack) {
      print('Subscribe error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to activate subscription'}));
    }
  }

  /// POST /subscriptions/cancel - Cancel subscription with grace period
  Future<Response> cancelSubscription(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      if (userId == null) return unauthorized("unauthorized");

      final subscription = await subscriptionRepository.getActiveSubscription(userId);

      if (subscription == null) {
        return Response(400, body: jsonEncode({'message': 'No active subscription to cancel'}));
      }

      // Grace period = full remaining billing cycle
      final graceEndDate = subscription.endDate;

      await subscriptionRepository.cancelSubscription(subscription.id, graceEndDate: graceEndDate);

      await historyRepository.createHistoryEntry(
        HistoryEntryModel(
          userId: userId,
          type: 'subscription_cancelled',
          title: 'Subscription Cancelled',
          description:
              'Your subscription will remain active until ${graceEndDate.toIso8601String().split("T").first}.',
          relatedId: subscription.id,
          relatedCollection: 'subscriptions',
          timestamp: DateTime.now(),
          id: '',
        ),
      );

      await notificationRepository.create(
        NotificationModel(
          userId: userId,
          type: 'subscription_cancelled',
          title: 'Subscription Cancelled',
          body: 'Your subscription remains active until the end of the current billing period.',
          relatedId: subscription.id,
          relatedCollection: 'subscriptions',
          createdAt: DateTime.now(),
          id: '',
        ),
      );

      return Response.ok(
        jsonEncode({
          'message': 'Subscription cancelled successfully',
          'subscriptionId': subscription.id,
          'activeUntil': graceEndDate.toIso8601String(),
          'gracePeriod': true,
        }),
      );
    } catch (e, stack) {
      print('Cancel subscription error: $e\n$stack');
      return Response.internalServerError();
    }
  }
}
