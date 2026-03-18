import 'package:neztmate_backend/features/maintenance/models/maintenance.dart';

abstract class MaintenanceRequestRepository {
  /// Tenant submits a new maintenance request
  Future<MaintenanceRequestModel> createRequest(MaintenanceRequestModel request);

  /// Get a single request by its ID (tenant, manager, artisan, or landowner)
  Future<MaintenanceRequestModel> getRequestById(String id);

  /// Tenant views all their submitted requests
  Future<List<MaintenanceRequestModel>> getRequestsByTenant(String tenantId);

  /// Get all requests related to a specific unit (manager/landowner view)
  Future<List<MaintenanceRequestModel>> getRequestsByUnit(String unitId);

  /// Manager views pending/assigned requests under their management
  Future<List<MaintenanceRequestModel>> getRequestsByManager(String managerId);

  /// Update request details (status, notes, photos, etc.)
  Future<void> updateRequest(MaintenanceRequestModel request);

  /// Delete/cancel a request (only allowed for tenant if still pending)
  Future<void> deleteRequest(String id);

  /// Manager assigns the request to an artisan
  Future<void> assignRequest(String id, String artisanId);
  /// Optional: Get requests assigned to a specific artisan
  Future<List<MaintenanceRequestModel>> getRequestsByArtisan(String artisanId);
}
