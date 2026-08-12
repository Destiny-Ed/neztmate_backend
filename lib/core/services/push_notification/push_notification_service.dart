import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:neztmate_backend/features/auth_user/repositories/user_repository.dart';

class PushNotificationService {
  final UserRepository userRepository;

  /// OAuth2 access token for FCM HTTP v1 (from service account)
  final Future<String> Function() getAccessToken;
  final String projectId;

  PushNotificationService({
    required this.userRepository,
    required this.getAccessToken,
    required this.projectId,
  });

  Future<void> sendToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      final user = await userRepository.getUserById(userId);
      final token = user.fcmToken;

      if (token.isEmpty) {
        print('Push skipped: no FCM token for $userId');
        return;
      }

      await sendToToken(token: token, title: title, body: body, data: {...?data, 'userId': userId});
    } catch (e, s) {
      print('Push to user $userId failed: $e\n$s');
      // Don't throw — push failure shouldn't break business flow
    }
  }

  Future<void> sendToToken({
    required String token,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    final accessToken = await getAccessToken();
    final url = Uri.parse('https://fcm.googleapis.com/v1/projects/$projectId/messages:send');

    final message = {
      'message': {
        'token': token,
        'notification': {'title': title, 'body': body},
        'data': {for (final e in (data ?? {}).entries) e.key: e.value.toString()},
        'android': {
          'priority': 'HIGH',
          'notification': {'sound': 'default', 'channel_id': 'neztmate_default'},
        },
        'apns': {
          'payload': {
            'aps': {'sound': 'default', 'badge': 1},
          },
        },
      },
    };

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $accessToken'},
      body: jsonEncode(message),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      print('FCM error ${response.statusCode}: ${response.body}');
      // Optional: clear invalid token on UNREGISTERED / INVALID_ARGUMENT
    }
  }

  Future<void> sendToMany({
    required List<String> userIds,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    for (final id in userIds) {
      await sendToUser(userId: id, title: title, body: body, data: data);
    }
  }
}
