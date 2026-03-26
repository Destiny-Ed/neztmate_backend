import 'dart:convert';
import 'package:neztmate_backend/features/messages/models/messages_model.dart';
import 'package:neztmate_backend/features/messages/repository/message_repo.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class MessageHandler {
  final MessageRepository repository;

  MessageHandler(this.repository);

  /// POST /messages - Send a new message
  Future<Response> sendMessage(Request request) async {
    try {
      final senderId = request.context['userId'] as String?;
      if (senderId == null) return Response(401, body: jsonEncode({'message': 'Unauthorized'}));

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;

      if (!body.containsKey('receiverId') || !body.containsKey('content')) {
        return Response(400, body: jsonEncode({'message': 'receiverId and content are required'}));
      }

      final message = MessageModel.fromMap(body, '').copyWith(senderId: senderId, createdAt: DateTime.now());

      final sent = await repository.sendMessage(message);

      return Response.ok(
        jsonEncode({'message': 'Message sent', 'data': sent.toMap()}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Send message error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to send message'}));
    }
  }

  /// GET /messages/conversation/<receiverId> - Get conversation between current user and another user
  Future<Response> getConversation(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final receiverId = request.params['receiverId'];

      if (userId == null || receiverId == null) {
        return Response(400, body: jsonEncode({'message': 'Missing user IDs'}));
      }

      final messages = await repository.getConversation(userId, receiverId);

      return Response.ok(
        jsonEncode({'messages': messages.map((m) => m.toMap()).toList()}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Get conversation error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to load conversation'}));
    }
  }

  /// PATCH /messages/<id>/read - Mark message as read
  Future<Response> markAsRead(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final messageId = request.params['id'];

      if (userId == null || messageId == null) {
        return Response(400, body: jsonEncode({'message': 'Missing ID'}));
      }

      await repository.markAsRead(messageId, userId);

      return Response.ok(jsonEncode({'message': 'Message marked as read'}));
    } catch (e) {
      return Response.internalServerError();
    }
  }

  /// GET /messages/chats - Get list of user's conversations (chat inbox)
  Future<Response> getUserChats(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      if (userId == null) {
        return Response(401, body: jsonEncode({'message': 'Unauthorized'}));
      }

      final chats = await repository.getUserChats(userId, limit: 20);

      return Response.ok(
        jsonEncode({'chats': chats.map((c) => c.toMap()).toList(), 'message': 'Chat list loaded'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Get user chats error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to load chat list'}));
    }
  }
}
