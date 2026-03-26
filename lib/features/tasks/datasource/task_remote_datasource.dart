import 'package:neztmate_backend/features/tasks/models/task_model.dart';

abstract class TaskRemoteDataSource {
  Future<TaskModel> createTask(TaskModel task);
  Future<TaskModel> getTaskById(String id);
  Future<List<TaskModel>> getTasksByRequest(String requestId);
  Future<List<TaskModel>> getTasksByArtisan(String artisanId);
  Future<List<TaskModel>> getTasksByManager(String managerId);
  Future<void> updateTask(TaskModel task);
  Future<void> completeTask(String id, String summary, double? cost);
}
