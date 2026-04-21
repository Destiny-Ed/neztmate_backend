import 'dart:convert';
import 'package:neztmate_backend/features/auth_user/repositories/user_repository.dart';
import 'package:neztmate_backend/features/history/model/user_history_model.dart';
import 'package:neztmate_backend/features/history/repository/user_history_repo.dart';
import 'package:neztmate_backend/features/notifications/models/notification_model.dart';
import 'package:neztmate_backend/features/notifications/repository/notification_repo.dart';
import 'package:neztmate_backend/features/properties/repository/property_repo.dart';
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
  final UserRepository userRepository;

  LeaseHandler({
    required this.leaseRepository,
    required this.historyRepository,
    required this.notificationRepository,
    required this.unitRepository,
    required this.propertyRepository,
    required this.userRepository,
  });

  //  TENANT ENDPOINTS

  /// GET /leases/me - Tenant views their active leases
  Future<Response> getMyLeases(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;

      if (userId == null) return _unauthorized();

      if (role != 'Tenant') {
        return Response(403, body: jsonEncode({'message': 'Only tenants can view their leases'}));
      }

      final leases = await leaseRepository.getActiveLeasesByTenant(userId);

      final enrichedLeases = await Future.wait(
        leases.map((lease) async {
          final tenant = await userRepository.getUserById(lease.tenantId);
          final unit = await unitRepository.getUnitById(lease.unitId);
          final property = await propertyRepository.getPropertyById(
            lease.unitId,
          ); // assuming you have propertyId in lease, adjust if needed

          return {
            ...lease.toMap(),
            'tenant': {
              'id': tenant.id,
              'fullName': tenant.fullName,
              'email': tenant.email,
              'phone': tenant.phone,
            },
            'unit': {
              'id': unit.id,
              'unitNumber': unit.unitNumber,
              'bedrooms': unit.bedrooms,
              'bathrooms': unit.bathrooms,
              'yearlyRent': unit.yearlyRent,
            },
            'property': {'id': property.id, 'name': property.name, 'address': property.address},
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
          final unit = await unitRepository.getUnitById(lease.unitId);
          final property = await propertyRepository.getPropertyById(
            lease.unitId,
          ); // assuming you have propertyId in lease, adjust if needed

          return {
            ...lease.toMap(),
            'tenant': {
              'id': tenant.id,
              'fullName': tenant.fullName,
              'email': tenant.email,
              'phone': tenant.phone,
            },
            'unit': {
              'id': unit.id,
              'unitNumber': unit.unitNumber,
              'bedrooms': unit.bedrooms,
              'bathrooms': unit.bathrooms,
              'yearlyRent': unit.yearlyRent,
            },
            'property': {'id': property.id, 'name': property.name, 'address': property.address},
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

  /// PATCH /leases/<id>/sign - Tenant signs the lease
  Future<Response> signLease(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final leaseId = request.params['id'];

      if (userId == null || leaseId == null) return _unauthorized();

      if (role != 'Tenant') {
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
          final property = await propertyRepository.getPropertyById(
            lease.unitId,
          ); // assuming you have propertyId in lease, adjust if needed

          return {
            ...lease.toMap(),
            'tenant': {
              'id': tenant.id,
              'fullName': tenant.fullName,
              'email': tenant.email,
              'phone': tenant.phone,
            },
            'unit': {
              'id': unit.id,
              'unitNumber': unit.unitNumber,
              'bedrooms': unit.bedrooms,
              'bathrooms': unit.bathrooms,
              'yearlyRent': unit.yearlyRent,
            },
            'property': {'id': property.id, 'name': property.name, 'address': property.address},
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

      if (role != 'Landowner') {
        return Response(403, body: jsonEncode({'message': 'Only landowners can access this'}));
      }

      final leases = await leaseRepository.getLeasesByLandowner(userId);

      final enrichedLeases = await Future.wait(
        leases.map((lease) async {
          final tenant = await userRepository.getUserById(lease.tenantId);
          final unit = await unitRepository.getUnitById(lease.unitId);
          final property = await propertyRepository.getPropertyById(
            lease.unitId,
          ); // assuming you have propertyId in lease, adjust if needed

          return {
            ...lease.toMap(),
            'tenant': {
              'id': tenant.id,
              'fullName': tenant.fullName,
              'email': tenant.email,
              'phone': tenant.phone,
            },
            'unit': {
              'id': unit.id,
              'unitNumber': unit.unitNumber,
              'bedrooms': unit.bedrooms,
              'bathrooms': unit.bathrooms,
              'yearlyRent': unit.yearlyRent,
            },
            'property': {'id': property.id, 'name': property.name, 'address': property.address},
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
        createdAt: DateTime.now(),
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

  Response _unauthorized() => Response(401, body: jsonEncode({'message': 'Unauthorized'}));
}
