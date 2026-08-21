import 'package:dart_firebase_admin/firestore.dart';
import 'package:neztmate_backend/features/history/datasource/history_remote_datasource.dart';
import 'package:neztmate_backend/features/history/model/user_history_model.dart';

class FirestoreHistoryDataSource implements HistoryRemoteDataSource {
  final Firestore firestore;

  FirestoreHistoryDataSource(this.firestore);

  CollectionReference _userHistory(String userId) =>
      firestore.collection('users').doc(userId).collection('history');

  @override
  Future<HistoryEntryModel> create(HistoryEntryModel entry) async {
    final collectionRef = _userHistory(entry.userId);
    final docRef = collectionRef.doc();
    final newEntry = entry.copyWith(id: docRef.id);
    await docRef.set(newEntry.toMap());
    return newEntry;
  }

  @override
  Future<List<HistoryEntryModel>> getByUser(
    String userId, {
    String? partnerId,
    int limit = 30,
    DateTime? startAfter,
    String? typeFilter,
  }) async {
    Query query = _userHistory(userId).orderBy('timestamp', descending: true);

    if (partnerId != null && partnerId.isNotEmpty) {
      query = query.where('partnerId', WhereFilter.equal, partnerId);
    }

    if (typeFilter != null && typeFilter.isNotEmpty) {
      query = query.where('type', WhereFilter.equal, typeFilter);
    }

    if (startAfter != null) {
      query = query.startAfter([startAfter.toIso8601String()]);
    }

    final snap = await query.limit(limit).get();

    return snap.docs.map((doc) {
      return HistoryEntryModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }).toList();
  }

  @override
  Future<List<HistoryEntryModel>> getByRelatedId(
    String relatedId,
    String relatedCollection, {
    String? partnerId,
  }) async {
    Query query = firestore
        .collectionGroup('history')
        .where('relatedId', WhereFilter.equal, relatedId)
        .where('relatedCollection', WhereFilter.equal, relatedCollection);

    if (partnerId != null && partnerId.isNotEmpty) {
      query = query.where('partnerId', WhereFilter.equal, partnerId);
    }

    final snap = await query.orderBy('timestamp', descending: true).limit(20).get();

    return snap.docs.map((doc) {
      return HistoryEntryModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }).toList();
  }

  @override
  Future<void> deleteOld(String userId, {String? partnerId, int olderThanDays = 365}) async {
    final threshold = DateTime.now().subtract(Duration(days: olderThanDays));

    Query query = _userHistory(userId).where('timestamp', WhereFilter.lessThan, threshold.toIso8601String());

    if (partnerId != null && partnerId.isNotEmpty) {
      query = query.where('partnerId', WhereFilter.equal, partnerId);
    }

    final snap = await query.get();

    for (final doc in snap.docs) {
      await doc.ref.delete();
    }
  }
}
