import 'dart:convert';
import 'package:neztmate_backend/core/di/injector.dart';
import 'package:neztmate_backend/core/services/subscription/subscription_limit_service.dart';
import 'package:neztmate_backend/core/utils.dart';
import 'package:neztmate_backend/features/auth_user/repositories/user_repository.dart';
import 'package:neztmate_backend/features/leases/service/lease_payment_calculator_service.dart';
import 'package:neztmate_backend/features/units/models/unit_comment_model.dart';
import 'package:neztmate_backend/features/units/models/unit_model.dart';
import 'package:neztmate_backend/features/units/repository/unit_repo.dart';
import 'package:shelf/shelf.dart';
import 'package:neztmate_backend/core/error.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

class UnitHandler {
  final UnitRepository unitRepository;
  final UserRepository userRepository;

  UnitHandler(this.unitRepository, this.userRepository);

  final subscriptionLimits = injector<SubscriptionLimitService>();

  /// GET /units/property/<propertyId>
  Future<Response> getUnitsByProperty(Request request) async {
    try {
      final propertyId = request.params['propertyId'];
      final role = request.context['role'] as String?;

      if (!['landowner', 'manager'].contains(role)) {
        return Response(403, body: jsonEncode({'message': 'Unauthorized to get property unit'}));
      }

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
  /// Query: propertyId, minBedrooms, maxRent, state, city, lat, lng, radiusKm, propertyType
  Future<Response> getAvailableUnits(Request request) async {
    try {
      final role = (request.context['role'] as String?)?.toLowerCase();
      final partnerId = request.context['partnerId'] as String?;
      final userId = request.context['userId'] as String?;

      if (partnerId == null || userId == null) {
        return badRequest('PartnerId and userId are required');
      }

      final q = request.url.queryParameters;
      final propertyId = q['propertyId'];
      final minBedrooms = int.tryParse(q['minBedrooms'] ?? '');
      final maxRent = double.tryParse(q['maxRent'] ?? '');
      final state = q['state'];
      final city = q['city'];
      final lat = double.tryParse(q['lat'] ?? '');
      final lng = double.tryParse(q['lng'] ?? '');
      final radiusKm = double.tryParse(q['radiusKm'] ?? '25') ?? 25;
      final propertyType = q['propertyType'];

      if (role == 'tenant' || role == null) {
        final fee = await getCurrentApplicationFee(partnerId);

        final int applicationFee = fee.enabled ? fee.amount.toInt() : 0;

        final unitsWithProperty = await unitRepository.getAvailableUnitsWithProperty(
          partnerId: partnerId,
          propertyId: propertyId,
          minBedrooms: minBedrooms,
          maxRent: maxRent,
          state: state,
          city: city,
          lat: lat,
          lng: lng,
          radiusKm: radiusKm,
          propertyType: propertyType,
        );

        return Response.ok(
          jsonEncode({
            'units': unitsWithProperty
                .map((u) => {...u.toMap(), 'unitApplicationFee': applicationFee})
                .toList(),
            'filters': {
              'state': state,
              'city': city,
              'lat': lat,
              'lng': lng,
              'radiusKm': radiusKm,
              'minBedrooms': minBedrooms,
              'maxRent': maxRent,
              'propertyType': propertyType,
            },
            'count': unitsWithProperty.length,
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Landowner / manager: own units with occupants
      final ownerUnits = await unitRepository.getMyUnitsWithOccupants(userId, role, partnerId: partnerId);
      return Response.ok(
        jsonEncode({'units': ownerUnits.map((u) => u.toMap()).toList()}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, s) {
      print('Error fetching available units: $e --- $s');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to load available units'}));
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
      final userId = request.context['userId'] as String?;
      final partnerId = request.context['partnerId'] as String?;

      final subscriptionPlan = request.context['subscriptionPlan'] as String;

      if (userId == null || role == null || partnerId == null) {
        return unauthorized('Unauthorized');
      }
      if (!['landowner', 'manager'].contains(role)) {
        return Response(403, body: jsonEncode({'message': 'Unauthorized to create unit'}));
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;

      //  Validation
      final validationErrors = _validateUnitBody(body);
      if (validationErrors.isNotEmpty) {
        return Response(400, body: jsonEncode({'message': 'Validation failed', 'errors': validationErrors}));
      }

      final user = await userRepository.getUserById(userId);

      if (user.verifiedIdentity != true) {
        return Response(
          403,
          body: jsonEncode({
            'message': 'Identity verification required',
            'code': 'IDENTITY_NOT_VERIFIED',
            'action': 'verify_identity',
          }),
        );
      }

      //  SUBSCRIPTION RESTRICTION

      await subscriptionLimits.assertCanCreateUnit(
        request: request,
        countUnits: () => unitRepository.countByOwner(userId, partnerId: partnerId),
      );

      body['createdAt'] = DateTime.now().toIso8601String();
      body['updatedAt'] = DateTime.now().toIso8601String();
      body['id'] = Uuid().v4();
      body['status'] ??= 'vacant';
      body['isListedForRent'] ??= false;
      body['durationMonths'] ??= 12;

      final unit = UnitModel.fromMap(body);

      final created = await unitRepository.createUnit(unit.copyWith(partnerId: partnerId));

      // Calculate and return cost breakdown
      final costBreakdown = LeasePaymentCalculatorService.calculateForUnit(
        unit: created,
        durationMonths: unit.durationMonths ?? 12,
      );

      return Response.ok(
        jsonEncode({
          'message': 'Unit created successfully',
          'unit': created.toMap(),
          'costBreakdown': costBreakdown,
        }),
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
      if (id == null) return badRequest('Missing unit ID');

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;

      // Validation
      final validationErrors = _validateUnitBody(body, isUpdate: true);
      if (validationErrors.isNotEmpty) {
        return Response(400, body: jsonEncode({'message': 'Validation failed', 'errors': validationErrors}));
      }

      body['updatedAt'] = DateTime.now().toIso8601String();

      final unit = UnitModel.fromMap(body, id: id);

      await unitRepository.updateUnit(unit);

      // Return cost breakdown
      final costBreakdown = LeasePaymentCalculatorService.calculateForUnit(
        unit: unit,
        durationMonths: unit.durationMonths ?? 12,
      );

      return Response.ok(
        jsonEncode({
          'message': 'Unit updated successfully',
          'unit': unit.toMap(),
          'costBreakdown': costBreakdown,
        }),
      );
    } catch (e, s) {
      print("Error updating unit: $e --- $s");
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to update unit'}));
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

  // lib/features/unit/handlers/unit_handler.dart
  Future<Response> toggleUnitListing(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final partnerId = request.context['partnerId'] as String?;
      final subscriptionPlan = request.context['subscriptionPlan'] as String;

      final unitId = request.params['id'];

      if (userId == null || unitId == null) {
        return Response(401, body: jsonEncode({'message': 'Unauthorized'}));
      }

      if (!['landowner', 'manager'].contains(role)) {
        return Response(
          403,
          body: jsonEncode({'message': 'Only Landowners and Managers can list/unlist units'}),
        );
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final isListed = body['isListed'] as bool?;

      if (isListed == null) {
        return Response(400, body: jsonEncode({'message': 'isListed field is required'}));
      }

      if (isListed) {
        // ========== SUBSCRIPTION RESTRICTION ==========

        await subscriptionLimits.assertCanListUnit(
          request: request,
          countListed: () => unitRepository.countByOwner(userId, partnerId: partnerId),
        );
      }

      await unitRepository.toggleUnitListing(unitId, isListed);

      final action = isListed ? 'listed' : 'unlisted';
      return Response.ok(
        jsonEncode({'message': 'Unit successfully $action for rent', 'unitId': unitId, 'isListed': isListed}),
        headers: {'Content-Type': 'application/json'},
      );
    } on NotFoundException catch (e) {
      return Response(404, body: jsonEncode({'message': e.message}));
    } on ValidationException catch (e) {
      return Response(400, body: jsonEncode({'message': e.message}));
    } catch (e, stack) {
      print('Toggle unit listing error: $e\n$stack');
      return Response.internalServerError(
        body: jsonEncode({'message': 'Failed to update unit listing status'}),
      );
    }
  }

  /// POST /units/<unitId>/like - Like a unit
  Future<Response> likeUnit(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final unitId = request.params['unitId'];

      if (userId == null || unitId == null) {
        return badRequest('Unit ID is required');
      }

      await unitRepository.toggleLike(unitId, userId);

      return Response.ok(jsonEncode({'message': 'Like updated successfully'}));
    } catch (e, s) {
      print("Comment like error $e\n$s");
      return Response.internalServerError();
    }
  }

  /// POST /units/<unitId>/comment - Comment on a unit
  Future<Response> commentOnUnit(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final partnerId = request.context['partnerId'] as String?;

      final unitId = request.params['unitId'];

      if (userId == null || unitId == null) {
        return badRequest('Unit ID is required');
      }

      if (partnerId == null) {
        return unauthorized("Unauthorized");
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final commentText = body['comment'] as String?;

      if (commentText == null || commentText.trim().isEmpty) {
        return badRequest('Comment cannot be empty');
      }

      final user = await userRepository.getUserById(userId);

      final comment = UnitCommentModel(
        id: '',
        unitId: unitId,
        userId: userId,
        partnerId: partnerId,
        userName: user.fullName,
        userPhotoUrl: user.profilePhotoUrl,
        comment: commentText.trim(),
        createdAt: DateTime.now(),
      );

      await unitRepository.addComment(comment);

      return Response.ok(jsonEncode({'message': 'Comment added successfully', 'comment': comment.toMap()}));
    } catch (e, s) {
      print("Error adding comments $e\n$s");

      return Response.internalServerError();
    }
  }

  /// GET /units/<unitId>/comments - Get comments for a unit
  Future<Response> getUnitComments(Request request) async {
    try {
      final unitId = request.params['unitId'];
      final userId = request.context['userId'] as String?;

      if (unitId == null || userId == null) return badRequest('Unit ID is required');

      final comments = await unitRepository.getCommentsForUnit(unitId);

      return Response.ok(
        jsonEncode({
          'unitId': unitId,
          'commentsCount': comments.length,
          'comments': comments.map((c) => c.toMap()).toList(),
        }),
      );
    } catch (e, s) {
      print("Error getting comments $e\n$s");
      return Response.internalServerError();
    }
  }

  List<String> _validateUnitBody(Map<String, dynamic> body, {bool isUpdate = false}) {
    final errors = <String>[];

    // Required fields for creation
    if (!isUpdate) {
      if (body['propertyId'] == null || body['propertyId'].toString().trim().isEmpty) {
        errors.add('propertyId is required');
      }
      if (body['unitNumber'] == null || body['unitNumber'].toString().trim().isEmpty) {
        errors.add('unitNumber is required');
      }
      if (body['monthlyRent'] == null || (body['monthlyRent'] as num) <= 0) {
        errors.add('monthlyRent must be greater than 0');
      }
    }

    // Common validations
    if (body['monthlyRent'] != null) {
      final rent = body['monthlyRent'] as num?;
      if (rent != null && rent <= 0) {
        errors.add('monthlyRent must be greater than 0');
      }
    }

    // Duration validation
    if (body['durationMonths'] != null) {
      final months = body['durationMonths'] as int?;
      if (months != null) {
        if (months < 1) errors.add('durationMonths must be at least 1');
        if (months > 60) errors.add('durationMonths cannot exceed 60 months (5 years)');
      }
    }

    // Images validation
    if (body['photoUrls'] != null) {
      final photos = body['photoUrls'] as List<dynamic>?;
      if (photos != null) {
        if (photos.isEmpty) {
          errors.add('At least one photo is required');
        } else if (photos.length > 10) {
          errors.add('Maximum 10 photos allowed');
        }
      }
    } else if (!isUpdate) {
      errors.add('photoUrls is required');
    }

    // Video validation (optional but size/type check)
    if (body['videoUrl'] != null) {
      final video = body['videoUrl'] as String?;
      if (video != null && video.isNotEmpty) {
        if (!video.startsWith('http')) {
          errors.add('videoUrl must be a valid URL');
        }
      }
    }

    // // Status validation
    // if (body['status'] != null) {
    //   final validStatuses = ['vacant', 'occupied', 'maintenance', 'reserved'];
    //   if (!validStatuses.contains(body['status'])) {
    //     errors.add('status must be one of: vacant, occupied, maintenance, reserved');
    //   }
    // }

    return errors;
  }
}
