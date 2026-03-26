import 'package:neztmate_backend/features/messages/handler/messages_handler.dart';
import 'package:shelf_router/shelf_router.dart';

Router messageRoutes(MessageHandler handler) {
  final router = Router();

  router.post('/', handler.sendMessage);
  router.get('/conversation/<receiverId>', handler.getConversation);
  router.patch('/<id>/read', handler.markAsRead);
  router.get('/chats', handler.getUserChats);

  return router;
}
