import 'package:neztmate_backend/features/applications/datasource/application_remote_datasource.dart';
import 'package:neztmate_backend/features/applications/models/application_model.dart';
import 'package:neztmate_backend/features/applications/repository/application_repo.dart';

class ApplicationRepositoryImpl implements ApplicationRepository {
  final ApplicationRemoteDataSource dataSource;

  ApplicationRepositoryImpl(this.dataSource);

  @override
  Future<ApplicationModel> createApplication(ApplicationModel application) async {
    return await dataSource.createApplication(application);
  }

  @override
  Future<ApplicationModel> getApplicationById(String id) async {
    return await dataSource.getApplicationById(id);
  }

  @override
  Future<List<ApplicationModel>> getApplicationsByTenant(String tenantId) async {
    return await dataSource.getApplicationsByTenant(tenantId);
  }

  @override
  Future<List<ApplicationModel>> getApplicationsByUnit(String unitId) async {
    return await dataSource.getApplicationsByUnit(unitId);
  }

  @override
  Future<void> updateApplication(ApplicationModel application) async {
    await dataSource.updateApplication(application);
  }

  @override
  Future<void> deleteApplication(String id) async {
    await dataSource.deleteApplication(id);
  }

  @override
  Future<void> approveApplication(String id, String reviewedBy) async {
    await dataSource.approveApplication(id, reviewedBy);
  }

  @override
  Future<void> rejectApplication(String id, String reviewedBy, String? reason) async {
    await dataSource.rejectApplication(id, reviewedBy, reason);
  }
}
