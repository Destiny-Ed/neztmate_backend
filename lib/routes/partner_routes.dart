import 'package:neztmate_backend/features/partners/handler/partner_handler.dart';
import 'package:shelf_router/shelf_router.dart';

/// Public — no auth
Router partnerPublicRoutes(PartnerHandler handler) {
  final router = Router();

  router.get('/config', handler.getPublicConfig); // ?slug=
  router.get('/public', handler.listPublicPartners); // landing page
  router.post('/requests', handler.submitPartnerRequest);
  router.get('/<id>', handler.getPartnerById);

  return router;
}

/// Protected — auth middleware
Router partnerProtectedRoutes(PartnerHandler handler) {
  final router = Router();

  // ── Partner admin (JWT partnerId) ──
  router.get('/me', handler.getMyPartner);
  router.patch('/me', handler.updateMyPartner);
  router.patch('/me/branding', handler.updateMyBranding);
  router.get('/me/notifications', handler.getMyPartnerNotifications);
  router.post('/me/notifications', handler.sendPartnerNotification);
  router.get('/me/analytics', handler.getMyPartnerAnalytics);

  // ── Platform admin ──
  router.get('/', handler.listPartners);
  router.post('/', handler.createPartner);
  router.post('/with-admin', handler.createPartnerWithAdmin);

  router.get('/requests', handler.listPartnerRequests);
  router.patch('/requests/<id>', handler.updatePartnerRequest);
  router.post('/requests/<id>/approve', handler.approvePartnerRequest);

  router.patch('/<id>', handler.updatePartner);
  router.patch('/<id>/status', handler.setPartnerStatus);
  router.post('/<id>/admin/reset-password', handler.resetPartnerAdminPassword);

  return router;
}

Router platformRoutes(PartnerHandler handler) {
  final router = Router();
  router.get('/analytics', handler.getPlatformAnalytics);
  return router;
}
