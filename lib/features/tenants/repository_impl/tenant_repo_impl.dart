import 'package:neztmate_backend/features/tenants/datasources/tenant_remote_datasource.dart';
import 'package:neztmate_backend/features/tenants/models/tenant_neightbor.dart';
import 'package:neztmate_backend/features/tenants/models/tenant_summary.dart';
import 'package:neztmate_backend/features/tenants/repository/tenant_respository.dart';

class TenantRepositoryImpl implements TenantRepository {
  final TenantRemoteDataSource dataSource;

  TenantRepositoryImpl(this.dataSource);

  @override
  Future<List<TenantSummary>> searchTenants({
    required String query,
    required String userId,
    required String role,
  }) async {
    return await dataSource.searchTenants(query: query, userId: userId, role: role);
  }

  @override
  Future<List<NeighborModel>> getTenantNeighbors(String propertyId, String tenantId) =>
      dataSource.getTenantNeighbors(propertyId, tenantId);
}
