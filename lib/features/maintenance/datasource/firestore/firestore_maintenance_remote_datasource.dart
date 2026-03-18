import 'package:dart_firebase_admin/firestore.dart';
import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/features/maintenance/datasource/maintenance_remote_datasource.dart';
import 'package:neztmate_backend/features/maintenance/models/maintenance.dart';

class FirestoreMaintenanceRequestDataSource implements MaintenanceRequestRemoteDataSource {
  final Firestore firestore;

  FirestoreMaintenanceRequestDataSource(this.firestore);

  CollectionReference get _requests => firestore.collection('maintenance_requests');

  @override
  Future<MaintenanceRequestModel> createRequest(MaintenanceRequestModel request) async {
    final docRef = _requests.doc(request.id.isNotEmpty ? request.id : null);
    final newRequest = request.copyWith(id: docRef.id);
    await docRef.set(newRequest.toMap());
    return newRequest;
  }

  @override
  Future<MaintenanceRequestModel> getRequestById(String id) async {
    final doc = await _requests.doc(id).get();
    if (!doc.exists) throw NotFoundException('Maintenance request', id);
    return MaintenanceRequestModel.fromMap(doc.data() as Map<String, dynamic>, id);
  }

  @override
  Future<List<MaintenanceRequestModel>> getRequestsByTenant(String tenantId) async {
    final snap = await _requests.where('tenantId', WhereFilter.equal, tenantId).get();
    return snap.docs.map((d) => MaintenanceRequestModel.fromMap(d.data(), d.id)).toList();
  }

  @override
  Future<List<MaintenanceRequestModel>> getRequestsByUnit(String unitId) async {
    final snap = await _requests.where('unitId', WhereFilter.equal, unitId).get();
    return snap.docs.map((d) => MaintenanceRequestModel.fromMap(d.data(), d.id)).toList();
  }

  @override
  Future<List<MaintenanceRequestModel>> getRequestsByManager(String managerId) async {
    // Example: manager sees requests assigned to them or in their properties
    final snap = await _requests.where('assignedBy', WhereFilter.equal, managerId).get();
    return snap.docs.map((d) => MaintenanceRequestModel.fromMap(d.data(), d.id)).toList();
  }

  @override
  Future<void> updateRequest(MaintenanceRequestModel request) async {
    await _requests.doc(request.id).update(request.toMap());
  }

  @override
  Future<void> deleteRequest(String id) async {
    await _requests.doc(id).delete();
  }

  @override
  Future<void> assignRequest(String id, String artisanId) async {
    await _requests.doc(id).update({
      'assignedTo': artisanId,
      'status': 'Assigned',
      'assignedAt': DateTime.now().toIso8601String(),
    });
  }
}
