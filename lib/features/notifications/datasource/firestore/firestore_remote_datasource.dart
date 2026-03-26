import 'package:dart_firebase_admin/firestore.dart';
import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/features/notifications/datasource/remote_datasource.dart';
import 'package:neztmate_backend/features/notifications/models/notification_model.dart';

class FirestoreNotificationDataSource implements NotificationRemoteDataSource {
  final Firestore firestore;

  FirestoreNotificationDataSource(this.firestore);

  @override
  Future<NotificationModel> create(NotificationModel notification) async {
    final docRef = firestore.collection('notifications').doc();
    final newNotif = notification.copyWith(id: docRef.id);
    await docRef.set(newNotif.toMap());
    return newNotif;
  }

  @override
  Future<List<NotificationModel>> getByUser(String userId, {int limit = 30, bool unreadOnly = false}) async {
    var query = firestore
        .collection('notifications')
        .where('userId', WhereFilter.equal, userId)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (unreadOnly) {
      query = query.where('isRead', WhereFilter.equal, false);
    }

    final snap = await query.get();

    return snap.docs.map((doc) {
      return NotificationModel.fromMap(doc.data(), doc.id);
    }).toList();
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    await firestore.collection('notifications').doc(notificationId).update({'isRead': true});
  }

  @override
  Future<void> markAllAsRead(String userId) async {
    final snap = await firestore
        .collection('notifications')
        .where('userId', WhereFilter.equal, userId)
        .where('isRead', WhereFilter.equal, false)
        .get();

    // final batch = firestore.batch();
    for (var doc in snap.docs) {
      // batch.update(doc.ref, {'isRead': true});
      doc.ref.update({'isRead': true});
    }
    // await batch.commit();
  }

  @override
  Future<void> delete(String id) async {
    await firestore.collection('notifications').doc(id).delete();
  }
}
