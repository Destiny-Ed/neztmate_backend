import 'dart:convert';
import 'package:neztmate_backend/core/services/payment/paystack_service.dart';
import 'package:neztmate_backend/features/history/model/user_history_model.dart';
import 'package:neztmate_backend/features/history/repository/user_history_repo.dart';
import 'package:neztmate_backend/features/notifications/models/notification_model.dart';
import 'package:neztmate_backend/features/notifications/repository/notification_repo.dart';
import 'package:neztmate_backend/features/payments/models/payments.dart';
import 'package:neztmate_backend/features/payments/repository/payment_repo.dart';
import 'package:neztmate_backend/features/subscriptions/model/plan_subscription_model.dart';
import 'package:neztmate_backend/features/subscriptions/model/user_subscription_model.dart';
import 'package:neztmate_backend/features/subscriptions/repository/subscription_repository.dart';
import 'package:shelf/shelf.dart';
import 'package:neztmate_backend/core/error.dart';
import 'package:shelf_router/shelf_router.dart';
import '../../auth_user/repositories/user_repository.dart';

class SubscriptionHandler {
  final SubscriptionRepository subscriptionRepository;
  final UserRepository userRepository;
  final NotificationRepository notificationRepository;
  final HistoryRepository historyRepository;
  final PaymentRepository paymentRepository;

  SubscriptionHandler(
    this.subscriptionRepository,
    this.userRepository,
    this.notificationRepository,
    this.historyRepository,
    this.paymentRepository,
  );

  final paystackService = PaystackService();

  /// POST /subscriptions/plans  (admin)
  Future<Response> createPlan(Request request) async {
    try {
      final userId = request.context['userId'] as String?;

      final role = request.context['role'] as String?;

      if (userId == null) return unauthorized('Unauthorized');

      if (role != 'admin') {
        return Response(403, body: jsonEncode({'message': 'Only admins can create plans'}));
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;

      final name = (body['name'] as String?)?.trim().toLowerCase();
      final monthlyPrice = (body['monthlyPrice'] as num?)?.toDouble();
      final yearlyPrice = (body['yearlyPrice'] as num?)?.toDouble();
      final maxListings = body['maxListings'] as int?;

      if (name == null || name.isEmpty) {
        return badRequest('name is required');
      }
      if (!['free', 'basic', 'premium', 'enterprise'].contains(name)) {
        return badRequest('name must be one of: free, basic, premium, enterprise');
      }
      if (monthlyPrice == null || monthlyPrice < 0) {
        return badRequest('Valid monthlyPrice is required');
      }
      if (yearlyPrice == null || yearlyPrice < 0) {
        return badRequest('Valid yearlyPrice is required');
      }
      if (maxListings == null) {
        return badRequest('maxListings is required (-1 for unlimited)');
      }

      final existing = await subscriptionRepository.getPlanById(name);
      if (existing != null) {
        return Response(409, body: jsonEncode({'message': 'Plan "$name" already exists'}));
      }

      final plan = SubscriptionPlanModel(
        id: name,
        name: name,
        monthlyPrice: monthlyPrice,
        yearlyPrice: yearlyPrice,
        maxListings: maxListings,
        hasAgentAssignment: body['hasAgentAssignment'] as bool? ?? false,
        hasAdvancedScreening: body['hasAdvancedScreening'] as bool? ?? false,
        hasAnalytics: body['hasAnalytics'] as bool? ?? false,
        hasPrioritySupport: body['hasPrioritySupport'] as bool? ?? false,
        isActive: body['isActive'] as bool? ?? true,
      );

      final created = await subscriptionRepository.createPlan(plan);

      return Response.ok(
        jsonEncode({
          'message': 'Plan created successfully',
          'plan': {'id': created.id, ...created.toMap()},
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Create plan error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to create plan'}));
    }
  }

  /// PATCH /subscriptions/plans/<id>  (admin)
  Future<Response> updatePlan(Request request) async {
    try {
      final role = request.context['role'] as String?;
      final planId = request.params['id'];

      if (role != 'admin') {
        return Response(403, body: jsonEncode({'message': 'Only admins can update plans'}));
      }
      if (planId == null || planId.isEmpty) {
        return badRequest('Plan id is required');
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final existing = await subscriptionRepository.getPlanById(planId);

      if (existing == null) {
        return Response(404, body: jsonEncode({'message': 'Plan not found'}));
      }

      final updated = SubscriptionPlanModel(
        id: existing.id,
        name: existing.name, // name/id should not change after create
        monthlyPrice: (body['monthlyPrice'] as num?)?.toDouble() ?? existing.monthlyPrice,
        yearlyPrice: (body['yearlyPrice'] as num?)?.toDouble() ?? existing.yearlyPrice,
        maxListings: body['maxListings'] as int? ?? existing.maxListings,
        hasAgentAssignment: body['hasAgentAssignment'] as bool? ?? existing.hasAgentAssignment,
        hasAdvancedScreening: body['hasAdvancedScreening'] as bool? ?? existing.hasAdvancedScreening,
        hasAnalytics: body['hasAnalytics'] as bool? ?? existing.hasAnalytics,
        hasPrioritySupport: body['hasPrioritySupport'] as bool? ?? existing.hasPrioritySupport,
        isActive: body['isActive'] as bool? ?? existing.isActive,
      );

      await subscriptionRepository.updatePlan(updated);

      return Response.ok(
        jsonEncode({
          'message': 'Plan updated successfully',
          'plan': {'id': updated.id, ...updated.toMap()},
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Update plan error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to update plan'}));
    }
  }

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
      final billingCycle = (body['billingCycle'] as String? ?? 'monthly').toLowerCase();

      if (planId == null || planId.isEmpty) {
        return badRequest('planId is required');
      }
      if (!['monthly', 'yearly'].contains(billingCycle)) {
        return badRequest('billingCycle must be monthly or yearly');
      }

      final plan = await subscriptionRepository.getPlanById(planId);
      if (plan == null || !plan.isActive) {
        return badRequest('Invalid or inactive plan');
      }

      // Already on this plan?
      final current = await subscriptionRepository.getActiveSubscription(userId);
      if (current != null) {
        final currentPlanId = current.planId.toLowerCase();
        final requestedPlanId = planId.toLowerCase();
        if (currentPlanId == requestedPlanId || currentPlanId == plan.name.toLowerCase()) {
          return Response(
            400,
            body: jsonEncode({
              'message': 'You are already subscribed to the ${plan.name} plan',
              'currentPlanId': current.planId,
              'status': current.status,
            }),
          );
        }
      }

      // Free plan → activate immediately (no Paystack)
      final amount = billingCycle == 'yearly' ? plan.yearlyPrice : plan.monthlyPrice;
      final isFree = plan.id.toLowerCase() == 'free';
      if (amount <= 0 || isFree) {
        final freeSub = UserSubscriptionModel(
          id: '',
          userId: userId,
          planId: plan.id,
          status: 'active',
          startDate: DateTime.now(),
          endDate: billingCycle == 'yearly'
              ? DateTime.now().add(const Duration(days: 365))
              : DateTime.now().add(const Duration(days: 30)),
          billingCycle: billingCycle,
          amountPaid: 0,
        );
        final created = await subscriptionRepository.createSubscription(freeSub);

        await historyRepository.createHistoryEntry(
          HistoryEntryModel(
            userId: userId,
            type: 'subscription_activated',
            title: '${plan.name} Subscription Activated',
            description: 'Free plan activated.',
            relatedId: created.id,
            relatedCollection: 'subscriptions',
            timestamp: DateTime.now(),
            id: '',
          ),
        );

        return Response.ok(
          jsonEncode({
            'message': 'Free plan activated',
            'subscription': created.toMap(),
            'requiresPayment': false,
          }),
        );
      }

      final user = await userRepository.getUserById(userId);
      final reference = 'nm_sub_${planId}_${userId.substring(0, 8)}_${DateTime.now().millisecondsSinceEpoch}';

      // Pending subscription (activated only after webhook)
      final subscription = UserSubscriptionModel(
        id: '',
        userId: userId,
        planId: plan.id,
        status: 'pending_payment',
        startDate: DateTime.now(),
        endDate: billingCycle == 'yearly'
            ? DateTime.now().add(const Duration(days: 365))
            : DateTime.now().add(const Duration(days: 30)),
        billingCycle: billingCycle,
        amountPaid: 0,
        paymentReference: reference,
      );

      final created = await subscriptionRepository.createSubscription(subscription);

      // Pending payment record
      await paymentRepository.createPayment(
        PaymentModel(
          id: '',
          leaseId: '',
          payerId: userId,
          propertyId: null,
          unitId: null,
          amount: amount,
          status: 'pending',
          method: 'Paystack',
          transactionRef: reference,
          type: 'subscription',
          createdAt: DateTime.now(),
        ),
      );

      final init = await paystackService.initializeTransaction(
        email: user.email,
        amount: amount,
        reference: reference,
        metadata: {
          'userId': userId,
          'planId': plan.id,
          'subscriptionId': created.id,
          'billingCycle': billingCycle,
          'type': 'subscription',
        },
      );

      return Response.ok(
        jsonEncode({
          'message': 'Complete payment to activate subscription',
          'requiresPayment': true,
          'authorizationUrl': init['authorization_url'],
          'reference': reference,
          'amount': amount,
          'subscription': created.toMap(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Subscribe error: $e\n$stack');
      return Response.internalServerError(
        body: jsonEncode({'message': 'Failed to initialize subscription payment'}),
      );
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
