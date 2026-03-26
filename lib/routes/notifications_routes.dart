import 'package:neztmate_backend/features/notifications/handler/handler.dart';
import 'package:shelf_router/shelf_router.dart';

Router notificationRoutes(NotificationHandler handler) {
  final router = Router();

  router.get('/', handler.getNotifications);
  router.patch('/<id>/read', handler.markAsRead);
  router.patch('/read-all', handler.markAllAsRead);

  return router;
}
