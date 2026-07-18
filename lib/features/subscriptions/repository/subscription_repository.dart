import 'package:neztmate_backend/features/subscriptions/model/plan_subscription_model.dart';
import 'package:neztmate_backend/features/subscriptions/model/user_subscription_model.dart';

abstract class SubscriptionRepository {
  Future<List<SubscriptionPlanModel>> getAllPlans();
  Future<UserSubscriptionModel?> getActiveSubscription(String userId);
  Future<void> createSubscription(UserSubscriptionModel subscription);
  Future<void> updateSubscription(String id, Map<String, dynamic> data);
  Future<List<UserSubscriptionModel>> getSubscriptionHistory(String userId);
}
