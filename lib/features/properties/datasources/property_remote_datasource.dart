import 'package:neztmate_backend/features/properties/models/property_model.dart';
import 'package:neztmate_backend/features/tenants/models/tenant_summary.dart';

abstract class PropertyRemoteDataSource {
  /// [property.partnerId] must be set by the handler from JWT / context
  Future<PropertyModel> createProperty(PropertyModel property);

  Future<PropertyModel> getPropertyById(String id);

  /// Public / tenant browse — always scope by partner
  Future<List<PropertyModel>> getAllAvailableProperties({required String partnerId});

  Future<List<PropertyModel>> getPropertiesByLandowner(String landownerId, {String? partnerId});

  Future<List<PropertyModel>> getPropertiesByManager(String managerId, {String? partnerId});

  Future<List<PropertyModel>> getPropertiesByArtisan(String artisanId, {String? partnerId});

  Future<void> updateProperty(PropertyModel property);

  Future<void> deleteProperty(String id);

  // Scoped via propertyId → property.partnerId (no extra param needed)
  Future<List<TenantSummary>> getTenantsByProperty(String propertyId);
  Future<List<TenantSummary>> getCurrentTenantsByProperty(String propertyId);
  Future<List<TenantSummary>> getPastTenantsByProperty(String propertyId);

  Future<void> assignUserToProperty({
    required String propertyId,
    required String userId,
    required String role, // Manager or Artisan
    String? commissionType,
    double? commissionRate,
    double? flatFeeAmount,
    String? flatFeePeriod,
  });

  Future<void> removeUserFromProperty({
    required String propertyId,
    required String userId,
    required String removedBy,
  });

  Future<int> countByOwner(String ownerId, {String? partnerId});
  Future<int> countManagersByOwner(String ownerId, {String? partnerId});
  Future<int> countArtisansByOwner(String ownerId, {String? partnerId});
}
