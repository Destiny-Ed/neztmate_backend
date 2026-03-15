import 'package:neztmate_backend/features/history/model/user_history_model.dart';

abstract class HistoryRemoteDataSource {
  Future<HistoryEntryModel> create(HistoryEntryModel entry);
  Future<List<HistoryEntryModel>> getByUser(String userId, {int limit = 30});
}
