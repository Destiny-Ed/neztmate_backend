import 'package:neztmate_backend/features/reviews/models/review_model.dart';

abstract class UserReviewRemoteDataSource {
  Future<UserReviewModel> createReview(UserReviewModel review);
  Future<List<UserReviewModel>> getReviewsForUser(String userId);
  Future<List<UserReviewModel>> getReviewsByReviewer(String reviewerId);
  Future<double> calculateAverageRating(String userId);
  Future<UserReviewModel?> getReviewById(String id);
  Future<UserReviewModel?> getExistingReview({
    required String reviewerId,
    required String reviewedEntityId,
    required String reviewedEntityType,
    required String reviewType,
  });
  Future<UserReviewModel> updateReview(UserReviewModel review);
  Future<void> deleteReview(String id);
  // Future<void> updateUserReputation(String userId);
  Future<void> updateUserReputationAfterReview(String reviewedUserId);
}
