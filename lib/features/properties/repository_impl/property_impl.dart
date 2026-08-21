import 'package:neztmate_backend/features/properties/datasources/property_remote_datasource.dart';
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
  Future<List<PropertyModel>> getMyProperties(String userId, String role, {String? partnerId}) async {
    final r = role.toLowerCase();
    if (r == 'landowner') {
      return dataSource.getPropertiesByLandowner(userId, partnerId: partnerId);
    }
    if (r == 'manager') {
      return dataSource.getPropertiesByManager(userId, partnerId: partnerId);
    }
    if (r == 'artisan') {
      return dataSource.getPropertiesByArtisan(userId, partnerId: partnerId);
    }
    return [];
  }

  @override
  Future<List<PropertyModel>> getAllAvailableProperties({required String partnerId}) =>
      dataSource.getAllAvailableProperties(partnerId: partnerId);

  @override
  Future<void> updateProperty(PropertyModel property) => dataSource.updateProperty(property);

  @override
  Future<void> deleteProperty(String id) => dataSource.deleteProperty(id);

  @override
  Future<List<PropertyModel>> getPropertiesByLandowner(String landownerId, {String? partnerId}) =>
      dataSource.getPropertiesByLandowner(landownerId, partnerId: partnerId);

  @override
  Future<List<PropertyModel>> getPropertiesByManager(String managerId, {String? partnerId}) =>
      dataSource.getPropertiesByManager(managerId, partnerId: partnerId);

  @override
  Future<List<PropertyModel>> getPropertiesByArtisan(String artisanId, {String? partnerId}) =>
      dataSource.getPropertiesByArtisan(artisanId, partnerId: partnerId);

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
  Future<int> countArtisansByOwner(String ownerId, {String? partnerId}) =>
      dataSource.countArtisansByOwner(ownerId, partnerId: partnerId);

  @override
  Future<int> countByOwner(String ownerId, {String? partnerId}) =>
      dataSource.countByOwner(ownerId, partnerId: partnerId);

  @override
  Future<int> countManagersByOwner(String ownerId, {String? partnerId}) =>
      dataSource.countManagersByOwner(ownerId, partnerId: partnerId);
}
