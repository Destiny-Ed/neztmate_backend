import 'package:neztmate_backend/features/reviews/handler/user_review_handler.dart';
import 'package:shelf_router/shelf_router.dart';

Router reviewRoutes(UserReviewHandler handler) {
  final router = Router();

  router.post('/create', handler.createReview);
  router.get('/user/<userId>', handler.getUserReviews);
  router.get('/user/<userId>/summary', handler.getUserReputationSummary);
  router.get('/my-reviews', handler.getMyWrittenReviews);

  return router;
}
