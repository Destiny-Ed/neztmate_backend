import 'package:neztmate_backend/features/affiliates/handler/affliate_handler.dart';
import 'package:shelf_router/shelf_router.dart';

Router affiliateRoutes(AffiliateHandler handler) {
  final router = Router();

  router.get('/me', handler.getMyReferralStats);
  router.get('/earnings', handler.getEarnings);
  router.post('/generate-link', handler.generateReferralLink);

  router.post('/request-payout', handler.requestPayout);

  router.post('/admin/affiliates/process-payout', handler.processManualPayout);

  return router;
}
