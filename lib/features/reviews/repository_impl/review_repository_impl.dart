import 'package:neztmate_backend/features/reviews/datasource/review_remote_datasource.dart';
import 'package:neztmate_backend/features/reviews/models/review_model.dart';
import 'package:neztmate_backend/features/reviews/repository/review_repository.dart';

class UserReviewRepositoryImpl implements UserReviewRepository {
  final UserReviewRemoteDataSource dataSource;

  UserReviewRepositoryImpl(this.dataSource);

  @override
  Future<double> calculateAverageRating(String userId) {
    return dataSource.calculateAverageRating(userId);
  }

  @override
  Future<UserReviewModel> createReview(UserReviewModel review) {
    return dataSource.createReview(review);
  }

  @override
  Future<List<UserReviewModel>> getReviewsForUser(String userId) {
    return dataSource.getReviewsForUser(userId);
  }

  @override
  Future<void> updateUserReputationAfterReview(String reviewedUserId) =>
      dataSource.updateUserReputationAfterReview(reviewedUserId);

  @override
  Future<void> deleteReview(String id) => dataSource.deleteReview(id);

  @override
  Future<UserReviewModel?> getExistingReview({
    required String reviewerId,
    required String reviewedEntityId,
    required String reviewedEntityType,
    required String reviewType,
  }) => dataSource.getExistingReview(
    reviewerId: reviewerId,
    reviewedEntityId: reviewedEntityId,
    reviewedEntityType: reviewedEntityType,
    reviewType: reviewType,
  );

  @override
  Future<UserReviewModel?> getReviewById(String id) => dataSource.getReviewById(id);

  @override
  Future<UserReviewModel> updateReview(UserReviewModel review) => dataSource.updateReview(review);

  @override
  Future<List<UserReviewModel>> getReviewsByReviewer(String reviewerId) =>
      dataSource.getReviewsByReviewer(reviewerId);
}
