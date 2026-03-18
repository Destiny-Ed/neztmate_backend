import 'package:neztmate_backend/features/history/model/user_history_model.dart';

abstract class HistoryRemoteDataSource {
  Future<HistoryEntryModel> create(HistoryEntryModel entry);
  Future<List<HistoryEntryModel>> getByUser(String userId, {int limit = 30, DateTime? startAfter});
  Future<List<HistoryEntryModel>> getByRelatedId(String relatedId, String relatedCollection);
  Future<void> deleteOld(String userId, {int olderThanDays = 365});
}
