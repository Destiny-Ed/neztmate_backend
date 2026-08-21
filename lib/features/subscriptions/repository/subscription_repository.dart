import 'package:neztmate_backend/features/subscriptions/model/plan_subscription_model.dart';
import 'package:neztmate_backend/features/subscriptions/model/user_subscription_model.dart';

abstract class SubscriptionRepository {
  Future<SubscriptionPlanModel> createPlan(SubscriptionPlanModel plan);
  Future<void> updatePlan(SubscriptionPlanModel plan);
  Future<SubscriptionPlanModel?> getPlanById(String id, {String? partnerId});
  Future<List<SubscriptionPlanModel>> getAllPlans({String? partnerId});

  Future<UserSubscriptionModel?> getActiveSubscription(String userId, {String? partnerId});

  Future<UserSubscriptionModel> createSubscription(UserSubscriptionModel subscription);
  Future<void> updateSubscription(String id, Map<String, dynamic> data);

  Future<List<UserSubscriptionModel>> getSubscriptionHistory(String userId, {String? partnerId});

  Future<void> cancelSubscription(String subscriptionId, {required DateTime graceEndDate});

  Future<UserSubscriptionModel?> getSubscriptionByReference(String reference);
  Future<void> activateSubscription(String subscriptionId, {required double amountPaid});

  Future<List<UserSubscriptionModel>> getExpiredSubscriptions({String? partnerId});
  Future<void> updateSubscriptionStatus(String subscriptionId, {required String status});
  Future<UserSubscriptionModel?> getSubscriptionById(String id);

  Future<void> deactivateOtherSubscriptions(String userId, {required String exceptId, String? partnerId});
}
