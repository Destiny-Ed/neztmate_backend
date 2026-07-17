import 'package:dart_firebase_admin/firestore.dart';
import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/features/leases/datasource/lease_remote_datasource.dart';
import 'package:neztmate_backend/features/leases/models/lease_settlement_agreement_model.dart';
import 'package:neztmate_backend/features/leases/models/lease_termination_request.dart';
import 'package:neztmate_backend/features/leases/models/leases_model.dart';
import 'package:neztmate_backend/features/units/repository/unit_repo.dart';

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
    final snap = await _leases
        .where('landownerId', WhereFilter.equal, landownerId)
        .where('status', WhereFilter.equal, 'pending payment')
        .get();
    return snap.docs.map((d) => LeaseModel.fromMap(d.data())).toList();
  }

  @override
  Future<List<LeaseModel>> getLeasesByManager(String managerId) async {
    final snap = await _leases
        .where('managerId', WhereFilter.equal, managerId)
        .where('status', WhereFilter.equal, 'pending payment')
        .get();
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
      'status': 'terminated',
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
      monthlyRent: lease.monthlyRent,
      fees: lease.fees,
      status: 'active',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      applicationId: '',
      propertyId: lease.propertyId,
    );

    await createLease(newLease);

    // Terminate old lease
    await _leases.doc(leaseId).update({
      'status': 'transferred',
      'transferStatus': 'approved',
      'transferApprovedBy': approvedBy,
      'transferApprovedAt': DateTime.now().toIso8601String(),
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
      'status': 'pending payment',
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
      status: 'active',
      isRenewed: true,
      renewedAt: DateTime.now(),
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
          .where('status', WhereFilter.equal, 'active')
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
          .where('status', WhereFilter.equal, 'active')
          .where('endDate', WhereFilter.lessThan, now)
          .get();

      int updatedCount = 0;

      for (var doc in snap.docs) {
        await firestore.collection('leases').doc(doc.id).update({
          'status': 'inactive',
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
      'status': 'transferRequested',
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
      'transferStatus': 'rejected',
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

  @override
  Future<Map<String, dynamic>> calculateEarlyTerminationSettlement(
    String leaseId,
    UnitRepository unitRepo,
  ) async {
    final lease = await getLeaseById(leaseId);
    final unit = await unitRepo.getUnitById(lease.unitId); // Get unit for fees

    final now = DateTime.now();
    final totalLeaseDays = lease.endDate.difference(lease.startDate).inDays;
    final remainingDays = lease.endDate.difference(now).inDays.clamp(0, totalLeaseDays);

    final monthlyRent = lease.monthlyRent;
    final dailyRent = monthlyRent / 365;

    // Prorated rent for remaining period
    final proratedRentDue = (dailyRent * remainingDays).roundToDouble();

    // Other fees from unit (service charges, etc.)
    double additionalFeesDue = 0.0;
    if (unit.fees != null) {
      for (var fee in unit.fees!) {
        if (fee.isOneTime == false) {
          // recurring fees
          additionalFeesDue += fee.amount;
        }
      }
    }

    // Penalty for early termination (e.g., 10% of remaining rent)
    double penalty = (proratedRentDue * 0.10).roundToDouble();

    // If tenant provides replacement, waive penalty
    final hasReplacement = lease.transferToTenantId != null;
    if (hasReplacement) {
      penalty = 0.0;
    }

    final netBalanceDueFromTenant = proratedRentDue + additionalFeesDue + penalty;
    final netRefundToTenant = 0.0; // No security deposit

    return {
      'remainingDays': remainingDays,
      'proratedRentDue': proratedRentDue,
      'additionalFeesDue': additionalFeesDue,
      'penalty': penalty,
      'hasReplacement': hasReplacement,
      'netBalanceDueFromTenant': netBalanceDueFromTenant,
      'netRefundToTenant': netRefundToTenant,
      'notes': hasReplacement
          ? 'Penalty waived due to replacement tenant'
          : 'Early termination penalty applied (10% of remaining rent)',
      'recommendation': 'Landlord and tenant should settle directly or through the app.',
    };
  }

  @override
  Future<List<LeaseTerminationRequest>> getTerminationRequests(String userId) async {
    final snap = await firestore
        .collection('leases')
        .where('landownerId', WhereFilter.equal, userId)
        .where('status', WhereFilter.isIn, ['EarlyTerminationRequested', 'TransferRequested'])
        .orderBy('updatedAt', descending: true)
        .get();

    return snap.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return LeaseTerminationRequest.fromMap(data);
    }).toList();
  }

  // SETTLEMENT AGREEMENTS

  @override
  Future<void> proposeSettlement(LeaseSettlementAgreement settlement) async {
    final docRef = firestore.collection('lease_settlements').doc();
    final newSettlement = settlement.copyWith(id: docRef.id);

    await docRef.set(newSettlement.toMap());

    // Link settlement to lease
    await _leases.doc(settlement.leaseId).update({
      'currentSettlementId': newSettlement.id,
      'settlementStatus': 'Proposed',
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> acceptSettlement(String leaseId, String acceptedBy) async {
    // Find latest settlement for this lease
    final snap = await firestore
        .collection('lease_settlements')
        .where('leaseId', WhereFilter.equal, leaseId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) throw NotFoundException('Settlement', leaseId);

    final settlementDoc = snap.docs.first;
    final settlementId = settlementDoc.id;

    await firestore.collection('lease_settlements').doc(settlementId).update({
      'status': 'agreed',
      'agreedAt': DateTime.now().toIso8601String(),
      'agreedBy': acceptedBy,
    });

    // Update lease status
    await _leases.doc(leaseId).update({
      'settlementStatus': 'agreed',
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> disputeSettlement({
    required String leaseId,
    required String disputedBy,
    required String reason,
  }) async {
    final snap = await firestore
        .collection('lease_settlements')
        .where('leaseId', WhereFilter.equal, leaseId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) throw NotFoundException('Settlement', leaseId);

    final settlementDoc = snap.docs.first;
    final settlementId = settlementDoc.id;

    await firestore.collection('lease_settlements').doc(settlementId).update({
      'status': 'disputed',
      'disputedBy': disputedBy,
      'disputeReason': reason,
      'disputedAt': DateTime.now().toIso8601String(),
    });

    await _leases.doc(leaseId).update({
      'settlementStatus': 'disputed',
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> resolveSettlementDispute({
    required String leaseId,
    required String resolvedBy,
    required String resolution, // 'accept', 'reject', 'modify'
    double? finalAmount,
    String? notes,
  }) async {
    final snap = await firestore
        .collection('lease_settlements')
        .where('leaseId', WhereFilter.equal, leaseId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) throw NotFoundException('Settlement', leaseId);

    final settlementDoc = snap.docs.first;
    final settlementId = settlementDoc.id;

    await firestore.collection('lease_settlements').doc(settlementId).update({
      'status': resolution == 'accept' ? 'Agreed' : 'Rejected',
      'resolvedBy': resolvedBy,
      'resolution': resolution,
      'finalAmount': finalAmount,
      'resolutionNotes': notes,
      'resolvedAt': DateTime.now().toIso8601String(),
    });

    await _leases.doc(leaseId).update({
      'settlementStatus': resolution == 'accept' ? 'Agreed' : 'Rejected',
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> confirmPaymentAndActivate(String leaseId, String confirmedBy) async {
    await _leases.doc(leaseId).update({
      'status': 'active',
      'paymentConfirmedAt': DateTime.now().toIso8601String(),
      'paymentConfirmedBy': confirmedBy,
      'updatedAt': DateTime.now().toIso8601String(),
    });

    print('✅ Lease activated and tenant added to unit after payment confirmation');
  }
}
