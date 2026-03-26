import 'dart:convert';
import 'package:neztmate_backend/features/notifications/repository/notification_repo.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class NotificationHandler {
  final NotificationRepository repository;

  NotificationHandler(this.repository);

  /// GET /notifications - Get user's notifications
  Future<Response> getNotifications(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      if (userId == null) {
        return Response(401, body: jsonEncode({'message': 'Unauthorized'}));
      }

      final unreadOnly = request.url.queryParameters['unread'] == 'true';

      final notifications = await repository.getByUser(userId, unreadOnly: unreadOnly);

      return Response.ok(
        jsonEncode({
          'notifications': notifications.map((n) => n.toMap()).toList(),
          'message': 'Notifications loaded',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Get notifications error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to load notifications'}));
    }
  }

  /// PATCH /notifications/<id>/read - Mark single notification as read
  Future<Response> markAsRead(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final notificationId = request.params['id'];

      if (userId == null || notificationId == null) {
        return Response(400, body: jsonEncode({'message': 'Missing ID'}));
      }

      await repository.markAsRead(notificationId);

      return Response.ok(jsonEncode({'message': 'Notification marked as read'}));
    } catch (e) {
      return Response.internalServerError();
    }
  }

  /// PATCH /notifications/read-all - Mark all notifications as read
  Future<Response> markAllAsRead(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      if (userId == null) {
        return Response(401, body: jsonEncode({'message': 'Unauthorized'}));
      }

      await repository.markAllAsRead(userId);

      return Response.ok(jsonEncode({'message': 'All notifications marked as read'}));
    } catch (e) {
      return Response.internalServerError();
    }
  }
}
