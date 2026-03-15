import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/features/auth_user/models/user_model.dart';
import 'package:neztmate_backend/features/auth_user/repositories/user_repository.dart';
import 'package:neztmate_backend/features/history/model/user_history_model.dart';
import 'package:neztmate_backend/features/history/repository/user_history_repo.dart';
import 'package:neztmate_backend/features/properties/datasources/property_remote_datasource.dart';
import 'package:neztmate_backend/features/properties/models/property_model.dart';
import 'package:neztmate_backend/features/units/datasource/unit_remote_datasource.dart';
import 'package:neztmate_backend/features/units/models/available_unit_response.dart';
import 'package:neztmate_backend/features/units/models/owner_unit_response.dart';
import 'package:neztmate_backend/features/units/models/unit_model.dart';
import 'package:neztmate_backend/features/units/repository/unit_repo.dart';

class UnitRepositoryImpl implements UnitRepository {
  final UnitRemoteDataSource unitDataSource;
  final PropertyRemoteDataSource propertyDataSource;
  final HistoryRepository historyRepository;
  final UserRepository userRepository; // to fetch tenant info

  UnitRepositoryImpl(
    this.unitDataSource,
    this.propertyDataSource,
    this.historyRepository,
    this.userRepository,
  );
  @override
  Future<UnitModel> createUnit(UnitModel unit) => unitDataSource.createUnit(unit);

  @override
  Future<UnitModel> getUnitById(String id) => unitDataSource.getUnitById(id);

  @override
  Future<List<UnitModel>> getUnitsByProperty(String propertyId) =>
      unitDataSource.getUnitsByProperty(propertyId);

  @override
  Future<List<UnitModel>> getAvailableUnitsByProperty(String propertyId) =>
      unitDataSource.getAvailableUnitsByProperty(propertyId);

  @override
  Future<List<UnitModel>> getAvailableUnits({String? propertyId, int? minBedrooms, double? maxRent}) =>
      unitDataSource.getAvailableUnits(propertyId: propertyId, minBedrooms: minBedrooms, maxRent: maxRent);

  @override
  Future<void> updateUnit(UnitModel unit) => unitDataSource.updateUnit(unit);

  @override
  Future<void> deleteUnit(String id) => unitDataSource.deleteUnit(id);

  @override
  Future<List<AvailableUnitResponse>> getAvailableUnitsWithProperty({
    String? propertyId,
    int? minBedrooms,
    double? maxRent,
  }) async {
    final units = await unitDataSource.getAvailableUnits(
      propertyId: propertyId,
      minBedrooms: minBedrooms,
      maxRent: maxRent,
    );

    final responses = <AvailableUnitResponse>[];
    for (var unit in units) {
      final property = await propertyDataSource.getPropertyById(unit.propertyId);
      responses.add(AvailableUnitResponse(unit, property));
    }
    return responses;
  }

  @override
  Future<List<OwnerUnitResponse>> getMyUnitsWithOccupants(String userId, String role) async {
    if (!['Landowner', 'Manager'].contains(role)) {
      throw ForbiddenException('Only Landowner or Manager can access occupant details');
    }

    // Step 1: Get all properties owned/managed by this user
    List<PropertyModel> properties;
    if (role == 'Landowner') {
      properties = await propertyDataSource.getPropertiesByLandowner(userId);
    } else {
      properties = await propertyDataSource.getPropertiesByManager(userId);
    }

    if (properties.isEmpty) return [];

    // Step 2: Collect all unit IDs from these properties
    final propertyIds = properties.map((p) => p.id).toList();

    // Step 3: Fetch all units under these properties
    final allUnits = <UnitModel>[];
    for (var propId in propertyIds) {
      final units = await unitDataSource.getUnitsByProperty(propId);
      allUnits.addAll(units);
    }

    // Step 4: Build enriched response for each unit
    final responses = <OwnerUnitResponse>[];

    for (var unit in allUnits) {
      User? currentTenant;
      List<HistoryEntryModel> occupantHistory = [];

      // Find active lease (current occupant)
      final activeLeases = await leaseRepository.getLeasesByUnit(unit.id);
      final activeLease = activeLeases.firstWhere(
        (l) => l.status == 'Active' && l.endDate.isAfter(DateTime.now()),
        orElse: () => null,
      );

      if (activeLease != null) {
        currentTenant = await userRepository.getUserById(activeLease.tenantId);
      }

      // Get occupant-related history (filter by lease/unit)
      final history = await historyRepository.getHistoryByRelatedId(
        unit.id,
        'units', // or 'leases' — depending on how you log
      );

      // Optional: filter history to lease-related only
      occupantHistory = history
          .where((h) => h.type.contains('lease') || h.relatedCollection == 'leases')
          .toList();

      responses.add(OwnerUnitResponse(unit, currentTenant, occupantHistory));
    }

    return responses;
  }
}
