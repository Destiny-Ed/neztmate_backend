import 'package:neztmate_backend/features/tenants/models/tenant_summary.dart';

abstract class TenantRepository {
  Future<List<TenantSummary>> searchTenants({
    required String query,
    required String userId,
    required String role,
  });
}
