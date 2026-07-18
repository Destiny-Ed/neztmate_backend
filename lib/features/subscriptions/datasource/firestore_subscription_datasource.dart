import 'package:dart_firebase_admin/firestore.dart';
import 'package:neztmate_backend/features/subscriptions/model/plan_subscription_model.dart';
import 'package:neztmate_backend/features/subscriptions/model/user_subscription_model.dart';
import 'package:neztmate_backend/features/subscriptions/repository/subscription_repository.dart';

class FirestoreSubscriptionRepository implements SubscriptionRepository {
  final Firestore firestore;

  FirestoreSubscriptionRepository(this.firestore);

  CollectionReference get _plans => firestore.collection('subscription_plans');
  CollectionReference get _subscriptions => firestore.collection('user_subscriptions');

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
  Future<void> createSubscription(UserSubscriptionModel subscription) async {
    final docRef = _subscriptions.doc();
    final newSubscription = subscription.copyWith(id: docRef.id);
    await docRef.set(newSubscription.toMap());
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
}
