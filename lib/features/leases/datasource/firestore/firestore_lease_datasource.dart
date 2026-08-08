import 'package:dart_firebase_admin/firestore.dart';
import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/features/leases/datasource/lease_remote_datasource.dart';
import 'package:neztmate_backend/features/leases/models/lease_request_model.dart';
import 'package:neztmate_backend/features/leases/models/lease_settlement_agreement_model.dart';
import 'package:neztmate_backend/features/leases/models/leases_model.dart';
import 'package:neztmate_backend/features/units/repository/unit_repo.dart';

class FirestoreLeaseDataSource implements LeaseRemoteDataSource {
  final Firestore firestore;

  FirestoreLeaseDataSource(this.firestore);

  CollectionReference get _leases => firestore.collection('leases');
  CollectionReference get _leaseRequests => firestore.collection('leases_requests');

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
      'status': 'pending_payment',
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
      // 'status': 'pending_renewal_payment',
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

  // ====================== LEASE REQUESTS ======================

  @override
  Future<LeaseRequestModel> createLeaseRequest(LeaseRequestModel request) async {
    // Block duplicate pending request of same type on same lease
    final existing = await getActiveLeaseRequest(request.leaseId, type: request.type);
    if (existing != null) {
      throw ValidationException('A pending ${request.type.value} request already exists for this lease');
    }

    final docRef = _leaseRequests.doc(request.id.isEmpty ? null : request.id);
    final newRequest = request.copyWith(
      id: docRef.id,
      status: LeaseRequestStatus.pending,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await docRef.set(newRequest.toMap());
    return newRequest;
  }

  @override
  Future<LeaseRequestModel> getLeaseRequestById(String requestId) async {
    final doc = await _leaseRequests.doc(requestId).get();
    if (!doc.exists) throw NotFoundException('LeaseRequest', requestId);
    return LeaseRequestModel.fromMap(doc.data() as Map<String, dynamic>);
  }

  @override
  Future<LeaseRequestModel?> getActiveLeaseRequest(String leaseId, {LeaseRequestType? type}) async {
    var query = _leaseRequests.where('leaseId', WhereFilter.equal, leaseId).where(
      'status',
      WhereFilter.arrayContains,
      [LeaseRequestStatus.pending.value, LeaseRequestStatus.approved.value],
    );

    if (type != null) {
      query = query.where('type', WhereFilter.equal, type.value);
    }

    final snap = await query.limit(1).get();
    if (snap.docs.isEmpty) return null;
    return LeaseRequestModel.fromMap(snap.docs.first.data() as Map<String, dynamic>);
  }

  @override
  Future<List<LeaseRequestModel>> getLeaseRequestsByLease(String leaseId) async {
    final snap = await _leaseRequests
        .where('leaseId', WhereFilter.equal, leaseId)
        .orderBy('createdAt', descending: true)
        .get();

    return snap.docs.map((d) => LeaseRequestModel.fromMap(d.data() as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<LeaseRequestModel>> getLeaseRequestsByTenant(String tenantId) async {
    final snap = await _leaseRequests
        .where('tenantId', WhereFilter.equal, tenantId)
        .orderBy('createdAt', descending: true)
        .get();

    return snap.docs.map((d) => LeaseRequestModel.fromMap(d.data() as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<LeaseRequestModel>> getLeaseRequestsForLandowner(String landownerId) async {
    final snap = await _leaseRequests
        .where('landownerId', WhereFilter.equal, landownerId)
        .orderBy('createdAt', descending: true)
        .get();

    return snap.docs.map((d) => LeaseRequestModel.fromMap(d.data() as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<LeaseRequestModel>> getLeaseRequestsForManager(String managerId) async {
    final snap = await _leaseRequests
        .where('managerId', WhereFilter.equal, managerId)
        .orderBy('createdAt', descending: true)
        .get();

    return snap.docs.map((d) => LeaseRequestModel.fromMap(d.data() as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<LeaseRequestModel>> getPendingLeaseRequestsForUser({
    required String userId,
    required String role,
  }) async {
    Query query;

    if (role == 'tenant') {
      query = _leaseRequests.where('tenantId', WhereFilter.equal, userId).where('status', WhereFilter.isIn, [
        LeaseRequestStatus.pending.value,
        LeaseRequestStatus.approved.value,
      ]);
    } else if (role == 'manager') {
      query = _leaseRequests.where('managerId', WhereFilter.equal, userId).where('status', WhereFilter.isIn, [
        LeaseRequestStatus.pending.value,
        LeaseRequestStatus.approved.value,
      ]);
    } else {
      // landowner
      query = _leaseRequests.where('landownerId', WhereFilter.equal, userId).where(
        'status',
        WhereFilter.isIn,
        [LeaseRequestStatus.pending.value, LeaseRequestStatus.approved.value],
      );
    }

    final snap = await query.orderBy('createdAt', descending: true).get();

    return snap.docs.map((d) => LeaseRequestModel.fromMap(d.data() as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> approveLeaseRequest({
    required String requestId,
    required String approvedBy,
    String? notes,
  }) async {
    final request = await getLeaseRequestById(requestId);

    if (request.status != LeaseRequestStatus.pending) {
      throw ValidationException('Only pending requests can be approved');
    }

    // 1. Mark request approved
    await _leaseRequests.doc(requestId).update({
      'status': LeaseRequestStatus.approved.value,
      'resolvedAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
      'metadata': {...request.metadata, 'approvedBy': approvedBy, if (notes != null) 'approvalNotes': notes},
    });

    // 2. Apply final lease side-effects
    switch (request.type) {
      case LeaseRequestType.transfer:
        await _finalizeTransfer(request, approvedBy);
        break;

      case LeaseRequestType.termination:
        await terminateLease(request.leaseId, request.reason ?? 'Early termination approved', approvedBy);
        break;

      case LeaseRequestType.rentAdjustment:
        final newRent = (request.metadata['newMonthlyRent'] as num?)?.toDouble();
        if (newRent == null) {
          throw ValidationException('newMonthlyRent missing in request metadata');
        }
        await _leases.doc(request.leaseId).update({
          'monthlyRent': newRent,
          'lastRentAdjustmentDate': DateTime.now().toIso8601String(),
          'lastRentAdjustmentReason': request.reason,
          'updatedAt': DateTime.now().toIso8601String(),
        });
        break;

      case LeaseRequestType.renewal:
        // Renewal payment flow usually finalizes via createRenewalLease after payment
        // Optionally mark lease pending_renewal_payment here if needed
        await markLeaseAsPendingRenewal(request.leaseId);
        break;

      case LeaseRequestType.settlement:
      case LeaseRequestType.maintenance:
      case LeaseRequestType.inspection:
      case LeaseRequestType.other:
        // No automatic lease mutation
        break;
    }
  }

  Future<void> _finalizeTransfer(LeaseRequestModel request, String approvedBy) async {
    final newTenantId = request.metadata['newTenantId'] as String?;
    if (newTenantId == null || newTenantId.isEmpty) {
      throw ValidationException('newTenantId missing in transfer request metadata');
    }

    final lease = await getLeaseById(request.leaseId);

    final newLease = LeaseModel(
      id: '',
      unitId: lease.unitId,
      tenantId: newTenantId,
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

    await _leases.doc(request.leaseId).update({
      'status': 'transferred',
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> rejectLeaseRequest({
    required String requestId,
    required String rejectedBy,
    required String reason,
  }) async {
    final request = await getLeaseRequestById(requestId);

    if (request.status != LeaseRequestStatus.pending) {
      throw ValidationException('Only pending requests can be rejected');
    }

    await _leaseRequests.doc(requestId).update({
      'status': LeaseRequestStatus.rejected.value,
      'reason': reason,
      'resolvedAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
      'metadata': {...request.metadata, 'rejectedBy': rejectedBy, 'rejectionReason': reason},
    });

    // Lease status is intentionally NOT changed
  }

  @override
  Future<void> cancelLeaseRequest({required String requestId, required String cancelledBy}) async {
    final request = await getLeaseRequestById(requestId);

    if (request.status != LeaseRequestStatus.pending) {
      throw ValidationException('Only pending requests can be cancelled');
    }

    await _leaseRequests.doc(requestId).update({
      'status': LeaseRequestStatus.cancelled.value,
      'resolvedAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
      'metadata': {...request.metadata, 'cancelledBy': cancelledBy},
    });
  }

  @override
  Future<void> completeLeaseRequest(String requestId) async {
    // final request = await getLeaseRequestById(requestId);

    await _leaseRequests.doc(requestId).update({
      'status': LeaseRequestStatus.completed.value,
      'resolvedAt': DateTime.now().toIso8601String(),
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
