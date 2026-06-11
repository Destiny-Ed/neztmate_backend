import 'package:neztmate_backend/features/notifications/handler/handler.dart';
import 'package:shelf_router/shelf_router.dart';

Router notificationRoutes(NotificationHandler handler) {
  final router = Router();

  router.get('/all', handler.getNotifications);
  router.patch('/read-all', handler.markAllAsRead);
  router.patch('/<id>/read', handler.markAsRead);

  return router;
}
