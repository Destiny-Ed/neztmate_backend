import 'package:neztmate_backend/features/units/handler/unit_handler.dart';
import 'package:shelf_router/shelf_router.dart';

Router unitRoutes(UnitHandler handler) {
  final router = Router();

  // Public / tenant-facing
  router.get('/available', handler.getAvailableUnits);
  router.get('/property/<propertyId>', handler.getUnitsByProperty);

  // Protected (authenticated users)
  router.get('/<id>', handler.getUnitById);

  // Admin / manager / landowner only (can be further restricted in middleware)
  router.post('/create', handler.createUnit);
  router.patch('/<id>/update', handler.updateUnit);
  router.delete('/<id>/delete', handler.deleteUnit);

  return router;
}
