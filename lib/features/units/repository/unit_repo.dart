import 'package:neztmate_backend/features/units/models/available_unit_response.dart';
import 'package:neztmate_backend/features/units/models/owner_unit_response.dart';
import 'package:neztmate_backend/features/units/models/unit_comment_model.dart';
import 'package:neztmate_backend/features/units/models/unit_model.dart';

abstract class UnitRepository {
  Future<UnitModel> createUnit(UnitModel unit);
  Future<UnitModel> getUnitById(String id);
  Future<List<UnitModel>> getUnitsByProperty(String propertyId);
  Future<List<UnitModel>> getAvailableUnitsByProperty(String propertyId);

  Future<List<UnitModel>> getAvailableUnits({
    required String partnerId,
    String? propertyId,
    int? minBedrooms,
    double? maxRent,
  });

  Future<void> updateUnit(UnitModel unit);
  Future<void> deleteUnit(String id);

  Future<List<AvailableUnitResponse>> getAvailableUnitsWithProperty({
    required String partnerId,
    String? propertyId,
    int? minBedrooms,
    double? maxRent,
  });

  Future<List<OwnerUnitResponse>> getMyUnitsWithOccupants(String userId, String role, {String? partnerId});

  Future<void> toggleUnitListing(String unitId, bool isListed);
  Future<void> updateUnitStatus({
    required String unitId,
    required String status,
    String? currentTenantId,
    bool? isListedForRent,
  });

  Future<void> toggleLike(String unitId, String userId);
  Future<void> addComment(UnitCommentModel comment);
  Future<List<UnitCommentModel>> getCommentsForUnit(String unitId);

  Future<int> countByOwner(String ownerId, {String? partnerId});
  Future<int> countListedByOwner(String ownerId, {String? partnerId});
}
