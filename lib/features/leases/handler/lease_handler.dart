import 'dart:convert';
import 'package:neztmate_backend/core/services/reputation/reputation_service.dart';
import 'package:neztmate_backend/features/auth_user/models/user_model.dart';
import 'package:neztmate_backend/features/auth_user/repositories/user_repository.dart';
import 'package:neztmate_backend/features/history/model/user_history_model.dart';
import 'package:neztmate_backend/features/history/repository/user_history_repo.dart';
import 'package:neztmate_backend/features/leases/models/leases_model.dart';
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
import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/features/leases/repository/lease_repo.dart';
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

  // ====================== HELPERS ======================

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

  // ====================== VIEW LEASES ======================

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

  Future<Response> getLeaseById(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final leaseId = request.params['id'];

      if (userId == null || leaseId == null) return _unauthorized();

      final lease = await leaseRepository.getLeaseById(leaseId);

      final isTenant = lease.tenantId == userId;
      final isLandowner = lease.landownerId == userId;
      final isManager = role == 'manager';

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

  Future<Response> getLeaseByApplicationId(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final applicationId = request.params['id'];

      if (userId == null || applicationId == null) return _unauthorized();

      final lease = await leaseRepository.getLeaseByApplicationId(applicationId);

      final isTenant = lease.tenantId == userId;
      final isLandowner = lease.landownerId == userId;
      final isManager = role == 'manager';

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

  // ====================== SIGNING ======================

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

      final activeLeases = await leaseRepository.getActiveLeasesByTenant(userId);
      if (activeLeases.isNotEmpty) {
        final currentLease = activeLeases.first;
        final daysUntilExpiry = currentLease.endDate.difference(DateTime.now()).inDays;
        if (daysUntilExpiry > 30) {
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
          'status': 'pending payment',
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

  // ====================== RENEWAL (OFFLINE) ======================

  Future<Response> requestRenewal(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final leaseId = request.params['id'];

      if (userId == null || leaseId == null) return _unauthorized();
      if (role != 'tenant') {
        return Response(403, body: jsonEncode({'message': 'Only tenants can request renewal'}));
      }

      final lease = await leaseRepository.getLeaseById(leaseId);
      if (lease.tenantId != userId) {
        return Response(403, body: jsonEncode({'message': 'This is not your lease'}));
      }
      if (!['inactive', 'expired'].contains(lease.status.toLowerCase())) {
        return badRequest('Only inactive or expired leases can be renewed');
      }

      await leaseRepository.markLeaseAsPendingRenewal(leaseId);

      await notificationRepository.create(
        NotificationModel(
          id: '',
          userId: lease.landownerId,
          type: 'renewal_requested',
          title: 'Tenant Requested Renewal',
          body: 'Your tenant has requested to renew the lease.',
          relatedId: leaseId,
          relatedCollection: 'leases',
          createdAt: DateTime.now(),
        ),
      );

      return Response.ok(
        jsonEncode({
          'message': 'Renewal request submitted successfully',
          'leaseId': leaseId,
          'status': 'pending payment',
        }),
      );
    } catch (e, stack) {
      print('Request renewal error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  Future<Response> offerRenewal(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final leaseId = request.params['id'];

      if (userId == null || leaseId == null) return _unauthorized();
      if (!['landowner', 'manager'].contains(role)) {
        return Response(403, body: jsonEncode({'message': 'Only landowners/managers can offer renewal'}));
      }

      final lease = await leaseRepository.getLeaseById(leaseId);
      if (lease.status.toLowerCase() != 'inactive') {
        return badRequest('Only inactive leases can be offered for renewal');
      }

      await leaseRepository.markLeaseAsPendingRenewal(leaseId);

      await notificationRepository.create(
        NotificationModel(
          id: '',
          userId: lease.tenantId,
          type: 'renewal_offered',
          title: 'Lease Renewal Available',
          body: 'Your landlord has offered to renew your lease. Please make payment to continue.',
          relatedId: leaseId,
          relatedCollection: 'leases',
          createdAt: DateTime.now(),
        ),
      );

      return Response.ok(
        jsonEncode({
          'message': 'Renewal offered successfully',
          'leaseId': leaseId,
          'status': 'pending payment',
        }),
      );
    } catch (e, stack) {
      print('Offer renewal error: $e\n$stack');
      return Response.internalServerError();
    }
  }

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

      if (receiptUrl == null || receiptUrl.trim().isEmpty) {
        return badRequest('receiptUrl is required');
      }
      if (amountPaid == null || amountPaid <= 0) {
        return badRequest('Valid amountPaid is required');
      }

      final lease = await leaseRepository.getLeaseById(leaseId);
      if (lease.tenantId != userId) {
        return Response(403, body: jsonEncode({'message': 'This is not your lease'}));
      }
      if (lease.status.toLowerCase() != 'pending payment') {
        return badRequest('Lease is not awaiting payment');
      }

      await leaseRepository.updateLease(
        lease.copyWith(paymentReceiptUrl: receiptUrl, status: 'payment submitted', updatedAt: DateTime.now()),
      );

      await notificationRepository.create(
        NotificationModel(
          id: '',
          userId: lease.landownerId,
          type: 'renewal_payment_submitted',
          title: 'Renewal Payment Submitted',
          body: 'Tenant has submitted payment proof for lease renewal. Please confirm.',
          relatedId: leaseId,
          relatedCollection: 'leases',
          createdAt: DateTime.now(),
        ),
      );

      return Response.ok(
        jsonEncode({
          'message': 'Payment proof submitted successfully. Waiting for landlord confirmation.',
          'leaseId': leaseId,
          'status': 'payment submitted',
        }),
      );
    } catch (e, stack) {
      print('Confirm renewal payment error: $e\n$stack');
      return Response.internalServerError();
    }
  }

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

      final oldLease = await leaseRepository.getLeaseById(leaseId);
      if (oldLease.status.toLowerCase() != 'payment submitted') {
        return badRequest('No payment has been submitted for this renewal');
      }

      final durationMonths = oldLease.durationMonths ?? 12;
      final newStartDate = oldLease.endDate;
      final newEndDate = newStartDate.add(Duration(days: durationMonths * 30));

      final newLease = await leaseRepository.createRenewalLease(
        oldLeaseId: leaseId,
        newStartDate: newStartDate,
        newEndDate: newEndDate,
        monthlyRent: oldLease.monthlyRent,
        reason: 'Renewal after offline payment confirmation',
        paymentReceiptUrl: oldLease.paymentReceiptUrl,
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
          body: 'Your lease has been renewed until ${newEndDate.toIso8601String().split("T").first}',
          relatedId: newLease.id,
          relatedCollection: 'leases',
          createdAt: DateTime.now(),
        ),
      );

      return Response.ok(
        jsonEncode({
          'message': 'Renewal payment approved. New lease is now active.',
          'newLeaseId': newLease.id,
          'oldLeaseId': leaseId,
          'newEndDate': newEndDate.toIso8601String(),
        }),
      );
    } catch (e, stack) {
      print('Approve renewal payment error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  // ====================== MANUAL LEASE ======================

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

  // ====================== CONFIRM PAYMENT ======================

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
      if (lease.status.toLowerCase() != 'pending payment') {
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

  // ====================== STATUS UPDATE ======================

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
      final newStatus = (body['status'] as String?)?.trim().toLowerCase();

      if (newStatus == null || newStatus.isEmpty) {
        return Response(400, body: jsonEncode({'message': 'Status is required'}));
      }

      final lease = await leaseRepository.getLeaseById(leaseId);

      if (lease.status.toLowerCase() == 'terminated') {
        return Response(400, body: jsonEncode({'message': 'Terminated leases cannot be modified'}));
      }

      if (newStatus == 'pending payment' && lease.endDate.isAfter(DateTime.now())) {
        return Response(
          400,
          body: jsonEncode({'message': 'Cannot set to Pending Payment. Current lease has not yet expired.'}),
        );
      }

      const allowedStatuses = ['pending signature', 'pending payment', 'active', 'inactive', 'terminated'];
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

  // ====================== TRANSFER ======================

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
      if (lease.status.toLowerCase() != 'active') {
        return Response(400, body: jsonEncode({'message': 'Only active leases can be transferred'}));
      }

      await leaseRepository.requestLeaseTransfer(
        leaseId: leaseId,
        newTenantId: newTenantId,
        reason: reason ?? 'Tenant relocation',
      );

      await notificationRepository.create(
        NotificationModel(
          userId: tenantId,
          type: 'lease_transfer_request_sent',
          title: 'Lease Transfer Requested',
          body: 'Your request to transfer the lease has been submitted.',
          relatedId: leaseId,
          relatedCollection: 'leases',
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
          relatedId: leaseId,
          relatedCollection: 'leases',
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
          relatedId: leaseId,
          relatedCollection: 'leases',
          createdAt: DateTime.now(),
          id: '',
        ),
      );

      return Response.ok(
        jsonEncode({'message': 'Lease transfer request submitted successfully', 'leaseId': leaseId}),
      );
    } catch (e, stack) {
      print('Request lease transfer error: $e\n$stack');
      return Response.internalServerError();
    }
  }

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

  Future<Response> rejectLeaseTransfer(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final leaseId = request.params['id'];

      if (userId == null || leaseId == null) return _unauthorized();
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
      if (lease.transferStatus?.toLowerCase() != 'pending') {
        return Response(400, body: jsonEncode({'message': 'No pending transfer request to reject'}));
      }

      await leaseRepository.rejectLeaseTransfer(leaseId, userId, reason);

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

      return Response.ok(jsonEncode({'message': 'Lease transfer rejected successfully', 'leaseId': leaseId}));
    } catch (e, stack) {
      print('Reject lease transfer error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  // ====================== EARLY TERMINATION ======================

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

      await leaseRepository.requestEarlyTermination(leaseId: leaseId, reason: reason, requestedBy: 'tenant');

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

      await leaseRepository.terminateLease(leaseId, reason, role ?? '');

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

  // ====================== INTERNAL ======================

  Future<PaymentModel> _recordLeasePaymentInternal({
    required LeaseModel lease,
    required double amount,
    required String paymentMethod,
    String? transactionRef,
    String? receiptUrl,
    required String confirmedBy,
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
      type: 'rent',
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
  // ====================== RENT ADJUSTMENT ======================

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
      final reason = body['reason'] as String?;

      if (newMonthlyRent == null || newMonthlyRent <= 0) {
        return badRequest('Valid new monthly rent is required');
      }
      if (reason == null || reason.trim().isEmpty) {
        return badRequest('Reason for rent adjustment is required');
      }

      final lease = await leaseRepository.getLeaseById(leaseId);

      await leaseRepository.proposeRentAdjustment(
        leaseId: leaseId,
        newMonthlyRent: newMonthlyRent,
        reason: reason,
        proposedBy: userId,
      );

      await notificationRepository.create(
        NotificationModel(
          id: '',
          userId: lease.tenantId,
          type: 'rent_adjustment_proposed',
          title: 'Rent Adjustment Proposed',
          body:
              'Your landlord proposed changing rent from ₦${lease.monthlyRent} to ₦$newMonthlyRent. Reason: $reason',
          relatedId: leaseId,
          relatedCollection: 'leases',
          createdAt: DateTime.now(),
        ),
      );

      await historyRepository.createHistoryEntry(
        HistoryEntryModel(
          userId: userId,
          type: 'rent_adjustment_proposed',
          title: 'Rent Adjustment Proposed',
          description: 'Proposed rent change to ₦$newMonthlyRent for lease $leaseId',
          relatedId: leaseId,
          relatedCollection: 'leases',
          timestamp: DateTime.now(),
          id: '',
        ),
      );

      return Response.ok(
        jsonEncode({
          'message': 'Rent adjustment proposed successfully',
          'newMonthlyRent': newMonthlyRent,
          'reason': reason,
        }),
      );
    } catch (e, stack) {
      print('Propose rent adjustment error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to propose rent adjustment'}));
    }
  }

  Future<Response> approveRentAdjustment(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final leaseId = request.params['id'];

      if (userId == null || leaseId == null) return _unauthorized();
      if (role != 'tenant') {
        return Response(403, body: jsonEncode({'message': 'Only tenant can approve rent adjustment'}));
      }

      await leaseRepository.approveRentAdjustment(leaseId, userId);

      await notificationRepository.create(
        NotificationModel(
          userId: userId,
          type: 'rent_adjustment_approved',
          title: 'Rent Adjustment Approved',
          body: 'You have approved the rent adjustment.',
          relatedId: leaseId,
          relatedCollection: 'leases',
          createdAt: DateTime.now(),
          id: '',
        ),
      );

      return Response.ok(jsonEncode({'message': 'Rent adjustment approved successfully'}));
    } catch (e, stack) {
      print('Approve rent adjustment error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  Future<Response> rejectRentAdjustment(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final leaseId = request.params['id'];

      if (userId == null || leaseId == null) return _unauthorized();
      if (role != 'tenant') {
        return Response(403, body: jsonEncode({'message': 'Only tenant can reject rent adjustment'}));
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final reason = body['reason'] as String? ?? 'No reason provided';

      await leaseRepository.rejectRentAdjustment(leaseId, userId, reason);

      return Response.ok(jsonEncode({'message': 'Rent adjustment rejected successfully'}));
    } catch (e, stack) {
      print('Reject rent adjustment error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  // ====================== SETTLEMENT ======================

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

  // ====================== REQUESTS VIEWING ======================

  Future<Response> getMyLeaseRequests(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      if (userId == null) return _unauthorized();

      final requests = await leaseRepository.getLeaseRequestsByUser(userId);

      return Response.ok(jsonEncode({'myRequests': requests}));
    } catch (e, stack) {
      print('Get my lease requests error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  Future<Response> getIncomingLeaseRequests(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;

      if (userId == null || !['landowner', 'manager'].contains(role)) {
        return Response(403, body: jsonEncode({'message': 'Unauthorized'}));
      }

      final requests = await leaseRepository.getIncomingLeaseRequests(userId, role!);

      return Response.ok(jsonEncode({'incomingRequests': requests}));
    } catch (e, stack) {
      print('Get incoming lease requests error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  Future<Response> getLeaseRequestDetails(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final leaseId = request.params['id'];

      if (userId == null || leaseId == null) return _unauthorized();

      final lease = await leaseRepository.getLeaseById(leaseId);

      final isTenant = lease.tenantId == userId;
      final isLandlordOrManager = lease.landownerId == userId || role == 'manager';

      if (!isTenant && !isLandlordOrManager) {
        return Response(403, body: jsonEncode({'message': 'Unauthorized to view this request'}));
      }

      String? requestType;
      String? status;
      String? reason;
      DateTime? proposedAt;

      if (lease.transferToTenantId != null && lease.transferStatus != null) {
        requestType = 'transfer';
        status = lease.transferStatus;
        reason = lease.terminationReason;
        proposedAt = lease.transferRequestedAt;
      } else if (lease.terminationReason != null || lease.terminationRequestedAt != null) {
        requestType = 'termination';
        status = lease.status == 'terminated' ? 'approved' : 'pending';
        reason = lease.terminationReason;
        proposedAt = lease.terminationRequestedAt;
      } else if (lease.proposedNewMonthlyRent != null) {
        requestType = 'rent_adjustment';
        status = lease.rentAdjustmentStatus;
        reason = lease.rentAdjustmentReason;
        proposedAt = lease.rentAdjustmentProposedAt;
      } else if (lease.renewalRequestedAt != null) {
        requestType = 'renewal';
        status = 'pending';
        proposedAt = lease.renewalRequestedAt;
        reason = lease.renewalReason;
      }

      return Response.ok(
        jsonEncode({
          'requestDetails': {
            'leaseId': lease.id,
            'requestType': requestType,
            'status': status ?? lease.status,
            'reason': reason,
            'proposedAt': proposedAt?.toIso8601String(),
            'tenantId': lease.tenantId,
            'landownerId': lease.landownerId,
            'unitId': lease.unitId,
            'monthlyRent': lease.monthlyRent,
            'proposedNewMonthlyRent': lease.proposedNewMonthlyRent,
            'newTenantId': lease.transferToTenantId,
            'terminationReason': lease.terminationReason,
            'renewalRequestedAt': lease.renewalRequestedAt?.toIso8601String(),
          },
        }),
      );
    } catch (e, stack) {
      print('Get lease request details error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  Future<Response> approveLeaseRequest(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final leaseId = request.params['id'];

      if (userId == null || leaseId == null) return _unauthorized();
      if (!['landowner', 'manager'].contains(role)) {
        return Response(403, body: jsonEncode({'message': 'Only landlords/managers can approve'}));
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final requestType = body['requestType'] as String?;

      if (requestType == null) return badRequest('requestType is required');

      switch (requestType) {
        case 'transfer':
          await leaseRepository.approveLeaseTransfer(leaseId, userId);
          break;
        case 'termination':
        case 'early_termination':
          await leaseRepository.approveEarlyTermination(leaseId, userId);
          break;
        case 'rent_adjustment':
          await leaseRepository.approveRentAdjustment(leaseId, userId);
          break;
        default:
          return badRequest('Invalid requestType');
      }

      return Response.ok(jsonEncode({'message': 'Request approved successfully'}));
    } catch (e, stack) {
      print('Approve lease request error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  Future<Response> rejectLeaseRequest(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final leaseId = request.params['id'];

      if (userId == null || leaseId == null) return _unauthorized();
      if (!['landowner', 'manager'].contains(role)) {
        return Response(403, body: jsonEncode({'message': 'Only landlords/managers can reject'}));
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final requestType = body['requestType'] as String?;
      final reason = body['reason'] as String? ?? 'No reason provided';

      if (requestType == null) return badRequest('requestType is required');

      switch (requestType) {
        case 'transfer':
          await leaseRepository.rejectLeaseTransfer(leaseId, userId, reason);
          break;
        case 'termination':
        case 'early_termination':
          await leaseRepository.rejectEarlyTermination(leaseId, userId, reason);
          break;
        case 'rent_adjustment':
          await leaseRepository.rejectRentAdjustment(leaseId, userId, reason);
          break;
        default:
          return badRequest('Invalid requestType');
      }

      return Response.ok(jsonEncode({'message': 'Request rejected successfully'}));
    } catch (e, stack) {
      print('Reject lease request error: $e\n$stack');
      return Response.internalServerError();
    }
  }
}
