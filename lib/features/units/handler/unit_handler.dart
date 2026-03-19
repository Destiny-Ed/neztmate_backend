import 'dart:convert';
import 'package:neztmate_backend/features/units/models/unit_model.dart';
import 'package:neztmate_backend/features/units/repository/unit_repo.dart';
import 'package:shelf/shelf.dart';
import 'package:neztmate_backend/core/error.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

class UnitHandler {
  final UnitRepository unitRepository;

  UnitHandler(this.unitRepository);

  /// GET /units/property/<propertyId>
  Future<Response> getUnitsByProperty(Request request) async {
    try {
      final propertyId = request.params['propertyId'];
      if (propertyId == null) {
        return Response(400, body: jsonEncode({'message': 'Missing property ID'}));
      }

      final units = await unitRepository.getUnitsByProperty(propertyId);
      return Response.ok(
        jsonEncode({'units': units.map((u) => u.toMap()).toList()}),
        headers: {'Content-Type': 'application/json'},
      );
    } on AppException catch (e) {
      return Response(400, body: jsonEncode({'message': e.message}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to load units'}));
    }
  }

  /// GET /units/available
  /// Optional query params: ?propertyId=xxx&minBedrooms=2&maxRent=500000
  Future<Response> getAvailableUnits(Request request) async {
    try {
      final role = request.context['role'] as String?;

      if (role == 'tenant' || role == null) {
        // Tenant sees unit + property
        final unitsWithProperty = await unitRepository.getAvailableUnitsWithProperty();
        return Response.ok(jsonEncode({'units': unitsWithProperty.map((u) => u.toMap()).toList()}));
      } else {
        // Landowner/Manager sees unit + occupants + history
        final userId = request.context['userId'] as String;
        final ownerUnits = await unitRepository.getMyUnitsWithOccupants(userId, role);
        return Response.ok(jsonEncode({'units': ownerUnits.map((u) => u.toMap()).toList()}));
      }
    } catch (e) {
      return Response.internalServerError();
    }
  }

  /// GET /units/<id>
  Future<Response> getUnitById(Request request) async {
    try {
      final id = request.params['id'];
      if (id == null) {
        return Response(400, body: jsonEncode({'message': 'Missing unit ID'}));
      }

      final unit = await unitRepository.getUnitById(id);
      return Response.ok(jsonEncode({'unit': unit.toMap()}));
    } on NotFoundException catch (e) {
      return Response(404, body: jsonEncode({'message': e.message}));
    } catch (e) {
      return Response.internalServerError();
    }
  }

  /// POST /units (admin/landowner/manager only)
  Future<Response> createUnit(Request request) async {
    try {
      final role = request.context['role'] as String?;
      if (!['landowner', 'manager'].contains(role)) {
        return Response(403, body: jsonEncode({'message': 'Unauthorized to create unit'}));
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;

      body['createdAt'] = DateTime.now().toIso8601String();
      body['updatedAt'] = DateTime.now().toIso8601String();
      body['id'] = Uuid().v4();

      final unit = UnitModel.fromMap(body);

      final created = await unitRepository.createUnit(unit);
      return Response.ok(
        jsonEncode({'message': 'Unit created', 'unit': created.toMap()}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, s) {
      print("Unit creation error $e --- $s");
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to create unit'}));
    }
  }

  /// PATCH /units/<id>
  Future<Response> updateUnit(Request request) async {
    try {
      final id = request.params['id'];
      if (id == null) return Response(400, body: jsonEncode({'message': 'Missing unit ID'}));

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      body['updatedAt'] = DateTime.now().toIso8601String();

      final unit = UnitModel.fromMap(body);

      await unitRepository.updateUnit(unit);
      return Response.ok(jsonEncode({'message': 'Unit updated'}));
    } catch (e) {
      return Response.internalServerError();
    }
  }

  /// DELETE /units/<id>
  Future<Response> deleteUnit(Request request) async {
    try {
      final id = request.params['id'];
      if (id == null) return Response(400, body: jsonEncode({'message': 'Missing unit ID'}));

      await unitRepository.deleteUnit(id);
      return Response.ok(jsonEncode({'message': 'Unit deleted'}));
    } catch (e) {
      return Response.internalServerError();
    }
  }
}
