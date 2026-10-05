import 'dart:async';
import 'dart:convert';
import 'package:neztmate_backend/core/services/auth/jwt_service.dart';
import 'package:neztmate_backend/core/services/chat/chat_connection_manager.dart';
import 'package:neztmate_backend/features/auth_user/repositories/user_repository.dart';
import 'package:neztmate_backend/features/messages/models/messages_model.dart';
import 'package:neztmate_backend/features/messages/repository/message_repo.dart';
import 'package:neztmate_backend/features/notifications/models/notification_model.dart';
import 'package:neztmate_backend/features/notifications/repository/notification_repo.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';

class MessageHandler {
  final MessageRepository repository;
  final UserRepository userRepository;
  final JwtService jwtService;
  final NotificationRepository notificationRepository;

  final ChatConnectionManager _connectionManager = ChatConnectionManager();

  MessageHandler(
    this.repository,
    this.jwtService,
    this.userRepository,
    this.notificationRepository,
  );

  /// POST /messages - Send a new message
  Future<Response> sendMessage(Request request) async {
    try {
      final senderId = request.context['userId'] as String?;
      final partnerId = request.context['partnerId'] as String?;

      if (senderId == null || partnerId == null) {
        return Response(401, body: jsonEncode({'message': 'Unauthorized'}));
      }

      final body =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;

      if (!body.containsKey('receiverId') || !body.containsKey('content')) {
        return Response(
          400,
          body: jsonEncode({'message': 'receiverId and content are required'}),
        );
      }

      final message = MessageModel(
        id: "",
        senderId: senderId,
        partnerId: partnerId,
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
      return Response.internalServerError(
        body: jsonEncode({'message': 'Failed to send message'}),
      );
    }
  }

  /// GET /messages/conversation/<receiverId> - Get conversation between current user and another user
  Future<Response> getConversation(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final partnerId = request.context['partnerId'] as String?;
      final receiverId = request.params['receiverId'];

      if (userId == null || receiverId == null || partnerId == null) {
        return Response(400, body: jsonEncode({'message': 'Missing user IDs'}));
      }

      final messages = await repository.getConversation(
        userId,
        receiverId,
        partnerId: partnerId,
      );

      return Response.ok(
        jsonEncode({'messages': messages.map((m) => m.toMap()).toList()}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Get conversation error: $e\n$stack');
      return Response.internalServerError(
        body: jsonEncode({'message': 'Failed to load conversation'}),
      );
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
      final partnerId = request.context['partnerId'] as String?;

      final limit = request.params['limit'];

      if (userId == null || partnerId == null) {
        return Response(401, body: jsonEncode({'message': 'Unauthorized'}));
      }

      final chats = await repository.getUserChats(
        userId,
        limit: int.parse(limit ?? "20"),
        partnerId: partnerId,
      );

      final enrichedChat = await Future.wait(
        chats.map((chat) async {
          final user = await userRepository.getUserById(chat.otherUserId);
          return chat.copyWith(
            otherUserName: user.fullName,
            otherUserPhotoUrl: user.profilePhotoUrl,
            otherRole: user.role,
            otherPhone: user.phone,
          );
        }),
      );

      return Response.ok(
        jsonEncode({
          'chats': enrichedChat.map((c) => c.toMap()).toList(),
          'message': 'Chat list loaded',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Get user chats error: $e\n$stack');
      return Response.internalServerError(
        body: jsonEncode({'message': 'Failed to load chat list'}),
      );
    }
  }

  ///Websocket
  /// WebSocket: /messages/ws?userId=xxx&token=yyy
  FutureOr<Response> getWebSocketHandler(Request request) async {
    return webSocketHandler((webSocket, _) {
      Timer? heartbeatTimer;
      String userId = '';
      String? partnerId;

      void startHeartbeat() {
        heartbeatTimer?.cancel();
        heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (_) {
          try {
            if (webSocket.closeCode != null) {
              heartbeatTimer?.cancel();
              return;
            }
            webSocket.sink.add(
              jsonEncode({
                'type': 'ping',
                'timestamp': DateTime.now().toIso8601String(),
              }),
            );
          } catch (_) {
            heartbeatTimer?.cancel();
            _connectionManager.removeConnection(webSocket);
          }
        });
      }

      webSocket.stream.listen(
        (dynamic raw) async {
          try {
            final data = jsonDecode(raw as String) as Map<String, dynamic>;
            final type = data['type'] as String?;

            if (type == 'auth') {
              final token = data['token'] as String?;
              if (token == null || token.isEmpty) {
                webSocket.sink.add(
                  jsonEncode({'error': 'Authentication token is required'}),
                );
                await webSocket.sink.close(4001, 'Missing token');
                return;
              }

              try {
                final jwt = jwtService.verify(token);
                final authenticatedUserId = jwt.payload['sub'] as String?;
                if (authenticatedUserId == null) {
                  throw Exception('Invalid token payload');
                }

                final queryUserId = data['userId'] as String?;
                if (queryUserId != null && queryUserId != authenticatedUserId) {
                  webSocket.sink.add(jsonEncode({'error': 'User ID mismatch'}));
                  await webSocket.sink.close(4003, 'Unauthorized');
                  return;
                }

                userId = authenticatedUserId;
                partnerId =
                    jwt.payload['partnerId'] as String?; // match your claim
                _connectionManager.addConnection(userId, webSocket);

                webSocket.sink.add(
                  jsonEncode({
                    'type': 'connected',
                    'userId': userId,
                    'timestamp': DateTime.now().toIso8601String(),
                  }),
                );
                startHeartbeat();
              } catch (e) {
                webSocket.sink.add(
                  jsonEncode({'error': 'Invalid or expired token'}),
                );
                await webSocket.sink.close(4001, 'Authentication failed');
              }
              return;
            }

            if (type == 'pong') return;

            if (type == 'send') {
              if (userId.isEmpty) {
                webSocket.sink.add(jsonEncode({'error': 'Not authenticated'}));
                return;
              }

              final receiverId = data['receiverId'] as String?;
              final content = (data['content'] as String?)?.trim();
              final propertyId = data['propertyId'] as String?;

              if (receiverId == null || content == null || content.isEmpty) {
                webSocket.sink.add(
                  jsonEncode({'error': 'receiverId and content are required'}),
                );
                return;
              }

              final saved = await repository.sendMessage(
                MessageModel(
                  id: '',
                  senderId: userId,
                  receiverId: receiverId,
                  partnerId: partnerId ?? '',
                  content: content,
                  propertyId: propertyId,
                  createdAt: DateTime.now(),
                ),
              );

              _connectionManager.broadcastToChat(userId, receiverId, {
                'type': 'new_message',
                'message': saved.toMap(),
              });

              final user = await userRepository.getUserById(userId);

              await notificationRepository.create(
                NotificationModel(
                  id: '',
                  userId: receiverId,
                  partnerId: partnerId ?? '',
                  type: 'new_message',
                  title: 'New message from ${user.fullName}',
                  body: content,
                  relatedId: saved.id,
                  relatedCollection: 'messages',
                  createdAt: DateTime.now(),
                ),
              );
            }
          } catch (e, stack) {
            print('WebSocket message error: $e\n$stack');
            try {
              webSocket.sink.add(
                jsonEncode({'error': 'Failed to process message'}),
              );
            } catch (_) {}
          }
        },
        onError: (e) {
          print('WebSocket error for $userId: $e');
          heartbeatTimer?.cancel();
          _connectionManager.removeConnection(webSocket);
        },
        onDone: () {
          print('WebSocket closed for $userId');
          heartbeatTimer?.cancel();
          _connectionManager.removeConnection(webSocket);
        },
      );
    })(request);
  }
}
