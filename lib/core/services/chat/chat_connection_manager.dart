import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class ChatConnectionManager {
  static final ChatConnectionManager _instance = ChatConnectionManager._internal();
  factory ChatConnectionManager() => _instance;
  ChatConnectionManager._internal();

  // userId -> list of active connections
  final Map<String, List<WebSocketChannel>> _connections = {};
  final Map<WebSocketChannel, String> _channelToUser = {};

  void addConnection(String userId, WebSocketChannel channel) {
    _connections.putIfAbsent(userId, () => []).add(channel);
    _channelToUser[channel] = userId;
    print('✅ WebSocket connected: $userId | Total: ${_connections[userId]!.length}');
  }

  void removeConnection(WebSocketChannel channel) {
    final userId = _channelToUser.remove(channel);
    if (userId != null) {
      _connections[userId]?.remove(channel);
      if (_connections[userId]?.isEmpty ?? true) {
        _connections.remove(userId);
      }
      print('❌ WebSocket disconnected: $userId');
    }
  }

  void broadcastToUser(String userId, Map<String, dynamic> message) {
    final connections = _connections[userId] ?? [];
    final encoded = jsonEncode(message);

    for (var channel in connections) {
      if (channel.closeCode == null) {
        channel.sink.add(encoded);
      }
    }
  }

  void broadcastToChat(String user1, String user2, Map<String, dynamic> message) {
    broadcastToUser(user1, message);
    broadcastToUser(user2, message);
  }
}
