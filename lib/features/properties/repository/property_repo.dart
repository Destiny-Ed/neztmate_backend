import 'package:neztmate_backend/features/properties/models/property_model.dart';
import 'package:neztmate_backend/features/tenants/models/tenant_summary.dart';

abstract class PropertyRepository {
  Future<PropertyModel> createProperty(PropertyModel property);
  Future<PropertyModel> getPropertyById(String id);
  Future<List<PropertyModel>> getAllAvailableProperties();
  Future<List<PropertyModel>> getMyProperties(String userId, String role);
  Future<List<PropertyModel>> getPropertiesByLandowner(String landownerId);
  Future<List<PropertyModel>> getPropertiesByManager(String managerId);
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
}
