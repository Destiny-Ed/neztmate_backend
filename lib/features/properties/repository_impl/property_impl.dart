import 'package:neztmate_backend/features/properties/datasources/property_remote_datasource.dart';
import 'package:neztmate_backend/features/properties/models/property_model.dart';
import 'package:neztmate_backend/features/properties/repository/property_repo.dart';

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
}
