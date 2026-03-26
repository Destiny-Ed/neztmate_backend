import 'package:neztmate_backend/features/tasks/datasource/task_remote_datasource.dart';
import 'package:neztmate_backend/features/tasks/models/task_model.dart';
import 'package:neztmate_backend/features/tasks/repository/task_repo.dart';

class TaskRepositoryImpl implements TaskRepository {
  final TaskRemoteDataSource dataSource;

  TaskRepositoryImpl(this.dataSource);

  @override
  Future<TaskModel> createTask(TaskModel task) async {
    return await dataSource.createTask(task);
  }

  @override
  Future<TaskModel> getTaskById(String id) async {
    return await dataSource.getTaskById(id);
  }

  @override
  Future<List<TaskModel>> getTasksByRequest(String requestId) async {
    return await dataSource.getTasksByRequest(requestId);
  }

  @override
  Future<List<TaskModel>> getTasksByArtisan(String artisanId) async {
    return await dataSource.getTasksByArtisan(artisanId);
  }

  @override
  Future<List<TaskModel>> getTasksByManager(String managerId) async {
    return await dataSource.getTasksByManager(managerId);
  }

  @override
  Future<void> updateTask(TaskModel task) async {
    await dataSource.updateTask(task);
  }

  @override
  Future<void> completeTask(String id, String summary, double? cost) async {
    await dataSource.completeTask(id, summary, cost);
  }
}
