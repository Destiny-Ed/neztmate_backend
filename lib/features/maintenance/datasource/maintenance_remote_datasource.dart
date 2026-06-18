import 'package:neztmate_backend/features/maintenance/models/maintenance_request.dart';
import 'package:neztmate_backend/features/maintenance/models/maintenance_task.dart';

abstract class MaintenanceRemoteDataSource {
  Future<MaintenanceRequestModel> createRequest(MaintenanceRequestModel request);
  Future<MaintenanceRequestModel> getRequestById(String id);
  Future<List<MaintenanceRequestModel>> getRequestsByTenant(String tenantId);
  Future<List<MaintenanceRequestModel>> getRequestsByProperty(String propertyId);
  Future<List<MaintenanceRequestModel>> getAllRequestsForManagerOrLandowner(String userId);

  // Tasks
  Future<MaintenanceTaskModel> createTask(MaintenanceTaskModel task);
  Future<List<MaintenanceTaskModel>> getTasksByRequest(String requestId);
  Future<List<MaintenanceTaskModel>> getTasksByArtisan(String artisanId);
  Future<MaintenanceTaskModel> getTaskById(String taskId);
  Future<void> updateTask(MaintenanceTaskModel task);
  Future<void> acceptTask(String taskId, String artisanId);
  Future<void> declineTask(String taskId, String artisanId);
  Future<void> completeTask(String taskId, String summary, double? actualCost);

  Future<List<MaintenanceTaskModel>> getActiveTasksByArtisanAndProperty({
    required String artisanId,
    required String propertyId,
  });
}
