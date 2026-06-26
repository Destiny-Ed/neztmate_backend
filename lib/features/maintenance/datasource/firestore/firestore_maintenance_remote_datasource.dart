import 'package:dart_firebase_admin/firestore.dart';
import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/features/maintenance/datasource/maintenance_remote_datasource.dart';
import 'package:neztmate_backend/features/maintenance/models/maintenance_request.dart';
import 'package:neztmate_backend/features/maintenance/models/maintenance_task.dart';

class FirestoreMaintenanceDataSource implements MaintenanceRemoteDataSource {
  final Firestore firestore;

  FirestoreMaintenanceDataSource(this.firestore);

  CollectionReference get _requests => firestore.collection('maintenance_requests');
  CollectionReference get _tasks => firestore.collection('maintenance_tasks');

  // REQUESTS
  @override
  Future<MaintenanceRequestModel> createRequest(MaintenanceRequestModel request) async {
    final docRef = _requests.doc();
    final newRequest = request.copyWith(id: docRef.id);
    await docRef.set(newRequest.toMap());
    return newRequest;
  }

  @override
  Future<MaintenanceRequestModel> getRequestById(String id) async {
    final doc = await _requests.doc(id).get();
    if (!doc.exists) throw NotFoundException('MaintenanceRequest', id);
    return MaintenanceRequestModel.fromMap(doc.data() as Map<String, dynamic>);
  }

  @override
  Future<List<MaintenanceRequestModel>> getRequestsByTenant(String tenantId) async {
    final snap = await _requests
        .where('tenantId', WhereFilter.equal, tenantId)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => MaintenanceRequestModel.fromMap(d.data())).toList();
  }

  @override
  Future<List<MaintenanceRequestModel>> getRequestsByProperty(String propertyId) async {
    final snap = await _requests
        .where('propertyId', WhereFilter.equal, propertyId)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => MaintenanceRequestModel.fromMap(d.data())).toList();
  }

  @override
  Future<List<MaintenanceRequestModel>> getAllRequestsForManagerOrLandowner(String userId) async {
    // This is simplified - in production, you should filter by properties owned/managed
    final snap = await _requests.orderBy('createdAt', descending: true).get();
    return snap.docs.map((d) => MaintenanceRequestModel.fromMap(d.data())).toList();
  }

  // TASKS
  @override
  Future<MaintenanceTaskModel> createTask(MaintenanceTaskModel task) async {
    final docRef = _tasks.doc();
    final newTask = task.copyWith(id: docRef.id);
    await docRef.set(newTask.toMap());
    return newTask;
  }

  @override
  Future<MaintenanceTaskModel> getTaskById(String taskId) async {
    final doc = await _tasks.doc(taskId).get();
    if (!doc.exists) throw NotFoundException('MaintenanceTask', taskId);
    return MaintenanceTaskModel.fromMap(doc.data() as Map<String, dynamic>);
  }

  @override
  Future<List<MaintenanceTaskModel>> getTasksByRequest(String requestId) async {
    final snap = await _tasks
        .where('maintenanceRequestId', WhereFilter.equal, requestId)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => MaintenanceTaskModel.fromMap(d.data())).toList();
  }

  @override
  Future<List<MaintenanceTaskModel>> getTasksByArtisan(String artisanId) async {
    final snap = await _tasks
        .where('artisanId', WhereFilter.equal, artisanId)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => MaintenanceTaskModel.fromMap(d.data())).toList();
  }

  @override
  Future<void> acceptTask(String taskId, String artisanId) async {
    await _tasks.doc(taskId).update({'status': 'Accepted', 'updatedAt': DateTime.now().toIso8601String()});
  }

  @override
  Future<void> declineTask(String taskId, String artisanId) async {
    await _tasks.doc(taskId).update({
      'status': 'Declined',
      'updatedAt': DateTime.now().toIso8601String(),
      'startedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> updateTask(MaintenanceTaskModel task) async {
    await _tasks.doc(task.id).update(task.toMap());
  }

  @override
  Future<void> completeTask(String taskId, String summary, double? actualCost) async {
    await _tasks.doc(taskId).update({
      'status': 'Completed',
      'summary': summary,
      'actualCost': actualCost,
      'completedAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<List<MaintenanceTaskModel>> getActiveTasksByArtisanAndProperty({
    required String artisanId,
    required String propertyId,
  }) async {
    try {
      final snap = await _tasks
          .where('artisanId', WhereFilter.equal, artisanId)
          .where('propertyId', WhereFilter.equal, propertyId)
          .where('status', WhereFilter.notEqual, 'Cancelled')
          .orderBy('createdAt', descending: true)
          .get();

      return snap.docs.map((d) => MaintenanceTaskModel.fromMap(d.data() as Map<String, dynamic>)).toList();
    } catch (e, s) {
      print('Error fetching active tasks for artisan on property: $e, stack : $s');
      return [];
    }
  }
}
