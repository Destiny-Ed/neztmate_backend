import 'package:neztmate_backend/features/subscriptions/model/plan_subscription_model.dart';
import 'package:neztmate_backend/features/subscriptions/model/user_subscription_model.dart';

abstract class SubscriptionRepository {
  // abstract
  Future<SubscriptionPlanModel> createPlan(SubscriptionPlanModel plan);
  Future<void> updatePlan(SubscriptionPlanModel plan);
  Future<SubscriptionPlanModel?> getPlanById(String id);
  Future<List<SubscriptionPlanModel>> getAllPlans();
  Future<UserSubscriptionModel?> getActiveSubscription(String userId);
  Future<UserSubscriptionModel> createSubscription(UserSubscriptionModel subscription);
  Future<void> updateSubscription(String id, Map<String, dynamic> data);
  Future<List<UserSubscriptionModel>> getSubscriptionHistory(String userId);
  Future<void> cancelSubscription(String subscriptionId, {required DateTime graceEndDate});

  Future<List<UserSubscriptionModel>> getExpiredSubscriptions();
  Future<void> updateSubscriptionStatus(String subscriptionId, {required String status});
}
