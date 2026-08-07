import 'package:dart_firebase_admin/firestore.dart';
import 'package:neztmate_backend/features/subscriptions/model/plan_subscription_model.dart';
import 'package:neztmate_backend/features/subscriptions/model/user_subscription_model.dart';
import 'package:neztmate_backend/features/subscriptions/repository/subscription_repository.dart';

class FirestoreSubscriptionRepository implements SubscriptionRepository {
  final Firestore firestore;

  FirestoreSubscriptionRepository(this.firestore);

  CollectionReference get _plans => firestore.collection('subscription_plans');
  CollectionReference get _subscriptions => firestore.collection('user_subscriptions');

  // Firestore
  @override
  Future<SubscriptionPlanModel> createPlan(SubscriptionPlanModel plan) async {
    final docRef = firestore.collection('subscription_plans').doc(plan.id.isNotEmpty ? plan.id : null);
    final created = plan.copyWith(id: docRef.id, createdAt: DateTime.now(), updatedAt: DateTime.now());
    await docRef.set(created.toMap());
    return created;
  }

  @override
  Future<void> updatePlan(SubscriptionPlanModel plan) async {
    await firestore.collection('subscription_plans').doc(plan.id).update({
      ...plan.toMap(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<SubscriptionPlanModel?> getPlanById(String id) async {
    final snap = await firestore
        .collection('subscription_plans')
        .where('id', WhereFilter.equal, id)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return SubscriptionPlanModel.fromMap(snap.docs.first.data() as Map<String, dynamic>);
  }

  @override
  Future<List<SubscriptionPlanModel>> getAllPlans() async {
    final snapshot = await _plans.where('isActive', WhereFilter.equal, true).get();

    return snapshot.docs
        .map((doc) => SubscriptionPlanModel.fromMap(doc.data() as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<UserSubscriptionModel?> getActiveSubscription(String userId) async {
    final snapshot = await _subscriptions
        .where('userId', WhereFilter.equal, userId)
        .where('status', WhereFilter.equal, 'active')
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final doc = snapshot.docs.first;
    return UserSubscriptionModel.fromMap(doc.data() as Map<String, dynamic>);
  }

  @override
  Future<UserSubscriptionModel> createSubscription(UserSubscriptionModel subscription) async {
    final docRef = _subscriptions.doc();
    final newSubscription = subscription.copyWith(id: docRef.id);
    await docRef.set(newSubscription.toMap());
    return newSubscription;
  }

  @override
  Future<void> updateSubscription(String id, Map<String, dynamic> data) async {
    await _subscriptions.doc(id).update(data);
  }

  @override
  Future<List<UserSubscriptionModel>> getSubscriptionHistory(String userId) async {
    final snapshot = await _subscriptions
        .where('userId', WhereFilter.equal, userId)
        .orderBy('startDate', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => UserSubscriptionModel.fromMap(doc.data() as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> cancelSubscription(String subscriptionId, {required DateTime graceEndDate}) async {
    await _subscriptions.doc(subscriptionId).update({
      'status': 'cancelled',
      'cancelledAt': DateTime.now().toIso8601String(),
      'graceEndDate': graceEndDate.toIso8601String(), // Full cycle access
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<List<UserSubscriptionModel>> getExpiredSubscriptions() async {
    final now = DateTime.now().toIso8601String();

    final snap = await _subscriptions
        .where('status', WhereFilter.equal, 'active')
        .where('endDate', WhereFilter.lessThan, now)
        .get();

    return snap.docs.map((doc) => UserSubscriptionModel.fromMap(doc.data() as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> updateSubscriptionStatus(String subscriptionId, {required String status}) async {
    await _subscriptions.doc(subscriptionId).update({
      'status': status,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<UserSubscriptionModel?> getSubscriptionByReference(String reference) async {
    final snap = await firestore
        .collection('user_subscriptions')
        .where('paymentReference', WhereFilter.equal, reference)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final data = snap.docs.first.data() as Map<String, dynamic>;
    return UserSubscriptionModel.fromMap({...data, 'id': snap.docs.first.id});
  }

  @override
  Future<void> activateSubscription(String subscriptionId, {required double amountPaid}) async {
    await firestore.collection('user_subscriptions').doc(subscriptionId).update({
      'status': 'active',
      'amountPaid': amountPaid,
      'activatedAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<UserSubscriptionModel?> getSubscriptionById(String id) async {
    final doc = await firestore.collection('user_subscriptions').doc(id).get();
    if (!doc.exists) return null;

    final data = doc.data() as Map<String, dynamic>;
    return UserSubscriptionModel.fromMap({...data, 'id': doc.id});
  }

  @override
  Future<void> deactivateOtherSubscriptions(String userId, {required String exceptId}) async {
    final snap = await firestore
        .collection('user_subscriptions')
        .where('userId', WhereFilter.equal, userId)
        .get();

    final updates = <Future>[];

    for (final doc in snap.docs) {
      if (doc.id == exceptId) continue;

      final data = doc.data() as Map<String, dynamic>;
      final status = (data['status'] as String?)?.toLowerCase() ?? '';

      // Only touch active / pending ones
      if (!['active', 'pending_payment'].contains(status)) continue;

      updates.add(
        firestore.collection('user_subscriptions').doc(doc.id).update({
          'status': 'replaced',
          'replacedBy': exceptId,
          'deactivatedAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        }),
      );
    }

    if (updates.isNotEmpty) {
      await Future.wait(updates);
    }
  }
}
