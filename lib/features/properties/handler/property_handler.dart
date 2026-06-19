import 'dart:convert';
import 'package:neztmate_backend/features/auth_user/repositories/user_repository.dart';
import 'package:neztmate_backend/features/maintenance/repository/maintenance_repo.dart';
import 'package:neztmate_backend/features/notifications/models/notification_model.dart';
import 'package:neztmate_backend/features/notifications/repository/notification_repo.dart';
import 'package:neztmate_backend/features/properties/models/property_model.dart';
import 'package:neztmate_backend/features/properties/repository/property_repo.dart';
import 'package:shelf/shelf.dart';
import 'package:neztmate_backend/core/error.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

class PropertyHandler {
  final PropertyRepository propertyRepository;
  final UserRepository userRepository;
  final MaintenanceRepository maintenanceRepository;
  final NotificationRepository notificationRepository;

  PropertyHandler(
    this.propertyRepository,
    this.notificationRepository,
    this.userRepository,
    this.maintenanceRepository,
  );

  // GET /properties (my properties)
  /// GET /properties - Get all properties belonging to the current user (Landowner/Manager)
  /// Enriched with current and past tenants
  Future<Response> getMyProperties(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;

      if (userId == null || role == null) {
        return _unauthorized();
      }

      if (!['landowner', 'manager', 'artisan'].contains(role)) {
        return Response(
          403,
          body: jsonEncode({'message': 'Only landowners and managers can view properties'}),
        );
      }

      final properties = await propertyRepository.getMyProperties(userId, role);

      // Enrich each property with tenant information
      final enrichedProperties = await Future.wait(
        properties.map((property) async {
          try {
            final currentTenants = await propertyRepository.getCurrentTenantsByProperty(property.id);
            final pastTenants = await propertyRepository.getPastTenantsByProperty(property.id);

            return {
              ...property.toMap(),
              'currentTenants': currentTenants.map((t) => t.toMap()).toList(),
              'pastTenants': pastTenants.map((t) => t.toMap()).toList(),
              'totalCurrentTenants': currentTenants.length,
              'totalPastTenants': pastTenants.length,
            };
          } catch (e) {
            // Fallback if tenant fetching fails
            return {
              ...property.toMap(),
              'currentTenants': [],
              'pastTenants': [],
              'totalCurrentTenants': 0,
              'totalPastTenants': 0,
            };
          }
        }),
      );

      return Response.ok(
        jsonEncode({
          'properties': enrichedProperties,
          'message': 'Properties loaded successfully',
          'totalProperties': enrichedProperties.length,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } on AppException catch (e) {
      return Response(400, body: jsonEncode({'message': e.message, 'properties': []}));
    } catch (e, stack) {
      print('Get my properties error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to load properties'}));
    }
  }

  /// GET /properties/<id> - Get property with enriched details
  Future<Response> getPropertyById(Request request) async {
    try {
      final propertyId = request.params['id'];
      if (propertyId == null) {
        return Response(400, body: jsonEncode({'message': 'Property ID required'}));
      }

      final property = await propertyRepository.getPropertyById(propertyId);

      // Get tenants
      final currentTenants = await propertyRepository.getCurrentTenantsByProperty(propertyId);
      final pastTenants = await propertyRepository.getPastTenantsByProperty(propertyId);

      // Get Landowner details
      final landowner = await userRepository.getUserById(property.landownerId);

      // Get Manager details (if assigned)
      Map<String, dynamic>? manager;
      if (property.managerId != null) {
        final managerUser = await userRepository.getUserById(property.managerId!);
        manager = {
          'id': managerUser.id,
          'fullName': managerUser.fullName,
          'email': managerUser.email,
          'phone': managerUser.phone,
          'profilePhotoUrl': managerUser.profilePhotoUrl,
          'role': managerUser.role,
        };
      }

      // Get Artisans + Their Active Tasks
      List<Map<String, dynamic>> artisansWithTasks = [];
      if (property.artisanIds != null && property.artisanIds!.isNotEmpty) {
        for (var artisanId in property.artisanIds!) {
          final artisanUser = await userRepository.getUserById(artisanId);

          // Get active tasks for this artisan on this property
          final activeTasks = await maintenanceRepository.getActiveTasksByArtisanAndProperty(
            artisanId: artisanId,
            propertyId: propertyId,
          );

          artisansWithTasks.add({
            'id': artisanUser.id,
            'fullName': artisanUser.fullName,
            'email': artisanUser.email,
            'phone': artisanUser.phone,
            'profilePhotoUrl': artisanUser.profilePhotoUrl,
            'role': artisanUser.role,
            'activeTasksCount': activeTasks.length,
            // 'activeTasks': activeTasks.map((t) => t.toMap()).toList(),
          });
        }
      }

      final response = {
        ...property.toMap(),
        'currentTenants': currentTenants.map((t) => t.toMap()).toList(),
        'pastTenants': pastTenants.map((t) => t.toMap()).toList(),
        'totalCurrentTenants': currentTenants.length,
        'totalPastTenants': pastTenants.length,
        'landowner': {
          'id': landowner.id,
          'fullName': landowner.fullName,
          'email': landowner.email,
          'phone': landowner.phone,
          'profilePhotoUrl': landowner.profilePhotoUrl,
          'role': landowner.role,
        },
        'manager': manager,
        'artisans': artisansWithTasks,
        'totalArtisans': artisansWithTasks.length,
      };

      return Response.ok(jsonEncode({'property': response}), headers: {'Content-Type': 'application/json'});
    } catch (e, stack) {
      print('Get property by id error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to fetch property details'}));
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

  /// POST /properties/<propertyId>/remove-user
  Future<Response> removeUserFromProperty(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final propertyId = request.params['propertyId'];
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final targetUserId = body['userId'] as String?;

      if (userId == null || propertyId == null || targetUserId == null) {
        return badRequest('Missing required fields');
      }

      if (!['landowner', 'manager'].contains(role)) {
        return Response(403, body: jsonEncode({'message': 'Insufficient permission'}));
      }

      await propertyRepository.removeUserFromProperty(
        propertyId: propertyId,
        userId: targetUserId,
        removedBy: userId,
      );

      // Send notifications
      await notificationRepository.create(
        NotificationModel(
          userId: targetUserId,
          type: 'removed_from_property',
          title: 'Removed from Property',
          body: 'You have been removed from this property.',
          relatedId: propertyId,
          relatedCollection: 'properties',
          createdAt: DateTime.now(),
          id: '',
        ),
      );

      return Response.ok(jsonEncode({'message': 'User removed from property successfully'}));
    } catch (e, stack) {
      print('Remove user from property error: $e\n$stack');
      return Response.internalServerError();
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

  /// GET /properties/<id>/artisans
  Future<Response> getArtisansForProperty(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final propertyId = request.params['id'];

      if (userId == null || propertyId == null) {
        return badRequest('Property ID is required');
      }

      // Only landowner or manager of the property should access
      final property = await propertyRepository.getPropertyById(propertyId);

      final isAuthorized =
          property.landownerId == userId ||
          (property.managerId == userId) ||
          ['manager', 'landowner'].contains(role);

      if (!isAuthorized) {
        return Response(403, body: jsonEncode({'message': 'Access denied'}));
      }

      final artisansWithStats = await propertyRepository.getArtisansWithStatsForProperty(propertyId);

      return Response.ok(
        jsonEncode({
          'artisans': artisansWithStats.map((a) => a.toMap()).toList(),
          'totalArtisans': artisansWithStats.length,
          'message': 'Artisans fetched successfully',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Get artisans for property error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to fetch artisans'}));
    }
  }

  Response _unauthorized() => Response(401, body: jsonEncode({'message': 'Unauthorized'}));
}
