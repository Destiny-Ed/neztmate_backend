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
    String? partnerId,
    int limit = 50,
    DateTime? startAfter,
    String? typeFilter,
  }) => dataSource.getByUser(
    userId,
    partnerId: partnerId,
    limit: limit,
    startAfter: startAfter,
    typeFilter: typeFilter,
  );

  @override
  Future<List<HistoryEntryModel>> getHistoryByRelatedId(
    String relatedId,
    String relatedCollection, {
    String? partnerId,
  }) => dataSource.getByRelatedId(relatedId, relatedCollection, partnerId: partnerId);

  @override
  Future<void> deleteOldEntries(String userId, {String? partnerId, int olderThanDays = 365}) =>
      dataSource.deleteOld(userId, partnerId: partnerId, olderThanDays: olderThanDays);
}
