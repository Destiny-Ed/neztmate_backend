import 'package:neztmate_backend/features/notifications/models/notification_model.dart';

abstract class NotificationRepository {
  Future<NotificationModel> createNotification(NotificationModel notification);
  Future<List<NotificationModel>> getNotificationsByUser(String userId, {int limit = 30});
  Future<void> markAsRead(String notificationId);
  Future<void> markAllAsRead(String userId);
  Future<void> deleteNotification(String id);
}
