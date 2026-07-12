import 'package:neztmate_backend/features/leases/datasource/lease_remote_datasource.dart';
import 'package:neztmate_backend/features/leases/models/lease_settlement_agreement_model.dart';
import 'package:neztmate_backend/features/leases/models/lease_termination_request.dart';
import 'package:neztmate_backend/features/leases/models/leases_model.dart';
import 'package:neztmate_backend/features/leases/repository/lease_repo.dart';
import 'package:neztmate_backend/features/units/repository/unit_repo.dart';

class LeaseRepositoryImpl implements LeaseRepository {
  final LeaseRemoteDataSource dataSource;

  LeaseRepositoryImpl(this.dataSource);

  @override
  Future<LeaseModel> createLease(LeaseModel lease) => dataSource.createLease(lease);

  @override
  Future<LeaseModel> getLeaseById(String id) => dataSource.getLeaseById(id);

  @override
  Future<List<LeaseModel>> getActiveLeasesByTenant(String tenantId) =>
      dataSource.getActiveLeasesByTenant(tenantId);

  @override
  Future<List<LeaseModel>> getLeasesByTenant(String tenantId) => dataSource.getLeasesByTenant(tenantId);

  @override
  Future<List<LeaseModel>> getLeasesByLandowner(String landownerId) =>
      dataSource.getLeasesByLandowner(landownerId);

  @override
  Future<List<LeaseModel>> getLeasesByUnit(String unitId) => dataSource.getLeasesByUnit(unitId);

  @override
  Future<void> updateLease(LeaseModel lease) => dataSource.updateLease(lease);

  @override
  Future<LeaseModel> getLeaseByApplicationId(String applicationId) =>
      dataSource.getLeaseByApplicationId(applicationId);

  @override
  Future<void> markLeaseAsSigned(String leaseId, String signedPdfUrl, String signedBy) =>
      dataSource.markLeaseAsSigned(leaseId, signedPdfUrl, signedBy);

  @override
  Future<void> updateLeaseStatus(String leaseId, String status) =>
      dataSource.updateLeaseStatus(leaseId, status);

  @override
  Future<void> terminateLease(String id, String reason, String terminatedBy) =>
      dataSource.terminateLease(id, reason, terminatedBy);

  @override
  Future<LeaseModel> renewLeaseAfterPayment(String leaseId) => dataSource.renewLeaseAfterPayment(leaseId);

  @override
  Future<List<LeaseModel>> getAllActiveLeases() => dataSource.getAllActiveLeases();
  @override
  Future<List<LeaseModel>> getExpiringLeases({int withinDays = 5}) =>
      dataSource.getExpiringLeases(withinDays: withinDays);
  @override
  Future<int> updateExpiredLeasesToInactive() => dataSource.updateExpiredLeasesToInactive();

  @override
  Future<void> approveLeaseTransfer(String leaseId, String approvedBy) =>
      dataSource.approveLeaseTransfer(leaseId, approvedBy);

  @override
  Future<void> rejectLeaseTransfer(String leaseId, String rejectedBy, String reason) =>
      dataSource.rejectLeaseTransfer(leaseId, rejectedBy, reason);

  @override
  Future<void> requestEarlyTermination({
    required String leaseId,
    required String reason,
    required String requestedBy,
  }) => dataSource.requestEarlyTermination(leaseId: leaseId, reason: reason, requestedBy: requestedBy);

  @override
  Future<void> requestLeaseTransfer({
    required String leaseId,
    required String newTenantId,
    required String reason,
  }) => dataSource.requestLeaseTransfer(leaseId: leaseId, newTenantId: newTenantId, reason: reason);

  @override
  Future<List<LeaseTerminationRequest>> getTerminationRequests(String userId) =>
      dataSource.getTerminationRequests(userId);

  @override
  Future<Map<String, dynamic>> calculateEarlyTerminationSettlement(String leaseId, UnitRepository unitRepo) =>
      dataSource.calculateEarlyTerminationSettlement(leaseId, unitRepo);

  @override
  Future<void> acceptSettlement(String leaseId, String acceptedBy) =>
      dataSource.acceptSettlement(leaseId, acceptedBy);

  @override
  Future<void> proposeSettlement(LeaseSettlementAgreement settlement) =>
      dataSource.proposeSettlement(settlement);

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
  }) => dataSource.resolveSettlementDispute(leaseId: leaseId, resolvedBy: resolvedBy, resolution: resolution);

  @override
  Future<void> confirmPaymentAndActivate(String leaseId, String confirmedBy) =>
      dataSource.confirmPaymentAndActivate(leaseId, confirmedBy);

  @override
  Future<List<LeaseModel>> getLeasesByManager(String managerId) => dataSource.getLeasesByManager(managerId);
}
