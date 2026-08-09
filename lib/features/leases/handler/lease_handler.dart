import 'dart:convert';
import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/core/services/reputation/reputation_service.dart';
import 'package:neztmate_backend/features/auth_user/models/user_model.dart';
import 'package:neztmate_backend/features/auth_user/repositories/user_repository.dart';
import 'package:neztmate_backend/features/history/model/user_history_model.dart';
import 'package:neztmate_backend/features/history/repository/user_history_repo.dart';
import 'package:neztmate_backend/features/leases/models/lease_request_model.dart';
import 'package:neztmate_backend/features/leases/models/leases_model.dart';
import 'package:neztmate_backend/features/leases/repository/lease_repo.dart';
import 'package:neztmate_backend/features/leases/service/lease_payment_calculator_service.dart';
import 'package:neztmate_backend/features/notifications/models/notification_model.dart';
import 'package:neztmate_backend/features/notifications/repository/notification_repo.dart';
import 'package:neztmate_backend/features/payments/models/payments.dart';
import 'package:neztmate_backend/features/payments/repository/payment_repo.dart';
import 'package:neztmate_backend/features/properties/repository/property_repo.dart';
import 'package:neztmate_backend/features/tenants/repository/tenant_respository.dart';
import 'package:neztmate_backend/features/units/models/unit_model.dart';
import 'package:neztmate_backend/features/units/repository/unit_repo.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

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

  // HELPERS

  Future<Map<String, dynamic>> _enrichLease(LeaseModel lease) async {
    final tenant = await userRepository.getUserById(lease.tenantId);
    final manager = await userRepository.getUserById(lease.managerId ?? lease.landownerId);
    final unit = await unitRepository.getUnitById(lease.unitId);
    final property = await propertyRepository.getPropertyById(lease.propertyId);
    final neighbors = await tenantRepository.getTenantNeighbors(lease.propertyId, lease.tenantId);
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
        'profilePhotoUrl': tenant.profilePhotoUrl,
      },
      'manager': {
        'id': manager.id,
        'fullName': manager.fullName,
        'email': manager.email,
        'phone': manager.phone,
        'role': manager.role,
        'profilePhotoUrl': manager.profilePhotoUrl,
      },
      'unit': unit.toMap(),
      'property': {
        'id': property.id,
        'name': property.name,
        'address': property.address,
        'landownerId': property.landownerId,
        'propertyPhotos': property.photoUrls,
      },
      'neighbors': neighbors.map((e) => e.toMap()).toList(),
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
              'ownerType': payoutAccount.userId == lease.managerId ? 'Manager' : 'Landowner',
              'accountName': payoutAccount.accountName,
              'accountNumber': payoutAccount.accountNumber,
              'bankName': payoutAccount.bankName,
              'bankCode': payoutAccount.bankCode,
              'currency': 'NGN',
            },
    };
  }

  Response _unauthorized() => Response(401, body: jsonEncode({'message': 'Unauthorized'}));

  // VIEW LEASES

  /// GET /leases/me
  Future<Response> getMyLeases(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;

      if (userId == null) return _unauthorized();
      if (!['tenant', 'manager', 'landowner'].contains(role)) {
        return Response(403, body: jsonEncode({'message': 'You are not authorized to view leases'}));
      }

      List<LeaseModel> leases = [];
      if (role == 'manager') {
        leases = await leaseRepository.getLeasesByManager(userId);
      } else if (role == 'landowner') {
        leases = await leaseRepository.getLeasesByLandowner(userId);
      } else {
        leases = await leaseRepository.getLeasesByTenant(userId);
      }

      final enrichedLeases = await Future.wait(leases.map(_enrichLease));

      return Response.ok(
        jsonEncode({'leases': enrichedLeases, 'message': 'Your leases loaded successfully'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Get my leases error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to load leases'}));
    }
  }

  /// GET /leases/<id>
  Future<Response> getLeaseById(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final leaseId = request.params['id'];

      if (userId == null || leaseId == null) return _unauthorized();

      final lease = await leaseRepository.getLeaseById(leaseId);

      final isTenant = lease.tenantId == userId;
      final isLandowner = lease.landownerId == userId;
      final isManager = role == 'manager' || lease.managerId == userId;

      if (!isTenant && !isLandowner && !isManager) {
        return Response(403, body: jsonEncode({'message': 'Forbidden'}));
      }

      final enriched = await _enrichLease(lease);

      return Response.ok(jsonEncode({'lease': enriched}), headers: {'Content-Type': 'application/json'});
    } on NotFoundException catch (e) {
      return Response(404, body: jsonEncode({'message': e.message}));
    } catch (e, stack) {
      print('Get lease by id error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to load lease'}));
    }
  }

  /// GET /leases/application/<id>
  Future<Response> getLeaseByApplicationId(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final applicationId = request.params['id'];

      if (userId == null || applicationId == null) return _unauthorized();

      final lease = await leaseRepository.getLeaseByApplicationId(applicationId);

      final isTenant = lease.tenantId == userId;
      final isLandowner = lease.landownerId == userId;
      final isManager = role == 'manager' || lease.managerId == userId;

      if (!isTenant && !isLandowner && !isManager) {
        return Response(403, body: jsonEncode({'message': 'Forbidden'}));
      }

      final enriched = await _enrichLease(lease);

      return Response.ok(jsonEncode({'lease': enriched}), headers: {'Content-Type': 'application/json'});
    } on NotFoundException catch (e) {
      return Response(404, body: jsonEncode({'message': e.message}));
    } catch (e, stack) {
      print('Get lease by application error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to load lease'}));
    }
  }

  /// GET /leases/property/<propertyId>
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

      final allLeases = role == 'landowner'
          ? await leaseRepository.getLeasesByLandowner(userId)
          : await leaseRepository.getLeasesByManager(userId);

      final leases = allLeases.where((l) => l.propertyId == propertyId).toList();
      final enrichedLeases = await Future.wait(leases.map(_enrichLease));

      return Response.ok(
        jsonEncode({'leases': enrichedLeases, 'message': 'Leases for this property'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Get leases by property error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  // SIGNING

  /// PATCH /leases/<id>/sign
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
      final paymentReceiptUrl = body['paymentReceiptUrl'] as String?;

      if (signedPdfUrl == null || signedPdfUrl.isEmpty) {
        return Response(400, body: jsonEncode({'message': 'signedPdfUrl is required'}));
      }
      if (paymentReceiptUrl == null || paymentReceiptUrl.isEmpty) {
        return Response(400, body: jsonEncode({'message': 'paymentReceiptUrl is required'}));
      }

      final lease = await leaseRepository.getLeaseById(leaseId);
      if (lease.tenantId != userId) {
        return Response(403, body: jsonEncode({'message': 'This is not your lease'}));
      }

      final activeLeases = await leaseRepository.getActiveLeasesByTenant(userId);
      if (activeLeases.isNotEmpty) {
        final currentLease = activeLeases.first;
        final daysUntilExpiry = currentLease.endDate.difference(DateTime.now()).inDays;
        if (daysUntilExpiry > 30 && currentLease.id != leaseId) {
          return Response(
            400,
            body: jsonEncode({
              'message':
                  'You already have an active lease. Please complete or terminate your current lease before signing a new one.',
              'currentLeaseId': currentLease.id,
              'currentLeaseEndDate': currentLease.endDate.toIso8601String(),
              'daysRemaining': daysUntilExpiry,
            }),
          );
        }
      }

      await leaseRepository.markLeaseAsSigned(leaseId, signedPdfUrl, paymentReceiptUrl, userId);

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
          'status': 'pending_payment',
          'signedAgreementPdfUrl': signedPdfUrl,
        }),
      );
    } on NotFoundException catch (e) {
      return Response(404, body: jsonEncode({'message': e.message}));
    } catch (e, stack) {
      print('Sign lease error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to sign lease'}));
    }
  }

  // PAYMENT CONFIRM

  /// PATCH /leases/<id>/confirm-payment
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
      final status = lease.status.toLowerCase().replaceAll(' ', '_');
      if (status != 'pending_payment' && status != 'payment_submitted') {
        return Response(400, body: jsonEncode({'message': 'Lease is not awaiting payment confirmation'}));
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final isRenewal = body['isRenewal'] as bool? ?? false;

      final unit = await unitRepository.getUnitById(lease.unitId);
      final paymentSummary = LeasePaymentCalculatorService.calculate(lease: lease, unit: unit);

      final double totalAmount = isRenewal
          ? (paymentSummary['renewalPayment']?['total'] as num? ?? lease.monthlyRent).toDouble()
          : (paymentSummary['firstPayment']?['total'] as num? ?? lease.monthlyRent).toDouble();

      await _recordLeasePaymentInternal(
        lease: lease,
        amount: totalAmount,
        paymentMethod: 'bank transfer',
        transactionRef: 'nm_${DateTime.now().millisecondsSinceEpoch}',
        receiptUrl: lease.paymentReceiptUrl,
        confirmedBy: userId,
        type: isRenewal ? 'rent_renewal' : 'rent',
      );

      if (isRenewal) {
        final durationMonths = lease.durationMonths ?? 12;
        final newStartDate = lease.endDate;
        final newEndDate = newStartDate.add(Duration(days: durationMonths * 30));

        final newLease = await leaseRepository.createRenewalLease(
          oldLeaseId: leaseId,
          newStartDate: newStartDate,
          newEndDate: newEndDate,
          monthlyRent: lease.monthlyRent,
          reason: 'Renewal after payment confirmation',
          paymentReceiptUrl: lease.paymentReceiptUrl,
        );

        await unitRepository.updateUnitStatus(
          unitId: lease.unitId,
          status: 'occupied',
          currentTenantId: lease.tenantId,
          isListedForRent: false,
        );

        return Response.ok(
          jsonEncode({
            'message': 'Renewal payment confirmed. New lease is active.',
            'newLeaseId': newLease.id,
            'oldLeaseId': leaseId,
          }),
        );
      }

      await leaseRepository.confirmPaymentAndActivate(leaseId, userId);

      await unitRepository.updateUnitStatus(
        unitId: lease.unitId,
        status: 'occupied',
        currentTenantId: lease.tenantId,
        isListedForRent: false,
      );

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

  // RENEWAL (OFFLINE)

  /// POST /leases/<id>/request-renewal
  Future<Response> requestRenewal(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final leaseId = request.params['id'];

      if (userId == null || leaseId == null) return _unauthorized();
      if (role != 'tenant') {
        return Response(403, body: jsonEncode({'message': 'Only tenants can request renewal'}));
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>? ?? {};

      final renewalDuration = body['renewalDuration'] as String?;
      final preferredStartDateRaw = body['preferredStartDate'] as String?;
      final notes = body['notes'] as String?;
      final autoRenew = body['autoRenew'] as bool? ?? false;

      if (renewalDuration == null || renewalDuration.trim().isEmpty) {
        return badRequest('renewalDuration is required (e.g. "12 Months")');
      }

      final allowedDurations = ['12 Months', '18 Months', '24 Months', '6 Months'];
      if (!allowedDurations.contains(renewalDuration.trim())) {
        return badRequest('Invalid renewalDuration. Allowed: ${allowedDurations.join(", ")}');
      }

      if (preferredStartDateRaw == null || preferredStartDateRaw.trim().isEmpty) {
        return badRequest('preferredStartDate is required');
      }

      DateTime preferredStartDate;
      try {
        preferredStartDate = DateTime.parse(preferredStartDateRaw);
      } catch (_) {
        return badRequest('preferredStartDate must be a valid ISO date');
      }

      if (preferredStartDate.isBefore(DateTime.now().subtract(const Duration(days: 1)))) {
        return badRequest('preferredStartDate cannot be in the past');
      }

      final lease = await leaseRepository.getLeaseById(leaseId);
      if (lease.tenantId != userId) {
        return Response(403, body: jsonEncode({'message': 'This is not your lease'}));
      }
      if (!['inactive', 'expired'].contains(lease.status.toLowerCase())) {
        return badRequest('Only inactive or expired leases can be renewed');
      }

      final created = await leaseRepository.createLeaseRequest(
        LeaseRequestModel(
          id: '',
          leaseId: lease.id,
          propertyId: lease.propertyId,
          unitId: lease.unitId,
          tenantId: lease.tenantId,
          landownerId: lease.landownerId,
          managerId: lease.managerId,
          type: LeaseRequestType.renewal,
          status: LeaseRequestStatus.pending,
          initiatedBy: LeaseRequestActor.tenant,
          initiatedById: userId,
          assignedToId: lease.managerId ?? lease.landownerId,
          title: 'Lease Renewal Request',
          reason: notes?.trim().isNotEmpty == true ? notes!.trim() : 'Tenant requested renewal',
          message: notes?.trim(),
          metadata: {
            'renewalDuration': renewalDuration.trim(),
            'preferredStartDate': preferredStartDate.toIso8601String(),
            'autoRenew': autoRenew,
            if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
          },
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await leaseRepository.markLeaseAsPendingRenewal(leaseId);

      await notificationRepository.create(
        NotificationModel(
          id: '',
          userId: lease.landownerId,
          type: 'renewal_requested',
          title: 'Tenant Requested Renewal',
          body: 'Your tenant has requested to renew the lease for $renewalDuration.',
          relatedId: created.id,
          relatedCollection: 'lease_requests',
          createdAt: DateTime.now(),
        ),
      );

      if (lease.managerId != null && lease.managerId != lease.landownerId) {
        await notificationRepository.create(
          NotificationModel(
            id: '',
            userId: lease.managerId!,
            type: 'renewal_requested',
            title: 'Tenant Requested Renewal',
            body: 'A tenant has requested to renew the lease for $renewalDuration.',
            relatedId: created.id,
            relatedCollection: 'lease_requests',
            createdAt: DateTime.now(),
          ),
        );
      }

      return Response.ok(
        jsonEncode({
          'message': 'Renewal request submitted successfully',
          'request': created.toMap(),
          'status': 'pending_renewal',
        }),
      );
    } on ValidationException catch (e) {
      return Response(400, body: jsonEncode({'message': e.message}));
    } catch (e, stack) {
      print('Request renewal error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  /// POST /leases/<id>/offer-renewal
  Future<Response> offerRenewal(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final leaseId = request.params['id'];

      if (userId == null || leaseId == null) return _unauthorized();
      if (!['landowner', 'manager'].contains(role)) {
        return Response(403, body: jsonEncode({'message': 'Only landowners/managers can offer renewal'}));
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>? ?? {};

      final renewalDuration = body['renewalDuration'] as String?;
      final preferredStartDateRaw = body['preferredStartDate'] as String?;
      final notes = body['notes'] as String?;
      final autoRenew = body['autoRenew'] as bool? ?? false;
      final proposedRent = (body['proposedRent'] as num?)?.toDouble();

      if (renewalDuration == null || renewalDuration.trim().isEmpty) {
        return badRequest('renewalDuration is required (e.g. "12 Months")');
      }

      final allowedDurations = ['12 Months', '18 Months', '24 Months', '6 Months'];
      if (!allowedDurations.contains(renewalDuration.trim())) {
        return badRequest('Invalid renewalDuration. Allowed: ${allowedDurations.join(", ")}');
      }

      if (preferredStartDateRaw == null || preferredStartDateRaw.trim().isEmpty) {
        return badRequest('preferredStartDate is required');
      }

      DateTime preferredStartDate;
      try {
        preferredStartDate = DateTime.parse(preferredStartDateRaw);
      } catch (_) {
        return badRequest('preferredStartDate must be a valid ISO date');
      }

      if (preferredStartDate.isBefore(DateTime.now().subtract(const Duration(days: 1)))) {
        return badRequest('preferredStartDate cannot be in the past');
      }

      final lease = await leaseRepository.getLeaseById(leaseId);
      if (lease.status.toLowerCase() != 'inactive') {
        return badRequest('Only inactive leases can be offered for renewal');
      }

      // Optional ownership check
      if (role == 'landowner' && lease.landownerId != userId) {
        return Response(403, body: jsonEncode({'message': 'This is not your property lease'}));
      }
      if (role == 'manager' && lease.managerId != userId) {
        return Response(403, body: jsonEncode({'message': 'You are not the manager of this lease'}));
      }

      final created = await leaseRepository.createLeaseRequest(
        LeaseRequestModel(
          id: '',
          leaseId: lease.id,
          propertyId: lease.propertyId,
          unitId: lease.unitId,
          tenantId: lease.tenantId,
          landownerId: lease.landownerId,
          managerId: lease.managerId,
          type: LeaseRequestType.renewal,
          status: LeaseRequestStatus.pending,
          initiatedBy: role == 'manager' ? LeaseRequestActor.manager : LeaseRequestActor.landlord,
          initiatedById: userId,
          assignedToId: lease.tenantId,
          title: 'Lease Renewal Offer',
          reason: notes?.trim().isNotEmpty == true ? notes!.trim() : 'Landlord offered renewal',
          message: notes?.trim(),
          metadata: {
            'renewalDuration': renewalDuration.trim(),
            'preferredStartDate': preferredStartDate.toIso8601String(),
            'autoRenew': autoRenew,
            if (proposedRent != null) 'proposedRent': proposedRent,
            if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
          },
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await leaseRepository.markLeaseAsPendingRenewal(leaseId);

      await notificationRepository.create(
        NotificationModel(
          id: '',
          userId: lease.tenantId,
          type: 'renewal_offered',
          title: 'Lease Renewal Available',
          body: 'Your landlord has offered to renew your lease for $renewalDuration.',
          relatedId: created.id,
          relatedCollection: 'lease_requests',
          createdAt: DateTime.now(),
        ),
      );

      return Response.ok(
        jsonEncode({
          'message': 'Renewal offered successfully',
          'request': created.toMap(),
          'status': 'pending_payment',
        }),
      );
    } on ValidationException catch (e) {
      return Response(400, body: jsonEncode({'message': e.message}));
    } catch (e, stack) {
      print('Offer renewal error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  /// POST /leases/<id>/confirm-renewal-payment
  Future<Response> confirmRenewalPayment(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final leaseId = request.params['id'];

      if (userId == null || leaseId == null) return _unauthorized();
      if (role != 'tenant') {
        return Response(403, body: jsonEncode({'message': 'Only tenants can confirm renewal payment'}));
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final receiptUrl = body['receiptUrl'] as String?;
      final amountPaid = (body['amountPaid'] as num?)?.toDouble();
      final requestId = body['requestId'] as String?;

      if (receiptUrl == null || receiptUrl.trim().isEmpty) {
        return badRequest('receiptUrl is required');
      }

      if (requestId == null || requestId.trim().isEmpty) {
        return badRequest('requestId is required');
      }
      if (amountPaid == null || amountPaid <= 0) {
        return badRequest('Valid amountPaid is required');
      }

      final lease = await leaseRepository.getLeaseById(leaseId);
      if (lease.tenantId != userId) {
        return Response(403, body: jsonEncode({'message': 'This is not your lease'}));
      }

      final renewalRequest = await leaseRepository.getLeaseRequestById(requestId);

      if (renewalRequest.leaseId != leaseId) {
        return badRequest('Request does not belong to this lease');
      }
      if (renewalRequest.tenantId != userId) {
        return Response(403, body: jsonEncode({'message': 'This is not your renewal request'}));
      }
      if (renewalRequest.type != LeaseRequestType.renewal) {
        return badRequest('Not a renewal request');
      }

      final reqStatus = renewalRequest.status;
      if (![
        LeaseRequestStatus.approved,
        LeaseRequestStatus.paymentRequired,
        LeaseRequestStatus.pending,
      ].contains(reqStatus)) {
        return badRequest('This renewal request is not awaiting payment proof');
      }

      final unit = await unitRepository.getUnitById(renewalRequest.unitId);

      // verify amount against calculator / metadata
      final metadata = renewalRequest.metadata;
      final durationStr = (metadata['renewalDuration'] as String?) ?? '12 Months';
      final months = parseDurationMonths(durationStr);

      final expectedSummary = await LeasePaymentCalculatorService.calculate(
        lease: lease,
        unit: unit,
        customDurationMonth: months,
      );
      if ((amountPaid != double.tryParse(expectedSummary['renewalPayment']['total'].toString()))) {
        return badRequest('Amount mismatch');
      }

      final updatedMetadata = {
        ...renewalRequest.metadata,
        'receiptUrl': receiptUrl.trim(),
        'amountPaid': amountPaid,
        'paymentMethod': 'offline',
        'paymentSubmittedAt': DateTime.now().toIso8601String(),
        'paymentSubmittedBy': userId,
      };

      final updatedRequest = await leaseRepository.updateLeaseRequest(
        renewalRequest.copyWith(
          status: LeaseRequestStatus.paymentSubmitted, // or a dedicated paymentSubmitted if you add it
          // Prefer adding: LeaseRequestStatus.paymentSubmitted
          metadata: updatedMetadata,
          message: 'Tenant submitted offline payment proof',
          updatedAt: DateTime.now(),
        ),
      );

      await notificationRepository.create(
        NotificationModel(
          id: '',
          userId: lease.landownerId,
          type: 'renewal_payment_submitted',
          title: 'Renewal Payment Submitted',
          body:
              'Tenant submitted payment proof (₦${amountPaid.toStringAsFixed(0)}) for lease renewal. Please review and approve.',
          relatedId: updatedRequest.id,
          relatedCollection: 'lease_requests',
          createdAt: DateTime.now(),
        ),
      );

      if (lease.managerId != null && lease.managerId != lease.landownerId) {
        await notificationRepository.create(
          NotificationModel(
            id: '',
            userId: lease.managerId!,
            type: 'renewal_payment_submitted',
            title: 'Renewal Payment Submitted',
            body: 'Tenant submitted renewal payment proof. Please review.',
            relatedId: updatedRequest.id,
            relatedCollection: 'lease_requests',
            createdAt: DateTime.now(),
          ),
        );
      }

      return Response.ok(
        jsonEncode({
          'message': 'Payment proof submitted successfully. Waiting for landlord confirmation.',
          'leaseId': leaseId,
          'requestId': updatedRequest.id,
          'requestStatus': updatedRequest.status.value,
        }),
      );
    } catch (e, stack) {
      print('Confirm renewal payment error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  /// GET /leases/<id>/renewal-payment-summary
  Future<Response> getRenewalPaymentSummary(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final leaseId = request.params['id'];
      if (userId == null || leaseId == null) return _unauthorized();

      final lease = await leaseRepository.getLeaseById(leaseId);

      final isParty = lease.tenantId == userId || lease.landownerId == userId || lease.managerId == userId;
      if (!isParty) {
        return Response(403, body: jsonEncode({'message': 'Forbidden'}));
      }

      final unit = await unitRepository.getUnitById(lease.unitId);

      // Latest approved / pending renewal request
      final renewalRequest = await leaseRepository.getActiveLeaseRequest(
        leaseId,
        type: LeaseRequestType.renewal,
      );

      final metadata = renewalRequest?.metadata ?? {};
      final durationStr = (metadata['renewalDuration'] as String?) ?? '12 Months';
      final months = parseDurationMonths(durationStr);

      final paymentSummary = LeasePaymentCalculatorService.calculate(
        lease: lease,
        unit: unit,
        customDurationMonth: months,
      );

      final payoutAccount = await paymentRepository.getDefaultPayoutAccount(
        lease.managerId ?? lease.landownerId,
      );

      return Response.ok(
        jsonEncode({
          'message': "Renewal payment summary loaded successfully",
          'leaseId': leaseId,
          'requestId': renewalRequest?.id,
          'paymentMode': lease.rentPaymentMode,
          // 'preferredStartDate': metadata['preferredStartDate'],
          "paymentSummary": paymentSummary,
          'paymentAccount': (payoutAccount == null || lease.rentPaymentMode.toLowerCase() == 'online')
              ? null
              : {
                  'id': payoutAccount.id,
                  'ownerId': payoutAccount.userId,
                  'ownerType': payoutAccount.userId == lease.managerId ? 'Manager' : 'Landowner',
                  'accountName': payoutAccount.accountName,
                  'accountNumber': payoutAccount.accountNumber,
                  'bankName': payoutAccount.bankName,
                  'bankCode': payoutAccount.bankCode,
                  'currency': 'NGN',
                },
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Renewal payment summary error: $e\n$stack');
      return Response.internalServerError(
        body: jsonEncode({'message': 'Failed to calculate renewal summary'}),
      );
    }
  }

  /// POST /leases/<id>/approve-renewal-payment
  Future<Response> approveRenewalPayment(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final leaseId = request.params['id'];

      if (userId == null || leaseId == null) return _unauthorized();
      if (!['landowner', 'manager'].contains(role)) {
        return Response(
          403,
          body: jsonEncode({'message': 'Only landowners or managers can approve renewal payment'}),
        );
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>? ?? {};
      final requestId = body['requestId'] as String?;

      if (requestId == null || requestId.trim().isEmpty) {
        return badRequest('requestId is required');
      }
      final oldLease = await leaseRepository.getLeaseById(leaseId);

      if (role == 'landowner' && oldLease.landownerId != userId) {
        return Response(403, body: jsonEncode({'message': 'Not your lease'}));
      }
      if (role == 'manager' && oldLease.managerId != userId) {
        return Response(403, body: jsonEncode({'message': 'Not your managed lease'}));
      }

      final renewalRequest = await leaseRepository.getLeaseRequestById(requestId);

      if (renewalRequest.leaseId != leaseId) {
        return badRequest('Request does not belong to this lease');
      }
      if (renewalRequest.type != LeaseRequestType.renewal) {
        return badRequest('Not a renewal request');
      }

      final receiptUrl = renewalRequest.metadata['receiptUrl'] as String?;
      if (receiptUrl == null || receiptUrl.isEmpty) {
        return badRequest('Tenant has not submitted a payment receipt yet');
      }

      // Mark request completed
      await leaseRepository.updateLeaseRequest(
        renewalRequest.copyWith(
          status: LeaseRequestStatus.completed,
          resolvedAt: DateTime.now(),
          updatedAt: DateTime.now(),
          metadata: {
            ...renewalRequest.metadata,
            'paymentApprovedAt': DateTime.now().toIso8601String(),
            'paymentApprovedBy': userId,
          },
        ),
      );

      // Duration from request metadata, fallback to lease
      final durationStr = renewalRequest.metadata['renewalDuration'] as String?;
      final durationMonths = parseDurationMonths(durationStr ?? '12 months');

      final proposedRent =
          (renewalRequest.metadata['proposedRent'] as num?)?.toDouble() ?? oldLease.monthlyRent;

      final amountPaid = (renewalRequest.metadata['amountPaid'] as double?)?.toDouble() ?? 0;

      final newLease = await leaseRepository.renewLeaseAfterPayment(
        oldLease.copyWith(durationMonths: durationMonths),
        durationMonths,
        proposedRent,
        receiptUrl,
      );

      await _recordLeasePaymentInternal(
        lease: newLease,
        amount: amountPaid,
        paymentMethod: 'bank transfer',
        transactionRef:
            'nm_rent_renewal_${newLease.id.substring(0, 5)}${DateTime.now().millisecondsSinceEpoch}',
        receiptUrl: receiptUrl,
        confirmedBy: userId,
        type: 'rent_renewal',
      );

      await unitRepository.updateUnitStatus(
        unitId: oldLease.unitId,
        status: 'occupied',
        currentTenantId: oldLease.tenantId,
        isListedForRent: false,
      );

      await notificationRepository.create(
        NotificationModel(
          id: '',
          userId: oldLease.tenantId,
          type: 'lease_renewed',
          title: 'Lease Renewed Successfully',
          body: 'Your lease has been renewed until ${newLease.endDate.toIso8601String().split("T").first}',
          relatedId: newLease.id,
          relatedCollection: 'leases',
          createdAt: DateTime.now(),
        ),
      );

      return Response.ok(
        jsonEncode({
          'message': 'Renewal payment approved. New lease is now active.',
          'requestId': renewalRequest.id,
          'newLeaseId': newLease.id,
          'oldLeaseId': leaseId,
          'newEndDate': newLease.endDate.toIso8601String(),
        }),
      );
    } catch (e, stack) {
      print('Approve renewal payment error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  // MANUAL LEASE

  /// POST /leases/manual
  Future<Response> createManualLease(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;

      if (userId == null || !['landowner', 'manager'].contains(role)) {
        return Response(
          403,
          body: jsonEncode({'message': 'Only landowners or managers can create manual leases'}),
        );
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;

      final requiredFields = [
        'unitId',
        'propertyId',
        'tenantEmail',
        'tenantFullName',
        'startDate',
        'endDate',
        'monthlyRent',
      ];
      for (final field in requiredFields) {
        if (body[field] == null || body[field].toString().trim().isEmpty) {
          return badRequest('$field is required');
        }
      }

      final monthlyRent = (body['monthlyRent'] as num?)?.toDouble();
      if (monthlyRent == null || monthlyRent <= 0) {
        return badRequest('monthlyRent must be greater than 0');
      }

      final startDate = DateTime.tryParse(body['startDate']);
      final endDate = DateTime.tryParse(body['endDate']);
      if (startDate == null || endDate == null) {
        return badRequest('Invalid startDate or endDate format. Use ISO8601');
      }
      if (endDate.isBefore(startDate)) {
        return badRequest('endDate must be after startDate');
      }

      final unitId = body['unitId'] as String;
      final propertyId = body['propertyId'] as String;
      final tenantEmail = (body['tenantEmail'] as String).toLowerCase().trim();
      final tenantFullName = body['tenantFullName'] as String;
      final tenantPhone = body['tenantPhone'] as String?;

      final unit = await unitRepository.getUnitById(unitId);
      final property = await propertyRepository.getPropertyById(propertyId);

      if (property.landownerId != userId && property.managerId != userId) {
        return Response(
          403,
          body: jsonEncode({'message': 'You do not have permission to create a lease on this property'}),
        );
      }
      if (unit.status.toLowerCase() == 'occupied' && unit.currentTenantId != null) {
        return badRequest('This unit is already occupied by another tenant');
      }

      User tenant;
      try {
        tenant = await userRepository.getUserByEmail(tenantEmail);
      } catch (_) {
        final newTenantId = const Uuid().v4();
        tenant = User(
          id: newTenantId,
          email: tenantEmail,
          fullName: tenantFullName,
          role: 'tenant',
          phone: tenantPhone,
          createdAt: DateTime.now(),
          lastLogin: DateTime.now(),
          fcmToken: '',
          platform: 'manual',
          country: 'Nigeria',
          primaryRole: 'tenant',
        );
        await userRepository.createUser(tenant);
      }

      final lease = LeaseModel(
        id: '',
        applicationId: 'manual_${DateTime.now().millisecondsSinceEpoch}',
        unitId: unitId,
        tenantId: tenant.id,
        landownerId: property.landownerId,
        propertyId: propertyId,
        managerId: property.managerId,
        startDate: startDate,
        endDate: endDate,
        monthlyRent: monthlyRent,
        durationMonths: body['durationMonths'] as int? ?? 12,
        fees: (body['fees'] as List?)?.map((e) => UnitFee.fromMap(e)).toList(),
        status: 'active',
        termsNotes: body['notes'] as String? ?? 'Existing tenant onboarded manually',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final createdLease = await leaseRepository.createManualLease(lease);

      await unitRepository.updateUnitStatus(
        unitId: unitId,
        status: 'occupied',
        currentTenantId: tenant.id,
        isListedForRent: false,
      );

      await notificationRepository.create(
        NotificationModel(
          id: '',
          userId: tenant.id,
          type: 'manual_lease_created',
          title: 'Lease Created',
          body: 'A lease has been created for you on NeztMate. Please log in to view details.',
          relatedId: createdLease.id,
          relatedCollection: 'leases',
          createdAt: DateTime.now(),
        ),
      );

      return Response.ok(
        jsonEncode({
          'message': 'Manual lease created successfully',
          'lease': createdLease.toMap(),
          'tenant': {
            'id': tenant.id,
            'fullName': tenant.fullName,
            'email': tenant.email,
            'phone': tenant.phone,
          },
        }),
      );
    } catch (e, stack) {
      print('Create manual lease error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to create manual lease'}));
    }
  }

  // STATUS

  /// PATCH /leases/<id>/status
  Future<Response> updateLeaseStatus(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final leaseId = request.params['id'];

      if (userId == null || leaseId == null) return _unauthorized();
      if (!['landowner', 'manager'].contains(role)) {
        return Response(
          403,
          body: jsonEncode({'message': 'Only landowners or managers can update lease status'}),
        );
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final newStatus = (body['status'] as String?)?.trim().toLowerCase().replaceAll(' ', '_');

      if (newStatus == null || newStatus.isEmpty) {
        return Response(400, body: jsonEncode({'message': 'Status is required'}));
      }

      final lease = await leaseRepository.getLeaseById(leaseId);

      if (lease.status.toLowerCase() == 'terminated') {
        return Response(400, body: jsonEncode({'message': 'Terminated leases cannot be modified'}));
      }

      if (newStatus == 'pending_payment' && lease.endDate.isAfter(DateTime.now())) {
        return Response(
          400,
          body: jsonEncode({'message': 'Cannot set to pending_payment. Current lease has not yet expired.'}),
        );
      }

      const allowedStatuses = ['pending_signature', 'pending_payment', 'active', 'inactive', 'terminated'];
      if (!allowedStatuses.contains(newStatus)) {
        return Response(
          400,
          body: jsonEncode({'message': 'Invalid status. Allowed: ${allowedStatuses.join(', ')}'}),
        );
      }

      await leaseRepository.updateLeaseStatus(leaseId, newStatus);

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

      return Response.ok(
        jsonEncode({
          'message': 'Lease status updated successfully',
          'leaseId': leaseId,
          'newStatus': newStatus,
        }),
      );
    } catch (e, stack) {
      print('Update lease status error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to update lease status'}));
    }
  }

  // TRANSFER REQUEST

  /// POST /leases/<id>/transfer
  Future<Response> requestLeaseTransfer(Request request) async {
    try {
      final tenantId = request.context['userId'] as String?;
      final leaseId = request.params['id'];

      if (tenantId == null || leaseId == null) return _unauthorized();

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final newTenantId = body['newTenantId'] as String?;
      final reason = body['reason'] as String? ?? 'Tenant relocation';

      if (newTenantId == null || newTenantId.isEmpty) {
        return badRequest('newTenantId (replacement tenant) is required');
      }

      final lease = await leaseRepository.getLeaseById(leaseId);
      if (lease.tenantId != tenantId) {
        return Response(403, body: jsonEncode({'message': 'You can only transfer your own lease'}));
      }
      if (lease.status.toLowerCase() != 'active') {
        return Response(400, body: jsonEncode({'message': 'Only active leases can be transferred'}));
      }

      final created = await leaseRepository.createLeaseRequest(
        LeaseRequestModel(
          id: '',
          leaseId: lease.id,
          propertyId: lease.propertyId,
          unitId: lease.unitId,
          tenantId: lease.tenantId,
          landownerId: lease.landownerId,
          managerId: lease.managerId,
          type: LeaseRequestType.transfer,
          status: LeaseRequestStatus.pending,
          initiatedBy: LeaseRequestActor.tenant,
          initiatedById: tenantId,
          assignedToId: lease.managerId ?? lease.landownerId,
          title: 'Lease Transfer Request',
          reason: reason,
          metadata: {'newTenantId': newTenantId},
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await notificationRepository.create(
        NotificationModel(
          userId: tenantId,
          type: 'lease_transfer_request_sent',
          title: 'Lease Transfer Requested',
          body: 'Your request to transfer the lease has been submitted.',
          relatedId: created.id,
          relatedCollection: 'lease_requests',
          createdAt: DateTime.now(),
          id: '',
        ),
      );

      await notificationRepository.create(
        NotificationModel(
          userId: newTenantId,
          type: 'lease_transfer_invited',
          title: 'You Have Been Invited to Take Over a Lease',
          body: 'A tenant has requested to transfer their lease to you.',
          relatedId: created.id,
          relatedCollection: 'lease_requests',
          createdAt: DateTime.now(),
          id: '',
        ),
      );

      await notificationRepository.create(
        NotificationModel(
          userId: lease.landownerId,
          type: 'lease_transfer_request',
          title: 'Lease Transfer Request',
          body: 'Tenant has requested to transfer lease to a new tenant.',
          relatedId: created.id,
          relatedCollection: 'lease_requests',
          createdAt: DateTime.now(),
          id: '',
        ),
      );

      return Response.ok(
        jsonEncode({'message': 'Lease transfer request submitted successfully', 'request': created.toMap()}),
      );
    } on ValidationException catch (e) {
      return Response(400, body: jsonEncode({'message': e.message}));
    } catch (e, stack) {
      print('Request lease transfer error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  // EARLY TERMINATION REQUEST

  /// POST /leases/<id>/early-termination
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
      if (lease.status.toLowerCase() != 'active') {
        return Response(400, body: jsonEncode({'message': 'Only active leases can be terminated early'}));
      }

      final settlement = await leaseRepository.calculateEarlyTerminationSettlement(leaseId, unitRepository);

      final created = await leaseRepository.createLeaseRequest(
        LeaseRequestModel(
          id: '',
          leaseId: lease.id,
          propertyId: lease.propertyId,
          unitId: lease.unitId,
          tenantId: lease.tenantId,
          landownerId: lease.landownerId,
          managerId: lease.managerId,
          type: LeaseRequestType.termination,
          status: LeaseRequestStatus.pending,
          initiatedBy: LeaseRequestActor.tenant,
          initiatedById: tenantId,
          assignedToId: lease.managerId ?? lease.landownerId,
          title: 'Early Termination Request',
          reason: reason,
          metadata: {'settlementPreview': settlement},
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await notificationRepository.create(
        NotificationModel(
          userId: lease.landownerId,
          type: 'early_termination_request',
          title: 'Early Termination Request',
          body: 'Tenant has requested early termination. Reason: $reason',
          relatedId: created.id,
          relatedCollection: 'lease_requests',
          createdAt: DateTime.now(),
          id: '',
        ),
      );

      return Response.ok(
        jsonEncode({
          'message': 'Early termination request submitted',
          'request': created.toMap(),
          'settlement': settlement,
        }),
      );
    } on ValidationException catch (e) {
      return Response(400, body: jsonEncode({'message': e.message}));
    } catch (e, stack) {
      print('Request early termination error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  /// PATCH /leases/<id>/terminate  (landlord force-terminate, no request)
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
      final settlement = await leaseRepository.calculateEarlyTerminationSettlement(leaseId, unitRepository);

      await leaseRepository.terminateLease(leaseId, reason, userId);

      await unitRepository.updateUnitStatus(
        unitId: lease.unitId,
        status: 'vacant',
        currentTenantId: null,
        isListedForRent: true,
      );

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

  // RENT ADJUSTMENT REQUEST

  /// POST /leases/<id>/adjust-rent
  Future<Response> proposeRentAdjustment(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final leaseId = request.params['id'];

      if (userId == null || leaseId == null) return _unauthorized();
      if (!['landowner', 'manager'].contains(role)) {
        return Response(
          403,
          body: jsonEncode({'message': 'Only landlords/managers can propose rent adjustments'}),
        );
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final newMonthlyRent = (body['newMonthlyRent'] as num?)?.toDouble();
      final effectiveStartDateRaw = body['effectiveStartDate'] as String?;

      final reason = body['reason'] as String?;

      if (newMonthlyRent == null || newMonthlyRent <= 0) {
        return badRequest('Valid new monthly rent is required');
      }
      if (reason == null || reason.trim().isEmpty) {
        return badRequest('Reason for rent adjustment is required');
      }

      if (effectiveStartDateRaw == null || effectiveStartDateRaw.trim().isEmpty) {
        return badRequest('effectiveStartDate is required');
      }

      DateTime effectiveStartDate;
      try {
        effectiveStartDate = DateTime.parse(effectiveStartDateRaw);
      } catch (_) {
        return badRequest('effectiveStartDate must be a valid ISO date');
      }
      final lease = await leaseRepository.getLeaseById(leaseId);

      final created = await leaseRepository.createLeaseRequest(
        LeaseRequestModel(
          id: '',
          leaseId: lease.id,
          propertyId: lease.propertyId,
          unitId: lease.unitId,
          tenantId: lease.tenantId,
          landownerId: lease.landownerId,
          managerId: lease.managerId,
          type: LeaseRequestType.rentAdjustment,
          status: LeaseRequestStatus.pending,
          initiatedBy: role == 'manager' ? LeaseRequestActor.manager : LeaseRequestActor.landlord,
          initiatedById: userId,
          assignedToId: lease.tenantId,
          title: 'Rent Adjustment Proposal',
          reason: reason,
          metadata: {
            'newMonthlyRent': newMonthlyRent,
            'currentMonthlyRent': lease.monthlyRent,
            'reason': reason,
            'effectiveStartDate': effectiveStartDate,
          },
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await notificationRepository.create(
        NotificationModel(
          id: '',
          userId: lease.tenantId,
          type: 'rent_adjustment_proposed',
          title: 'Rent Adjustment Proposed',
          body:
              'Your landlord proposed changing rent from ₦${lease.monthlyRent} to ₦$newMonthlyRent. Reason: $reason',
          relatedId: created.id,
          relatedCollection: 'lease_requests',
          createdAt: DateTime.now(),
        ),
      );

      return Response.ok(
        jsonEncode({'message': 'Rent adjustment proposed successfully', 'request': created.toMap()}),
      );
    } on ValidationException catch (e) {
      return Response(400, body: jsonEncode({'message': e.message}));
    } catch (e, stack) {
      print('Propose rent adjustment error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  // UNIFIED REQUEST ACTIONS

  /// PATCH /leases/requests/<requestId>/approve
  Future<Response> approveLeaseRequest(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final requestId = request.params['requestId'];

      if (userId == null || requestId == null) return _unauthorized();

      Map<String, dynamic> body = {};
      try {
        body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      } catch (_) {}
      final notes = body['notes'] as String?;

      final leaseRequest = await leaseRepository.getLeaseRequestById(requestId);

      if (leaseRequest.status != LeaseRequestStatus.pending) {
        return Response(400, body: jsonEncode({'message': 'Only pending requests can be approved'}));
      }

      final isTenantApprovingRent =
          leaseRequest.type == LeaseRequestType.rentAdjustment &&
          role == 'tenant' &&
          leaseRequest.tenantId == userId;

      final isOwnerOrManager =
          ['landowner', 'manager'].contains(role) &&
          (leaseRequest.landownerId == userId || leaseRequest.managerId == userId);

      if (!isTenantApprovingRent && !isOwnerOrManager) {
        return Response(403, body: jsonEncode({'message': 'Not allowed to approve this request'}));
      }

      await leaseRepository.approveLeaseRequest(requestId: requestId, approvedBy: userId, notes: notes);

      if (leaseRequest.type == LeaseRequestType.transfer) {
        final newTenantId = leaseRequest.metadata['newTenantId'] as String?;
        if (newTenantId != null) {
          await unitRepository.updateUnitStatus(
            unitId: leaseRequest.unitId,
            status: 'occupied',
            currentTenantId: newTenantId,
            isListedForRent: false,
          );
        }
      } else if (leaseRequest.type == LeaseRequestType.termination) {
        await unitRepository.updateUnitStatus(
          unitId: leaseRequest.unitId,
          status: 'vacant',
          currentTenantId: null,
          isListedForRent: true,
        );
        await userReputationService.updateUserReputation(leaseRequest.tenantId);
      }

      await notificationRepository.create(
        NotificationModel(
          userId: leaseRequest.initiatedById,
          type: 'lease_request_approved',
          title: 'Request Approved',
          body: 'Your ${leaseRequest.type.value} request was approved.',
          relatedId: requestId,
          relatedCollection: 'lease_requests',
          createdAt: DateTime.now(),
          id: '',
        ),
      );

      return Response.ok(
        jsonEncode({
          'message': 'Request approved successfully',
          'requestId': requestId,
          'type': leaseRequest.type.value,
        }),
      );
    } on NotFoundException catch (e) {
      return Response(404, body: jsonEncode({'message': e.message}));
    } on ValidationException catch (e) {
      return Response(400, body: jsonEncode({'message': e.message}));
    } catch (e, stack) {
      print('Approve lease request error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  /// PATCH /leases/requests/<requestId>/reject
  Future<Response> rejectLeaseRequest(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final requestId = request.params['requestId'];

      if (userId == null || requestId == null) return _unauthorized();

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final reason = body['reason'] as String?;
      if (reason == null || reason.trim().isEmpty) {
        return badRequest('Rejection reason is required');
      }

      final leaseRequest = await leaseRepository.getLeaseRequestById(requestId);

      if (leaseRequest.status != LeaseRequestStatus.pending) {
        return Response(400, body: jsonEncode({'message': 'Only pending requests can be rejected'}));
      }

      final isTenantRejectingRent =
          leaseRequest.type == LeaseRequestType.rentAdjustment &&
          role == 'tenant' &&
          leaseRequest.tenantId == userId;

      final isOwnerOrManager =
          ['landowner', 'manager'].contains(role) &&
          (leaseRequest.landownerId == userId || leaseRequest.managerId == userId);

      if (!isTenantRejectingRent && !isOwnerOrManager) {
        return Response(403, body: jsonEncode({'message': 'Not allowed to reject this request'}));
      }

      await leaseRepository.rejectLeaseRequest(requestId: requestId, rejectedBy: userId, reason: reason);

      await notificationRepository.create(
        NotificationModel(
          userId: leaseRequest.initiatedById,
          type: 'lease_request_rejected',
          title: 'Request Rejected',
          body: 'Your ${leaseRequest.type.value} request was rejected. Reason: $reason',
          relatedId: requestId,
          relatedCollection: 'lease_requests',
          createdAt: DateTime.now(),
          id: '',
        ),
      );

      return Response.ok(jsonEncode({'message': 'Request rejected successfully', 'requestId': requestId}));
    } on NotFoundException catch (e) {
      return Response(404, body: jsonEncode({'message': e.message}));
    } on ValidationException catch (e) {
      return Response(400, body: jsonEncode({'message': e.message}));
    } catch (e, stack) {
      print('Reject lease request error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  /// PATCH /leases/requests/<requestId>/cancel
  Future<Response> cancelLeaseRequest(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final requestId = request.params['requestId'];

      if (userId == null || requestId == null) return _unauthorized();

      final leaseRequest = await leaseRepository.getLeaseRequestById(requestId);
      if (leaseRequest.initiatedById != userId) {
        return Response(403, body: jsonEncode({'message': 'Only the initiator can cancel this request'}));
      }
      if (leaseRequest.status != LeaseRequestStatus.pending) {
        return Response(400, body: jsonEncode({'message': 'Only pending requests can be cancelled'}));
      }

      await leaseRepository.cancelLeaseRequest(requestId: requestId, cancelledBy: userId);

      return Response.ok(jsonEncode({'message': 'Request cancelled successfully', 'requestId': requestId}));
    } on NotFoundException catch (e) {
      return Response(404, body: jsonEncode({'message': e.message}));
    } on ValidationException catch (e) {
      return Response(400, body: jsonEncode({'message': e.message}));
    } catch (e, stack) {
      print('Cancel lease request error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  // REQUEST LISTS

  /// GET /leases/requests
  Future<Response> getMyLeaseRequests(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      if (userId == null || role == null) return _unauthorized();

      final requests = await leaseRepository.getPendingLeaseRequestsForUser(userId: userId, role: role);

      return Response.ok(
        jsonEncode({'requests': requests.map((r) => r.toMap()).toList(), 'message': 'Lease requests loaded'}),
      );
    } catch (e, stack) {
      print('Get my lease requests error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  /// GET /leases/requests/incoming
  Future<Response> getIncomingLeaseRequests(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;

      if (userId == null || !['landowner', 'manager'].contains(role)) {
        return Response(403, body: jsonEncode({'message': 'Unauthorized'}));
      }

      final requests = await leaseRepository.getPendingLeaseRequestsForUser(userId: userId, role: role!);

      return Response.ok(jsonEncode({'incomingRequests': requests.map((r) => r.toMap()).toList()}));
    } catch (e, stack) {
      print('Get incoming lease requests error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  /// GET /leases/requests/<requestId>
  Future<Response> getLeaseRequestById(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final requestId = request.params['requestId'];

      if (userId == null || requestId == null) return _unauthorized();

      final leaseRequest = await leaseRepository.getLeaseRequestById(requestId);

      final allowed =
          leaseRequest.tenantId == userId ||
          leaseRequest.landownerId == userId ||
          leaseRequest.managerId == userId ||
          role == 'manager';

      if (!allowed) {
        return Response(403, body: jsonEncode({'message': 'Forbidden'}));
      }

      return Response.ok(jsonEncode({'request': leaseRequest.toMap()}));
    } on NotFoundException catch (e) {
      return Response(404, body: jsonEncode({'message': e.message}));
    } catch (e, stack) {
      print('Get lease request by id error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  // SETTLEMENT

  /// PATCH /leases/<id>/settlement/accept
  Future<Response> acceptSettlement(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final leaseId = request.params['id'];
      if (userId == null || leaseId == null) return _unauthorized();

      final lease = await leaseRepository.getLeaseById(leaseId);
      await leaseRepository.acceptSettlement(leaseId, userId);
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

  /// PATCH /leases/<id>/settlement/dispute
  Future<Response> disputeSettlement(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final leaseId = request.params['id'];
      if (userId == null || leaseId == null) return _unauthorized();

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final disputeReason = body['reason'] as String?;
      if (disputeReason == null || disputeReason.trim().isEmpty) {
        return badRequest('Dispute reason is required');
      }

      final lease = await leaseRepository.getLeaseById(leaseId);
      await leaseRepository.disputeSettlement(leaseId: leaseId, disputedBy: userId, reason: disputeReason);

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

  /// PATCH /leases/<id>/settlement/resolve
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
      final resolution = body['resolution'] as String?;
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

  // INTERNAL

  Future<PaymentModel> _recordLeasePaymentInternal({
    required LeaseModel lease,
    required double amount,
    required String paymentMethod,
    String? transactionRef,
    String? receiptUrl,
    required String confirmedBy,
    required String type,
  }) async {
    final payment = PaymentModel(
      id: '',
      leaseId: lease.id,
      payerId: lease.tenantId,
      receiverId: lease.landownerId,
      propertyId: lease.propertyId,
      unitId: lease.unitId,
      amount: amount,
      status: 'paid',
      method: paymentMethod,
      transactionRef: transactionRef,
      receiptUrl: receiptUrl,
      type: type,
      createdAt: DateTime.now(),
    );

    final createdPayment = await paymentRepository.createPayment(payment);

    await historyRepository.createHistoryEntry(
      HistoryEntryModel(
        userId: lease.tenantId,
        type: 'rent_paid',
        title: 'Rent Payment Recorded',
        description: '₦${amount.toStringAsFixed(0)} confirmed for lease.',
        relatedId: createdPayment.id,
        relatedCollection: 'payments',
        timestamp: DateTime.now(),
        id: '',
      ),
    );

    await historyRepository.createHistoryEntry(
      HistoryEntryModel(
        userId: confirmedBy,
        type: 'rent_confirmed',
        title: 'Rent Payment Confirmed',
        description: 'You confirmed payment for lease ${lease.id}',
        relatedId: createdPayment.id,
        relatedCollection: 'payments',
        timestamp: DateTime.now(),
        id: '',
      ),
    );

    return createdPayment;
  }
}

int parseDurationMonths(String duration) {
  final lower = duration.toLowerCase();
  final match = RegExp(r'(\d+)').firstMatch(lower);
  final n = int.tryParse(match?.group(1) ?? '') ?? 12;
  if (lower.contains('year')) return n * 12;
  return n; // "12 Months" → 12
}
