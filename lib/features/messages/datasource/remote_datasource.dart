import 'package:neztmate_backend/features/messages/models/chats_model.dart';
import 'package:neztmate_backend/features/messages/models/messages_model.dart';

abstract class MessageRemoteDataSource {
  Future<MessageModel> sendMessage(MessageModel message);
  Future<List<MessageModel>> getConversation(
    String userId1,
    String userId2, {
    String? propertyId,
    int limit = 50,
  });
  Future<MessageModel> getMessageById(String id);
  Future<void> markAsRead(String messageId, String readerId);
  Future<void> deleteMessage(String id);
  Future<List<ChatSummaryModel>> getUserChats(String userId, {int limit = 20});
}
