import 'package:dart_firebase_admin/firestore.dart';
import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/features/maintenance/datasource/maintenance_remote_datasource.dart';
import 'package:neztmate_backend/features/maintenance/models/maintenance_request.dart';
import 'package:neztmate_backend/features/maintenance/models/maintenance_task.dart';
import 'package:neztmate_backend/features/properties/repository/property_repo.dart';

class FirestoreMaintenanceDataSource implements MaintenanceRemoteDataSource {
  final Firestore firestore;
  final PropertyRepository propertyRepository;

  FirestoreMaintenanceDataSource(this.firestore, this.propertyRepository);

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
  Future<List<MaintenanceRequestModel>> getRequestsByTenant(String tenantId, {String? partnerId}) async {
    var query = _requests.where('tenantId', WhereFilter.equal, tenantId);
    if (partnerId != null && partnerId.isNotEmpty) {
      query = query.where('partnerId', WhereFilter.equal, partnerId);
    }
    final snap = await query.orderBy('createdAt', descending: true).get();
    return snap.docs.map((d) => MaintenanceRequestModel.fromMap(d.data() as Map<String, dynamic>)).toList();
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
  Future<List<MaintenanceRequestModel>> getAllRequestsForManagerOrLandowner(
    String userId, {
    String? partnerId,
    String? role,
  }) async {
    final r = (role ?? '').toLowerCase();

    List properties;
    if (r == 'manager') {
      properties = await propertyRepository.getPropertiesByManager(userId, partnerId: partnerId);
    } else {
      // landowner default
      properties = await propertyRepository.getPropertiesByLandowner(userId, partnerId: partnerId);
    }

    if (properties.isEmpty) return [];

    final propertyIds = properties.map((p) => p.id as String).toList();
    final results = <MaintenanceRequestModel>[];

    for (var i = 0; i < propertyIds.length; i += 30) {
      final batch = propertyIds.skip(i).take(30).toList();
      var query = _requests.where('propertyId', WhereFilter.isIn, batch);
      if (partnerId != null && partnerId.isNotEmpty) {
        query = query.where('partnerId', WhereFilter.equal, partnerId);
      }
      final snap = await query.orderBy('createdAt', descending: true).get();
      results.addAll(snap.docs.map((d) => MaintenanceRequestModel.fromMap(d.data() as Map<String, dynamic>)));
    }

    results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return results;
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
  Future<List<MaintenanceTaskModel>> getTasksByArtisan(String artisanId, {String? partnerId}) async {
    var query = _tasks.where('artisanId', WhereFilter.equal, artisanId);
    if (partnerId != null && partnerId.isNotEmpty) {
      query = query.where('partnerId', WhereFilter.equal, partnerId);
    }
    final snap = await query.orderBy('createdAt', descending: true).get();
    return snap.docs.map((d) => MaintenanceTaskModel.fromMap(d.data() as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> acceptTask(String taskId, String artisanId) async {
    await _tasks.doc(taskId).update({
      'status': 'Accepted',
      'startedAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
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

  @override
  Future<String> calculateRequestStatus(String requestId) async {
    final tasks = await getTasksByRequest(requestId);

    if (tasks.isEmpty) return 'Pending';

    final hasInProgress = tasks.any((t) => t.status == 'InProgress');
    final hasCompleted = tasks.any((t) => t.status == 'Completed');
    final allCompleted = tasks.every((t) => t.status == 'Completed');
    final hasPending = tasks.any((t) => t.status == 'Pending' || t.status == 'Accepted');

    if (allCompleted) return 'Completed';
    if (hasInProgress) return 'InProgress';
    if (hasPending) return 'InProgress'; // or 'Pending' based on your preference
    return 'Pending';
  }

  @override
  Future<void> updateRequestStatus(String requestId, String newStatus) async {
    await firestore.collection('maintenance_requests').doc(requestId).update({
      'status': newStatus,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }
}
