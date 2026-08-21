import 'package:neztmate_backend/features/history/model/user_history_model.dart';

abstract class HistoryRepository {
  Future<HistoryEntryModel> createHistoryEntry(HistoryEntryModel entry);

  Future<List<HistoryEntryModel>> getHistoryByUser(
    String userId, {
    String? partnerId,
    int limit = 50,
    DateTime? startAfter,
    String? typeFilter,
  });

  Future<List<HistoryEntryModel>> getHistoryByRelatedId(
    String relatedId,
    String relatedCollection, {
    String? partnerId,
  });

  Future<void> deleteOldEntries(String userId, {String? partnerId, int olderThanDays = 365});
}
