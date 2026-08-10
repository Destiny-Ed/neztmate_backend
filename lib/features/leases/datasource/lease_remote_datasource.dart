import 'package:neztmate_backend/features/leases/models/lease_request_model.dart';
import 'package:neztmate_backend/features/leases/models/lease_settlement_agreement_model.dart';
import 'package:neztmate_backend/features/leases/models/leases_model.dart';
import 'package:neztmate_backend/features/units/repository/unit_repo.dart';

abstract class LeaseRemoteDataSource {
  // BASIC CRUD
  Future<LeaseModel> createLease(LeaseModel lease);
  Future<LeaseModel> createManualLease(LeaseModel lease);
  Future<LeaseModel> getLeaseById(String id);
  Future<LeaseModel> getLeaseByApplicationId(String applicationId);
  Future<void> updateLease(LeaseModel lease);
  Future<void> updateLeaseStatus(String leaseId, String status);

  // QUERIES
  Future<List<LeaseModel>> getActiveLeasesByTenant(String tenantId);
  Future<List<LeaseModel>> getLeasesByTenant(String tenantId);
  Future<List<LeaseModel>> getLeasesByLandowner(String landownerId);
  Future<List<LeaseModel>> getLeasesByManager(String managerId);
  Future<List<LeaseModel>> getLeasesByUnit(String unitId);
  Future<List<LeaseModel>> getAllActiveLeases();
  Future<List<LeaseModel>> getExpiringLeases({int withinDays = 5});
  Future<LeaseRequestModel> updateLeaseRequest(LeaseRequestModel request);

  // SIGNING & ACTIVATION
  Future<void> markLeaseAsSigned(
    String leaseId,
    String signedPdfUrl,
    String paymentReceiptUrl,
    String signedBy,
  );
  Future<void> confirmPaymentAndActivate(String leaseId, String confirmedBy);

  // RENEWAL (finalization only)
  /// Marks lease as awaiting renewal payment (does not create a request by itself)
  Future<void> markLeaseAsPendingRenewal(String leaseId);

  Future<LeaseModel> createRenewalLease({
    required String oldLeaseId,
    required DateTime newStartDate,
    required DateTime newEndDate,
    required double monthlyRent,
    String? reason,
    String? paymentReceiptUrl,
  });

  Future<LeaseModel> renewLeaseAfterPayment(
    LeaseModel oldLease,
    int? durationMonths,
    double? proposedRent,
    String? paymentReceiptUrl,
  );

  // SETTLEMENT
  Future<void> proposeSettlement(LeaseSettlementAgreement settlement);
  Future<void> acceptSettlement(String leaseId, String acceptedBy);
  Future<void> disputeSettlement({
    required String leaseId,
    required String disputedBy,
    required String reason,
  });
  Future<void> resolveSettlementDispute({
    required String leaseId,
    required String resolvedBy,
    required String resolution, // accept | reject | modify
    double? finalAmount,
    String? notes,
  });

  // LEASE REQUESTS
  Future<LeaseRequestModel> createLeaseRequest(LeaseRequestModel request);
  Future<LeaseRequestModel> getLeaseRequestById(String requestId);
  Future<LeaseRequestModel?> getActiveLeaseRequest(String leaseId, {LeaseRequestType? type});
  Future<List<LeaseRequestModel>> getLeaseRequestsByLease(String leaseId);
  Future<List<LeaseRequestModel>> getLeaseRequestsByTenant(String tenantId);
  Future<List<LeaseRequestModel>> getLeaseRequestsForLandowner(String landownerId);
  Future<List<LeaseRequestModel>> getLeaseRequestsForManager(String managerId);
  Future<List<LeaseRequestModel>> getPendingLeaseRequestsForUser({
    required String userId,
    required String role, // tenant | landowner | manager
  });

  /// Approves request + applies final lease side-effects (transfer, terminate, rent change, etc.)
  Future<void> approveLeaseRequest({required String requestId, required String approvedBy, String? notes});

  Future<void> rejectLeaseRequest({
    required String requestId,
    required String rejectedBy,
    required String reason,
  });

  Future<void> cancelLeaseRequest({required String requestId, required String cancelledBy});

  Future<void> completeLeaseRequest(String requestId);

  /// Helper used when approving early termination
  Future<Map<String, dynamic>> calculateEarlyTerminationSettlement(String leaseId, UnitRepository unitRepo);

  // SYSTEM / CRON
  Future<int> updateExpiredLeasesToInactive();
  Future<void> terminateLease(String id, String reason, String terminatedBy);

  Future<void> setPendingRenewalTerms(String leaseId, Map<String, dynamic> terms);

  Future<void> clearPendingRenewalTerms(String leaseId);
}
