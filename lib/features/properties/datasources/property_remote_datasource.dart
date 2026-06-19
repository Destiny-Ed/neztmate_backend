import 'package:neztmate_backend/features/auth_user/models/user_model.dart';
import 'package:neztmate_backend/features/properties/models/artisan_with_stats.dart';
import 'package:neztmate_backend/features/properties/models/property_model.dart';
import 'package:neztmate_backend/features/tenants/models/tenant_summary.dart';

abstract class PropertyRemoteDataSource {
  Future<PropertyModel> createProperty(PropertyModel property);
  Future<PropertyModel> getPropertyById(String id);
  Future<List<PropertyModel>> getPropertiesByLandowner(String landownerId);
  Future<List<PropertyModel>> getPropertiesByManager(String managerId);
  Future<List<PropertyModel>> getPropertiesByArtisan(String artisanId);
  Future<List<PropertyModel>> getAllProperties(); // for tenants to browse
  Future<void> updateProperty(PropertyModel property);
  Future<void> deleteProperty(String id);
  Future<List<TenantSummary>> getTenantsByProperty(String propertyId);
  Future<List<TenantSummary>> getCurrentTenantsByProperty(String propertyId);
  Future<List<TenantSummary>> getPastTenantsByProperty(String propertyId);
  Future<void> assignUserToProperty({
    required String propertyId,
    required String userId,
    required String role, // Manager or Artisan
  });

  Future<void> removeUserFromProperty({
    required String propertyId,
    required String userId,
    required String removedBy, // Who performed the removal
  });

  /// Get all artisans assigned to a specific property
  Future<List<User>> getArtisansForProperty(String propertyId);

  /// Optional: Get artisans with their active tasks count
  Future<List<ArtisanWithStats>> getArtisansWithStatsForProperty(String propertyId);
}
