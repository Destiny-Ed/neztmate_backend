import 'package:neztmate_backend/features/reviews/models/review_model.dart';

abstract class UserReviewRemoteDataSource {
  Future<UserReviewModel> createReview(UserReviewModel review);
  Future<UserReviewModel?> getReviewById(String id);
  Future<List<UserReviewModel>> getReviewsForUser(String userId);
  Future<List<UserReviewModel>> getReviewsByReviewer(String reviewerId);
  Future<double> calculateAverageRating(String userId);

  Future<UserReviewModel?> getExistingReview({
    required String reviewerId,
    required String reviewedEntityId,
    required String reviewedEntityType,
    required String reviewType,
  });

  Future<UserReviewModel> updateReview(UserReviewModel review);
  Future<void> deleteReview(String id);

  Future<void> updateUserReputationAfterReview(String reviewedUserId);

  Future<List<UserReviewModel>> getReviewsForEntity({required String entityId, required String entityType});

  Future<double> calculateAverageRatingForEntity({required String entityId, required String entityType});
}
