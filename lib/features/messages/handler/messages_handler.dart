import 'dart:async';
import 'dart:convert';
import 'package:neztmate_backend/core/services/auth/jwt_service.dart';
import 'package:neztmate_backend/core/services/chat/chat_connection_manager.dart';
import 'package:neztmate_backend/features/auth_user/repositories/user_repository.dart';
import 'package:neztmate_backend/features/messages/models/messages_model.dart';
import 'package:neztmate_backend/features/messages/repository/message_repo.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class MessageHandler {
  final MessageRepository repository;
  final UserRepository userRepository;
  final JwtService jwtService;

  final ChatConnectionManager _connectionManager = ChatConnectionManager();

  MessageHandler(this.repository, this.jwtService, this.userRepository);

  /// POST /messages - Send a new message
  Future<Response> sendMessage(Request request) async {
    try {
      final senderId = request.context['userId'] as String?;
      if (senderId == null) return Response(401, body: jsonEncode({'message': 'Unauthorized'}));

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;

      if (!body.containsKey('receiverId') || !body.containsKey('content')) {
        return Response(400, body: jsonEncode({'message': 'receiverId and content are required'}));
      }

      final message = MessageModel(
        id: "",
        senderId: senderId,
        receiverId: body['receiverId'],
        content: body['content'],
        createdAt: DateTime.now(),
      );

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
      final limit = request.params['limit'];

      if (userId == null) {
        return Response(401, body: jsonEncode({'message': 'Unauthorized'}));
      }

      final chats = await repository.getUserChats(userId, limit: int.parse(limit ?? "20"));

      final enrichedChat = await Future.wait(
        chats.map((chat) async {
          final user = await userRepository.getUserById(chat.otherUserId);
          return chat.copyWith(otherUserName: user.fullName, otherUserPhotoUrl: user.profilePhotoUrl);
        }),
      );

      return Response.ok(
        jsonEncode({'chats': enrichedChat.map((c) => c.toMap()).toList(), 'message': 'Chat list loaded'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Get user chats error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to load chat list'}));
    }
  }

  ///Websocket
  /// WebSocket: /messages/ws?userId=xxx&receiverId=yyy
  Handler getWebSocketHandler(Request request) {
    return webSocketHandler((WebSocketChannel webSocket, String? protocol) async {
      final token = request.params['token'];
      final userIdFromQuery = request.params['userId'];

      // AUTHENTICATION
      if (token == null || token.isEmpty) {
        webSocket.sink.add(jsonEncode({'error': 'Authentication token is required'}));
        webSocket.sink.close(4001, 'Missing token');
        return;
      }

      String? authenticatedUserId;
      try {
        final jwt = jwtService.verify(token);
        authenticatedUserId = jwt.payload['sub'] as String?;

        if (authenticatedUserId == null) {
          throw Exception('Invalid token payload');
        }

        // Optional: Validate userId from query matches token
        if (userIdFromQuery != null && userIdFromQuery != authenticatedUserId) {
          webSocket.sink.add(jsonEncode({'error': 'User ID mismatch'}));
          webSocket.sink.close(4003, 'Unauthorized');
          return;
        }
      } catch (e) {
        webSocket.sink.add(jsonEncode({'error': 'Invalid or expired token'}));
        webSocket.sink.close(4001, 'Authentication failed');
        return;
      }

      final userId = authenticatedUserId;
      _connectionManager.addConnection(userId, webSocket);

      print('WebSocket authenticated for user: $userId');

      // Send connection success
      webSocket.sink.add(
        jsonEncode({'type': 'connected', 'userId': userId, 'timestamp': DateTime.now().toIso8601String()}),
      );

      // HEARTBEAT (Ping/Pong)
      Timer? heartbeatTimer;

      void startHeartbeat() {
        heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
          if (webSocket.closeCode == null) {
            try {
              webSocket.sink.add(jsonEncode({'type': 'ping', 'timestamp': DateTime.now().toIso8601String()}));
            } catch (_) {
              heartbeatTimer?.cancel();
            }
          }
        });
      }

      startHeartbeat();

      // Handle incoming messages
      webSocket.stream.listen(
        (dynamic message) async {
          try {
            final data = jsonDecode(message as String) as Map<String, dynamic>;
            final type = data['type'] as String?;

            // Handle pong response
            if (type == 'pong') {
              // Connection is alive - can log last activity if needed
              return;
            }

            if (type == 'send') {
              final receiverId = data['receiverId'] as String?;
              final content = data['content'] as String?;
              final propertyId = data['propertyId'] as String?;

              if (receiverId == null || content == null || content.trim().isEmpty) {
                webSocket.sink.add(jsonEncode({'error': 'receiverId and content are required'}));
                return;
              }

              final newMessage = MessageModel(
                id: '',
                senderId: userId,
                receiverId: receiverId,
                content: content.trim(),
                propertyId: propertyId,
                createdAt: DateTime.now(),
              );

              final savedMessage = await repository.sendMessage(newMessage);

              final payload = {'type': 'new_message', 'message': savedMessage.toMap()};

              _connectionManager.broadcastToChat(userId, receiverId, payload);
            }
          } catch (e, stack) {
            print('WebSocket message error: $e\n$stack');
            webSocket.sink.add(jsonEncode({'error': 'Invalid message format'}));
          }
        },
        onError: (error) => print('WebSocket error for $userId: $error'),
        onDone: () {
          heartbeatTimer?.cancel();
          _connectionManager.removeConnection(webSocket);
        },
      );
    });
  }
}
