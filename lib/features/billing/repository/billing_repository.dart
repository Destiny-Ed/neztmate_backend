import 'package:neztmate_backend/features/billing/model/application_model.dart';
import 'package:neztmate_backend/features/billing/model/user_subscription_model.dart';

abstract class BillingRepository {
  // Subscriptions
  Future<UserSubscriptionModel> createSubscription(UserSubscriptionModel subscription);
  Future<UserSubscriptionModel?> getActiveSubscription(String userId);
  Future<bool> hasActiveSubscription(String userId);

  // Application Fees
  Future<ApplicationFeeModel> chargeApplicationFee(ApplicationFeeModel fee);
  Future<bool> hasPaidApplicationFee(String tenantId, String unitId);
  Future<List<ApplicationFeeModel>> getApplicationFeesByTenant(String tenantId);
}
