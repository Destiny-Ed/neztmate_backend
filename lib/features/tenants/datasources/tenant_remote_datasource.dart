import 'package:neztmate_backend/features/tenants/models/tenant_summary.dart';

abstract class TenantRemoteDataSource {
  Future<List<TenantSummary>> searchTenants({
    required String query,
    required String userId,
    required String role,
  });
}
