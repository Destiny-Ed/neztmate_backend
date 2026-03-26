import 'package:dart_firebase_admin/firestore.dart';
import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/features/tasks/datasource/task_remote_datasource.dart';
import 'package:neztmate_backend/features/tasks/models/task_model.dart';

class FirestoreTaskDataSource implements TaskRemoteDataSource {
  final Firestore firestore;

  FirestoreTaskDataSource(this.firestore);

  CollectionReference get _tasks => firestore.collection('tasks');

  @override
  Future<TaskModel> createTask(TaskModel task) async {
    final docRef = _tasks.doc(task.id.isNotEmpty ? task.id : null);
    final newTask = task.copyWith(id: docRef.id);
    await docRef.set(newTask.toMap());
    return newTask;
  }

  @override
  Future<TaskModel> getTaskById(String id) async {
    final doc = await _tasks.doc(id).get();
    if (!doc.exists) {
      throw NotFoundException('Task', id);
    }
    return TaskModel.fromMap(doc.data() as Map<String, dynamic>, id);
  }

  @override
  Future<List<TaskModel>> getTasksByRequest(String requestId) async {
    final snap = await _tasks.where('requestId', WhereFilter.equal, requestId).get();
    return snap.docs.map((d) => TaskModel.fromMap(d.data(), d.id)).toList();
  }

  @override
  Future<List<TaskModel>> getTasksByArtisan(String artisanId) async {
    final snap = await _tasks.where('artisanId', WhereFilter.equal, artisanId).get();
    return snap.docs.map((d) => TaskModel.fromMap(d.data(), d.id)).toList();
  }

  @override
  Future<List<TaskModel>> getTasksByManager(String managerId) async {
    final snap = await _tasks.where('managerId', WhereFilter.equal, managerId).get();
    return snap.docs.map((d) => TaskModel.fromMap(d.data(), d.id)).toList();
  }

  @override
  Future<void> updateTask(TaskModel task) async {
    await _tasks.doc(task.id).update(task.toMap());
  }

  @override
  Future<void> completeTask(String id, String summary, double? cost) async {
    await _tasks.doc(id).update({
      'status': 'Completed',
      'workSummary': summary,
      'totalCost': cost,
      'completedTime': DateTime.now().toIso8601String(),
    });
  }
}
