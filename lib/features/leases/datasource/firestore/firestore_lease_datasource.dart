import 'package:dart_firebase_admin/firestore.dart';
import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/features/leases/datasource/lease_remote_datasource.dart';
import 'package:neztmate_backend/features/leases/models/leases_model.dart';

class FirestoreLeaseDataSource implements LeaseRemoteDataSource {
  final Firestore firestore;

  FirestoreLeaseDataSource(this.firestore);

  CollectionReference get _leases => firestore.collection('leases');

  @override
  Future<LeaseModel> createLease(LeaseModel lease) async {
    final docRef = _leases.doc(lease.id.isEmpty ? null : lease.id);
    await docRef.set(lease.toMap());
    return lease.copyWith(id: docRef.id);
  }

  @override
  Future<LeaseModel> getLeaseById(String id) async {
    final doc = await _leases.doc(id).get();
    if (!doc.exists) throw NotFoundException('Lease', id);
    return LeaseModel.fromMap(doc.data() as Map<String, dynamic>);
  }

  @override
  Future<List<LeaseModel>> getActiveLeasesByTenant(String tenantId) async {
    final snap = await _leases
        .where('tenantId', WhereFilter.equal, tenantId)
        .where('status', WhereFilter.equal, 'Active')
        .get();
    return snap.docs.map((d) => LeaseModel.fromMap(d.data())).toList();
  }

  @override
  Future<List<LeaseModel>> getLeasesByLandowner(String landownerId) async {
    final snap = await _leases.where('landownerId', WhereFilter.equal, landownerId).get();
    return snap.docs.map((d) => LeaseModel.fromMap(d.data())).toList();
  }

  @override
  Future<List<LeaseModel>> getLeasesByUnit(String unitId) async {
    final snap = await _leases.where('unitId', WhereFilter.equal, unitId).get();
    return snap.docs.map((d) => LeaseModel.fromMap(d.data())).toList();
  }

  @override
  Future<void> updateLease(LeaseModel lease) async {
    await _leases.doc(lease.id).update(lease.toMap());
  }

  @override
  Future<void> terminateLease(String id, String reason, String terminatedBy) async {
    await firestore.collection('leases').doc(id).update({
      'status': 'Terminated',
      'terminationReason': reason,
      'terminatedAt': DateTime.now().toIso8601String(),
      'terminatedBy': terminatedBy,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<LeaseModel> getLeaseByApplicationId(String applicationId) async {
    final snap = await firestore
        .collection('leases')
        .where('applicationId', WhereFilter.equal, applicationId)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) throw NotFoundException('Lease', 'application:$applicationId');

    final doc = snap.docs.first;
    return LeaseModel.fromMap(doc.data() as Map<String, dynamic>);
  }

  @override
  Future<void> markLeaseAsSigned(String leaseId, String signedPdfUrl, String signedBy) async {
    await firestore.collection('leases').doc(leaseId).update({
      'signedAgreementPdfUrl': signedPdfUrl,
      'signedAt': DateTime.now().toIso8601String(),
      'signedBy': signedBy,
      'status': 'Pending Payment',
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> markLeaseAsActive(String leaseId) async {
    await firestore.collection('leases').doc(leaseId).update({
      'status': 'Active',
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  
}
