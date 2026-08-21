import 'package:neztmate_backend/features/applications/datasource/application_remote_datasource.dart';
import 'package:neztmate_backend/features/applications/models/application_model.dart';
import 'package:neztmate_backend/features/applications/repository/application_repo.dart';

class ApplicationRepositoryImpl implements ApplicationRepository {
  final ApplicationRemoteDataSource dataSource;

  ApplicationRepositoryImpl(this.dataSource);

  @override
  Future<ApplicationModel> createApplication(ApplicationModel application) =>
      dataSource.createApplication(application);

  @override
  Future<ApplicationModel> getApplicationById(String id) => dataSource.getApplicationById(id);

  @override
  Future<List<ApplicationModel>> getApplicationsByTenant(String tenantId, {String? partnerId}) =>
      dataSource.getApplicationsByTenant(tenantId, partnerId: partnerId);

  @override
  Future<List<ApplicationModel>> getApplicationsByUnit(String unitId) =>
      dataSource.getApplicationsByUnit(unitId);

  @override
  Future<void> updateApplication(ApplicationModel application) => dataSource.updateApplication(application);

  @override
  Future<void> deleteApplication(String id) => dataSource.deleteApplication(id);

  @override
  Future<ApplicationModel> approveApplication(String id, String reviewedBy) =>
      dataSource.approveApplication(id, reviewedBy);

  @override
  Future<void> rejectApplication(String id, String reviewedBy, String? reason) =>
      dataSource.rejectApplication(id, reviewedBy, reason);

  @override
  Future<void> withdrawApplication(String id, String tenantId, String? reason) =>
      dataSource.withdrawApplication(id, tenantId, reason);

  @override
  Future<List<ApplicationModel>> getApplicationsForManagerOrOwner(
    String userId,
    String role, {
    String? partnerId,
  }) => dataSource.getApplicationsForManagerOrOwner(userId, role, partnerId: partnerId);
}
