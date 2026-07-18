import 'package:neztmate_backend/features/subscriptions/handler/subscription_handler.dart';
import 'package:shelf_router/shelf_router.dart';

Router subscriptionRoutes(SubscriptionHandler handler) {
  final router = Router();

  router.get('/plans', handler.getPlans);
  router.get('/me', handler.getMySubscription);
  router.post('/subscribe', handler.subscribe);
  router.post('/cancel', handler.cancelSubscription);

  return router;
}
