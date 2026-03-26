import 'package:neztmate_backend/features/notifications/datasource/remote_datasource.dart';
import 'package:neztmate_backend/features/notifications/models/notification_model.dart';
import 'package:neztmate_backend/features/notifications/repository/notification_repo.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final NotificationRemoteDataSource dataSource;

  NotificationRepositoryImpl(this.dataSource);

  @override
  Future<NotificationModel> create(NotificationModel notification) => dataSource.create(notification);

  @override
  Future<List<NotificationModel>> getByUser(String userId, {int limit = 30, bool unreadOnly = false}) =>
      dataSource.getByUser(userId, limit: limit, unreadOnly: unreadOnly);

  @override
  Future<void> markAsRead(String notificationId) => dataSource.markAsRead(notificationId);

  @override
  Future<void> markAllAsRead(String userId) => dataSource.markAllAsRead(userId);

  @override
  Future<void> delete(String id) => dataSource.delete(id);
}
