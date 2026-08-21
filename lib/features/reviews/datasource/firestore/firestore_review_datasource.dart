import 'package:dart_firebase_admin/firestore.dart';
import 'package:neztmate_backend/core/services/reputation/reputation_service.dart';
import 'package:neztmate_backend/features/auth_user/repositories/user_repository.dart';
import 'package:neztmate_backend/features/payments/repository/payment_repo.dart';
import 'package:neztmate_backend/features/reviews/datasource/review_remote_datasource.dart';
import 'package:neztmate_backend/features/reviews/models/review_model.dart';
import 'package:neztmate_backend/features/reviews/repository/review_repository.dart';
import 'package:neztmate_backend/features/reviews/repository_impl/review_repository_impl.dart';

Query _withPartner(Query q, String? partnerId) {
  if (partnerId != null && partnerId.isNotEmpty) {
    return q.where('partnerId', WhereFilter.equal, partnerId);
  }
  return q;
}

class FirestoreUserReviewDataSource implements UserReviewRemoteDataSource {
  final Firestore firestore;
  final UserRepository userRepository;
  final PaymentRepository paymentRepository;

  FirestoreUserReviewDataSource(this.firestore, this.userRepository, this.paymentRepository);

  CollectionReference get _reviews => firestore.collection('user_reviews');

  @override
  Future<UserReviewModel> createReview(UserReviewModel review) async {
    final docRef = _reviews.doc();
    final newReview = review.copyWith(id: docRef.id);

    await docRef.set(newReview.toMap());

    // Update reputation
    await updateUserReputationAfterReview(review.reviewedEntityId);

    return newReview;
  }

  @override
  Future<UserReviewModel?> getReviewById(String id) async {
    final doc = await _reviews.doc(id).get();
    if (!doc.exists) return null;
    return UserReviewModel.fromMap(doc.data() as Map<String, dynamic>);
  }

  @override
  Future<List<UserReviewModel>> getReviewsForUser(String userId, {String? partnerId}) async {
    var q = _reviews
        .where('reviewedEntityId', WhereFilter.equal, userId)
        .where('reviewedEntityType', WhereFilter.equal, 'user');
    q = _withPartner(q, partnerId);
    final snap = await q.orderBy('createdAt', descending: true).get();
    return snap.docs.map((doc) => UserReviewModel.fromMap(doc.data() as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<UserReviewModel>> getReviewsByReviewer(String reviewerId, {String? partnerId}) async {
    var q = _reviews.where('reviewerId', WhereFilter.equal, reviewerId);
    q = _withPartner(q, partnerId);
    final snap = await q.orderBy('createdAt', descending: true).get();
    return snap.docs.map((doc) => UserReviewModel.fromMap(doc.data() as Map<String, dynamic>)).toList();
  }

  @override
  Future<double> calculateAverageRating(String userId, {String? partnerId}) async {
    var q = _reviews
        .where('reviewedEntityId', WhereFilter.equal, userId)
        .where('reviewedEntityType', WhereFilter.equal, 'user');
    q = _withPartner(q, partnerId);
    final snap = await q.get();
    if (snap.docs.isEmpty) return 0.0;
    double sum = 0.0;
    for (final doc in snap.docs) {
      sum += ((doc.data() as Map)['rating'] as num).toDouble();
    }
    return sum / snap.docs.length;
  }

  @override
  Future<UserReviewModel?> getExistingReview({
    required String reviewerId,
    required String reviewedEntityId,
    required String reviewedEntityType,
    required String reviewType,
    String? partnerId,
  }) async {
    var q = _reviews
        .where('reviewerId', WhereFilter.equal, reviewerId)
        .where('reviewedEntityId', WhereFilter.equal, reviewedEntityId)
        .where('reviewedEntityType', WhereFilter.equal, reviewedEntityType)
        .where('reviewType', WhereFilter.equal, reviewType);
    q = _withPartner(q, partnerId);
    final snap = await q.limit(1).get();
    if (snap.docs.isEmpty) return null;
    return UserReviewModel.fromMap(snap.docs.first.data() as Map<String, dynamic>);
  }

  @override
  Future<UserReviewModel> updateReview(UserReviewModel review) async {
    await _reviews.doc(review.id).update(review.toMap());
    return review;
  }

  @override
  Future<void> deleteReview(String id) async {
    await _reviews.doc(id).delete();
  }

  @override
  Future<void> updateUserReputationAfterReview(String reviewedUserId) async {
    final reviewRepository = UserReviewRepositoryImpl(this);
    final reputationService = UserReputationService(userRepository, paymentRepository, reviewRepository);
    await reputationService.updateUserReputation(reviewedUserId);
  }

  @override
  Future<List<UserReviewModel>> getReviewsForEntity({
    required String entityId,
    required String entityType,
    String? partnerId,
  }) async {
    var q = _reviews
        .where('reviewedEntityId', WhereFilter.equal, entityId)
        .where('reviewedEntityType', WhereFilter.equal, entityType);
    q = _withPartner(q, partnerId);
    final snap = await q.orderBy('createdAt', descending: true).get();
    return snap.docs.map((doc) => UserReviewModel.fromMap(doc.data() as Map<String, dynamic>)).toList();
  }

  @override
  Future<double> calculateAverageRatingForEntity({
    required String entityId,
    required String entityType,
    String? partnerId,
  }) async {
    var q = _reviews
        .where('reviewedEntityId', WhereFilter.equal, entityId)
        .where('reviewedEntityType', WhereFilter.equal, entityType);
    q = _withPartner(q, partnerId);
    final snap = await q.get();
    if (snap.docs.isEmpty) return 0.0;
    double sum = 0.0;
    for (final doc in snap.docs) {
      sum += ((doc.data() as Map)['rating'] as num).toDouble();
    }
    return sum / snap.docs.length;
  }
}
