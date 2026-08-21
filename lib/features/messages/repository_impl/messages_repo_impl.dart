import 'package:neztmate_backend/features/messages/datasource/remote_datasource.dart';
import 'package:neztmate_backend/features/messages/models/chats_model.dart';
import 'package:neztmate_backend/features/messages/models/messages_model.dart';
import 'package:neztmate_backend/features/messages/repository/message_repo.dart';

class MessageRepositoryImpl implements MessageRepository {
  final MessageRemoteDataSource dataSource;

  MessageRepositoryImpl(this.dataSource);

  @override
  Future<MessageModel> sendMessage(MessageModel message) => dataSource.sendMessage(message);

  @override
  Future<List<MessageModel>> getConversation(
    String userId1,
    String userId2, {
    String? propertyId,
    String? partnerId,
    int limit = 50,
  }) => dataSource.getConversation(
    userId1,
    userId2,
    propertyId: propertyId,
    partnerId: partnerId,
    limit: limit,
  );
  @override
  Future<MessageModel> getMessageById(String id) => dataSource.getMessageById(id);

  @override
  Future<void> markAsRead(String messageId, String readerId) =>
      dataSource.markChatAsRead(messageId, readerId);

  @override
  Future<void> deleteMessage(String id) => dataSource.deleteMessage(id);

  @override
  Future<List<ChatSummaryModel>> getUserChats(String userId, {String? partnerId, int limit = 20}) =>
      dataSource.getUserChats(userId, partnerId: partnerId, limit: limit);
}
