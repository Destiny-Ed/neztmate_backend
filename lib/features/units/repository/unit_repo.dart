import 'package:neztmate_backend/features/units/models/available_unit_response.dart';
import 'package:neztmate_backend/features/units/models/owner_unit_response.dart';
import 'package:neztmate_backend/features/units/models/unit_model.dart';

abstract class UnitRepository {
  Future<UnitModel> createUnit(UnitModel unit);
  Future<UnitModel> getUnitById(String id);
  Future<List<UnitModel>> getUnitsByProperty(String propertyId);
  Future<List<UnitModel>> getAvailableUnitsByProperty(String propertyId);
  Future<List<UnitModel>> getAvailableUnits({String? propertyId, int? minBedrooms, double? maxRent});
  Future<void> updateUnit(UnitModel unit);
  Future<void> deleteUnit(String id);
  // Tenant view
  Future<List<AvailableUnitResponse>> getAvailableUnitsWithProperty({
    String? propertyId,
    int? minBedrooms,
    double? maxRent,
  });

  // Landowner/Manager view
  Future<List<OwnerUnitResponse>> getMyUnitsWithOccupants(String userId, String role);
  Future<void> toggleUnitListing(String unitId, bool isListed);
  Future<void> updateUnitStatus({
    required String unitId,
    required String status,
    String? currentTenantId,
    bool? isListedForRent,
  });
}
