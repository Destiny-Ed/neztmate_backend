import 'package:neztmate_backend/features/tasks/handler/task_handler.dart';
import 'package:shelf_router/shelf_router.dart';

Router taskRoutes(TaskHandler handler) {
  final router = Router();

  // Manager endpoints
  router.post('/', handler.createTask);
  router.get('/request/<requestId>', handler.getTasksByRequest);

  // Artisan endpoints
  router.get('/me', handler.getMyTasks);
  router.patch('/<id>/complete', handler.completeTask);

  // General (artisan or manager)
  router.get('/<id>', handler.getTaskById);

  return router;
}
