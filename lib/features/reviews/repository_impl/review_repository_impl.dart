import 'package:neztmate_backend/features/reviews/datasource/review_remote_datasource.dart';
import 'package:neztmate_backend/features/reviews/models/review_model.dart';
import 'package:neztmate_backend/features/reviews/repository/review_repository.dart';

class UserReviewRepositoryImpl implements UserReviewRepository {
  final UserReviewRemoteDataSource dataSource;

  UserReviewRepositoryImpl(this.dataSource);

  @override
  Future<UserReviewModel> createReview(UserReviewModel review) => dataSource.createReview(review);

  @override
  Future<UserReviewModel?> getReviewById(String id) => dataSource.getReviewById(id);

  @override
  Future<List<UserReviewModel>> getReviewsForUser(String userId, {String? partnerId}) =>
      dataSource.getReviewsForUser(userId, partnerId: partnerId);

  @override
  Future<List<UserReviewModel>> getReviewsByReviewer(String reviewerId, {String? partnerId}) =>
      dataSource.getReviewsByReviewer(reviewerId, partnerId: partnerId);

  @override
  Future<double> calculateAverageRating(String userId, {String? partnerId}) =>
      dataSource.calculateAverageRating(userId, partnerId: partnerId);

  @override
  Future<UserReviewModel?> getExistingReview({
    required String reviewerId,
    required String reviewedEntityId,
    required String reviewedEntityType,
    required String reviewType,
    String? partnerId,
  }) => dataSource.getExistingReview(
    reviewerId: reviewerId,
    reviewedEntityId: reviewedEntityId,
    reviewedEntityType: reviewedEntityType,
    reviewType: reviewType,
    partnerId: partnerId,
  );

  @override
  Future<UserReviewModel> updateReview(UserReviewModel review) => dataSource.updateReview(review);

  @override
  Future<void> deleteReview(String id) => dataSource.deleteReview(id);

  @override
  Future<void> updateUserReputationAfterReview(String reviewedUserId) =>
      dataSource.updateUserReputationAfterReview(reviewedUserId);

  @override
  Future<List<UserReviewModel>> getReviewsForEntity({
    required String entityId,
    required String entityType,
    String? partnerId,
  }) => dataSource.getReviewsForEntity(entityId: entityId, entityType: entityType, partnerId: partnerId);

  @override
  Future<double> calculateAverageRatingForEntity({
    required String entityId,
    required String entityType,
    String? partnerId,
  }) => dataSource.calculateAverageRatingForEntity(
    entityId: entityId,
    entityType: entityType,
    partnerId: partnerId,
  );
}
