import 'package:neztmate_backend/features/maintenance/handler/maintenance_handler.dart';
import 'package:shelf_router/shelf_router.dart';

Router maintenanceRoutes(MaintenanceRequestHandler handler) {
  final router = Router();

  // Tenant endpoints
  router.post('/', handler.submitRequest);
  router.get('/me', handler.getMyRequests);
  router.delete('/<id>', handler.deleteRequest);

  // Manager/Landowner endpoints
  router.get('/unit/<unitId>', handler.getRequestsByUnit);
  router.patch('/<id>/assign', handler.assignRequest);

  // General (tenant + manager/artisan)
  router.get('/<id>', handler.getRequestById);
  router.patch('/<id>', handler.updateRequest);

  return router;
}
