import 'package:dart_firebase_admin/firestore.dart';
import 'package:neztmate_backend/features/billing/model/application_model.dart';
import 'package:neztmate_backend/features/billing/model/user_subscription_model.dart';
import 'package:neztmate_backend/features/billing/repository/billing_repository.dart';

class FirestoreBillingDataSource implements BillingRepository {
  final Firestore firestore;

  FirestoreBillingDataSource(this.firestore);

  @override
  Future<UserSubscriptionModel> createSubscription(UserSubscriptionModel subscription) async {
    final docRef = firestore.collection('user_subscriptions').doc();
    // final newSub = subscription.copyWith(id: docRef.id); // assume copyWith
    // await docRef.set(newSub.toMap());
    // return newSub;
    return subscription;
  }

  @override
  Future<UserSubscriptionModel?> getActiveSubscription(String userId) async {
    final snap = await firestore
        .collection('user_subscriptions')
        .where('userId', WhereFilter.equal, userId)
        .where('isActive', WhereFilter.equal, true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return UserSubscriptionModel.fromMap(snap.docs.first.data(), snap.docs.first.id);
  }

  @override
  Future<bool> hasActiveSubscription(String userId) async {
    final sub = await getActiveSubscription(userId);
    return sub != null;
  }

  @override
  Future<ApplicationFeeModel> chargeApplicationFee(ApplicationFeeModel fee) async {
    // final docRef = firestore.collection('application_fees').doc();
    // final newFee = fee.copyWith(id: docRef.id);
    // await docRef.set(newFee.toMap());
    // return newFee;
    return fee;
  }

  @override
  Future<bool> hasPaidApplicationFee(String tenantId, String unitId) async {
    final snap = await firestore
        .collection('application_fees')
        .where('tenantId', WhereFilter.equal, tenantId)
        .where('unitId', WhereFilter.equal, unitId)
        .where('status', WhereFilter.equal, 'Paid')
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  @override
  Future<List<ApplicationFeeModel>> getApplicationFeesByTenant(String tenantId) async {
    final snap = await firestore
        .collection('application_fees')
        .where('tenantId', WhereFilter.equal, tenantId)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => ApplicationFeeModel.fromMap(d.data(), d.id)).toList();
  }
}
