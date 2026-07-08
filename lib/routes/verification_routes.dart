

import 'package:neztmate_backend/features/verification/handler/verification_handler.dart';
import 'package:shelf_router/shelf_router.dart';

Router verificationRoutes(VerificationHandler handler) {
  final router = Router();

  router.post('/initiate', handler.initiateVerification);
  // router.post('/webhooks', handler.handleWebhook);

  return router;
}