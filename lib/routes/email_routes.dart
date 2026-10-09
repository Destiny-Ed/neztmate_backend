import 'package:neztmate_backend/features/emails/handler/email_handler.dart';
import 'package:shelf_router/shelf_router.dart';

Router emailRoutes(EmailHandler handler) {
  final router = Router();

  router.post('/send', handler.send);
  router.post('/campaign', handler.campaign);
  router.post('/welcome', handler.resendWelcome);

  return router;
}
