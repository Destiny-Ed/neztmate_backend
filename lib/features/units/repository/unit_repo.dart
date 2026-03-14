import 'package:neztmate_backend/features/units/models/unit_model.dart';

abstract class UnitRepository {
  Future<UnitModel> createUnit(UnitModel unit);
  Future<UnitModel> getUnitById(String id);
  Future<List<UnitModel>> getUnitsByProperty(String propertyId);
  Future<List<UnitModel>> getAvailableUnitsByProperty({
    String? propertyId,
    int? minBedrooms,
    double? maxRent,
  });
  Future<void> updateUnit(UnitModel unit);
  Future<void> deleteUnit(String id);
}
