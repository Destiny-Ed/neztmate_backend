import 'dart:math';

import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/features/auth_user/models/user_model.dart';
import 'package:neztmate_backend/features/auth_user/repositories/user_repository.dart';
import 'package:neztmate_backend/features/history/model/user_history_model.dart';
import 'package:neztmate_backend/features/history/repository/user_history_repo.dart';
import 'package:neztmate_backend/features/leases/repository/lease_repo.dart';
import 'package:neztmate_backend/features/properties/datasources/property_remote_datasource.dart';
import 'package:neztmate_backend/features/properties/models/property_model.dart';
import 'package:neztmate_backend/features/units/datasource/unit_remote_datasource.dart';
import 'package:neztmate_backend/features/units/models/available_unit_response.dart';
import 'package:neztmate_backend/features/units/models/owner_unit_response.dart';
import 'package:neztmate_backend/features/units/models/unit_comment_model.dart';
import 'package:neztmate_backend/features/units/models/unit_model.dart';
import 'package:neztmate_backend/features/units/repository/unit_repo.dart';

class UnitRepositoryImpl implements UnitRepository {
  final UnitRemoteDataSource unitDataSource;
  final PropertyRemoteDataSource propertyDataSource;
  final LeaseRepository leaseRepository;
  final HistoryRepository historyRepository;
  final UserRepository userRepository;

  UnitRepositoryImpl(
    this.unitDataSource,
    this.propertyDataSource,
    this.historyRepository,
    this.userRepository,
    this.leaseRepository,
  );

  @override
  Future<UnitModel> createUnit(UnitModel unit) async {
    // Ensure partnerId from parent property if missing
    if (unit.partnerId.isEmpty || unit.partnerId == 'neztmate') {
      final property = await propertyDataSource.getPropertyById(unit.propertyId);
      return unitDataSource.createUnit(unit.copyWith(partnerId: property.partnerId));
    }
    return unitDataSource.createUnit(unit);
  }

  @override
  Future<UnitModel> getUnitById(String id) => unitDataSource.getUnitById(id);

  @override
  Future<List<UnitModel>> getUnitsByProperty(String propertyId) =>
      unitDataSource.getUnitsByProperty(propertyId);

  @override
  Future<List<UnitModel>> getAvailableUnitsByProperty(String propertyId) =>
      unitDataSource.getAvailableUnitsByProperty(propertyId);

  @override
  Future<void> updateUnit(UnitModel unit) => unitDataSource.updateUnit(unit);

  @override
  Future<void> deleteUnit(String id) => unitDataSource.deleteUnit(id);

  @override
  Future<List<OwnerUnitResponse>> getMyUnitsWithOccupants(
    String userId,
    String role, {
    String? partnerId,
  }) async {
    final r = role.toLowerCase();
    if (!['landowner', 'manager'].contains(r)) {
      throw ForbiddenException('Only Landowner or Manager can access occupant details');
    }

    final List<PropertyModel> properties = r == 'landowner'
        ? await propertyDataSource.getPropertiesByLandowner(userId, partnerId: partnerId)
        : await propertyDataSource.getPropertiesByManager(userId, partnerId: partnerId);

    if (properties.isEmpty) return [];

    final responses = <OwnerUnitResponse>[];

    for (final property in properties) {
      final units = await unitDataSource.getUnitsByProperty(property.id);

      for (final unit in units) {
        User? currentTenant;
        List<HistoryEntryModel> occupantHistory = [];

        final activeLeases = await leaseRepository.getLeasesByUnit(unit.id);
        final active = activeLeases.where((l) {
          final status = l.status.toLowerCase();
          return status == 'active' || status == 'pending payment';
        }).toList();

        if (active.isNotEmpty) {
          final lease = active.first;
          if (lease.tenantId.isNotEmpty) {
            currentTenant = await userRepository.getUserById(lease.tenantId);
          }
        }

        final history = await historyRepository.getHistoryByRelatedId(unit.id, 'units');
        occupantHistory = history
            .where((h) => h.type.contains('lease') || h.relatedCollection == 'leases')
            .toList();

        responses.add(OwnerUnitResponse(unit, currentTenant, occupantHistory));
      }
    }

    return responses;
  }

  @override
  Future<void> toggleUnitListing(String unitId, bool isListed) =>
      unitDataSource.toggleUnitListing(unitId, isListed);

  @override
  Future<void> updateUnitStatus({
    required String unitId,
    required String status,
    String? currentTenantId,
    bool? isListedForRent,
  }) => unitDataSource.updateUnitStatus(
    unitId: unitId,
    status: status,
    currentTenantId: currentTenantId,
    isListedForRent: isListedForRent,
  );

  @override
  Future<void> addComment(UnitCommentModel comment) => unitDataSource.addComment(comment);

  @override
  Future<List<UnitCommentModel>> getCommentsForUnit(String unitId) =>
      unitDataSource.getCommentsForUnit(unitId);

  @override
  Future<void> toggleLike(String unitId, String userId) => unitDataSource.toggleLike(unitId, userId);

  @override
  Future<int> countByOwner(String ownerId, {String? partnerId}) =>
      unitDataSource.countByOwner(ownerId, partnerId: partnerId);

  @override
  Future<int> countListedByOwner(String ownerId, {String? partnerId}) =>
      unitDataSource.countListedByOwner(ownerId, partnerId: partnerId);

  @override
  Future<List<UnitModel>> getAvailableUnits({
    required String partnerId,
    String? propertyId,
    int? minBedrooms,
    double? maxRent,
    String? propertyType,
    int limit = 40,
  }) => unitDataSource.getAvailableUnits(
    partnerId: partnerId,
    propertyId: propertyId,
    minBedrooms: minBedrooms,
    maxRent: maxRent,
    limit: limit,
  );

  @override
  Future<List<AvailableUnitResponse>> getAvailableUnitsWithProperty({
    required String partnerId,
    String? propertyId,
    int? minBedrooms,
    double? maxRent,
    String? state,
    String? city,
    double? lat,
    double? lng,
    double radiusKm = 25,
    String? propertyType,
    int limit = 40,
  }) async {
    final units = await unitDataSource.getAvailableUnits(
      partnerId: partnerId,
      propertyId: propertyId,
      minBedrooms: minBedrooms,
      maxRent: maxRent,
      limit: limit * 3, // fetch extra before location filter
    );

    final responses = <AvailableUnitResponse>[];

    for (final unit in units) {
      if (minBedrooms != null && (unit.bedrooms ?? 0) < minBedrooms) continue;
      if (maxRent != null && unit.monthlyRent > maxRent) continue;

      final property = await propertyDataSource.getPropertyById(unit.propertyId);
      if (property.partnerId != partnerId) continue;

      if (propertyType != null &&
          propertyType.isNotEmpty &&
          property.type.toLowerCase() != propertyType.toLowerCase()) {
        continue;
      }
      if (state != null && state.isNotEmpty && (property.state ?? '').toLowerCase() != state.toLowerCase()) {
        continue;
      }
      if (city != null && city.isNotEmpty && (property.city ?? '').toLowerCase() != city.toLowerCase()) {
        continue;
      }
      if (lat != null && lng != null) {
        if (property.latitude == null || property.longitude == null) continue;
        final d = _haversineKm(lat, lng, property.latitude!, property.longitude!);
        if (d > radiusKm) continue;
      }

      responses.add(AvailableUnitResponse(unit, property));
      if (responses.length >= limit) break;
    }

    // Optional: sort by distance when geo used
    if (lat != null && lng != null) {
      responses.sort((a, b) {
        final da = _haversineKm(lat, lng, a.property.latitude!, a.property.longitude!);
        final db = _haversineKm(lat, lng, b.property.latitude!, b.property.longitude!);
        return da.compareTo(db);
      });
    }

    return responses;
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    double rad(double d) => d * 3.141592653589793 / 180;
    final dLat = rad(lat2 - lat1);
    final dLon = rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) + cos(rad(lat1)) * cos(rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }
}
