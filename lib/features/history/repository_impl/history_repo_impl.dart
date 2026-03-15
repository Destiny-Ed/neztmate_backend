import 'package:neztmate_backend/features/history/datasource/history_remote_datasource.dart';
import 'package:neztmate_backend/features/history/model/user_history_model.dart';
import 'package:neztmate_backend/features/history/repository/user_history_repo.dart';

class HistoryRepositoryImpl implements HistoryRepository {
  final HistoryRemoteDataSource dataSource;
  HistoryRepositoryImpl(this.dataSource);

  @override
  Future<HistoryEntryModel> create(HistoryEntryModel entry) => dataSource.create(entry);

  @override
  Future<List<HistoryEntryModel>> getByUser(String userId, {int limit = 30}) =>
      dataSource.getByUser(userId, limit: limit);
}
