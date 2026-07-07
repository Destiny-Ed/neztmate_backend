import 'package:dart_firebase_admin/firestore.dart';
import 'package:neztmate_backend/core/services/reputation/reputation_service.dart';
import 'package:neztmate_backend/features/reviews/datasource/review_remote_datasource.dart';
import 'package:neztmate_backend/features/reviews/models/review_model.dart';

class FirestoreUserReviewDataSource implements UserReviewRemoteDataSource {
  final Firestore firestore;
  final UserReputationService reputationService;

  FirestoreUserReviewDataSource(this.firestore, this.reputationService);

  CollectionReference get _reviews => firestore.collection('user_reviews');

  @override
  Future<UserReviewModel> createReview(UserReviewModel review) async {
    final docRef = _reviews.doc();
    final newReview = review.copyWith(id: docRef.id);
    await docRef.set(newReview.toMap());
    await updateUserReputationAfterReview(review.reviewedUserId);
    return newReview;
  }

  @override
  Future<List<UserReviewModel>> getReviewsForUser(String userId) async {
    final snap = await _reviews
        .where('reviewedUserId', WhereFilter.equal, userId)
        .orderBy('createdAt', descending: true)
        .get();

    return snap.docs.map((doc) => UserReviewModel.fromMap(doc.data())).toList();
  }

  @override
  Future<double> calculateAverageRating(String userId) async {
    final snap = await _reviews.where('reviewedUserId', WhereFilter.equal, userId).get();
    if (snap.docs.isEmpty) return 0.0;

    double sum = 0.0;
    for (var doc in snap.docs) {
      sum += (doc.data()['rating'] as num).toDouble();
    }
    return sum / snap.docs.length;
  }

  @override
  Future<void> updateUserReputationAfterReview(String reviewedUserId) async {
    await reputationService.updateUserReputation(reviewedUserId);
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
  Future<List<UserReviewModel>> getReviewsByReviewer(String reviewerId) async {
    final snap = await _reviews
        .where('reviewerId', WhereFilter.equal, reviewerId)
        .orderBy('createdAt', descending: true)
        .get();

    return snap.docs.map((doc) => UserReviewModel.fromMap(doc.data() as Map<String, dynamic>)).toList();
  }

  @override
  Future<UserReviewModel?> getExistingReview({
    required String reviewerId,
    required String reviewedUserId,
    required String reviewType,
  }) async {
    final snap = await _reviews
        .where('reviewerId', WhereFilter.equal, reviewerId)
        .where('reviewedUserId', WhereFilter.equal, reviewedUserId)
        .where('reviewType', WhereFilter.equal, reviewType)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;

    final doc = snap.docs.first;
    return UserReviewModel.fromMap(doc.data() as Map<String, dynamic>);
  }

  @override
  Future<UserReviewModel?> getReviewById(String id) async {
    final doc = await _reviews.doc(id).get();
    if (!doc.exists) return null;

    return UserReviewModel.fromMap(doc.data() as Map<String, dynamic>);
  }
}
