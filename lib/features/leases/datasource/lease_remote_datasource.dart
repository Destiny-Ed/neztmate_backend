import 'package:neztmate_backend/features/leases/models/leases_model.dart';

abstract class LeaseRemoteDataSource {
  Future<LeaseModel> createLease(LeaseModel lease);
  Future<LeaseModel> getLeaseById(String id);
  Future<List<LeaseModel>> getActiveLeasesByTenant(String tenantId);
  Future<List<LeaseModel>> getLeasesByLandowner(String landownerId);
  Future<List<LeaseModel>> getLeasesByUnit(String unitId);
  Future<void> updateLease(LeaseModel lease);
  Future<void> terminateLease(String id);
  Future<LeaseModel> getLeaseByApplicationId(String applicationId);
  Future<void> markLeaseAsSigned(String leaseId, String signedPdfUrl, String signedBy);
}
