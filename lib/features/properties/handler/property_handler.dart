import 'dart:convert';
import 'package:neztmate_backend/features/auth_user/repositories/user_repository.dart';
import 'package:neztmate_backend/features/leases/models/lease_request_model.dart';
import 'package:neztmate_backend/features/leases/repository/lease_repo.dart';
import 'package:neztmate_backend/features/maintenance/repository/maintenance_repo.dart';
import 'package:neztmate_backend/features/notifications/models/notification_model.dart';
import 'package:neztmate_backend/features/notifications/repository/notification_repo.dart';
import 'package:neztmate_backend/features/payments/repository/payment_repo.dart';
import 'package:neztmate_backend/features/properties/models/property_model.dart';
import 'package:neztmate_backend/features/properties/repository/property_repo.dart';
import 'package:neztmate_backend/features/units/models/unit_model.dart';
import 'package:neztmate_backend/features/units/repository/unit_repo.dart';
import 'package:shelf/shelf.dart';
import 'package:neztmate_backend/core/error.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

class PropertyHandler {
  final PropertyRepository propertyRepository;
  final UserRepository userRepository;
  final MaintenanceRepository maintenanceRepository;
  final UnitRepository unitRepository;
  final PaymentRepository paymentRepository;
  final NotificationRepository notificationRepository;
  final LeaseRepository leaseRepository;

  PropertyHandler(
    this.propertyRepository,
    this.notificationRepository,
    this.userRepository,
    this.maintenanceRepository,
    this.unitRepository,
    this.paymentRepository,
    this.leaseRepository,
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
            final units = await unitRepository.getUnitsByProperty(property.id);

            return {
              ...property.copyWith(totalUnits: units.length).toMap(),
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
  /// GET /properties/<id> - Get property with fully enriched details
  Future<Response> getPropertyById(Request request) async {
    try {
      final currentUserId = request.context['userId'] as String?;
      final userRole = request.context['role'] as String?;
      final propertyId = request.params['id'];

      if (propertyId == null) {
        return badRequest('Property ID is required');
      }

      if (currentUserId == null) {
        return unauthorized('unauthorized');
      }

      final property = await propertyRepository.getPropertyById(propertyId);

      // Fetch common data
      final currentTenants = await propertyRepository.getCurrentTenantsByProperty(propertyId);
      final pastTenants = await propertyRepository.getPastTenantsByProperty(propertyId);

      final landowner = await userRepository.getUserById(property.landownerId);

      // Manager details
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

      // Artisans list (visible to Landowner & Manager)
      List<Map<String, dynamic>> artisansWithTasks = [];
      if (['landowner', 'manager'].contains(userRole) &&
          property.artisanIds != null &&
          property.artisanIds!.isNotEmpty) {
        for (var artisanId in property.artisanIds!) {
          final artisanUser = await userRepository.getUserById(artisanId);

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
          });
        }
      }

      //  ARTISAN-SPECIFIC ENRICHMENT
      List<Map<String, dynamic>> myAssignedTasks = [];
      if (userRole == 'artisan') {
        final tasks = await maintenanceRepository.getActiveTasksByArtisanAndProperty(
          artisanId: currentUserId,
          propertyId: propertyId,
        );

        myAssignedTasks = tasks.map((task) => task.toMap()).toList();
        // final enrichedTask = await Future.wait(
        //   tasks.map((task) async {
        //     final maintenance = await maintenanceRepository.getRequestById(task.maintenanceRequestId);
        //     final unit = await unitRepository.getUnitById(maintenance.unitId);
        //     return {...task.toMap(), 'unit': unit.unitNumber, 'urgency': maintenance.priority};
        //   }),
        // );

        // myAssignedTasks = enrichedTask;
      }

      // Build final response
      final response = {
        ...property.toMap(),
        'landowner': {
          'id': landowner.id,
          'fullName': landowner.fullName,
          'email': landowner.email,
          'phone': landowner.phone,
          'profilePhotoUrl': landowner.profilePhotoUrl,
          'role': landowner.role,
        },
        'manager': manager,

        // Landowner / Manager only data
        if (['landowner', 'manager'].contains(userRole)) ...{
          'currentTenants': currentTenants.map((t) => t.toMap()).toList(),
          'pastTenants': pastTenants.map((t) => t.toMap()).toList(),
          'totalCurrentTenants': currentTenants.length,
          'totalPastTenants': pastTenants.length,
          'artisans': artisansWithTasks,
          'totalArtisans': artisansWithTasks.length,
        },

        // Artisan only data
        if (userRole == 'artisan') ...{
          'myAssignedTasks': myAssignedTasks,
          'myActiveTasksCount': myAssignedTasks.length,
        },
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
      final subscriptionPlan = request.context['subscriptionPlan'] as String;
      final partnerId = request.context['partnerId'] as String?;
      if (role != 'landowner') {
        return Response(403, body: jsonEncode({'message': 'Only landowners can create properties'}));
      }

      final landownerId = request.context['userId'] as String?;
      if (landownerId == null || partnerId == null) {
        return Response(400, body: jsonEncode({'message': 'Landowner ID and parnerId are required'}));
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;

      if (body['name'] == null) {
        return badRequest("Property name is required");
      }
      if (body['address'] == null) {
        return badRequest("Property address is required");
      }
      if (body['documents'] == null) {
        return badRequest("Property documents is required");
      }

      if (body['photoUrls'] == null) {
        return badRequest("Photo Urls is required");
      }

      final photos = body['photoUrls'] as List<dynamic>;

      if (photos.isEmpty) {
        return badRequest("Photos is required");
      }

      final documents = body['documents'] as List<dynamic>;

      if (documents.isEmpty) {
        return badRequest("Property Documents is required");
      }

      if (body['totalUnits'] == null || body['totalUnits'].runtimeType != int) {
        return badRequest("Total units must be an integer");
      }

      // ========== SUBSCRIPTION RESTRICTION ==========

      final currentPropertyCount = await propertyRepository.countByOwner(landownerId);

      final maxProperties = _getMaxProperties(subscriptionPlan);

      if (currentPropertyCount >= maxProperties) {
        return Response(
          403,
          body: jsonEncode({
            'message':
                'You have reached the maximum number of properties allowed on the $subscriptionPlan plan ($maxProperties). Please upgrade your subscription.',
            'currentCount': currentPropertyCount,
            'maxAllowed': maxProperties,
            'plan': subscriptionPlan,
            'upgradeUrl': '/subscriptions/plans',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }
      //

      body['createdAt'] = DateTime.now().toIso8601String();
      body['updatedAt'] = DateTime.now().toIso8601String();
      body['id'] = Uuid().v4();
      final property = PropertyModel.fromMap(body);

      //Check if payout account is linked for the landowner

      final payoutAccounts = await paymentRepository.getDefaultPayoutAccount(landownerId);
      if (payoutAccounts == null) {
        return Response(
          400,
          body: jsonEncode({'message': 'Please link a payout account before creating a property'}),
        );
      }

      final created = await propertyRepository.createProperty(property.copyWith(partnerId: partnerId));
      return Response.ok(jsonEncode({'message': 'Property created', 'property': created.toMap()}));
    } catch (e, s) {
      print("Error creating property : $e  $s");
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

      // Prepare photo URLs safely
      List<Map<String, dynamic>> documents = [];
      if (body['documents'] != null) {
        documents = (body['documents'] as List<dynamic>).cast<Map<String, dynamic>>();
      }

      if (documents.isEmpty) {
        return badRequest('At least one document type is required');
      }

      // Create updated property using copyWith
      final updatedProperty = existingProperty.copyWith(
        name: body['name'] as String,
        address: body['address'] as String,
        documents: documents,
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
      final partnerId = request.context['partnerId'] as String?;
      final propertyId = request.params['propertyId'];
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final targetUserId = body['userId'] as String?;

      if (userId == null || propertyId == null || targetUserId == null) {
        return badRequest('Missing required fields');
      }

      if (partnerId == null) {
        return badRequest("Partner Id is required");
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
          partnerId: partnerId,
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
            'primarySkill': artisanUser.primarySkill,
            'rating': artisanUser.rating,
            "completedTasksCount": activeTasks.where((e) => e.status == 'Completed').length,
          });
        }
      }

      return Response.ok(
        jsonEncode({
          'artisans': artisansWithTasks,
          'totalArtisans': artisansWithTasks.length,
          'message': 'Artisans fetched successfully',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Get artisans for property error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to fetch artisans'}));
    }
  }

  /// POST /properties/<id>/adjust-terms
  /// Bulk: one rentAdjustment request per active lease on this property.
  Future<Response> proposePropertyTermsAdjustment(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final partnerId = request.context['partnerId'] as String?;
      final propertyId = request.params['id'];

      if (userId == null || propertyId == null || partnerId == null) {
        return Response(401, body: jsonEncode({'message': 'Unauthorized'}));
      }
      if (!['landowner', 'manager'].contains(role)) {
        return Response(
          403,
          body: jsonEncode({'message': 'Only landowners or managers can propose bulk adjustments'}),
        );
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final reason = body['reason'] as String?;
      final notes = body['notes'] as String?;
      final feeUpdateMode = (body['feeUpdateMode'] as String?)?.toLowerCase() ?? 'replace';
      final newMonthlyRent = (body['newMonthlyRent'] as num?)?.toDouble();
      final rentIncreasePercent = (body['rentIncreasePercent'] as num?)?.toDouble();

      if (reason == null || reason.trim().isEmpty) {
        return Response(400, body: jsonEncode({'message': 'Reason is required'}));
      }
      if (!['replace', 'merge'].contains(feeUpdateMode)) {
        return Response(400, body: jsonEncode({'message': 'feeUpdateMode must be replace or merge'}));
      }
      if (newMonthlyRent != null && rentIncreasePercent != null) {
        return Response(
          400,
          body: jsonEncode({'message': 'Use either newMonthlyRent or rentIncreasePercent, not both'}),
        );
      }

      List<UnitFee>? parseFees(List<dynamic>? raw, {required bool defaultOneTime}) {
        if (raw == null) return null;
        return raw.map((e) {
          final m = Map<String, dynamic>.from(e as Map);
          final name = m['name']?.toString().trim() ?? '';
          final amount = (m['amount'] as num?)?.toDouble();
          if (name.isEmpty || amount == null || amount < 0) {
            throw ValidationException('Each fee needs a name and valid amount');
          }
          return UnitFee(
            name: name,
            amount: amount,
            isPercentage: m['isPercentage'] as bool? ?? false,
            isOneTime: m['isOneTime'] as bool? ?? defaultOneTime,
          );
        }).toList();
      }

      List<UnitFee>? recurringFees;
      List<UnitFee>? oneTimeFees;
      try {
        recurringFees = parseFees(body['recurringFees'] as List?, defaultOneTime: false);
        oneTimeFees = parseFees(body['oneTimeFees'] as List?, defaultOneTime: true);
      } on ValidationException catch (e) {
        return Response(400, body: jsonEncode({'message': e.message}));
      }

      final hasRentFlat = newMonthlyRent != null && newMonthlyRent > 0;
      final hasRentPercent = rentIncreasePercent != null;
      final hasFees = recurringFees != null || oneTimeFees != null;

      if (!hasRentFlat && !hasRentPercent && !hasFees) {
        return Response(
          400,
          body: jsonEncode({'message': 'Provide newMonthlyRent, rentIncreasePercent, and/or fees'}),
        );
      }
      if (hasRentPercent && (rentIncreasePercent <= -100)) {
        return Response(400, body: jsonEncode({'message': 'Invalid rentIncreasePercent'}));
      }

      final property = await propertyRepository.getPropertyById(propertyId);
      if (role == 'landowner' && property.landownerId != userId) {
        return Response(403, body: jsonEncode({'message': 'Not your property'}));
      }
      if (role == 'manager' && property.managerId != userId) {
        return Response(403, body: jsonEncode({'message': 'Not your managed property'}));
      }

      final activeLeases = await leaseRepository.getActiveLeasesByProperty(propertyId);
      // Implement if missing: leases where propertyId == id && status Active (or Inactive pending renewal)

      if (activeLeases.isEmpty) {
        return Response(400, body: jsonEncode({'message': 'No active leases on this property'}));
      }

      final createdIds = <String>[];
      final skipped = <Map<String, dynamic>>[];

      for (final lease in activeLeases) {
        final pending = await leaseRepository.getActiveLeaseRequest(
          lease.id,
          type: LeaseRequestType.rentAdjustment,
        );
        if (pending != null) {
          skipped.add({'leaseId': lease.id, 'reason': 'Pending Adjustment Exists'});
          continue;
        }

        double? proposedRent;
        if (hasRentFlat) {
          proposedRent = newMonthlyRent;
        } else if (hasRentPercent) {
          proposedRent = lease.monthlyRent * (1 + rentIncreasePercent / 100);
          proposedRent = double.parse(proposedRent?.toStringAsFixed(2) ?? '0');
        }

        final fees = lease.fees ?? <UnitFee>[];
        final currentRecurring = fees.where((f) => !f.isOneTime).toList();
        final currentOneTime = fees.where((f) => f.isOneTime).toList();

        final changes = <String>[];
        if (proposedRent != null) {
          changes.add('rent ₦${lease.monthlyRent.toStringAsFixed(0)} → ₦${proposedRent.toStringAsFixed(0)}');
        }
        if (recurringFees != null) changes.add('recurring fees updated');
        if (oneTimeFees != null) changes.add('one-time fees updated');

        final created = await leaseRepository.createLeaseRequest(
          LeaseRequestModel(
            id: '',
            leaseId: lease.id,
            propertyId: lease.propertyId,
            unitId: lease.unitId,
            tenantId: lease.tenantId,
            landownerId: lease.landownerId,
            managerId: lease.managerId,
            partnerId: partnerId,
            type: LeaseRequestType.rentAdjustment,
            status: LeaseRequestStatus.pending,
            initiatedBy: role == 'manager' ? LeaseRequestActor.manager : LeaseRequestActor.landlord,
            initiatedById: userId,
            assignedToId: lease.tenantId,
            title: 'Terms adjustment for next renewal',
            reason: reason.trim(),
            message: notes?.trim(),
            metadata: {
              'appliesAt': 'renewal',
              'bulkPropertyId': propertyId,
              'currentMonthlyRent': lease.monthlyRent,
              if (proposedRent != null) 'newMonthlyRent': proposedRent,
              if (hasRentPercent) 'rentIncreasePercent': rentIncreasePercent,
              if (recurringFees != null) 'recurringFees': recurringFees.map((f) => f.toMap()).toList(),
              if (oneTimeFees != null) 'oneTimeFees': oneTimeFees.map((f) => f.toMap()).toList(),
              'feeUpdateMode': feeUpdateMode,
              'currentRecurringFees': currentRecurring.map((f) => f.toMap()).toList(),
              'currentOneTimeFees': currentOneTime.map((f) => f.toMap()).toList(),
              'reason': reason.trim(),
              if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
              'changes': changes,
            },
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        createdIds.add(created.id);

        await notificationRepository.create(
          NotificationModel(
            id: '',
            userId: lease.tenantId,
            partnerId: partnerId,
            type: 'rent_adjustment_proposed',
            title: 'Lease terms update proposed',
            body:
                'Your landlord proposed changes for your next renewal (${changes.join(', ')}). '
                'Current rent stays the same until renewal.',
            relatedId: created.id,
            relatedCollection: 'lease_requests',
            createdAt: DateTime.now(),
          ),
        );
      }

      return Response.ok(
        jsonEncode({
          'message': 'Proposed terms adjustment to ${createdIds.length} tenant(s)',
          'propertyId': propertyId,
          'created': createdIds.length,
          'skipped': skipped,
          'requestIds': createdIds,
        }),
      );
    } catch (e, stack) {
      print('Bulk adjust-terms error: $e\n$stack');
      return Response.internalServerError(
        body: jsonEncode({'message': 'Failed to propose property-wide adjustment'}),
      );
    }
  }

  Response _unauthorized() => Response(401, body: jsonEncode({'message': 'Unauthorized'}));
}

int _getMaxProperties(String plan) {
  switch (plan.toLowerCase()) {
    case 'basic':
      return 10;
    case 'premium':
      return 9999; // practically unlimited
    case 'enterprise':
      return 9999;
    case 'free':
    default:
      return 2;
  }
}
