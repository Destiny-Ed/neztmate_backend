import 'package:neztmate_backend/features/maintenance/datasource/maintenance_remote_datasource.dart';
import 'package:neztmate_backend/features/maintenance/models/maintenance.dart';

import 'package:neztmate_backend/features/maintenance/repository/maintenance_repo.dart';

class MaintenanceRequestRepositoryImpl implements MaintenanceRequestRepository {
  final MaintenanceRequestRemoteDataSource dataSource;

  MaintenanceRequestRepositoryImpl(this.dataSource);

  @override
  Future<MaintenanceRequestModel> createRequest(MaintenanceRequestModel request) async {
    return await dataSource.createRequest(request);
  }

  @override
  Future<MaintenanceRequestModel> getRequestById(String id) async {
    return await dataSource.getRequestById(id);
  }

  @override
  Future<List<MaintenanceRequestModel>> getRequestsByTenant(String tenantId) async {
    return await dataSource.getRequestsByTenant(tenantId);
  }

  @override
  Future<List<MaintenanceRequestModel>> getRequestsByUnit(String unitId) async {
    return await dataSource.getRequestsByUnit(unitId);
  }

  @override
  Future<List<MaintenanceRequestModel>> getRequestsByManager(String managerId) async {
    return await dataSource.getRequestsByManager(managerId);
  }

  @override
  Future<void> updateRequest(MaintenanceRequestModel request) async {
    await dataSource.updateRequest(request);
  }

  @override
  Future<void> deleteRequest(String id) async {
    await dataSource.deleteRequest(id);
  }

  @override
  Future<void> assignRequest(String id, String artisanId) async {
    await dataSource.assignRequest(id, artisanId);
  }

  @override
  Future<List<MaintenanceRequestModel>> getOverdueRequests() {
    // TODO: implement getOverdueRequests
    throw UnimplementedError();
  }

  @override
  Future<List<MaintenanceRequestModel>> getRequestsByArtisan(String artisanId) {
    // TODO: implement getRequestsByArtisan
    throw UnimplementedError();
  }
}
