import 'package:neztmate_backend/features/notifications/models/notification_model.dart';

abstract class NotificationRepository {
  Future<NotificationModel> create(NotificationModel notification);

  Future<List<NotificationModel>> getByUser(
    String userId, {
    String? partnerId,
    int limit = 30,
    bool unreadOnly = false,
  });

  Future<void> markAsRead(String notificationId);

  Future<void> markAllAsRead(String userId, {String? partnerId});

  Future<void> delete(String id);
}
