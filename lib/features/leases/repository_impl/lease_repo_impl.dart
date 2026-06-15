import 'package:neztmate_backend/features/leases/datasource/lease_remote_datasource.dart';
import 'package:neztmate_backend/features/leases/models/leases_model.dart';
import 'package:neztmate_backend/features/leases/repository/lease_repo.dart';

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
}
