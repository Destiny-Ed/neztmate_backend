import 'package:neztmate_backend/features/history/model/user_history_model.dart';

abstract class HistoryRemoteDataSource {
  Future<HistoryEntryModel> create(HistoryEntryModel entry);

  Future<List<HistoryEntryModel>> getByUser(
    String userId, {
    String? partnerId,
    int limit = 30,
    DateTime? startAfter,
    String? typeFilter,
  });

  Future<List<HistoryEntryModel>> getByRelatedId(
    String relatedId,
    String relatedCollection, {
    String? partnerId,
  });

  Future<void> deleteOld(String userId, {String? partnerId, int olderThanDays = 365});
}
