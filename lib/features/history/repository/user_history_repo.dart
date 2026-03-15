import 'package:neztmate_backend/features/history/model/user_history_model.dart';

abstract class HistoryRepository {
  /// Logs a new history entry for a user
  Future<HistoryEntryModel> createHistoryEntry(HistoryEntryModel entry);

  /// Get recent history for a specific user
  Future<List<HistoryEntryModel>> getHistoryByUser(
    String userId, {
    int limit = 50,
    DateTime? startAfter,
    String? typeFilter, // optional: e.g. only "lease_signed"
  });

  /// Get history entries related to a specific entity (e.g. all actions on a lease)
  Future<List<HistoryEntryModel>> getHistoryByRelatedId(String relatedId, String relatedCollection);

  /// Optional: delete old entries (cleanup job)
  Future<void> deleteOldEntries(String userId, {int olderThanDays = 365});
}
