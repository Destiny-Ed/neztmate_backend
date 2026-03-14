import 'package:neztmate_backend/features/properties/models/property_model.dart';

abstract class PropertyRemoteDataSource {
  Future<PropertyModel> createProperty(PropertyModel property);
  Future<PropertyModel> getPropertyById(String id);
  Future<List<PropertyModel>> getPropertiesByLandowner(String landownerId);
  Future<List<PropertyModel>> getPropertiesByManager(String managerId);
  Future<List<PropertyModel>> getAllProperties(); // for tenants to browse
  Future<void> updateProperty(PropertyModel property);
  Future<void> deleteProperty(String id);
}
