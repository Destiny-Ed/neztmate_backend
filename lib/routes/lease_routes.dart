import 'package:neztmate_backend/features/leases/handler/lease_handler.dart';
import 'package:shelf_router/shelf_router.dart';

Router leaseRoutes(LeaseHandler handler) {
  final router = Router();

  router.get('/me', handler.getMyLeases);
  router.get('/property/<propertyId>', handler.getLeasesByProperty);
  router.get('/<id>', handler.getLeaseById);

  return router;
}
