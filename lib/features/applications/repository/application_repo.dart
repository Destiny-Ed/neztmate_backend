import 'package:neztmate_backend/features/applications/models/application_model.dart';

abstract class ApplicationRepository {
  Future<ApplicationModel> createApplication(ApplicationModel application);
  Future<ApplicationModel> getApplicationById(String id);
  Future<List<ApplicationModel>> getApplicationsByTenant(String tenantId);
  Future<List<ApplicationModel>> getApplicationsByUnit(String unitId);
  Future<void> updateApplication(ApplicationModel application);
  Future<void> deleteApplication(String id);
  Future<void> approveApplication(String id, String reviewedBy);
  Future<void> rejectApplication(String id, String reviewedBy, String? reason);
  Future<void> withdrawApplication(String id, String tenantId, String? reason);
}
