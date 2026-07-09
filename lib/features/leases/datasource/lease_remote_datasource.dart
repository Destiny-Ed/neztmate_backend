import 'package:neztmate_backend/features/leases/models/leases_model.dart';

abstract class LeaseRemoteDataSource {
  Future<LeaseModel> createLease(LeaseModel lease);
  Future<LeaseModel> getLeaseById(String id);
  Future<List<LeaseModel>> getActiveLeasesByTenant(String tenantId);
  Future<List<LeaseModel>> getLeasesByTenant(String tenantId);
  Future<List<LeaseModel>> getLeasesByLandowner(String landownerId);
  Future<List<LeaseModel>> getLeasesByUnit(String unitId);
  Future<void> updateLease(LeaseModel lease);
  Future<void> terminateLease(String id, String reason, String terminatedBy);

  Future<LeaseModel> getLeaseByApplicationId(String applicationId);
  Future<void> markLeaseAsSigned(String leaseId, String signedPdfUrl, String signedBy);
  Future<LeaseModel> renewLeaseAfterPayment(String leaseId);
  Future<void> updateLeaseStatus(String leaseId, String status);

  /// Get all active leases across the system (for cron jobs, reminders, etc.)
  Future<List<LeaseModel>> getAllActiveLeases();

  // Optional: Get active leases expiring soon
  Future<List<LeaseModel>> getExpiringLeases({int withinDays = 5});

  Future<int> updateExpiredLeasesToInactive();

  Future<void> requestLeaseTransfer({
    required String leaseId,
    required String newTenantId,
    required String reason,
  });

  Future<void> approveLeaseTransfer(String leaseId, String approvedBy);

  Future<void> rejectLeaseTransfer(String leaseId, String rejectedBy, String reason);

  Future<void> requestEarlyTermination({
    required String leaseId,
    required String reason,
    required String requestedBy,
  });
}
