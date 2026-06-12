import 'dart:convert';
import 'package:neztmate_backend/features/auth_user/repositories/user_repository.dart';
import 'package:neztmate_backend/features/history/model/user_history_model.dart';
import 'package:neztmate_backend/features/history/repository/user_history_repo.dart';
import 'package:neztmate_backend/features/notifications/models/notification_model.dart';
import 'package:neztmate_backend/features/notifications/repository/notification_repo.dart';
import 'package:neztmate_backend/features/properties/repository/property_repo.dart';
import 'package:neztmate_backend/features/tenants/repository/tenant_respository.dart';
import 'package:neztmate_backend/features/units/repository/unit_repo.dart';
import 'package:shelf/shelf.dart';
import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/features/leases/repository/lease_repo.dart';
import 'package:shelf_router/shelf_router.dart';

class LeaseHandler {
  final LeaseRepository leaseRepository;
  final HistoryRepository historyRepository;
  final NotificationRepository notificationRepository;
  final UnitRepository unitRepository;
  final PropertyRepository propertyRepository;
  final TenantRepository tenantRepository;
  final UserRepository userRepository;

  LeaseHandler({
    required this.leaseRepository,
    required this.historyRepository,
    required this.notificationRepository,
    required this.unitRepository,
    required this.propertyRepository,
    required this.userRepository,
    required this.tenantRepository,
  });

  //  TENANT ENDPOINTS

  /// GET /leases/me - Tenant views their active leases
  Future<Response> getMyLeases(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;

      if (userId == null) return _unauthorized();

      if (role != 'tenant') {
        return Response(403, body: jsonEncode({'message': 'Only tenants can view their leases'}));
      }

      // final leases = await leaseRepository.getActiveLeasesByTenant(userId);
      final leases = await leaseRepository.getLeasesByTenant(userId);

      final enrichedLeases = await Future.wait(
        leases.map((lease) async {
          final tenant = await userRepository.getUserById(lease.tenantId);
          final manager = await userRepository.getUserById(lease.managerId ?? lease.landownerId);

          final unit = await unitRepository.getUnitById(lease.unitId);
          final property = await propertyRepository.getPropertyById(lease.propertyId);
          final tenantNeighbors = await tenantRepository.getTenantNeighbors(lease.propertyId, lease.tenantId);

          return {
            ...lease.toMap(),
            'tenant': {
              'id': tenant.id,
              'fullName': tenant.fullName,
              'email': tenant.email,
              'phone': tenant.phone,
              "profilePhotoUrl": tenant.profilePhotoUrl,
            },
            'neighbors': tenantNeighbors.map((e) => e.toMap()).toList(),
            'manager': {
              'id': manager.id,
              'fullName': manager.fullName,
              'email': manager.email,
              'phone': manager.phone,
              'role': manager.role,
              "profilePhotoUrl": manager.profilePhotoUrl,
            },
            'unit': unit.toMap(),
            'property': {
              'id': property.id,
              'name': property.name,
              'address': property.address,
              "landownerId": property.landownerId,
              "propertyPhotos": property.photoUrls,
            },
            'duration': {
              'startDate': lease.startDate.toIso8601String(),
              'endDate': lease.endDate.toIso8601String(),
              'monthsRemaining': lease.endDate.difference(DateTime.now()).inDays ~/ 30,
            },
          };
        }),
      );

      return Response.ok(
        jsonEncode({'leases': enrichedLeases, 'message': 'Your leases loaded successfully'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Get my leases error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to load leases'}));
    }
  }

  /// GET /leases/<id> - View single lease (tenant, landowner or manager)
  Future<Response> getLeaseById(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final leaseId = request.params['id'];

      if (userId == null || leaseId == null) return _unauthorized();

      final lease = await leaseRepository.getLeaseById(leaseId);

      // Authorization
      final isTenant = lease.tenantId == userId;
      final isLandowner = lease.landownerId == userId;
      final isManager = role == 'manager';

      if (!isTenant && !isLandowner && !isManager) {
        return Response(403, body: jsonEncode({'message': 'Forbidden'}));
      }

      final enrichedLease = await Future.wait(
        [lease].map((lease) async {
          final tenant = await userRepository.getUserById(lease.tenantId);
          final manager = await userRepository.getUserById(lease.managerId ?? lease.landownerId);

          final unit = await unitRepository.getUnitById(lease.unitId);
          final property = await propertyRepository.getPropertyById(lease.propertyId);
          final tenantNeighbors = await tenantRepository.getTenantNeighbors(lease.propertyId, lease.tenantId);

          return {
            ...lease.toMap(),
            'tenant': {
              'id': tenant.id,
              'fullName': tenant.fullName,
              'email': tenant.email,
              'phone': tenant.phone,
              "profilePhotoUrl": tenant.profilePhotoUrl,
            },
            'neighbors': tenantNeighbors.map((e) => e.toMap()).toList(),
            'manager': {
              'id': manager.id,
              'fullName': manager.fullName,
              'email': manager.email,
              'phone': manager.phone,
              'role': manager.role,
              "profilePhotoUrl": manager.profilePhotoUrl,
            },
            'unit': unit.toMap(),
            'property': {
              'id': property.id,
              'name': property.name,
              'address': property.address,
              "landownerId": property.landownerId,
              "propertyPhotos": property.photoUrls,
            },
            'duration': {
              'startDate': lease.startDate.toIso8601String(),
              'endDate': lease.endDate.toIso8601String(),
              'monthsRemaining': lease.endDate.difference(DateTime.now()).inDays ~/ 30,
            },
          };
        }),
      );

      return Response.ok(
        jsonEncode({'lease': enrichedLease.first}),
        headers: {'Content-Type': 'application/json'},
      );
    } on NotFoundException catch (e) {
      return Response(404, body: jsonEncode({'message': e.message}));
    } catch (e, stack) {
      print('Get lease by id error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to load lease'}));
    }
  }

  Future<Response> getLeaseByTenantId(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final leaseId = request.params['id'];

      if (userId == null || leaseId == null) return _unauthorized();

      final lease = await leaseRepository.getLeaseById(leaseId);

      // Authorization
      final isTenant = lease.tenantId == userId;
      final isLandowner = lease.landownerId == userId;
      final isManager = role == 'manager';

      if (!isTenant && !isLandowner && !isManager) {
        return Response(403, body: jsonEncode({'message': 'Forbidden'}));
      }

      final enrichedLease = await Future.wait(
        [lease].map((lease) async {
          final tenant = await userRepository.getUserById(lease.tenantId);
          final unit = await unitRepository.getUnitById(lease.unitId);
          final manager = await userRepository.getUserById(lease.managerId ?? lease.landownerId);

          final property = await propertyRepository.getPropertyById(lease.propertyId);
          final tenantNeighbors = await tenantRepository.getTenantNeighbors(lease.propertyId, lease.tenantId);

          return {
            ...lease.toMap(),
            'tenant': {
              'id': tenant.id,
              'fullName': tenant.fullName,
              'email': tenant.email,
              'phone': tenant.phone,
              "profilePhotoUrl": tenant.profilePhotoUrl,
            },
            'neighbors': tenantNeighbors.map((e) => e.toMap()).toList(),

            'manager': {
              'id': manager.id,
              'fullName': manager.fullName,
              'email': manager.email,
              'phone': manager.phone,
              "profilePhotoUrl": manager.profilePhotoUrl,
              'role': manager.role,
            },
            'unit': unit.toMap(),
            'property': {
              'id': property.id,
              'name': property.name,
              'address': property.address,
              "landownerId": property.landownerId,
              "propertyPhotos": property.photoUrls,
            },
            'duration': {
              'startDate': lease.startDate.toIso8601String(),
              'endDate': lease.endDate.toIso8601String(),
              'monthsRemaining': lease.endDate.difference(DateTime.now()).inDays ~/ 30,
            },
          };
        }),
      );

      return Response.ok(
        jsonEncode({'lease': enrichedLease.first}),
        headers: {'Content-Type': 'application/json'},
      );
    } on NotFoundException catch (e) {
      return Response(404, body: jsonEncode({'message': e.message}));
    } catch (e, stack) {
      print('Get lease by id error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to load lease'}));
    }
  }

  /// GET /leases/<id>/application - View single lease (tenant, landowner or manager)
  Future<Response> getLeaseByApplicationId(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final applicationId = request.params['id'];
      if (userId == null || applicationId == null) return _unauthorized();

      final lease = await leaseRepository.getLeaseByApplicationId(applicationId);

      // Authorization
      final isTenant = lease.tenantId == userId;
      final isLandowner = lease.landownerId == userId;
      final isManager = role == 'manager';

      if (!isTenant && !isLandowner && !isManager) {
        return Response(403, body: jsonEncode({'message': 'Forbidden'}));
      }

      final enrichedLease = await Future.wait(
        [lease].map((lease) async {
          final tenant = await userRepository.getUserById(lease.tenantId);
          final unit = await unitRepository.getUnitById(lease.unitId);
          final manager = await userRepository.getUserById(lease.managerId ?? lease.landownerId);

          final property = await propertyRepository.getPropertyById(lease.propertyId);
          final tenantNeighbors = await tenantRepository.getTenantNeighbors(lease.propertyId, lease.tenantId);

          return {
            ...lease.toMap(),
            'tenant': {
              'id': tenant.id,
              'fullName': tenant.fullName,
              'email': tenant.email,
              'phone': tenant.phone,
              "profilePhotoUrl": tenant.profilePhotoUrl,
            },
            'neighbors': tenantNeighbors.map((e) => e.toMap()).toList(),

            'manager': {
              'id': manager.id,
              'fullName': manager.fullName,
              'email': manager.email,
              'phone': manager.phone,
              "profilePhotoUrl": manager.profilePhotoUrl,
              'role': manager.role,
            },
            'unit': unit.toMap(),
            'property': {
              'id': property.id,
              'name': property.name,
              'address': property.address,
              "landownerId": property.landownerId,
              "propertyPhotos": property.photoUrls,
            },
            'duration': {
              'startDate': lease.startDate.toIso8601String(),
              'endDate': lease.endDate.toIso8601String(),
              'monthsRemaining': lease.endDate.difference(DateTime.now()).inDays ~/ 30,
            },
          };
        }),
      );

      return Response.ok(
        jsonEncode({'lease': enrichedLease.first}),
        headers: {'Content-Type': 'application/json'},
      );
    } on NotFoundException catch (e) {
      return Response(404, body: jsonEncode({'message': e.message}));
    } catch (e, stack) {
      print('Get application lease by id error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to load lease'}));
    }
  }

  /// PATCH /leases/<id>/sign - Tenant signs the lease
  Future<Response> signLease(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final leaseId = request.params['id'];

      if (userId == null || leaseId == null) return _unauthorized();

      if (role != 'tenant') {
        return Response(403, body: jsonEncode({'message': 'Only tenants can sign leases'}));
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final signedPdfUrl = body['signedPdfUrl'] as String?;

      if (signedPdfUrl == null || signedPdfUrl.isEmpty) {
        return Response(400, body: jsonEncode({'message': 'signedPdfUrl is required'}));
      }

      await leaseRepository.markLeaseAsSigned(leaseId, signedPdfUrl, userId);

      final lease = await leaseRepository.getLeaseById(leaseId);

      // Log history
      await historyRepository.createHistoryEntry(
        HistoryEntryModel(
          userId: userId,
          type: 'lease_signed',
          title: 'Lease Signed',
          description: 'You signed the lease for Unit ${lease.unitId}',
          relatedId: leaseId,
          relatedCollection: 'leases',
          timestamp: DateTime.now(),
          id: '',
        ),
      );

      await historyRepository.createHistoryEntry(
        HistoryEntryModel(
          userId: lease.landownerId,
          type: 'lease_signed',
          title: 'Tenant Signed Lease',
          description: 'Tenant signed lease for Unit ${lease.unitId}',
          relatedId: leaseId,
          relatedCollection: 'leases',
          timestamp: DateTime.now(),
          id: '',
        ),
      );

      // Send notifications
      await notificationRepository.create(
        NotificationModel(
          id: '',
          userId: userId,
          type: 'lease_signed',
          title: 'Lease Signed Successfully',
          body: 'Your lease is now pending first payment.',
          relatedId: leaseId,
          relatedCollection: 'leases',
          createdAt: DateTime.now(),
        ),
      );

      await notificationRepository.create(
        NotificationModel(
          id: '',
          userId: lease.landownerId,
          type: 'lease_signed',
          title: 'Lease Signed by Tenant',
          body: 'Tenant has signed the lease agreement.',
          relatedId: leaseId,
          relatedCollection: 'leases',
          createdAt: DateTime.now(),
        ),
      );

      return Response.ok(
        jsonEncode({
          'message': 'Lease signed successfully',
          'leaseId': leaseId,
          'status': 'Pending Payment',
          'signedAgreementPdfUrl': signedPdfUrl,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } on NotFoundException catch (e) {
      return Response(404, body: jsonEncode({'message': e.message}));
    } catch (e, stack) {
      print('Sign lease error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to sign lease'}));
    }
  }

  //  LANDOWNER / MANAGER ENDPOINTS

  /// GET /leases/property/<propertyId> → Landowner/Manager sees leases for a property
  Future<Response> getLeasesByProperty(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final propertyId = request.params['propertyId'];

      if (userId == null || role == null || propertyId == null) {
        return Response(400, body: jsonEncode({'message': 'Missing required parameters'}));
      }

      if (!['landowner', 'manager'].contains(role)) {
        return Response(403, body: jsonEncode({'message': 'Unauthorized'}));
      }

      final leases = await leaseRepository.getLeasesByUnit(propertyId); // or filter by property

      final enrichedLeases = await Future.wait(
        leases.map((lease) async {
          final tenant = await userRepository.getUserById(lease.tenantId);
          final unit = await unitRepository.getUnitById(lease.unitId);
          final manager = await userRepository.getUserById(lease.managerId ?? lease.landownerId);

          final property = await propertyRepository.getPropertyById(lease.unitId);
          final tenantNeighbors = await tenantRepository.getTenantNeighbors(lease.propertyId, lease.tenantId);

          return {
            ...lease.toMap(),
            'tenant': {
              'id': tenant.id,
              'fullName': tenant.fullName,
              'email': tenant.email,
              'phone': tenant.phone,
              "profilePhotoUrl": tenant.profilePhotoUrl,
            },
            'neighbors': tenantNeighbors.map((e) => e.toMap()).toList(),

            'manager': {
              'id': manager.id,
              'fullName': manager.fullName,
              'email': manager.email,
              'phone': manager.phone,
              "profilePhotoUrl": manager.profilePhotoUrl,
              'role': manager.role,
            },
            'unit': unit.toMap(),

            'property': {
              'id': property.id,
              'name': property.name,
              'address': property.address,
              "propertyPhotos": property.photoUrls,
            },
            'duration': {
              'startDate': lease.startDate.toIso8601String(),
              'endDate': lease.endDate.toIso8601String(),
              'monthsRemaining': lease.endDate.difference(DateTime.now()).inDays ~/ 30,
            },
          };
        }),
      );

      return Response.ok(jsonEncode({'leases': enrichedLeases, 'message': 'Leases for this property'}));
    } catch (e) {
      return Response.internalServerError();
    }
  }

  /// GET /leases/landowner/me - Landowner views their leases
  Future<Response> getLandownerLeases(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;

      if (userId == null) return _unauthorized();

      if (role != 'landowner') {
        return Response(403, body: jsonEncode({'message': 'Only landowners can access this'}));
      }

      final leases = await leaseRepository.getLeasesByLandowner(userId);

      final enrichedLeases = await Future.wait(
        leases.map((lease) async {
          final tenant = await userRepository.getUserById(lease.tenantId);
          final unit = await unitRepository.getUnitById(lease.unitId);
          final manager = await userRepository.getUserById(lease.managerId ?? lease.landownerId);

          final property = await propertyRepository.getPropertyById(lease.unitId);
          final tenantNeighbors = await tenantRepository.getTenantNeighbors(lease.propertyId, lease.tenantId);

          return {
            ...lease.toMap(),
            'tenant': {
              'id': tenant.id,
              'fullName': tenant.fullName,
              'email': tenant.email,
              'phone': tenant.phone,
              "profilePhotoUrl": tenant.profilePhotoUrl,
            },
            'neighbors': tenantNeighbors.map((e) => e.toMap()).toList(),

            'manager': {
              'id': manager.id,
              'fullName': manager.fullName,
              'email': manager.email,
              'phone': manager.phone,
              "profilePhotoUrl": manager.profilePhotoUrl,
              'role': manager.role,
            },
            'unit': unit.toMap(),
            'property': {
              'id': property.id,
              'name': property.name,
              'address': property.address,
              "propertyPhotos": property.photoUrls,
            },
            'duration': {
              'startDate': lease.startDate.toIso8601String(),
              'endDate': lease.endDate.toIso8601String(),
              'monthsRemaining': lease.endDate.difference(DateTime.now()).inDays ~/ 30,
            },
          };
        }),
      );

      return Response.ok(
        jsonEncode({'leases': enrichedLeases, 'message': 'Your properties leases'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Get landowner leases error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  /// PATCH /leases/<id>/terminate - Landowner or Manager terminates lease

  Future<Response> terminateLease(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final leaseId = request.params['id'];

      if (userId == null || leaseId == null) return _unauthorized();

      if (!['landowner', 'manager'].contains(role)) {
        return Response(403, body: jsonEncode({'message': 'Only landowners/managers can terminate leases'}));
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final reason = body['reason'] as String?;

      if (reason == null || reason.trim().isEmpty) {
        return Response(400, body: jsonEncode({'message': 'Termination reason is required'}));
      }

      final lease = await leaseRepository.getLeaseById(leaseId);

      if (lease.endDate.isAfter(DateTime.now())) {
        return Response(
          400,
          body: jsonEncode({
            'message': 'Cannot Terminate this Lease at this time. Current lease has not yet expired.',
          }),
        );
      }

      // 1. Terminate the lease
      await leaseRepository.terminateLease(leaseId, reason, userId);

      // 2. Update unit status (vacant + available again)
      await unitRepository.updateUnitStatus(
        unitId: lease.unitId,
        status: 'vacant',
        currentTenantId: null,
        isListedForRent: true,
      );

      // 3. Log history + notifications

      // Log history for tenant
      await historyRepository.createHistoryEntry(
        HistoryEntryModel(
          userId: lease.tenantId,
          type: 'lease_terminated',
          title: 'Lease Terminated',
          description: 'Your lease has been terminated. Reason: $reason',
          relatedId: leaseId,
          relatedCollection: 'leases',
          timestamp: DateTime.now(),
          id: '',
        ),
      );

      // Log history for landowner
      await historyRepository.createHistoryEntry(
        HistoryEntryModel(
          userId: userId,
          type: 'lease_terminated',
          title: 'Lease Terminated',
          description: 'You terminated the lease for Unit ${lease.unitId}. Reason: $reason',
          relatedId: leaseId,
          relatedCollection: 'leases',
          timestamp: DateTime.now(),
          id: '',
        ),
      );

      // Send notifications
      await notificationRepository.create(
        NotificationModel(
          userId: lease.tenantId,
          type: 'lease_terminated',
          title: 'Lease Terminated',
          body: 'Your lease has been terminated by the landlord. Reason: $reason',
          relatedId: leaseId,
          relatedCollection: 'leases',
          createdAt: DateTime.now(),
          id: '',
        ),
      );

      await notificationRepository.create(
        NotificationModel(
          userId: userId,
          type: 'lease_terminated',
          title: 'Lease Terminated Successfully',
          body: 'You have terminated the lease for Unit ${lease.unitId}',
          relatedId: leaseId,
          relatedCollection: 'leases',
          createdAt: DateTime.now(),
          id: '',
        ),
      );

      return Response.ok(
        jsonEncode({
          'message': 'Lease terminated successfully',
          'leaseId': leaseId,
          'unitStatusUpdated': true,
        }),
      );
    } catch (e, stack) {
      print('Terminate lease error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to terminate lease'}));
    }
  }

  /// PATCH /leases/<id>/renew - Renew existing lease
  Future<Response> renewLease(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final leaseId = request.params['id'];

      if (userId == null || leaseId == null) return _unauthorized();

      if (!['landowner', 'manager'].contains(role)) {
        return Response(403, body: jsonEncode({'message': 'Only landowners/managers can renew leases'}));
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final newEndDate = DateTime.parse(body['newEndDate'] as String);
      final reason = body['reason'] as String?;

      final oldLease = await leaseRepository.getLeaseById(leaseId);

      // Create renewed lease
      final renewedLease = oldLease.copyWith(
        id: '',
        startDate: oldLease.endDate,
        endDate: newEndDate,
        status: 'Active',
        isRenewed: true,
        previousLeaseId: leaseId,
        renewalReason: reason,
        updatedAt: DateTime.now(),
      );

      final newLease = await leaseRepository.createLease(renewedLease);

      // Update unit (keep occupied)
      await unitRepository.updateUnitStatus(
        unitId: oldLease.unitId,
        status: 'occupied',
        currentTenantId: oldLease.tenantId,
        isListedForRent: false,
      );

      await historyRepository.createHistoryEntry(
        HistoryEntryModel(
          id: '',
          userId: oldLease.tenantId,
          type: 'lease_renewed',
          title: 'Lease Renewed',
          description: 'Your lease has been renewed until ${newEndDate.toIso8601String().split('T').first}.',
          relatedId: newLease.id,
          relatedCollection: 'leases',
          timestamp: DateTime.now(),
        ),
      );

      await historyRepository.createHistoryEntry(
        HistoryEntryModel(
          id: '',
          userId: userId,
          type: 'lease_renewed',
          title: 'Lease Renewed',
          description: 'Lease for Unit ${oldLease.unitId} was renewed successfully.',
          relatedId: newLease.id,
          relatedCollection: 'leases',
          timestamp: DateTime.now(),
        ),
      );

      await notificationRepository.create(
        NotificationModel(
          id: '',
          userId: oldLease.tenantId,
          type: 'lease_renewed',
          title: 'Lease Renewed',
          body:
              'Your lease has been renewed and remains active until ${newEndDate.toIso8601String().split('T').first}.',
          relatedId: newLease.id,
          relatedCollection: 'leases',
          createdAt: DateTime.now(),
        ),
      );

      await notificationRepository.create(
        NotificationModel(
          id: '',
          userId: userId,
          type: 'lease_renewed',
          title: 'Lease Renewal Successful',
          body: 'Lease renewal completed successfully.',
          relatedId: newLease.id,
          relatedCollection: 'leases',
          createdAt: DateTime.now(),
        ),
      );

      return Response.ok(
        jsonEncode({
          'message': 'Lease renewed successfully',
          'newLeaseId': newLease.id,
          'oldLeaseId': leaseId,
        }),
      );
    } catch (e, stack) {
      print('Renew lease error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to renew lease'}));
    }
  }

  /// PATCH /leases/<id>/status - Update lease status (Landowner/Manager only)
  Future<Response> updateLeaseStatus(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final leaseId = request.params['id'];

      if (userId == null || leaseId == null) {
        return _unauthorized();
      }

      if (!['landowner', 'manager'].contains(role)) {
        return Response(
          403,
          body: jsonEncode({'message': 'Only landowners or managers can update lease status'}),
        );
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final newStatus = (body['status'] as String?)?.trim().toLowerCase();

      if (newStatus == null || newStatus.isEmpty) {
        return Response(400, body: jsonEncode({'message': 'Status is required'}));
      }

      // Fetch current lease
      final lease = await leaseRepository.getLeaseById(leaseId);

      // === BUSINESS RULE VALIDATIONS ===

      // 1. Cannot change a terminated lease
      if (lease.status.toLowerCase() == 'terminated') {
        return Response(400, body: jsonEncode({'message': 'Terminated leases cannot be modified'}));
      }

      // 2. Cannot set to Pending Payment if current lease hasn't expired
      if (newStatus.toLowerCase() == 'pending payment') {
        if (lease.endDate.isAfter(DateTime.now())) {
          return Response(
            400,
            body: jsonEncode({
              'message': 'Cannot set to Pending Payment or Renew Lease. Current lease has not yet expired.',
            }),
          );
        }
      }

      // 3. Can only set to Active after signing
      if (newStatus.toLowerCase() == 'active') {
        if (lease.status.toLowerCase() != 'pending payment' &&
            lease.status.toLowerCase() != 'pending signature') {
          return Response(
            400,
            body: jsonEncode({
              'message': 'Lease must be signed and payment made before it can be marked Active',
            }),
          );
        }
      }

      // 4. Cannot set back to Pending Signature after signing
      if (newStatus.toLowerCase() == 'pending signature' &&
          ['active', 'pending Payment', 'terminated'].contains(lease.status.toLowerCase())) {
        return Response(
          400,
          body: jsonEncode({'message': 'Cannot revert to Pending Signature after signing'}),
        );
      }

      // 5. Validate status is allowed
      const allowedStatuses = ['pending signature', 'pending payment', 'active', 'inactive', 'terminated'];
      if (!allowedStatuses.contains(newStatus.toLowerCase())) {
        return Response(
          400,
          body: jsonEncode({'message': 'Invalid status. Allowed: ${allowedStatuses.join(', ')}'}),
        );
      }

      // Perform the update
      await leaseRepository.updateLeaseStatus(leaseId, newStatus);

      String title;
      String description;
      String notificationBody;

      switch (newStatus) {
        case 'pending signature':
          title = 'Lease Awaiting Signature';
          description = 'Lease is awaiting tenant signature.';
          notificationBody = 'Please review and sign your lease agreement.';
          break;

        case 'pending payment':
          title = 'Lease Awaiting Payment';
          description = 'Lease has moved to payment stage.';
          notificationBody = 'Your lease agreement is awaiting payment.';
          break;

        case 'active':
          title = 'Lease Activated';
          description = 'Lease is now active.';
          notificationBody = 'Your lease is now active.';
          break;

        case 'inactive':
          title = 'Lease Inactive';
          description = 'Lease has been marked inactive.';
          notificationBody = 'Your lease has been marked inactive.';
          break;

        case 'terminated':
          title = 'Lease Terminated';
          description = 'Lease has been terminated.';
          notificationBody = 'Your lease agreement has been terminated.';
          break;

        default:
          title = 'Lease Updated';
          description = 'Lease status updated.';
          notificationBody = 'Lease status changed.';
      }

      // Optional: Update unit status if lease becomes active or terminated
      if (newStatus == 'active') {
        await unitRepository.updateUnitStatus(
          unitId: lease.unitId,
          status: 'occupied',
          currentTenantId: lease.tenantId,
          isListedForRent: false,
        );
      } else if (newStatus == 'terminated') {
        await unitRepository.updateUnitStatus(
          unitId: lease.unitId,
          status: 'vacant',
          currentTenantId: null,
          isListedForRent: true,
        );
      }

      await historyRepository.createHistoryEntry(
        HistoryEntryModel(
          id: '',
          userId: lease.tenantId,
          type: 'lease_status_changed',
          title: title,
          description: description,
          relatedId: leaseId,
          relatedCollection: 'leases',
          timestamp: DateTime.now(),
        ),
      );

      await historyRepository.createHistoryEntry(
        HistoryEntryModel(
          id: '',
          userId: userId,
          type: 'lease_status_changed',
          title: title,
          description: 'Lease status updated to ${newStatus.toUpperCase()}.',
          relatedId: leaseId,
          relatedCollection: 'leases',
          timestamp: DateTime.now(),
        ),
      );

      await notificationRepository.create(
        NotificationModel(
          id: '',
          userId: lease.tenantId,
          type: 'lease_status_changed',
          title: title,
          body: notificationBody,
          relatedId: leaseId,
          relatedCollection: 'leases',
          createdAt: DateTime.now(),
        ),
      );

      await notificationRepository.create(
        NotificationModel(
          id: '',
          userId: userId,
          type: 'lease_status_changed',
          title: 'Lease Updated',
          body: 'Lease status changed to ${newStatus.toUpperCase()}.',
          relatedId: leaseId,
          relatedCollection: 'leases',
          createdAt: DateTime.now(),
        ),
      );

      return Response.ok(
        jsonEncode({
          'message': 'Lease status updated successfully',
          'leaseId': leaseId,
          'newStatus': newStatus,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Update lease status error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to update lease status'}));
    }
  }

  Response _unauthorized() => Response(401, body: jsonEncode({'message': 'Unauthorized'}));
}
