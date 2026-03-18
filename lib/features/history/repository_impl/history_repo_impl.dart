import 'package:neztmate_backend/features/history/datasource/history_remote_datasource.dart';
import 'package:neztmate_backend/features/history/model/user_history_model.dart';
import 'package:neztmate_backend/features/history/repository/user_history_repo.dart';

class HistoryRepositoryImpl implements HistoryRepository {
  final HistoryRemoteDataSource dataSource;

  HistoryRepositoryImpl(this.dataSource);

  @override
  Future<HistoryEntryModel> createHistoryEntry(HistoryEntryModel entry) => dataSource.create(entry);

  @override
  Future<List<HistoryEntryModel>> getHistoryByUser(
    String userId, {
    int limit = 50,
    DateTime? startAfter,
    String? typeFilter,
  }) async {
    // typeFilter can be added later if datasource supports it
    return dataSource.getByUser(userId, limit: limit, startAfter: startAfter);
  }

  @override
  Future<List<HistoryEntryModel>> getHistoryByRelatedId(String relatedId, String relatedCollection) =>
      dataSource.getByRelatedId(relatedId, relatedCollection);

  @override
  Future<void> deleteOldEntries(String userId, {int olderThanDays = 365}) =>
      dataSource.deleteOld(userId, olderThanDays: olderThanDays);
}
