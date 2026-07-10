import 'package:neztmate_backend/features/reviews/handler/user_review_handler.dart';
import 'package:shelf_router/shelf_router.dart';

Router reviewRoutes(UserReviewHandler handler) {
  final router = Router();

  router.post('/', handler.createReview);
  router.patch('/<id>', handler.updateReview);
  router.delete('/<id>', handler.deleteReview);

  router.get('/user/<userId>', handler.getUserReviews);
  router.get('/user/<userId>/summary', handler.getUserReputationSummary);
  router.get('/my-reviews', handler.getMyWrittenReviews);

  // NEW: Get reviews for any entity (property, unit, etc.)
  router.get('/entity/<entityType>/<entityId>', handler.getReviewsByEntity);

  return router;
}
