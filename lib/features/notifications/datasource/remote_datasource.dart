import 'package:neztmate_backend/features/notifications/models/notification_model.dart';

abstract class NotificationRemoteDataSource {
  Future<NotificationModel> create(NotificationModel notification);
  Future<List<NotificationModel>> getByUser(String userId, {int limit = 30, bool unreadOnly = false});
  Future<void> markAsRead(String notificationId);
  Future<void> markAllAsRead(String userId);
  Future<void> delete(String id);
}
