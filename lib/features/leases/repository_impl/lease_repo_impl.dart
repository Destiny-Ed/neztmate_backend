
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
  Future<List<LeaseModel>> getLeasesByLandowner(String landownerId) =>
      dataSource.getLeasesByLandowner(landownerId);

  @override
  Future<List<LeaseModel>> getLeasesByUnit(String unitId) => dataSource.getLeasesByUnit(unitId);

  @override
  Future<void> updateLease(LeaseModel lease) => dataSource.updateLease(lease);

  @override
  Future<void> terminateLease(String id) => dataSource.terminateLease(id);
}
