import 'package:neztmate_backend/features/leases/handler/lease_handler.dart';
import 'package:shelf_router/shelf_router.dart';

Router leaseRoutes(LeaseHandler handler) {
  final router = Router();

  router.get('/me', handler.getMyLeases);
  router.get('/landowner/me', handler.getLandownerLeases);
  router.get('/<id>', handler.getLeaseById);
  router.patch('/<id>/sign', handler.signLease);
  router.patch('/<id>/terminate', handler.terminateLease);
  router.get('/property/<propertyId>', handler.getLeasesByProperty);

  return router;
}
