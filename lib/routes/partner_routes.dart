import 'package:neztmate_backend/features/partners/handler/partner_handler.dart';
import 'package:shelf_router/shelf_router.dart';

Router partnerPublicRoutes(PartnerHandler handler) {
  final router = Router();
  router.get('/config', handler.getPublicConfig); // ?slug=neztmate
  router.get('/<id>', handler.getPartnerById);
  return router;
}

Router partnerProtectedRoutes(PartnerHandler handler) {
  final router = Router();
  router.get('/me', handler.getMyPartner);
  router.get('/', handler.listPartners);
  router.post('/', handler.createPartner); // lock down to super-admin later
  return router;
}
