import 'package:dart_firebase_admin/firestore.dart';
import 'package:neztmate_backend/features/history/datasource/history_remote_datasource.dart';
import 'package:neztmate_backend/features/history/model/user_history_model.dart';

class FirestoreHistoryDataSource implements HistoryRemoteDataSource {
  final Firestore firestore;

  FirestoreHistoryDataSource(this.firestore);

  @override
  Future<HistoryEntryModel> create(HistoryEntryModel entry) async {
    // Create a new document reference (auto-generated ID)
    final collectionRef = firestore.collection('users').doc(entry.userId).collection('history');
    final docRef = collectionRef.doc(); // auto ID

    final newEntry = entry.copyWith(id: docRef.id);

    // Write the document
    await docRef.set(newEntry.toMap());

    return newEntry;
  }

  @override
  Future<List<HistoryEntryModel>> getByUser(String userId, {int limit = 30, DateTime? startAfter}) async {
    var query = firestore
        .collection('users')
        .doc(userId)
        .collection('history')
        .orderBy('timestamp', descending: true)
        .limit(limit);

    if (startAfter != null) {
      // startAfter takes the value of the last field in orderBy
      query = query.startAfter([startAfter.toIso8601String()]);
    }

    final snap = await query.get();

    return snap.docs.map((doc) {
      return HistoryEntryModel.fromMap(doc.data(), doc.id);
    }).toList();
  }

  @override
  Future<List<HistoryEntryModel>> getByRelatedId(String relatedId, String relatedCollection) async {
    final snap = await firestore
        .collectionGroup('history')
        .where('relatedId', WhereFilter.equal, relatedId)
        .where('relatedCollection', WhereFilter.equal, relatedCollection)
        .orderBy('timestamp', descending: true)
        .limit(20)
        .get();

    return snap.docs.map((doc) {
      return HistoryEntryModel.fromMap(doc.data(), doc.id);
    }).toList();
  }

  @override
  Future<void> deleteOld(String userId, {int olderThanDays = 365}) async {
    final threshold = DateTime.now().subtract(Duration(days: olderThanDays));

    // Get documents older than threshold
    final snap = await firestore
        .collection('users')
        .doc(userId)
        .collection('history')
        .where('timestamp', WhereFilter.lessThan, threshold.toIso8601String())
        .get();

    // Batch delete using WriteBatch
    // final batch = firestore.batch();

    // for (final doc in snap.docs) {
    //   batch.delete(doc.ref); // .ref is the DocumentReference
    // }

    // Commit the batch
    // await batch.commit();

    // Delete one by one (no batch)
    for (final doc in snap.docs) {
      await doc.ref.delete();
    }
  }
}
