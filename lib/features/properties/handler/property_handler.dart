import 'dart:convert';
import 'dart:developer';
import 'package:neztmate_backend/features/properties/models/property_model.dart';
import 'package:neztmate_backend/features/properties/repository/property_repo.dart';
import 'package:shelf/shelf.dart';
import 'package:neztmate_backend/core/error.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

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
      return Response(400, body: jsonEncode({'message': e.message, 'properties': []}));
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
      return Response(404, body: jsonEncode({'message': e.message, 'property': {}}));
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

      if (body['name'] == null) {
        return badRequest("Property name is required");
      }
      if (body['address'] == null) {
        return badRequest("Property address is required");
      }
      if (body['proofOfOwnershipUrl'] == null) {
        return badRequest("Property proof of ownership is required");
      }

      if (body['photoUrls'] == null) {
        return badRequest("Photo Urls is required");
      }

      final photos = body['photoUrls'] as List<dynamic>;

      if (photos.isEmpty) {
        return badRequest("Photos is required");
      }

      if (body['totalUnits'] == null || body['totalUnits'].runtimeType != int) {
        return badRequest("Total units must be an integer");
      }

      body['createdAt'] = DateTime.now().toIso8601String();
      body['updatedAt'] = DateTime.now().toIso8601String();
      body['id'] = Uuid().v4();
      final property = PropertyModel.fromMap(body);

      final created = await propertyRepository.createProperty(property);
      return Response.ok(jsonEncode({'message': 'Property created', 'property': created.toMap()}));
    } catch (e, s) {
      print("Error creating property : $e === $s");
      return Response.internalServerError();
    }
  }

  // PATCH /properties/<id>
  Future<Response> updateProperty(Request request) async {
    try {
      final propertyId = request.params['id'];
      if (propertyId == null || propertyId.isEmpty) {
        return Response(400, body: jsonEncode({'message': 'Property ID is required'}));
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;

      // Basic validation
      if (body['name'] == null || (body['name'] as String).trim().isEmpty) {
        return badRequest('Property name is required');
      }
      if (body['address'] == null || (body['address'] as String).trim().isEmpty) {
        return badRequest('Property address is required');
      }
      if (body['proofOfOwnershipUrl'] == null || (body['proofOfOwnershipUrl'] as String).trim().isEmpty) {
        return badRequest('Proof of ownership URL is required');
      }

      // Get existing property first
      final existingProperty = await propertyRepository.getPropertyById(propertyId);

      // Prepare photo URLs safely
      List<String> photoUrls = [];
      if (body['photoUrls'] != null) {
        photoUrls = (body['photoUrls'] as List<dynamic>).cast<String>();
      }

      if (photoUrls.isEmpty) {
        return badRequest('At least one photo URL is required');
      }

      // Create updated property using copyWith
      final updatedProperty = existingProperty.copyWith(
        name: body['name'] as String,
        address: body['address'] as String,
        proofOfOwnershipUrl: body['proofOfOwnershipUrl'] as String,
        photoUrls: photoUrls,
        totalUnits: body['totalUnits'] as int?,
        amenities: body['amenities'] != null ? (body['amenities'] as List<dynamic>).cast<String>() : null,
        updatedAt: DateTime.now(),
      );

      print("Updating property: ${updatedProperty.toMap()}");

      // Perform the update
      await propertyRepository.updateProperty(updatedProperty);

      return Response.ok(
        jsonEncode({'message': 'Property updated successfully', 'property': updatedProperty.toMap()}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print("Error updating property: $e");
      print("Stack trace: $stack");

      if (e is NotFoundException) {
        return Response(404, body: jsonEncode({'message': e.message}));
      }
      if (e is ValidationException) {
        return Response(400, body: jsonEncode({'message': e.message}));
      }

      return Response.internalServerError(body: jsonEncode({'message': 'Failed to update property'}));
    }
  }

  // DELETE /properties/<id>
  Future<Response> deleteProperty(Request request) async {
    try {
      final id = request.params['id'];
      if (id == null) return Response(400, body: jsonEncode({'message': 'Missing Property ID'}));

      await propertyRepository.deleteProperty(id);
      return Response.ok(jsonEncode({'message': 'Property deleted'}));
    } catch (e) {
      return Response.internalServerError();
    }
  }

  Response _unauthorized() => Response(401, body: jsonEncode({'message': 'Unauthorized'}));
}
