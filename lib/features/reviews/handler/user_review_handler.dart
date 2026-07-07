import 'dart:convert';
import 'package:neztmate_backend/features/reviews/models/review_model.dart';
import 'package:neztmate_backend/features/reviews/repository/review_repository.dart';
import 'package:shelf/shelf.dart';
import 'package:neztmate_backend/core/error.dart';
import 'package:shelf_router/shelf_router.dart';
import '../../auth_user/repositories/user_repository.dart';

class UserReviewHandler {
  final UserReviewRepository reviewRepository;
  final UserRepository userRepository;

  UserReviewHandler(this.reviewRepository, this.userRepository);

  /// POST /reviews - Create a new review (with duplicate prevention)
  Future<Response> createReview(Request request) async {
    try {
      final reviewerId = request.context['userId'] as String?;
      final reviewerRole = request.context['role'] as String?;
      if (reviewerId == null) return unauthorized("Missing authentication");

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;

      final reviewedUserId = body['reviewedUserId'] as String?;
      final reviewType = body['reviewType'] as String?;
      final rating = (body['rating'] as num?)?.toDouble();
      final comment = body['comment'] as String?;

      if (reviewedUserId == null || reviewType == null || rating == null || comment == null) {
        return badRequest('reviewedUserId, reviewType, rating, and comment are required');
      }

      if (rating < 1.0 || rating > 5.0) {
        return badRequest('rating must be between 1.0 and 5.0');
      }

      if (comment.trim().isEmpty) {
        return badRequest('comment cannot be empty');
      }

      if (reviewedUserId == reviewerId) {
        return badRequest('You cannot review yourself');
      }

      // === Prevent Duplicate Reviews ===
      final existingReview = await reviewRepository.getExistingReview(
        reviewerId: reviewerId,
        reviewedUserId: reviewedUserId,
        reviewType: reviewType,
      );

      if (existingReview != null) {
        return Response(
          409,
          body: jsonEncode({
            'message': 'You have already reviewed this user for this category',
            'existingReviewId': existingReview.id,
          }),
        );
      }

      final review = UserReviewModel(
        id: '',
        reviewerId: reviewerId,
        reviewedUserId: reviewedUserId,
        reviewType: reviewType,
        rating: rating,
        reviewerRole: reviewerRole ?? 'unknown',
        comment: comment.trim(),
        relatedLeaseId: body['relatedLeaseId'] as String?,
        relatedTaskId: body['relatedTaskId'] as String?,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final created = await reviewRepository.createReview(review);

      return Response.ok(
        jsonEncode({'message': 'Review submitted successfully', 'review': created.toMap()}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Create review error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  /// PATCH /reviews/<id> - Edit your own review
  Future<Response> updateReview(Request request) async {
    try {
      final reviewerId = request.context['userId'] as String?;
      final reviewId = request.params['id'];

      if (reviewerId == null || reviewId == null) {
        return badRequest('Review ID is required');
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;

      final existingReview = await reviewRepository.getReviewById(reviewId);

      if (existingReview == null) {
        return Response(404, body: jsonEncode({'message': 'Review not found'}));
      }

      // Only the original reviewer can edit
      if (existingReview.reviewerId != reviewerId) {
        return Response(403, body: jsonEncode({'message': 'You can only edit your own reviews'}));
      }

      final updatedReview = existingReview.copyWith(
        rating: (body['rating'] as num?)?.toDouble(),
        comment: body['comment'] as String?,
        updatedAt: DateTime.now(),
      );

      final result = await reviewRepository.updateReview(updatedReview);

      return Response.ok(
        jsonEncode({'message': 'Review updated successfully', 'review': result.toMap()}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Update review error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  /// DELETE /reviews/<id> - Delete your own review
  Future<Response> deleteReview(Request request) async {
    try {
      final reviewerId = request.context['userId'] as String?;
      final reviewId = request.params['id'];

      if (reviewerId == null || reviewId == null) {
        return badRequest('Review ID is required');
      }

      final existingReview = await reviewRepository.getReviewById(reviewId);

      if (existingReview == null) {
        return Response(404, body: jsonEncode({'message': 'Review not found'}));
      }

      if (existingReview.reviewerId != reviewerId) {
        return Response(403, body: jsonEncode({'message': 'You can only delete your own reviews'}));
      }

      await reviewRepository.deleteReview(reviewId);

      return Response.ok(jsonEncode({'message': 'Review deleted successfully'}));
    } catch (e, stack) {
      print('Delete review error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  /// GET /reviews/user/<userId> - Get all reviews for a user
  Future<Response> getUserReviews(Request request) async {
    try {
      final userId = request.params['userId'];
      if (userId == null) {
        return badRequest('User ID is required');
      }

      final reviews = await reviewRepository.getReviewsForUser(userId);
      final averageRating = await reviewRepository.calculateAverageRating(userId);

      return Response.ok(
        jsonEncode({
          'userId': userId,
          'averageRating': averageRating,
          'totalReviews': reviews.length,
          'reviews': reviews.map((r) => r.toMap()).toList(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Get user reviews error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  /// GET /reviews/user/<userId>/summary - Get only reputation summary
  Future<Response> getUserReputationSummary(Request request) async {
    try {
      final userId = request.params['userId'];
      if (userId == null) return badRequest('User ID is required');

      final user = await userRepository.getUserById(userId);

      return Response.ok(
        jsonEncode({
          'userId': user.id,
          'fullName': user.fullName,
          'role': user.role,
          'averageRating': user.averageRating,
          'totalReviews': user.totalReviews,
          'tenantReputation': user.tenantReputation,
          'landlordReputation': user.landlordReputation,
          'artisanReputation': user.artisanReputation,
          'paymentOnTimeRate': user.paymentOnTimeRate,
          'badges': user.badges,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError();
    }
  }

  /// GET /reviews/my-reviews - Reviews written by current user
  Future<Response> getMyWrittenReviews(Request request) async {
    try {
      final reviewerId = request.context['userId'] as String?;
      if (reviewerId == null) return unauthorized("Missing authentication");

      final reviews = await reviewRepository.getReviewsByReviewer(reviewerId);

      return Response.ok(
        jsonEncode({'reviewsWritten': reviews.length, 'reviews': reviews.map((r) => r.toMap()).toList()}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError();
    }
  }
}
