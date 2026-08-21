import 'package:neztmate_backend/features/tenants/models/tenant_neightbor.dart';
import 'package:neztmate_backend/features/tenants/models/tenant_summary.dart';

abstract class TenantRepository {
  Future<List<TenantSummary>> searchTenants({
    required String query,
    required String userId,
    required String role,
    String? partnerId,
  });

  /// Scoped by propertyId (property already belongs to a partner)
  Future<List<NeighborModel>> getTenantNeighbors(String propertyId, String tenantId);
}
