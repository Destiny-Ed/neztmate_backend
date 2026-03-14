import 'package:neztmate_backend/features/messages/models/messages_model.dart';

abstract class MessageRepository {
  Future<MessageModel> sendMessage(MessageModel message);
  Future<List<MessageModel>> getConversation(String userId1, String userId2, {String? propertyId});
  Future<MessageModel> getMessageById(String id);
  Future<void> markAsRead(String messageId, String readerId);
  Future<void> deleteMessage(String id);
}
