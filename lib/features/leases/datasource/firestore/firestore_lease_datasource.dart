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
  Future<List<LeaseModel>> getLeasesByTenant(String tenantId) async {
    final snap = await _leases.where('tenantId', WhereFilter.equal, tenantId).get();
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
  Future<void> approveLeaseTransfer(String leaseId, String approvedBy) async {
    final lease = await getLeaseById(leaseId);

    if (lease.transferToTenantId == null) throw Exception('No transfer request');

    // Create new lease for replacement tenant
    final newLease = LeaseModel(
      id: '',
      unitId: lease.unitId,
      tenantId: lease.transferToTenantId!,
      landownerId: lease.landownerId,
      managerId: lease.managerId,
      startDate: DateTime.now(),
      endDate: lease.endDate,
      yearlyRent: lease.yearlyRent,
      fees: lease.fees,
      status: 'Active',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      applicationId: '',
      propertyId: lease.propertyId,
    );

    await createLease(newLease);

    // Terminate old lease
    await _leases.doc(leaseId).update({
      'status': 'Transferred',
      'transferStatus': 'Approved',
      'approvedBy': approvedBy,
      'approvedAt': DateTime.now().toIso8601String(),
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
  Future<void> updateLeaseStatus(String leaseId, String status) async {
    await firestore.collection('leases').doc(leaseId).update({
      'status': status,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<LeaseModel> renewLeaseAfterPayment(String leaseId) async {
    final lease = await getLeaseById(leaseId);

    final newEndDate = lease.endDate.add(const Duration(days: 365)); // 1 year renewal

    final renewedLease = lease.copyWith(
      id: "",
      startDate: lease.endDate,
      endDate: newEndDate,
      nextDueDate: lease.endDate.add(const Duration(days: 365)), // next rent due in 1 year
      status: 'Active',
      isRenewed: true,
      previousLeaseId: leaseId,
      updatedAt: DateTime.now(),
      createdAt: DateTime.now(),
    );

    return await createLease(renewedLease);
  }

  @override
  Future<List<LeaseModel>> getAllActiveLeases() async {
    try {
      final snap = await firestore
          .collection('leases')
          .where('status', WhereFilter.equal, 'Active')
          .orderBy('endDate', descending: false) // Earliest ending first
          .get();

      return snap.docs.map((doc) => LeaseModel.fromMap(doc.data() as Map<String, dynamic>)).toList();
    } catch (e) {
      print('Error fetching all active leases: $e');
      return [];
    }
  }

  @override
  Future<List<LeaseModel>> getExpiringLeases({int withinDays = 5}) async {
    try {
      final thresholdDate = DateTime.now().add(Duration(days: withinDays));

      final snap = await firestore
          .collection('leases')
          .where('status', WhereFilter.equal, 'Active')
          .where('endDate', WhereFilter.lessThanOrEqual, thresholdDate.toIso8601String())
          .orderBy('endDate', descending: false)
          .get();

      return snap.docs.map((doc) => LeaseModel.fromMap(doc.data() as Map<String, dynamic>)).toList();
    } catch (e) {
      print('Error fetching expiring leases: $e');
      return [];
    }
  }

  @override
  Future<int> updateExpiredLeasesToInactive() async {
    try {
      final now = DateTime.now().toIso8601String();
      final snap = await firestore
          .collection('leases')
          .where('status', WhereFilter.equal, 'Active')
          .where('endDate', WhereFilter.lessThan, now)
          .get();

      int updatedCount = 0;

      for (var doc in snap.docs) {
        await firestore.collection('leases').doc(doc.id).update({
          'status': 'Inactive',
          'updatedAt': DateTime.now().toIso8601String(),
        });
        updatedCount++;
      }

      print('Updated $updatedCount leases to Inactive');
      return updatedCount;
    } catch (e) {
      print('Error updating expired leases: $e');
      return 0;
    }
  }

  @override
  Future<void> requestLeaseTransfer({
    required String leaseId,
    required String newTenantId,
    required String reason,
  }) async {
    await _leases.doc(leaseId).update({
      'status': 'TransferRequested',
      'transferToTenantId': newTenantId,
      'transferStatus': 'Pending',
      'transferReason': reason,
      'transferRequestedAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> rejectLeaseTransfer(String leaseId, String rejectedBy, String reason) async {
    await _leases.doc(leaseId).update({
      'transferStatus': 'Rejected',
      'rejectedBy': rejectedBy,
      'rejectionReason': reason,
      'rejectedAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> requestEarlyTermination({
    required String leaseId,
    required String reason,
    required String requestedBy,
  }) async {
    await _leases.doc(leaseId).update({
      'status': 'EarlyTerminationRequested',
      'terminationReason': reason,
      'terminationRequestedBy': requestedBy,
      'terminationRequestedAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }
}
