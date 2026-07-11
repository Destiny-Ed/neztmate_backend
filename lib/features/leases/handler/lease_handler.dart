import 'dart:convert';
import 'package:neztmate_backend/core/services/reputation/reputation_service.dart';
import 'package:neztmate_backend/features/auth_user/repositories/user_repository.dart';
import 'package:neztmate_backend/features/history/model/user_history_model.dart';
import 'package:neztmate_backend/features/history/repository/user_history_repo.dart';
import 'package:neztmate_backend/features/leases/models/lease_settlement_agreement_model.dart';
import 'package:neztmate_backend/features/leases/service/lease_payment_calculator_service.dart';
import 'package:neztmate_backend/features/notifications/models/notification_model.dart';
import 'package:neztmate_backend/features/notifications/repository/notification_repo.dart';
import 'package:neztmate_backend/features/payments/repository/payment_repo.dart';
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
  final UserReputationService userReputationService;
  final PaymentRepository paymentRepository;

  LeaseHandler({
    required this.leaseRepository,
    required this.historyRepository,
    required this.notificationRepository,
    required this.unitRepository,
    required this.propertyRepository,
    required this.userRepository,
    required this.tenantRepository,
    required this.userReputationService,
    required this.paymentRepository,
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

          final paymentSummary = LeasePaymentCalculatorService.calculate(lease: lease, unit: unit);

          final payoutAccount = await paymentRepository.getDefaultPayoutAccount(
            lease.managerId ?? lease.landownerId,
          );

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
            'paymentSummary': paymentSummary,
            'paymentAccount': payoutAccount == null
                ? null
                : {
                    'id': payoutAccount.id,
                    'ownerId': payoutAccount.userId,
                    'ownerType': payoutAccount.userId == lease.managerId ? "Manager" : "Landowner",
                    "accountName": payoutAccount.accountName,
                    "accountNumber": payoutAccount.accountNumber,
                    "bankName": payoutAccount.bankName,
                    "bankCode": payoutAccount.bankCode,
                    "currency": 'NGN',
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

          final paymentSummary = LeasePaymentCalculatorService.calculate(lease: lease, unit: unit);

          final payoutAccount = await paymentRepository.getDefaultPayoutAccount(
            lease.managerId ?? lease.landownerId,
          );

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
            'paymentSummary': paymentSummary,
            'paymentAccount': payoutAccount == null
                ? null
                : {
                    'id': payoutAccount.id,
                    'ownerId': payoutAccount.userId,
                    'ownerType': payoutAccount.userId == lease.managerId ? "Manager" : "Landowner",
                    "accountName": payoutAccount.accountName,
                    "accountNumber": payoutAccount.accountNumber,
                    "bankName": payoutAccount.bankName,
                    "bankCode": payoutAccount.bankCode,
                    "currency": 'NGN',
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
  Future<Response> terminateLeaseByLandowner(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final leaseId = request.params['id'];

      if (userId == null || leaseId == null) return _unauthorized();

      if (!['landowner', 'manager'].contains(role)) {
        return Response(403, body: jsonEncode({'message': 'Only landlords/managers can terminate leases'}));
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final reason = body['reason'] as String?;

      if (reason == null || reason.trim().isEmpty) {
        return badRequest('Termination reason is required');
      }

      final lease = await leaseRepository.getLeaseById(leaseId);

      //calculate settlement
      final settlement = await leaseRepository.calculateEarlyTerminationSettlement(leaseId, unitRepository);

      await leaseRepository.terminateLease(leaseId, reason, role ?? "");

      // Update unit to vacant
      await unitRepository.updateUnitStatus(
        unitId: lease.unitId,
        status: 'vacant',
        currentTenantId: null,
        isListedForRent: true,
      );

      // Reputation impact (negative for tenant)
      await userReputationService.updateUserReputation(lease.tenantId);

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

      return Response.ok(
        jsonEncode({
          'message': 'Lease terminated successfully',
          'leaseId': leaseId,
          'settlement': settlement,
        }),
      );
    } catch (e, stack) {
      print('Landlord terminate lease error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  /// POST /leases/<id>/transfer - Tenant requests to transfer lease with replacement
  Future<Response> requestLeaseTransfer(Request request) async {
    try {
      final tenantId = request.context['userId'] as String?;
      final leaseId = request.params['id'];

      if (tenantId == null || leaseId == null) return _unauthorized();

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final newTenantId = body['newTenantId'] as String?;
      final reason = body['reason'] as String?;

      if (newTenantId == null) {
        return badRequest('newTenantId (replacement tenant) is required');
      }

      final lease = await leaseRepository.getLeaseById(leaseId);

      if (lease.tenantId != tenantId) {
        return Response(403, body: jsonEncode({'message': 'You can only transfer your own lease'}));
      }

      if (lease.status != 'Active') {
        return Response(400, body: jsonEncode({'message': 'Only active leases can be transferred'}));
      }

      await leaseRepository.requestLeaseTransfer(
        leaseId: leaseId,
        newTenantId: newTenantId,
        reason: reason ?? 'Tenant relocation',
      );

      await notificationRepository.create(
        NotificationModel(
          userId: lease.landownerId,
          type: 'lease_transfer_request',
          title: 'Lease Transfer Request',
          body: 'Tenant has requested to transfer lease to new tenant.',
          relatedId: leaseId,
          relatedCollection: 'leases',
          createdAt: DateTime.now(),
          id: '',
        ),
      );

      return Response.ok(
        jsonEncode({
          'message': 'Lease transfer request submitted. Awaiting landlord approval.',
          'leaseId': leaseId,
        }),
      );
    } catch (e, stack) {
      print('Request lease transfer error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  /// PATCH /leases/<id>/approve-termination - Landlord approves early termination
  Future<Response> approveEarlyTermination(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final leaseId = request.params['id'];

      if (userId == null || leaseId == null) return _unauthorized();

      if (!['landowner', 'manager'].contains(role)) {
        return Response(
          403,
          body: jsonEncode({'message': 'Only landlords/managers can approve termination'}),
        );
      }

      final lease = await leaseRepository.getLeaseById(leaseId);

      final settlement = await leaseRepository.calculateEarlyTerminationSettlement(leaseId, unitRepository);

      await leaseRepository.terminateLease(leaseId, 'Approved early termination', role ?? "");

      // Update unit to vacant
      await unitRepository.updateUnitStatus(
        unitId: lease.unitId,
        status: 'vacant',
        currentTenantId: null,
        isListedForRent: true,
      );

      // Notify tenant
      await notificationRepository.create(
        NotificationModel(
          userId: lease.tenantId,
          type: 'early_termination_approved',
          title: 'Early Termination Approved',
          body: 'Your early termination request has been approved.',
          relatedId: leaseId,
          relatedCollection: 'leases',
          createdAt: DateTime.now(),
          id: '',
        ),
      );

      return Response.ok(
        jsonEncode({'message': 'Early termination approved', 'leaseId': leaseId, 'settlement': settlement}),
      );
    } catch (e, stack) {
      print('Approve early termination error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  /// POST /leases/<id>/settlement - Propose settlement amount
  Future<Response> proposeSettlement(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final leaseId = request.params['id'];

      if (userId == null || leaseId == null) return _unauthorized();

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final agreedAmount = (body['agreedAmount'] as num?)?.toDouble();
      final paymentMethod = body['paymentMethod'] as String?;

      if (agreedAmount == null || paymentMethod == null) {
        return badRequest('agreedAmount and paymentMethod are required');
      }

      final lease = await leaseRepository.getLeaseById(leaseId);

      final isTenant = lease.tenantId == userId;
      final isLandowner = lease.landownerId == userId;

      if (!isTenant && !isLandowner) {
        return Response(403, body: jsonEncode({'message': 'Forbidden'}));
      }

      final settlement = LeaseSettlementAgreement(
        id: '',
        leaseId: leaseId,
        initiatedBy: isTenant ? 'tenant' : 'landowner',
        agreedAmount: agreedAmount,
        paymentMethod: paymentMethod,
        createdAt: DateTime.now(),
      );

      await leaseRepository.proposeSettlement(settlement);

      // Notify the other party
      final otherPartyId = isTenant ? lease.landownerId : lease.tenantId;

      await notificationRepository.create(
        NotificationModel(
          userId: otherPartyId,
          type: 'settlement_proposed',
          title: 'Settlement Proposal',
          body: '${isTenant ? "Tenant" : "Landlord"} proposed settlement of ₦$agreedAmount',
          relatedId: leaseId,
          relatedCollection: 'leases',
          createdAt: DateTime.now(),
          id: '',
        ),
      );

      return Response.ok(
        jsonEncode({'message': 'Settlement proposal sent', 'settlement': settlement.toMap()}),
      );
    } catch (e, stack) {
      print('Propose settlement error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  /// PATCH /leases/<id>/settlement/accept - Accept settlement
  Future<Response> acceptSettlement(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final leaseId = request.params['id'];

      if (userId == null || leaseId == null) return _unauthorized();

      final lease = await leaseRepository.getLeaseById(leaseId);

      await leaseRepository.acceptSettlement(leaseId, userId);

      // Mark lease as terminated after settlement agreement
      await leaseRepository.terminateLease(leaseId, 'Settlement agreed', 'system');

      await unitRepository.updateUnitStatus(
        unitId: lease.unitId,
        status: 'vacant',
        currentTenantId: null,
        isListedForRent: true,
      );

      return Response.ok(
        jsonEncode({'message': 'Settlement accepted. Lease terminated successfully.', 'leaseId': leaseId}),
      );
    } catch (e, stack) {
      print('Accept settlement error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  /// PATCH /leases/<id>/settlement/dispute - Dispute settlement proposal
  Future<Response> disputeSettlement(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final leaseId = request.params['id'];

      if (userId == null || leaseId == null) return _unauthorized();

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final disputeReason = body['disputeReason'] as String?;

      if (disputeReason == null || disputeReason.trim().isEmpty) {
        return badRequest('Dispute reason is required');
      }

      final lease = await leaseRepository.getLeaseById(leaseId);

      await leaseRepository.disputeSettlement(leaseId: leaseId, disputedBy: userId, reason: disputeReason);

      // Notify the other party
      final otherPartyId = lease.tenantId == userId ? lease.landownerId : lease.tenantId;

      await notificationRepository.create(
        NotificationModel(
          userId: otherPartyId,
          type: 'settlement_disputed',
          title: 'Settlement Disputed',
          body: 'The other party has disputed the settlement proposal.',
          relatedId: leaseId,
          relatedCollection: 'leases',
          createdAt: DateTime.now(),
          id: '',
        ),
      );

      return Response.ok(jsonEncode({'message': 'Settlement disputed successfully', 'leaseId': leaseId}));
    } catch (e, stack) {
      print('Dispute settlement error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  /// PATCH /leases/<id>/settlement/resolve - Resolve dispute (Landlord/Manager only)
  Future<Response> resolveSettlementDispute(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final leaseId = request.params['id'];

      if (userId == null || leaseId == null) return _unauthorized();

      if (!['landowner', 'manager'].contains(role)) {
        return Response(403, body: jsonEncode({'message': 'Only landlords/managers can resolve disputes'}));
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final resolution = body['resolution'] as String?; // 'accept', 'reject', 'modify'
      final finalAmount = (body['finalAmount'] as num?)?.toDouble();
      final notes = body['notes'] as String?;

      if (resolution == null) {
        return badRequest('resolution (accept/reject/modify) is required');
      }

      await leaseRepository.resolveSettlementDispute(
        leaseId: leaseId,
        resolvedBy: userId,
        resolution: resolution,
        finalAmount: finalAmount,
        notes: notes,
      );

      final lease = await leaseRepository.getLeaseById(leaseId);

      await notificationRepository.create(
        NotificationModel(
          userId: lease.tenantId,
          type: 'settlement_resolved',
          title: 'Settlement Dispute Resolved',
          body: 'The dispute has been resolved by the landlord.',
          relatedId: leaseId,
          relatedCollection: 'leases',
          createdAt: DateTime.now(),
          id: '',
        ),
      );

      return Response.ok(
        jsonEncode({
          'message': 'Settlement dispute resolved',
          'resolution': resolution,
          'finalAmount': finalAmount,
        }),
      );
    } catch (e, stack) {
      print('Resolve settlement dispute error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  /// PATCH /leases/<id>/approve-transfer - Landlord/Manager approves transfer
  Future<Response> approveLeaseTransfer(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final leaseId = request.params['id'];

      if (userId == null || leaseId == null) return _unauthorized();

      if (!['landowner', 'manager'].contains(role)) {
        return Response(403, body: jsonEncode({'message': 'Only landlords/managers can approve transfers'}));
      }

      final lease = await leaseRepository.getLeaseById(leaseId);

      if (lease.transferToTenantId == null) {
        return Response(400, body: jsonEncode({'message': 'No pending transfer request'}));
      }

      await leaseRepository.approveLeaseTransfer(leaseId, userId);

      // Update unit
      await unitRepository.updateUnitStatus(
        unitId: lease.unitId,
        status: 'occupied',
        currentTenantId: lease.transferToTenantId,
      );

      await notificationRepository.create(
        NotificationModel(
          userId: lease.tenantId,
          type: 'lease_transfer_approved',
          title: 'Lease Transfer Approved',
          body: 'Your lease transfer has been approved.',
          relatedId: leaseId,
          relatedCollection: 'leases',
          createdAt: DateTime.now(),
          id: '',
        ),
      );

      return Response.ok(
        jsonEncode({
          'message': 'Lease transfer approved successfully',
          'newTenantId': lease.transferToTenantId,
        }),
      );
    } catch (e, stack) {
      print('Approve lease transfer error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  /// PATCH /leases/<id>/reject-transfer - Landlord rejects lease transfer
  Future<Response> rejectLeaseTransfer(Request request) async {
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
          body: jsonEncode({'message': 'Only landlords or managers can reject lease transfers'}),
        );
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final reason = body['reason'] as String?;

      if (reason == null || reason.trim().isEmpty) {
        return badRequest('Rejection reason is required');
      }

      final lease = await leaseRepository.getLeaseById(leaseId);

      if (lease.transferStatus != 'Pending') {
        return Response(400, body: jsonEncode({'message': 'No pending transfer request to reject'}));
      }

      await leaseRepository.rejectLeaseTransfer(leaseId, userId, reason);

      // Notify original tenant
      await notificationRepository.create(
        NotificationModel(
          userId: lease.tenantId,
          type: 'lease_transfer_rejected',
          title: 'Lease Transfer Rejected',
          body: 'Your lease transfer request was rejected. Reason: $reason',
          relatedId: leaseId,
          relatedCollection: 'leases',
          createdAt: DateTime.now(),
          id: '',
        ),
      );

      // Log history
      await historyRepository.createHistoryEntry(
        HistoryEntryModel(
          userId: lease.tenantId,
          type: 'lease_transfer_rejected',
          title: 'Lease Transfer Rejected',
          description: 'Transfer request was rejected by landlord. Reason: $reason',
          relatedId: leaseId,
          relatedCollection: 'leases',
          timestamp: DateTime.now(),
          id: '',
        ),
      );

      await historyRepository.createHistoryEntry(
        HistoryEntryModel(
          userId: userId,
          type: 'lease_transfer_rejected',
          title: 'Lease Transfer Rejected',
          description: 'You rejected the lease transfer request for Unit ${lease.unitId}',
          relatedId: leaseId,
          relatedCollection: 'leases',
          timestamp: DateTime.now(),
          id: '',
        ),
      );

      return Response.ok(jsonEncode({'message': 'Lease transfer rejected successfully', 'leaseId': leaseId}));
    } catch (e, stack) {
      print('Reject lease transfer error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to reject lease transfer'}));
    }
  }

  /// POST /leases/<id>/early-termination - Tenant requests early termination
  Future<Response> requestEarlyTermination(Request request) async {
    try {
      final tenantId = request.context['userId'] as String?;
      final leaseId = request.params['id'];

      if (tenantId == null || leaseId == null) return _unauthorized();

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final reason = body['reason'] as String?;

      if (reason == null || reason.trim().isEmpty) {
        return badRequest('Reason for early termination is required');
      }

      final lease = await leaseRepository.getLeaseById(leaseId);

      if (lease.tenantId != tenantId) {
        return Response(403, body: jsonEncode({'message': 'You can only terminate your own lease'}));
      }

      if (lease.status != 'Active') {
        return Response(400, body: jsonEncode({'message': 'Only active leases can be terminated early'}));
      }

      // Calculate settlement
      final settlement = await leaseRepository.calculateEarlyTerminationSettlement(leaseId, unitRepository);

      await leaseRepository.requestEarlyTermination(leaseId: leaseId, reason: reason, requestedBy: 'tenant');

      // Notify Landlord
      await notificationRepository.create(
        NotificationModel(
          userId: lease.landownerId,
          type: 'early_termination_request',
          title: 'Early Termination Request',
          body: 'Tenant has requested early termination. Reason: $reason',
          relatedId: leaseId,
          relatedCollection: 'leases',
          createdAt: DateTime.now(),
          id: '',
        ),
      );

      return Response.ok(
        jsonEncode({
          'message': 'Early termination request submitted',
          'leaseId': leaseId,
          'settlement': settlement,
        }),
      );
    } catch (e, stack) {
      print('Request early termination error: $e\n$stack');
      return Response.internalServerError();
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
          ['active', 'pending payment', 'terminated'].contains(lease.status.toLowerCase())) {
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

  /// GET /leases/termination-requests - Get all termination/transfer requests (for landowner/manager)
  Future<Response> getTerminationRequests(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;

      if (userId == null || !['landowner', 'manager'].contains(role)) {
        return Response(
          403,
          body: jsonEncode({'message': 'Only landlords/managers can view termination requests'}),
        );
      }

      final requests = await leaseRepository.getTerminationRequests(userId);

      return Response.ok(jsonEncode({'terminationRequests': requests.map((req) => req.toMap()).toList()}));
    } catch (e, stack) {
      print('Get termination requests error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  /// PATCH /leases/<id>/confirm-payment - Landlord confirms payment received
  Future<Response> confirmPaymentReceived(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final leaseId = request.params['id'];

      if (userId == null || leaseId == null) return _unauthorized();

      if (!['landowner', 'manager'].contains(role)) {
        return Response(403, body: jsonEncode({'message': 'Only landlords/managers can confirm payment'}));
      }

      final lease = await leaseRepository.getLeaseById(leaseId);

      if (lease.status != 'Pending Payment') {
        return Response(400, body: jsonEncode({'message': 'Lease is not awaiting payment confirmation'}));
      }

      // Confirm payment and activate lease
      await leaseRepository.confirmPaymentAndActivate(leaseId, userId);

      // Add tenant to unit
      await unitRepository.updateUnitStatus(
        unitId: lease.unitId,
        status: 'occupied',
        currentTenantId: lease.tenantId,
        isListedForRent: false,
      );

      // Notifications
      // await notificationRepository.create(/* tenant notification */);
      // await notificationRepository.create(/* landlord confirmation */);

      return Response.ok(
        jsonEncode({
          'message': 'Payment confirmed. Tenant officially added to unit.',
          'leaseId': leaseId,
          'unitUpdated': true,
        }),
      );
    } catch (e, stack) {
      print('Confirm payment error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  Response _unauthorized() => Response(401, body: jsonEncode({'message': 'Unauthorized'}));
}
