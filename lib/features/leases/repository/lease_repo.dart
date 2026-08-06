import 'package:neztmate_backend/features/leases/models/lease_settlement_agreement_model.dart';
import 'package:neztmate_backend/features/leases/models/lease_termination_request.dart';
import 'package:neztmate_backend/features/leases/models/leases_model.dart';
import 'package:neztmate_backend/features/units/repository/unit_repo.dart';

abstract class LeaseRepository {
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

  // SIGNING & ACTIVATION
  Future<void> markLeaseAsSigned(
    String leaseId,
    String signedPdfUrl,
    String paymentReceiptUrl,
    String signedBy,
  );
  Future<void> confirmPaymentAndActivate(String leaseId, String confirmedBy);

  // RENEWAL
  Future<void> markLeaseAsPendingRenewal(String leaseId);
  Future<LeaseModel> createRenewalLease({
    required String oldLeaseId,
    required DateTime newStartDate,
    required DateTime newEndDate,
    required double monthlyRent,
    String? reason,
    String? paymentReceiptUrl,
  });
  Future<LeaseModel> renewLeaseAfterPayment(String leaseId); // keep for backward compatibility

  // TRANSFER
  Future<void> requestLeaseTransfer({
    required String leaseId,
    required String newTenantId,
    required String reason,
  });
  Future<void> approveLeaseTransfer(String leaseId, String approvedBy);
  Future<void> rejectLeaseTransfer(String leaseId, String rejectedBy, String reason);

  // EARLY TERMINATION
  Future<void> requestEarlyTermination({
    required String leaseId,
    required String reason,
    required String requestedBy,
  });
  Future<void> approveEarlyTermination(String leaseId, String approvedBy);
  Future<void> rejectEarlyTermination(String leaseId, String rejectedBy, String reason);
  Future<List<LeaseTerminationRequest>> getTerminationRequests(String userId);
  Future<Map<String, dynamic>> calculateEarlyTerminationSettlement(String leaseId, UnitRepository unitRepo);

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
    required String resolution,
    double? finalAmount,
    String? notes,
  });

  // RENT ADJUSTMENT
  Future<void> proposeRentAdjustment({
    required String leaseId,
    required double newMonthlyRent,
    required String reason,
    required String proposedBy,
  });
  Future<void> approveRentAdjustment(String leaseId, String approvedBy);
  Future<void> rejectRentAdjustment(String leaseId, String rejectedBy, String reason);

  // REQUEST VIEWING
  Future<List<Map<String, dynamic>>> getLeaseRequestsByUser(String userId);
  Future<List<Map<String, dynamic>>> getIncomingLeaseRequests(String userId, String role);
  Future<void> updateLeaseRequestStatus(String leaseId, String requestType, String status, String? reason);

  // SYSTEM / CRON
  Future<int> updateExpiredLeasesToInactive();
  Future<void> terminateLease(String id, String reason, String terminatedBy);
}
