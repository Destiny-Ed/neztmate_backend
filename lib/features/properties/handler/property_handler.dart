import 'dart:convert';
import 'package:neztmate_backend/features/properties/models/property_model.dart';
import 'package:neztmate_backend/features/properties/repository/property_repo.dart';
import 'package:shelf/shelf.dart';
import 'package:neztmate_backend/core/error.dart';
import 'package:shelf_router/shelf_router.dart';

class PropertyHandler {
  final PropertyRepository propertyRepository;

  PropertyHandler(this.propertyRepository);

  // GET /properties (my properties)
  Future<Response> getMyProperties(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      if (userId == null || role == null) return _unauthorized();

      final properties = await propertyRepository.getMyProperties(userId, role);
      return Response.ok(jsonEncode({'properties': properties.map((p) => p.toMap()).toList()}));
    } on AppException catch (e) {
      return Response(400, body: jsonEncode({'message': e.message}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to load properties'}));
    }
  }

  // GET /properties/<id>
  Future<Response> getPropertyById(Request request) async {
    try {
      final id = request.params['id'];
      if (id == null) return Response(400, body: jsonEncode({'message': 'Missing property ID'}));

      final property = await propertyRepository.getPropertyById(id);
      return Response.ok(jsonEncode({'property': property.toMap()}));
    } on NotFoundException catch (e) {
      return Response(404, body: jsonEncode({'message': e.message}));
    } catch (e) {
      return Response.internalServerError();
    }
  }

  // POST /properties (only Landowner)
  Future<Response> createProperty(Request request) async {
    try {
      final role = request.context['role'] as String?;
      if (role != 'landowner') {
        return Response(403, body: jsonEncode({'message': 'Only landowners can create properties'}));
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final property = PropertyModel.fromMap(body, '');

      final created = await propertyRepository.createProperty(property);
      return Response.ok(jsonEncode({'message': 'Property created', 'property': created.toMap()}));
    } catch (e) {
      return Response.internalServerError();
    }
  }

  // PATCH /properties/<id>
  Future<Response> updateProperty(Request request) async {
    try {
      final id = request.params['id'];
      if (id == null) return Response(400, body: jsonEncode({'message': 'Missing ID'}));

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final property = PropertyModel.fromMap(body, id);

      await propertyRepository.updateProperty(property);
      return Response.ok(jsonEncode({'message': 'Property updated'}));
    } catch (e) {
      return Response.internalServerError();
    }
  }

  // DELETE /properties/<id>
  Future<Response> deleteProperty(Request request) async {
    try {
      final id = request.params['id'];
      if (id == null) return Response(400, body: jsonEncode({'message': 'Missing ID'}));

      await propertyRepository.deleteProperty(id);
      return Response.ok(jsonEncode({'message': 'Property deleted'}));
    } catch (e) {
      return Response.internalServerError();
    }
  }

  Response _unauthorized() => Response(401, body: jsonEncode({'message': 'Unauthorized'}));
}
