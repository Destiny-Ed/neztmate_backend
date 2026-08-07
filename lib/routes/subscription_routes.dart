import 'package:neztmate_backend/features/subscriptions/handler/subscription_handler.dart';
import 'package:shelf_router/shelf_router.dart';

Router subscriptionRoutes(SubscriptionHandler handler) {
  final router = Router();

  router.post('/plans', handler.createPlan); // admin
  router.get('/plans', handler.getPlans);
  router.patch('/plans/<id>', handler.updatePlan); // admin
  router.get('/me', handler.getMySubscription);
  router.post('/subscribe', handler.subscribe);
  router.post('/cancel', handler.cancelSubscription);

  return router;
}
