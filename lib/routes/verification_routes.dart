import 'package:neztmate_backend/features/verification/handler/verification_handler.dart';
import 'package:shelf_router/shelf_router.dart';

Router verificationRoutes(VerificationHandler handler) {
  final router = Router();
  router.post('/initiate', handler.initiate);
  return router;
}

// Public webhook — mount WITHOUT auth middleware
Router verificationPublicRoutes(VerificationHandler handler) {
  final router = Router();
  router.post('/webhook/veriff', handler.veriffWebhook);
  router.post('/webhook/youverify', handler.youVerifyWebhook);
  return router;
}
