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

  /// POST /reviews - Create a review
  Future<Response> createReview(Request request) async {
    try {
      final reviewerId = request.context['userId'] as String?;
      final reviewerRole = request.context['role'] as String?;

      if (reviewerId == null) return unauthorized("You're not authorized");

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;

      final reviewedEntityId = body['reviewedEntityId'] as String?;
      final reviewedEntityType = body['reviewedEntityType'] as String?;
      final reviewType = body['reviewType'] as String?;
      final rating = (body['rating'] as num?)?.toDouble();
      final comment = (body['comment'] as String?)?.trim() ?? '';

      if (reviewedEntityId == null || reviewedEntityType == null || reviewType == null || rating == null) {
        return badRequest('reviewedEntityId, reviewedEntityType, reviewType and rating are required');
      }

      if (rating < 1.0 || rating > 5.0) {
        return badRequest('Rating must be between 1.0 and 5.0');
      }

      if (comment.isEmpty) {
        return badRequest('Comment is required');
      }

      // Prevent self-review for users
      if (reviewedEntityType == 'user' && reviewedEntityId == reviewerId) {
        return badRequest('You cannot review yourself');
      }

      final existing = await reviewRepository.getExistingReview(
        reviewerId: reviewerId,
        reviewedEntityId: reviewedEntityId,
        reviewedEntityType: reviewedEntityType,
        reviewType: reviewType,
      );

      if (existing != null) {
        return Response(
          409,
          body: jsonEncode({'message': 'You have already reviewed this entity', 'reviewId': existing.id}),
        );
      }

      final reviewer = await userRepository.getUserById(reviewerId);

      final review = UserReviewModel(
        id: '',
        reviewerId: reviewerId,
        reviewerName: reviewer.fullName,
        reviewerPhotoUrl: reviewer.profilePhotoUrl,
        reviewerRole: reviewerRole ?? 'unknown',
        reviewedEntityId: reviewedEntityId,
        reviewedEntityType: reviewedEntityType,
        reviewType: reviewType,
        rating: rating,
        comment: comment,
        tags: List<String>.from(body['tags'] ?? []),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final created = await reviewRepository.createReview(review);

      return Response.ok(jsonEncode({'message': 'Review submitted successfully', 'review': created.toMap()}));
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

      if (reviewerId == null || reviewId == null) return badRequest('Review ID is required');

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;

      final existingReview = await reviewRepository.getReviewById(reviewId);
      if (existingReview == null) {
        return Response(404, body: jsonEncode({'message': 'Review not found'}));
      }

      if (existingReview.reviewerId != reviewerId) {
        return Response(403, body: jsonEncode({'message': 'You can only edit your own reviews'}));
      }

      final updatedReview = existingReview.copyWith(
        rating: (body['rating'] as num?)?.toDouble(),
        comment: body['comment'] as String?,
        updatedAt: DateTime.now(),
      );

      final result = await reviewRepository.updateReview(updatedReview);

      return Response.ok(jsonEncode({'message': 'Review updated successfully', 'review': result.toMap()}));
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

      if (reviewerId == null || reviewId == null) return badRequest('Review ID is required');

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
      if (userId == null) return badRequest('User ID is required');

      final reviews = await reviewRepository.getReviewsForUser(userId);
      final averageRating = await reviewRepository.calculateAverageRating(userId);

      return Response.ok(
        jsonEncode({
          'userId': userId,
          'averageRating': averageRating,
          'totalReviews': reviews.length,
          'reviews': reviews.map((r) => r.toMap()).toList(),
        }),
      );
    } catch (e, stack) {
      print('Get user reviews error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  /// NEW: GET /reviews/entity/<entityType>/<entityId> - Get reviews for any entity (property, unit, etc.)
  Future<Response> getReviewsByEntity(Request request) async {
    try {
      final entityType = request.params['entityType'];
      final entityId = request.params['entityId'];

      if (entityType == null || entityId == null) {
        return badRequest('Entity type and ID are required');
      }

      final reviews = await reviewRepository.getReviewsForEntity(entityId: entityId, entityType: entityType);

      final averageRating = await reviewRepository.calculateAverageRatingForEntity(
        entityId: entityId,
        entityType: entityType,
      );

      return Response.ok(
        jsonEncode({
          'entityId': entityId,
          'entityType': entityType,
          'averageRating': averageRating,
          'totalReviews': reviews.length,
          'reviews': reviews.map((r) => r.toMap()).toList(),
        }),
      );
    } catch (e, stack) {
      print('Get entity reviews error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  /// GET /reviews/user/<userId>/summary - Get reputation summary
  Future<Response> getUserReputationSummary(Request request) async {
    try {
      final userId = request.params['userId'];
      if (userId == null) return badRequest('User ID is required');

      final user = await userRepository.getUserById(userId);

      return Response.ok(
        jsonEncode({
          'userId': user.id,
          'fullName': user.fullName,
          'primaryRole': user.primaryRole,
          'roles': user.roles,
          'averageRating': user.averageRating,
          'totalReviews': user.totalReviews,
          'tenantReputation': user.tenantReputation,
          'landlordReputation': user.landlordReputation,
          'artisanReputation': user.artisanReputation,
          'paymentOnTimeRate': user.paymentOnTimeRate,
          'badges': user.badges,
        }),
      );
    } catch (e) {
      return Response.internalServerError();
    }
  }

  /// GET /reviews/my-reviews - Reviews written by current user
  Future<Response> getMyWrittenReviews(Request request) async {
    try {
      final reviewerId = request.context['userId'] as String?;
      if (reviewerId == null) return unauthorized("You're not authorised");

      final reviews = await reviewRepository.getReviewsByReviewer(reviewerId);

      return Response.ok(
        jsonEncode({'reviewsWritten': reviews.length, 'reviews': reviews.map((r) => r.toMap()).toList()}),
      );
    } catch (e) {
      return Response.internalServerError();
    }
  }
}
