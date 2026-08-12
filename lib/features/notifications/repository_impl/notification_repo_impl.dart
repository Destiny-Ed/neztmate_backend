import 'dart:async';

import 'package:neztmate_backend/core/services/push_notification/push_notification_service.dart';
import 'package:neztmate_backend/features/notifications/datasource/remote_datasource.dart';
import 'package:neztmate_backend/features/notifications/models/notification_model.dart';
import 'package:neztmate_backend/features/notifications/repository/notification_repo.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final NotificationRemoteDataSource dataSource;
  final PushNotificationService pushNotificationService;

  NotificationRepositoryImpl(this.dataSource, this.pushNotificationService);

  @override
  Future<NotificationModel> create(NotificationModel notification) async {
    final result = dataSource.create(notification);

    unawaited(
      pushNotificationService.sendToUser(
        userId: notification.userId,
        title: notification.title,
        body: notification.body,
        data: {
          'type': notification.type,
          'relatedId': ?notification.relatedId,
          'relatedCollection': ?notification.relatedCollection,
        },
      ),
    );
    return result;
  }

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
