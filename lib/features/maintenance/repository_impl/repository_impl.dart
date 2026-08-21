import 'package:neztmate_backend/features/maintenance/datasource/maintenance_remote_datasource.dart';
import 'package:neztmate_backend/features/maintenance/models/maintenance_request.dart';
import 'package:neztmate_backend/features/maintenance/models/maintenance_task.dart';
import 'package:neztmate_backend/features/maintenance/repository/maintenance_repo.dart';

class MaintenanceRepositoryImpl implements MaintenanceRepository {
  final MaintenanceRemoteDataSource dataSource;

  MaintenanceRepositoryImpl(this.dataSource);

  @override
  Future<MaintenanceRequestModel> createRequest(MaintenanceRequestModel request) =>
      dataSource.createRequest(request);

  @override
  Future<MaintenanceRequestModel> getRequestById(String id) => dataSource.getRequestById(id);

  @override
  Future<List<MaintenanceRequestModel>> getRequestsByTenant(String tenantId, {String? partnerId}) =>
      dataSource.getRequestsByTenant(tenantId, partnerId: partnerId);

  @override
  Future<List<MaintenanceRequestModel>> getRequestsByProperty(String propertyId) =>
      dataSource.getRequestsByProperty(propertyId);

  @override
  Future<List<MaintenanceRequestModel>> getAllRequestsForManagerOrLandowner(
    String userId, {
    String? partnerId,
    String? role,
  }) => dataSource.getAllRequestsForManagerOrLandowner(userId, partnerId: partnerId, role: role);

  @override
  Future<MaintenanceTaskModel> createTask(MaintenanceTaskModel task) => dataSource.createTask(task);

  @override
  Future<MaintenanceTaskModel> getTaskById(String taskId) => dataSource.getTaskById(taskId);

  @override
  Future<List<MaintenanceTaskModel>> getTasksByRequest(String requestId) =>
      dataSource.getTasksByRequest(requestId);

  @override
  Future<List<MaintenanceTaskModel>> getTasksByArtisan(String artisanId, {String? partnerId}) =>
      dataSource.getTasksByArtisan(artisanId, partnerId: partnerId);

  @override
  Future<void> acceptTask(String taskId, String artisanId) => dataSource.acceptTask(taskId, artisanId);

  @override
  Future<void> declineTask(String taskId, String artisanId) => dataSource.declineTask(taskId, artisanId);

  @override
  Future<void> updateTask(MaintenanceTaskModel task) async {
    await dataSource.updateTask(task);
    final newRequestStatus = await dataSource.calculateRequestStatus(task.maintenanceRequestId);
    await dataSource.updateRequestStatus(task.maintenanceRequestId, newRequestStatus);
  }

  @override
  Future<void> completeTask(String taskId, String summary, double? actualCost) =>
      dataSource.completeTask(taskId, summary, actualCost);

  @override
  Future<List<MaintenanceTaskModel>> getActiveTasksByArtisanAndProperty({
    required String artisanId,
    required String propertyId,
  }) => dataSource.getActiveTasksByArtisanAndProperty(artisanId: artisanId, propertyId: propertyId);
}
