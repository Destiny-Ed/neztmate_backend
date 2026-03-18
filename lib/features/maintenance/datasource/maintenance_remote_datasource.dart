  import 'package:neztmate_backend/features/maintenance/models/maintenance.dart';

abstract class MaintenanceRequestRemoteDataSource {
  Future<MaintenanceRequestModel> createRequest(MaintenanceRequestModel request);
  Future<MaintenanceRequestModel> getRequestById(String id);
  Future<List<MaintenanceRequestModel>> getRequestsByTenant(String tenantId);
  Future<List<MaintenanceRequestModel>> getRequestsByUnit(String unitId);
  Future<List<MaintenanceRequestModel>> getRequestsByManager(String managerId);
  Future<void> updateRequest(MaintenanceRequestModel request);
  Future<void> deleteRequest(String id);
  Future<void> assignRequest(String id, String artisanId);
}
