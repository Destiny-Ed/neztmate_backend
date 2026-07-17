import 'package:neztmate_backend/features/invites/handler/invite_handler.dart';
import 'package:shelf_router/shelf_router.dart';

Router inviteRoutes(InviteHandler handler) {
  final router = Router();

  router.post('/send', handler.sendInvite); // Send invite
  router.get('/me', handler.getMyInvites); // My sent invites
  router.get('/requests', handler.getInviteRequests); // Invites sent to me
  router.get('/<id>', handler.getInviteById); // Get single invite
  router.post('/<id>/accept', handler.acceptInvite);
  router.post('/<id>/decline', handler.declineInvite);
  router.post('/<id>/withdraw', handler.withdrawInvite);

  return router;
}
