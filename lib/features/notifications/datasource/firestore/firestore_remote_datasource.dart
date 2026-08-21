import 'package:dart_firebase_admin/firestore.dart';
import 'package:neztmate_backend/features/notifications/datasource/remote_datasource.dart';
import 'package:neztmate_backend/features/notifications/models/notification_model.dart';

class FirestoreNotificationDataSource implements NotificationRemoteDataSource {
  final Firestore firestore;

  FirestoreNotificationDataSource(this.firestore);

  CollectionReference get _notifications => firestore.collection('notifications');

  @override
  Future<NotificationModel> create(NotificationModel notification) async {
    final docRef = _notifications.doc();
    final newNotif = notification.copyWith(id: docRef.id);
    await docRef.set(newNotif.toMap());
    return newNotif;
  }

  @override
  Future<List<NotificationModel>> getByUser(
    String userId, {
    String? partnerId,
    int limit = 30,
    bool unreadOnly = false,
  }) async {
    Query query = _notifications.where('userId', WhereFilter.equal, userId);

    if (partnerId != null && partnerId.isNotEmpty) {
      query = query.where('partnerId', WhereFilter.equal, partnerId);
    }

    if (unreadOnly) {
      query = query.where('isRead', WhereFilter.equal, false);
    }

    final snap = await query.orderBy('createdAt', descending: true).limit(limit).get();

    return snap.docs.map((doc) {
      return NotificationModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }).toList();
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    await _notifications.doc(notificationId).update({'isRead': true});
  }

  @override
  Future<void> markAllAsRead(String userId, {String? partnerId}) async {
    Query query = _notifications
        .where('userId', WhereFilter.equal, userId)
        .where('isRead', WhereFilter.equal, false);

    if (partnerId != null && partnerId.isNotEmpty) {
      query = query.where('partnerId', WhereFilter.equal, partnerId);
    }

    final snap = await query.get();

    for (final doc in snap.docs) {
      await doc.ref.update({'isRead': true});
    }
  }

  @override
  Future<void> delete(String id) async {
    await _notifications.doc(id).delete();
  }
}
