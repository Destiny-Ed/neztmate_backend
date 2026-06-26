import 'package:neztmate_backend/features/maintenance/handler/maintenance_handler.dart';
import 'package:shelf_router/shelf_router.dart';

Router maintenanceRoutes(MaintenanceHandler handler) {
  final router = Router();

  // Maintenance Requests
  router.post('/create', handler.createRequest);
  router.get('/all', handler.getAllRequests); // Manager/Landowner - All requests
  router.get('/me', handler.getMyRequests); // Tenant - My requests
  router.get('/<id>/request', handler.getRequestById); // Tenant - My requests

  // Tasks
  router.post('/<requestId>/tasks/assign', handler.assignTask);
  router.delete('/tasks/<taskId>/remove', handler.removeAssignedArtisan);
  router.patch('/tasks/<id>/accept', handler.acceptTask);
  router.patch('/tasks/<id>/decline', handler.declineTask);
  router.patch('/tasks/<id>/complete', handler.completeTask);
  router.get('/tasks/<id>', handler.getTaskById);

  router.get('/tasks/my', handler.getMyTasks);

  // Payment Approval
  router.patch('/tasks/<id>/approve-payment', handler.approveTaskPayment);

  return router;
}
