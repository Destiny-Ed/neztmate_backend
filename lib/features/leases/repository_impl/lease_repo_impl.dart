import 'package:neztmate_backend/features/leases/datasource/lease_remote_datasource.dart';
import 'package:neztmate_backend/features/leases/models/lease_request_model.dart';
import 'package:neztmate_backend/features/leases/models/lease_settlement_agreement_model.dart';
import 'package:neztmate_backend/features/leases/models/leases_model.dart';
import 'package:neztmate_backend/features/leases/repository/lease_repo.dart';
import 'package:neztmate_backend/features/units/repository/unit_repo.dart';

class LeaseRepositoryImpl implements LeaseRepository {
  final LeaseRemoteDataSource dataSource;

  LeaseRepositoryImpl(this.dataSource);

  // BASIC CRUD
  @override
  Future<LeaseModel> createLease(LeaseModel lease) => dataSource.createLease(lease);

  @override
  Future<LeaseModel> createManualLease(LeaseModel lease) => dataSource.createManualLease(lease);

  @override
  Future<LeaseModel> getLeaseById(String id) => dataSource.getLeaseById(id);

  @override
  Future<LeaseModel> getLeaseByApplicationId(String applicationId) =>
      dataSource.getLeaseByApplicationId(applicationId);

  @override
  Future<void> updateLease(LeaseModel lease) => dataSource.updateLease(lease);

  @override
  Future<void> updateLeaseStatus(String leaseId, String status) =>
      dataSource.updateLeaseStatus(leaseId, status);

  // QUERIES
  @override
  Future<List<LeaseModel>> getActiveLeasesByTenant(String tenantId) =>
      dataSource.getActiveLeasesByTenant(tenantId);

  @override
  Future<List<LeaseModel>> getLeasesByTenant(String tenantId) => dataSource.getLeasesByTenant(tenantId);

  @override
  Future<List<LeaseModel>> getLeasesByLandowner(String landownerId) =>
      dataSource.getLeasesByLandowner(landownerId);

  @override
  Future<List<LeaseModel>> getLeasesByManager(String managerId) => dataSource.getLeasesByManager(managerId);

  @override
  Future<List<LeaseModel>> getLeasesByUnit(String unitId) => dataSource.getLeasesByUnit(unitId);

  @override
  Future<List<LeaseModel>> getAllActiveLeases() => dataSource.getAllActiveLeases();

  @override
  Future<List<LeaseModel>> getExpiringLeases({int withinDays = 5}) =>
      dataSource.getExpiringLeases(withinDays: withinDays);

  // SIGNING & ACTIVATION
  @override
  Future<void> markLeaseAsSigned(
    String leaseId,
    String signedPdfUrl,
    String paymentReceiptUrl,
    String signedBy,
  ) => dataSource.markLeaseAsSigned(leaseId, signedPdfUrl, paymentReceiptUrl, signedBy);

  @override
  Future<void> confirmPaymentAndActivate(String leaseId, String confirmedBy) =>
      dataSource.confirmPaymentAndActivate(leaseId, confirmedBy);

  // RENEWAL
  @override
  Future<void> markLeaseAsPendingRenewal(String leaseId) => dataSource.markLeaseAsPendingRenewal(leaseId);

  @override
  Future<LeaseModel> createRenewalLease({
    required String oldLeaseId,
    required DateTime newStartDate,
    required DateTime newEndDate,
    required double monthlyRent,
    String? reason,
    String? paymentReceiptUrl,
  }) => dataSource.createRenewalLease(
    oldLeaseId: oldLeaseId,
    newStartDate: newStartDate,
    newEndDate: newEndDate,
    monthlyRent: monthlyRent,
    reason: reason,
    paymentReceiptUrl: paymentReceiptUrl,
  );

  @override
  Future<LeaseModel> renewLeaseAfterPayment(String leaseId) => dataSource.renewLeaseAfterPayment(leaseId);

  // SETTLEMENT
  @override
  Future<void> proposeSettlement(LeaseSettlementAgreement settlement) =>
      dataSource.proposeSettlement(settlement);

  @override
  Future<void> acceptSettlement(String leaseId, String acceptedBy) =>
      dataSource.acceptSettlement(leaseId, acceptedBy);

  @override
  Future<void> disputeSettlement({
    required String leaseId,
    required String disputedBy,
    required String reason,
  }) => dataSource.disputeSettlement(leaseId: leaseId, disputedBy: disputedBy, reason: reason);

  @override
  Future<void> resolveSettlementDispute({
    required String leaseId,
    required String resolvedBy,
    required String resolution,
    double? finalAmount,
    String? notes,
  }) => dataSource.resolveSettlementDispute(
    leaseId: leaseId,
    resolvedBy: resolvedBy,
    resolution: resolution,
    finalAmount: finalAmount,
    notes: notes,
  );

  // LEASE REQUESTS
  @override
  Future<LeaseRequestModel> createLeaseRequest(LeaseRequestModel request) =>
      dataSource.createLeaseRequest(request);

  @override
  Future<LeaseRequestModel> getLeaseRequestById(String requestId) =>
      dataSource.getLeaseRequestById(requestId);

  @override
  Future<LeaseRequestModel?> getActiveLeaseRequest(String leaseId, {LeaseRequestType? type}) =>
      dataSource.getActiveLeaseRequest(leaseId, type: type);

  @override
  Future<List<LeaseRequestModel>> getLeaseRequestsByLease(String leaseId) =>
      dataSource.getLeaseRequestsByLease(leaseId);

  @override
  Future<List<LeaseRequestModel>> getLeaseRequestsByTenant(String tenantId) =>
      dataSource.getLeaseRequestsByTenant(tenantId);

  @override
  Future<List<LeaseRequestModel>> getLeaseRequestsForLandowner(String landownerId) =>
      dataSource.getLeaseRequestsForLandowner(landownerId);

  @override
  Future<List<LeaseRequestModel>> getLeaseRequestsForManager(String managerId) =>
      dataSource.getLeaseRequestsForManager(managerId);

  @override
  Future<List<LeaseRequestModel>> getPendingLeaseRequestsForUser({
    required String userId,
    required String role,
  }) => dataSource.getPendingLeaseRequestsForUser(userId: userId, role: role);

  @override
  Future<void> approveLeaseRequest({required String requestId, required String approvedBy, String? notes}) =>
      dataSource.approveLeaseRequest(requestId: requestId, approvedBy: approvedBy, notes: notes);

  @override
  Future<void> rejectLeaseRequest({
    required String requestId,
    required String rejectedBy,
    required String reason,
  }) => dataSource.rejectLeaseRequest(requestId: requestId, rejectedBy: rejectedBy, reason: reason);

  @override
  Future<void> cancelLeaseRequest({required String requestId, required String cancelledBy}) =>
      dataSource.cancelLeaseRequest(requestId: requestId, cancelledBy: cancelledBy);

  @override
  Future<void> completeLeaseRequest(String requestId) => dataSource.completeLeaseRequest(requestId);

  @override
  Future<Map<String, dynamic>> calculateEarlyTerminationSettlement(String leaseId, UnitRepository unitRepo) =>
      dataSource.calculateEarlyTerminationSettlement(leaseId, unitRepo);

  // SYSTEM / CRON
  @override
  Future<int> updateExpiredLeasesToInactive() => dataSource.updateExpiredLeasesToInactive();

  @override
  Future<void> terminateLease(String id, String reason, String terminatedBy) =>
      dataSource.terminateLease(id, reason, terminatedBy);
}
