import 'package:dart_firebase_admin/firestore.dart';
import 'package:neztmate_backend/features/history/datasource/history_remote_datasource.dart';
import 'package:neztmate_backend/features/history/model/user_history_model.dart';

class FirestoreHistoryDataSource implements HistoryRemoteDataSource {
  final Firestore firestore;
  FirestoreHistoryDataSource(this.firestore);

  @override
  Future<HistoryEntryModel> create(HistoryEntryModel entry) async {
    final docRef = firestore.collection('users').doc(entry.userId).collection('history').doc();

    final newEntry = entry.copyWith(id: docRef.id);
    await docRef.set(newEntry.toMap());
    return newEntry;
  }

  @override
  Future<List<HistoryEntryModel>> getByUser(String userId, {int limit = 30}) async {
    final snap = await firestore
        .collection('users')
        .doc(userId)
        .collection('history')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    return snap.docs.map((d) => HistoryEntryModel.fromMap(d.data(), d.id)).toList();
  }
}
