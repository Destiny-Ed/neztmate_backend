import 'package:neztmate_backend/features/auth_user/handler/user_handler.dart';
import 'package:shelf_router/shelf_router.dart';

Router userRoutes(UserHandler handler) {
  final router = Router();

  // All routes below are protected
  router.get('/me', handler.getCurrentUser);
  router.patch('/me', handler.updateCurrentUser);
  router.delete('/me', handler.deleteCurrentUser);
  router.get('/<id>', handler.getUserById);

  return router;
}
