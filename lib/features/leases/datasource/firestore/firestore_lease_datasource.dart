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

  //  BASIC CRUD

  @override
  Future<LeaseModel> createLease(LeaseModel lease) async {
    final docRef = _leases.doc(lease.id.isEmpty ? null : lease.id);
    await docRef.set(lease.toMap());
    return lease.copyWith(id: docRef.id);
  }

  @override
  Future<LeaseModel> createManualLease(LeaseModel lease) async {
    final docRef = _leases.doc();
    final newLease = lease.copyWith(id: docRef.id);
    await docRef.set(newLease.toMap());
    return newLease;
  }

  @override
  Future<LeaseModel> getLeaseById(String id) async {
    final doc = await _leases.doc(id).get();
    if (!doc.exists) throw NotFoundException('Lease', id);
    return LeaseModel.fromMap(doc.data() as Map<String, dynamic>);
  }

  @override
  Future<LeaseModel> getLeaseByApplicationId(String applicationId) async {
    final snap = await _leases.where('applicationId', WhereFilter.equal, applicationId).limit(1).get();

    if (snap.docs.isEmpty) {
      throw NotFoundException('Lease', 'application:$applicationId');
    }

    return LeaseModel.fromMap(snap.docs.first.data() as Map<String, dynamic>);
  }

  @override
  Future<void> updateLease(LeaseModel lease) async {
    await _leases.doc(lease.id).update(lease.toMap());
  }

  @override
  Future<void> updateLeaseStatus(String leaseId, String status) async {
    await _leases.doc(leaseId).update({'status': status, 'updatedAt': DateTime.now().toIso8601String()});
  }

  //  QUERIES

  @override
  Future<List<LeaseModel>> getActiveLeasesByTenant(String tenantId) async {
    final snap = await _leases
        .where('tenantId', WhereFilter.equal, tenantId)
        .where('status', WhereFilter.equal, 'active')
        .get();
    return snap.docs.map((d) => LeaseModel.fromMap(d.data() as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<LeaseModel>> getLeasesByTenant(String tenantId) async {
    final snap = await _leases.where('tenantId', WhereFilter.equal, tenantId).get();
    return snap.docs.map((d) => LeaseModel.fromMap(d.data() as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<LeaseModel>> getLeasesByLandowner(String landownerId) async {
    final snap = await _leases.where('landownerId', WhereFilter.equal, landownerId).get();
    return snap.docs.map((d) => LeaseModel.fromMap(d.data() as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<LeaseModel>> getLeasesByManager(String managerId) async {
    final snap = await _leases.where('managerId', WhereFilter.equal, managerId).get();
    return snap.docs.map((d) => LeaseModel.fromMap(d.data() as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<LeaseModel>> getLeasesByUnit(String unitId) async {
    final snap = await _leases.where('unitId', WhereFilter.equal, unitId).get();
    return snap.docs.map((d) => LeaseModel.fromMap(d.data() as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<LeaseModel>> getAllActiveLeases() async {
    try {
      final snap = await _leases
          .where('status', WhereFilter.equal, 'active')
          .orderBy('endDate', descending: false)
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

      final snap = await _leases
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

  //  SIGNING & ACTIVATION

  @override
  Future<void> markLeaseAsSigned(
    String leaseId,
    String signedPdfUrl,
    String paymentReceiptUrl,
    String signedBy,
  ) async {
    await _leases.doc(leaseId).update({
      'signedAgreementPdfUrl': signedPdfUrl,
      'signedAt': DateTime.now().toIso8601String(),
      'paymentReceiptUrl': paymentReceiptUrl,
      'signedBy': signedBy,
      'status': 'pending payment',
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
  }

  //  RENEWAL

  @override
  Future<void> markLeaseAsPendingRenewal(String leaseId) async {
    await _leases.doc(leaseId).update({
      'status': 'pending payment',
      'renewalRequestedAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<LeaseModel> createRenewalLease({
    required String oldLeaseId,
    required DateTime newStartDate,
    required DateTime newEndDate,
    required double monthlyRent,
    String? reason,
    String? paymentReceiptUrl,
  }) async {
    final oldLease = await getLeaseById(oldLeaseId);

    final newLease = oldLease.copyWith(
      id: '',
      startDate: newStartDate,
      endDate: newEndDate,
      nextDueDate: newEndDate,
      monthlyRent: monthlyRent,
      status: 'active',
      isRenewed: true,
      previousLeaseId: oldLeaseId,
      renewalReason: reason,
      paymentReceiptUrl: paymentReceiptUrl ?? oldLease.paymentReceiptUrl,
      renewedAt: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final created = await createLease(newLease);

    // Keep old lease for history
    await _leases.doc(oldLeaseId).update({
      'status': 'renewed',
      'updatedAt': DateTime.now().toIso8601String(),
    });

    return created;
  }

  @override
  Future<LeaseModel> renewLeaseAfterPayment(String leaseId) async {
    final lease = await getLeaseById(leaseId);
    final durationMonths = lease.durationMonths ?? 12;
    final newStartDate = lease.endDate;
    final newEndDate = newStartDate.add(Duration(days: durationMonths * 30));

    return createRenewalLease(
      oldLeaseId: leaseId,
      newStartDate: newStartDate,
      newEndDate: newEndDate,
      monthlyRent: lease.monthlyRent,
      reason: 'Automatic renewal after payment',
      paymentReceiptUrl: lease.paymentReceiptUrl,
    );
  }

  //  TRANSFER

  @override
  Future<void> requestLeaseTransfer({
    required String leaseId,
    required String newTenantId,
    required String reason,
  }) async {
    await _leases.doc(leaseId).update({
      'status': 'transfer_requested',
      'transferToTenantId': newTenantId,
      'transferStatus': 'pending',
      'transferReason': reason,
      'transferRequestedAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> approveLeaseTransfer(String leaseId, String approvedBy) async {
    final lease = await getLeaseById(leaseId);

    if (lease.transferToTenantId == null) {
      throw Exception('No transfer request found');
    }

    final newLease = LeaseModel(
      id: '',
      unitId: lease.unitId,
      tenantId: lease.transferToTenantId!,
      landownerId: lease.landownerId,
      managerId: lease.managerId,
      propertyId: lease.propertyId,
      applicationId: 'transfer_${DateTime.now().millisecondsSinceEpoch}',
      startDate: DateTime.now(),
      endDate: lease.endDate,
      monthlyRent: lease.monthlyRent,
      fees: lease.fees,
      status: 'active',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await createLease(newLease);

    await _leases.doc(leaseId).update({
      'status': 'transferred',
      'transferStatus': 'approved',
      'transferApprovedBy': approvedBy,
      'transferApprovedAt': DateTime.now().toIso8601String(),
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

  //  EARLY TERMINATION

  @override
  Future<void> requestEarlyTermination({
    required String leaseId,
    required String reason,
    required String requestedBy,
  }) async {
    await _leases.doc(leaseId).update({
      'status': 'early_termination_requested',
      'terminationReason': reason,
      'terminationRequestedBy': requestedBy,
      'terminationRequestedAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> approveEarlyTermination(String leaseId, String approvedBy) async {
    await _leases.doc(leaseId).update({
      'status': 'terminated',
      'terminationApprovedBy': approvedBy,
      'terminationApprovedAt': DateTime.now().toIso8601String(),
      'requestStatus': 'approved',
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> rejectEarlyTermination(String leaseId, String rejectedBy, String reason) async {
    await _leases.doc(leaseId).update({
      'requestStatus': 'rejected',
      'terminationRejectedBy': rejectedBy,
      'terminationRejectionReason': reason,
      'terminationRejectedAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<List<LeaseTerminationRequest>> getTerminationRequests(String userId) async {
    final snap = await _leases
        .where('landownerId', WhereFilter.equal, userId)
        .where('status', WhereFilter.arrayContains, ['early_termination_requested', 'transfer_requested'])
        .orderBy('updatedAt', descending: true)
        .get();

    return snap.docs.map((doc) {
      return LeaseTerminationRequest.fromMap(doc.data() as Map<String, dynamic>);
    }).toList();
  }

  @override
  Future<Map<String, dynamic>> calculateEarlyTerminationSettlement(
    String leaseId,
    UnitRepository unitRepo,
  ) async {
    final lease = await getLeaseById(leaseId);
    final unit = await unitRepo.getUnitById(lease.unitId);

    final now = DateTime.now();
    final totalLeaseDays = lease.endDate.difference(lease.startDate).inDays;
    final remainingDays = lease.endDate.difference(now).inDays.clamp(0, totalLeaseDays);

    final monthlyRent = lease.monthlyRent;
    final dailyRent = monthlyRent / 30; // more accurate for monthly rent

    final proratedRentDue = (dailyRent * remainingDays).roundToDouble();

    double additionalFeesDue = 0.0;
    if (unit.fees != null) {
      for (var fee in unit.fees!) {
        if (fee.isOneTime == false) {
          additionalFeesDue += fee.amount;
        }
      }
    }

    double penalty = (proratedRentDue * 0.10).roundToDouble();
    final hasReplacement = lease.transferToTenantId != null;
    if (hasReplacement) penalty = 0.0;

    return {
      'remainingDays': remainingDays,
      'proratedRentDue': proratedRentDue,
      'additionalFeesDue': additionalFeesDue,
      'penalty': penalty,
      'hasReplacement': hasReplacement,
      'netBalanceDueFromTenant': proratedRentDue + additionalFeesDue + penalty,
      'netRefundToTenant': 0.0,
      'notes': hasReplacement
          ? 'Penalty waived due to replacement tenant'
          : 'Early termination penalty applied (10% of remaining rent)',
      'recommendation': 'Landlord and tenant should settle directly or through the app.',
    };
  }

  //  SETTLEMENT

  @override
  Future<void> proposeSettlement(LeaseSettlementAgreement settlement) async {
    final docRef = firestore.collection('lease_settlements').doc();
    final newSettlement = settlement.copyWith(id: docRef.id);
    await docRef.set(newSettlement.toMap());

    await _leases.doc(settlement.leaseId).update({
      'currentSettlementId': newSettlement.id,
      'settlementStatus': 'proposed',
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> acceptSettlement(String leaseId, String acceptedBy) async {
    final snap = await firestore
        .collection('lease_settlements')
        .where('leaseId', WhereFilter.equal, leaseId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) throw NotFoundException('Settlement', leaseId);

    await firestore.collection('lease_settlements').doc(snap.docs.first.id).update({
      'status': 'agreed',
      'agreedAt': DateTime.now().toIso8601String(),
      'agreedBy': acceptedBy,
    });

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

    await firestore.collection('lease_settlements').doc(snap.docs.first.id).update({
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
    required String resolution,
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

    await firestore.collection('lease_settlements').doc(snap.docs.first.id).update({
      'status': resolution == 'accept' ? 'agreed' : 'rejected',
      'resolvedBy': resolvedBy,
      'resolution': resolution,
      'finalAmount': finalAmount,
      'resolutionNotes': notes,
      'resolvedAt': DateTime.now().toIso8601String(),
    });

    await _leases.doc(leaseId).update({
      'settlementStatus': resolution == 'accept' ? 'agreed' : 'rejected',
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  //  RENT ADJUSTMENT

  @override
  Future<void> proposeRentAdjustment({
    required String leaseId,
    required double newMonthlyRent,
    required String reason,
    required String proposedBy,
  }) async {
    await _leases.doc(leaseId).update({
      'proposedNewMonthlyRent': newMonthlyRent,
      'rentAdjustmentStatus': 'pending',
      'rentAdjustmentReason': reason,
      'rentAdjustmentProposedBy': proposedBy,
      'rentAdjustmentProposedAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> approveRentAdjustment(String leaseId, String approvedBy) async {
    final lease = await getLeaseById(leaseId);

    await _leases.doc(leaseId).update({
      'monthlyRent': lease.proposedNewMonthlyRent,
      'proposedNewMonthlyRent': null,
      'rentAdjustmentStatus': 'approved',
      'lastRentAdjustmentDate': DateTime.now().toIso8601String(),
      'lastRentAdjustmentReason': lease.rentAdjustmentReason,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> rejectRentAdjustment(String leaseId, String rejectedBy, String reason) async {
    await _leases.doc(leaseId).update({
      'proposedNewMonthlyRent': null,
      'rentAdjustmentStatus': 'rejected',
      'rentAdjustmentRejectionReason': reason,
      'rentAdjustmentRejectedBy': rejectedBy,
      'rentAdjustmentRejectedAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  //  REQUEST VIEWING

  @override
  Future<List<Map<String, dynamic>>> getLeaseRequestsByUser(String userId) async {
    final snap = await _leases.where('tenantId', WhereFilter.equal, userId).get();

    return snap.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'leaseId': doc.id,
        'requestType': data['requestType'],
        'status': data['requestStatus'] ?? data['transferStatus'] ?? data['rentAdjustmentStatus'],
        'reason': data['requestReason'] ?? data['terminationReason'] ?? data['rentAdjustmentReason'],
        'proposedAt':
            data['requestProposedAt'] ??
            data['transferRequestedAt'] ??
            data['terminationRequestedAt'] ??
            data['rentAdjustmentProposedAt'],
      };
    }).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getIncomingLeaseRequests(String userId, String role) async {
    final field = role == 'landowner' ? 'landownerId' : 'managerId';

    final snap = await _leases.where(field, WhereFilter.equal, userId).get();

    return snap.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'leaseId': doc.id,
        'requestType': data['requestType'],
        'status': data['requestStatus'] ?? data['transferStatus'] ?? data['rentAdjustmentStatus'],
        'reason': data['requestReason'] ?? data['terminationReason'] ?? data['rentAdjustmentReason'],
        'proposedAt':
            data['requestProposedAt'] ??
            data['transferRequestedAt'] ??
            data['terminationRequestedAt'] ??
            data['rentAdjustmentProposedAt'],
        'tenantId': data['tenantId'],
      };
    }).toList();
  }

  @override
  Future<void> updateLeaseRequestStatus(
    String leaseId,
    String requestType,
    String status,
    String? reason,
  ) async {
    await _leases.doc(leaseId).update({
      'requestType': requestType,
      'requestStatus': status,
      'requestReason': reason,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  //  SYSTEM / CRON

  @override
  Future<int> updateExpiredLeasesToInactive() async {
    try {
      final now = DateTime.now().toIso8601String();
      final snap = await _leases
          .where('status', WhereFilter.equal, 'active')
          .where('endDate', WhereFilter.lessThan, now)
          .get();

      int updatedCount = 0;

      for (var doc in snap.docs) {
        await _leases.doc(doc.id).update({
          'status': 'inactive',
          'updatedAt': DateTime.now().toIso8601String(),
        });
        updatedCount++;
      }

      print('Updated $updatedCount leases to inactive');
      return updatedCount;
    } catch (e) {
      print('Error updating expired leases: $e');
      return 0;
    }
  }

  @override
  Future<void> terminateLease(String id, String reason, String terminatedBy) async {
    await _leases.doc(id).update({
      'status': 'terminated',
      'terminationReason': reason,
      'terminatedAt': DateTime.now().toIso8601String(),
      'terminatedBy': terminatedBy,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }
}
