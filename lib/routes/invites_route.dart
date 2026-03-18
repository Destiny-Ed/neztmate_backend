import 'package:neztmate_backend/features/invites/handler/invite_handler.dart';
import 'package:shelf_router/shelf_router.dart';

Router inviteRoutes(InviteHandler handler) {
  final router = Router();

  router.post('/', handler.sendInvite);
  router.get('/', handler.getMyInvites);
  router.post('/<id>/accept', handler.acceptInvite);

  return router;
}
