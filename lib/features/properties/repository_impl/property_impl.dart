import 'package:neztmate_backend/features/auth_user/models/user_model.dart';
import 'package:neztmate_backend/features/properties/datasources/property_remote_datasource.dart';
import 'package:neztmate_backend/features/properties/models/artisan_with_stats.dart';
import 'package:neztmate_backend/features/properties/models/property_model.dart';
import 'package:neztmate_backend/features/properties/repository/property_repo.dart';
import 'package:neztmate_backend/features/tenants/models/tenant_summary.dart';

class PropertyRepositoryImpl implements PropertyRepository {
  final PropertyRemoteDataSource dataSource;

  PropertyRepositoryImpl(this.dataSource);

  @override
  Future<PropertyModel> createProperty(PropertyModel property) => dataSource.createProperty(property);

  @override
  Future<PropertyModel> getPropertyById(String id) => dataSource.getPropertyById(id);

  @override
  Future<List<PropertyModel>> getMyProperties(String userId, String role) async {
    if (role == 'landowner') {
      return dataSource.getPropertiesByLandowner(userId);
    } else if (role == 'manager') {
      return dataSource.getPropertiesByManager(userId);
    } else if (role == 'artisan') {
      return dataSource.getPropertiesByArtisan(userId);
    }
    return [];
  }

  @override
  Future<List<PropertyModel>> getAllAvailableProperties() => dataSource.getAllProperties();

  @override
  Future<void> updateProperty(PropertyModel property) => dataSource.updateProperty(property);

  @override
  Future<void> deleteProperty(String id) => dataSource.deleteProperty(id);

  @override
  Future<List<PropertyModel>> getPropertiesByLandowner(String landownerId) =>
      dataSource.getPropertiesByLandowner(landownerId);

  @override
  Future<List<PropertyModel>> getPropertiesByManager(String managerId) =>
      dataSource.getPropertiesByManager(managerId);

  @override
  Future<List<TenantSummary>> getCurrentTenantsByProperty(String propertyId) =>
      dataSource.getCurrentTenantsByProperty(propertyId);

  @override
  Future<List<TenantSummary>> getPastTenantsByProperty(String propertyId) =>
      dataSource.getPastTenantsByProperty(propertyId);

  @override
  Future<List<TenantSummary>> getTenantsByProperty(String propertyId) =>
      dataSource.getTenantsByProperty(propertyId);

  @override
  Future<void> assignUserToProperty({
    required String propertyId,
    required String userId,
    required String role,
    String? commissionType,
    double? commissionRate,
    double? flatFeeAmount,
    String? flatFeePeriod,
  }) => dataSource.assignUserToProperty(
    propertyId: propertyId,
    userId: userId,
    role: role,
    commissionType: commissionType,
    commissionRate: commissionRate,
    flatFeeAmount: flatFeeAmount,
    flatFeePeriod: flatFeePeriod,
  );

  @override
  Future<void> removeUserFromProperty({
    required String propertyId,
    required String userId,
    required String removedBy,
  }) => dataSource.removeUserFromProperty(propertyId: propertyId, userId: userId, removedBy: removedBy);

  @override
  Future<List<PropertyModel>> getPropertiesByArtisan(String artisanId) =>
      dataSource.getPropertiesByManager(artisanId);
}
