import 'package:neztmate_backend/features/announcement/handler/announcement_handler.dart';
import 'package:shelf_router/shelf_router.dart';

Router announcementRoutes(AnnouncementHandler handler) {
  final router = Router();

  router.post('/create', handler.create);
  router.get('/admin', handler.listAdmin);
  router.get('/active', handler.listActive);
  router.patch('/<id>', handler.update);
  router.delete('/<id>', handler.deactivate);

  return router;
}
