import 'dart:convert';
import 'package:neztmate_backend/core/services/payment/paystack_service.dart';
import 'package:neztmate_backend/features/applications/models/application_model.dart';
import 'package:neztmate_backend/features/applications/repository/application_repo.dart';
import 'package:neztmate_backend/features/auth_user/repositories/user_repository.dart';
import 'package:neztmate_backend/features/leases/models/leases_model.dart';
import 'package:neztmate_backend/features/leases/repository/lease_repo.dart';
import 'package:neztmate_backend/features/leases/service/lease_pdf_service.dart';
import 'package:neztmate_backend/features/notifications/models/notification_model.dart';
import 'package:neztmate_backend/features/notifications/repository/notification_repo.dart';
import 'package:neztmate_backend/features/payments/models/payments.dart';
import 'package:neztmate_backend/features/payments/repository/payment_repo.dart';
import 'package:neztmate_backend/features/properties/repository/property_repo.dart';
import 'package:neztmate_backend/features/reviews/repository/review_repository.dart';
import 'package:neztmate_backend/features/units/repository/unit_repo.dart';
import 'package:shelf/shelf.dart';
import 'package:neztmate_backend/core/error.dart';
import 'package:shelf_router/shelf_router.dart';

class ApplicationHandler {
  final ApplicationRepository applicationRepository;
  final UserRepository userRepository;
  final PropertyRepository propertyRepository;
  final UnitRepository unitRepository;
  final LeaseRepository leaseRepository;
  final NotificationRepository notificationRepository;
  final UserReviewRepository userReviewRepository;
  final PaymentRepository paymentRepository;

  ApplicationHandler({
    required this.applicationRepository,
    required this.userRepository,
    required this.propertyRepository,
    required this.unitRepository,
    required this.leaseRepository,
    required this.notificationRepository,
    required this.userReviewRepository,
    required this.paymentRepository,
  });

  final paystackService = PaystackService();

  /// POST /applications - Tenant submits lease application (with #2000 application fee)
  Future<Response> submitApplication(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;

      if (userId == null || role != 'tenant') {
        return Response(403, body: jsonEncode({'message': 'Only tenants can submit applications'}));
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;

      // Required fields validation
      if (!body.containsKey('unitId') || body['unitId'].toString().isEmpty) {
        return Response(400, body: jsonEncode({'message': 'unitId is required'}));
      }
      if (!body.containsKey('propertyId') || body['propertyId'].toString().isEmpty) {
        return Response(400, body: jsonEncode({'message': 'propertyId is required'}));
      }

      if (!body.containsKey('landownerId') || body['landownerId'].toString().isEmpty) {
        return Response(400, body: jsonEncode({'message': 'landownerId is required'}));
      }
      if (!body.containsKey('screeningData')) {
        return Response(400, body: jsonEncode({'message': 'screeningData is required'}));
      }

      final unitId = body['unitId'] as String;
      final propertyId = body['propertyId'] as String;
      final landownerId = body['landownerId'] as String;

      // Check if tenant already has a pending application for this unit
      final existingApplications = await applicationRepository.getApplicationsByTenant(userId);

      final alreadyApplied = existingApplications.any(
        (app) => app.unitId == unitId && (app.status == 'Pending' || app.status == 'Approved'),
      );

      if (alreadyApplied) {
        return Response(
          409,
          body: jsonEncode({
            'message':
                'You have already submitted an application for this unit. You cannot submit another one until it is resolved.',
          }),
        );
      }

      // Check for Fee Pending applications
      final feePendingApplication = existingApplications.cast<ApplicationModel?>().firstWhere(
        (app) => app?.unitId == unitId && app?.status.toLowerCase() == 'fee_pending',
        orElse: () => null,
      );

      if (feePendingApplication != null) {
        // Resume payment for existing fee-pending application
        return await _completePayment(
          body,
          feePendingApplication,
          userId,
          unitId,
          message: "Resume payment to activate your application",
        );
      }

      // Optional: Check if unit is already occupied
      final unit = await unitRepository.getUnitById(unitId);

      if (unit.status != 'vacant' && unit.currentTenantId != null) {
        return Response(
          400,
          body: jsonEncode({
            'message': 'This unit is currently occupied and not available for new applications.',
          }),
        );
      }

      // Create the application
      final application = ApplicationModel(
        id: "",
        unitId: unitId,
        tenantId: userId,
        propertyId: propertyId,
        appliedAt: DateTime.now(),
        screeningData: ScreeningData.fromMap(body['screeningData'] as Map<String, dynamic>),
        // status: 'Pending',
        status: 'fee_pending',
        applicationFee: 2000.0,
        feePaymentStatus: 'Pending',
        message: body['message'] as String?,
        proposedRent: (body['proposedRent'] as num?)?.toDouble(),
        desiredStartDate: body['desiredStartDate'] != null
            ? DateTime.parse(body['desiredStartDate'] as String)
            : null,
        documents: (body['documents'] as List<dynamic>?)?.cast<String>(),
        landownerId: landownerId,
      );

      final created = await applicationRepository.createApplication(application);

      // Initialize ₦2000 payment
      return await _completePayment(body, created, userId, unitId);
    } on NotFoundException catch (e) {
      return Response(404, body: jsonEncode({'message': e.message}));
    } on ValidationException catch (e) {
      return Response(400, body: jsonEncode({'message': e.message}));
    } catch (e, stack) {
      print('Submit application error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to submit application'}));
    }
  }

  Future<Response> _completePayment(
    Map<String, dynamic> body,
    ApplicationModel created,
    String userId,
    String unitId, {
    String? message,
  }) async {
    final paymentRef = 'appfee_${created.id}_${DateTime.now().millisecondsSinceEpoch}';

    final initPayment = await paystackService.initializeTransaction(
      email: body['email'] ?? 'tenant@example.com',
      amount: 2000.0,
      reference: paymentRef,
      metadata: {
        'type': 'application_fee',
        'applicationId': created.id,
        'tenantId': userId,
        'unitId': unitId,
      },
    );

    if (created.feePaymentReference == null) {
      //     // Save pending payment
      final pendingPayment = PaymentModel(
        id: '',
        leaseId: "",
        payerId: userId,
        propertyId: "",
        unitId: unitId,
        amount: 2000.0,
        status: 'Pending',
        method: 'Paystack',
        transactionRef: initPayment['reference'],
        type: 'application_fee',
        createdAt: DateTime.now(),
      );

      await paymentRepository.createPayment(pendingPayment);

      await applicationRepository.updateApplication(
        created.copyWith(feePaymentReference: pendingPayment.transactionRef),
      );
    }

    print("Init payment response:::: $initPayment");

    return Response.ok(
      jsonEncode({
        'message': message ?? 'Application submitted successfully',
        'application': created.toMap(),
        'paymentReference': created.feePaymentReference ?? initPayment['reference'],
        'paymentUrl': initPayment['authorization_url'],
        'amount': 2000.0,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// PATCH /applications/{id}/withdraw - Tenant withdraws their application
  Future<Response> withdrawApplication(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final appId = request.params['id'];

      if (userId == null || appId == null) {
        return Response(400, body: jsonEncode({'message': 'Missing ID'}));
      }

      if (role != 'tenant') {
        return Response(403, body: jsonEncode({'message': 'Only tenant can withdraw their application'}));
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final reason = body['reason'] as String?;

      await applicationRepository.withdrawApplication(appId, userId, reason);

      return Response.ok(
        jsonEncode({'message': 'Application withdrawn successfully'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Withdraw application error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to withdraw application'}));
    }
  }

  /// GET /applications/me - Get applications (Tenant sees their own | Manager/Landowner sees all applications for their properties)
  Future<Response> getMyApplications(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;

      if (userId == null || role == null) {
        return Response(401, body: jsonEncode({'message': 'Unauthorized'}));
      }

      List<ApplicationModel> applications = [];

      if (role == 'tenant') {
        applications = await applicationRepository.getApplicationsByTenant(userId);
      } else if (['manager', 'landowner'].contains(role)) {
        applications = await applicationRepository.getApplicationsForManagerOrOwner(userId, role);
      } else {
        return Response(403, body: jsonEncode({'message': 'Access denied'}));
      }

      // Filter out withdrawn applications for non-tenants
      if (role != 'tenant') {
        applications = applications.where((app) => app.status != 'Withdrawn').toList();
      }

      // Enrich with tenant, property, and unit details
      final enrichedApplications = await Future.wait(
        applications.map((app) async {
          try {
            final tenant = await userRepository.getUserById(app.tenantId);
            final property = await propertyRepository.getPropertyById(app.propertyId);
            final unit = await unitRepository.getUnitById(app.unitId);

            return {
              ...app.toMap(),
              'tenant': {
                'id': tenant.id,
                'fullName': tenant.fullName,
                'email': tenant.email,
                'phone': tenant.phone,
                'verifiedIdentity': tenant.verifiedIdentity,
                'profilePhotoUrl': tenant.profilePhotoUrl,
              },
              'property': {
                'id': property.id,
                'name': property.name,
                'address': property.address,
                'type': property.type,
              },
              'unit': {
                'id': unit.id,
                'unitNumber': unit.unitNumber,
                'bedrooms': unit.bedrooms,
                'bathrooms': unit.bathrooms,
                'yearlyRent': unit.yearlyRent,
                'status': unit.status,
              },
            };
          } catch (e) {
            return {
              ...app.toMap(),
              'tenant': {'id': app.tenantId},
              'property': {'id': app.propertyId},
              'unit': {'id': app.unitId},
            };
          }
        }),
      );

      return Response.ok(
        jsonEncode({
          'applications': enrichedApplications,
          'message': role == 'Tenant'
              ? 'Your applications loaded'
              : 'Applications for your properties loaded',
          'count': enrichedApplications.length,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Get my applications error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to load applications'}));
    }
  }

  /// GET /applications/unit/<unitId> - Manager/Landowner views applications for a unit
  Future<Response> getApplicationsByUnit(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final unitId = request.params['unitId'];

      if (userId == null || unitId == null) {
        return Response(400, body: jsonEncode({'message': 'Missing user ID or unit ID'}));
      }

      if (!['landowner', 'manager'].contains(role)) {
        return Response(
          403,
          body: jsonEncode({'message': 'Only landowners or managers can view unit applications'}),
        );
      }

      final applications = await applicationRepository.getApplicationsByUnit(unitId);

      final enrichedApplications = await Future.wait(
        applications.map((app) async {
          final tenant = await userRepository.getUserById(app.tenantId);
          final property = await propertyRepository.getPropertyById(app.propertyId);
          final unit = await unitRepository.getUnitById(app.unitId);

          return {
            ...app.toMap(),
            'tenant': {
              'id': tenant.id,
              'fullName': tenant.fullName,
              'email': tenant.email,
              'phone': tenant.phone,
              'verifiedIdentity': tenant.verifiedIdentity,

              'profilePhotoUrl': tenant.profilePhotoUrl,
            },
            'property': {
              'id': property.id,
              'name': property.name,
              'address': property.address,
              'type': property.type,
            },
            'unit': {
              'id': unit.id,
              'unitNumber': unit.unitNumber,
              'bedrooms': unit.bedrooms,
              'bathrooms': unit.bathrooms,
              'yearlyRent': unit.yearlyRent,
              'status': unit.status,
            },
          };
        }),
      );

      return Response.ok(
        jsonEncode({'applications': enrichedApplications, 'message': 'Applications for this unit'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Get applications by unit error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to load applications'}));
    }
  }

  /// GET /applications/<id> - View single application with full details
  Future<Response> getApplicationById(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final appId = request.params['id'];

      if (userId == null || appId == null) {
        return Response(400, body: jsonEncode({'message': 'Missing ID'}));
      }

      final application = await applicationRepository.getApplicationById(appId);

      // Authorization check
      final isApplicant = application.tenantId == userId;
      final isManagerOrOwner = ['landowner', 'manager'].contains(role);

      if (!isApplicant && !isManagerOrOwner) {
        return Response(403, body: jsonEncode({'message': 'Forbidden'}));
      }

      // Enrich with related data
      final tenant = await userRepository.getUserById(application.tenantId);
      final property = await propertyRepository.getPropertyById(application.propertyId);
      final unit = await unitRepository.getUnitById(application.unitId);

      // Get tenant's previous reviews (especially from other landlords)
      final tenantReviews = isManagerOrOwner
          ? await userReviewRepository.getReviewsForUser(application.tenantId)
          : [];

      final enrichedApplication = {
        ...application.toMap(),

        'tenant': {
          'id': tenant.id,
          'fullName': tenant.fullName,
          'email': tenant.email,
          'phone': tenant.phone,
          'profilePhotoUrl': tenant.profilePhotoUrl,
          'verifiedIdentity': tenant.verifiedIdentity,
          'verifiedEmployment': tenant.verifiedEmployment,

          // === Reputation & Trust Info ===
          'averageRating': tenant.averageRating,
          'totalReviews': tenant.totalReviews,
          'tenantReputation': tenant.tenantReputation,
          'paymentOnTimeRate': tenant.paymentOnTimeRate,
          'badges': tenant.badges,
          'lastReviewedAt': tenant.lastReviewedAt?.toIso8601String(),
        },

        'property': {
          'id': property.id,
          'name': property.name,
          'address': property.address,
          'type': property.type,
          'amenities': property.amenities,
        },

        'unit': {
          'id': unit.id,
          'unitNumber': unit.unitNumber,
          'bedrooms': unit.bedrooms,
          'bathrooms': unit.bathrooms,
          'yearlyRent': unit.yearlyRent,
          'status': unit.status,
        },

        // === Extra Info for Landowner/Manager ===
        if (isManagerOrOwner) ...{
          'tenantReviews': tenantReviews.map((review) => review.toMap()).toList(),
          'tenantPaymentHistorySummary': {
            'totalRentPayments': tenant.totalPaymentsMade,
            'onTimePayments': tenant.onTimePayments,
            'onTimeRate': tenant.paymentOnTimeRate,
          },
        },
      };

      return Response.ok(
        jsonEncode({
          'application': enrichedApplication,
          'message': 'Application details fetched successfully',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } on NotFoundException catch (e) {
      return Response(404, body: jsonEncode({'message': e.message}));
    } catch (e, stack) {
      print('Get application error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to load application'}));
    }
  }

  /// PATCH /applications/<id>/approve - Manager/Landowner approves
  Future<Response> approveApplication(Request request) async {
    try {
      final approverId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final appId = request.params['id'];

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;

      final durationMonths = body['durationMonths'] as int?;

      if (approverId == null || appId == null) {
        return Response(400, body: jsonEncode({'message': 'Missing ID'}));
      }

      if (!['manager', 'landowner'].contains(role)) {
        return Response(403, body: jsonEncode({'message': 'Only managers or landowners can approve'}));
      }

      if (durationMonths == null || ![12, 24, 36].contains(durationMonths)) {
        return badRequest('durationMonths must be 12, 24, or 36');
      }

      // 1. Approve the application
      final application = await applicationRepository.getApplicationById(appId);
      await applicationRepository.approveApplication(appId, approverId);
      final unit = await unitRepository.getUnitById(application.unitId);

      // 2. Create Lease Record
      final leaseService = LeasePdfService();

      final startDate = application.desiredStartDate ?? DateTime.now().add(const Duration(days: 7));
      final endDate = startDate.add(Duration(days: durationMonths * 30));

      final lease = LeaseModel(
        id: '',
        applicationId: appId,
        unitId: application.unitId,
        tenantId: application.tenantId,
        propertyId: application.propertyId,
        landownerId: role == 'landowner' ? approverId : application.landownerId,
        managerId: role == 'manager' ? approverId : null,
        startDate: startDate,
        endDate: endDate,
        yearlyRent: application.proposedRent ?? unit.yearlyRent,
        fees: unit.fees,
        status: 'Pending Signature',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final createdLease = await leaseRepository.createLease(lease);

      // 3. Generate PDF (Auto-generated)
      // Note: You need to fetch tenant, landowner, unit, property here in real code
      // For now, we simulate
      final generatedPdfUrl = await leaseService.generateLeasePdf(
        lease: createdLease,
        unit: await unitRepository.getUnitById(application.unitId),
        property: await propertyRepository.getPropertyById(application.propertyId),
        tenant: await userRepository.getUserById(application.tenantId),
        landowner: await userRepository.getUserById(lease.landownerId),
      );

      // Update lease with generated PDF
      await leaseRepository.updateLease(createdLease.copyWith(generatedLeasePdfUrl: generatedPdfUrl));

      // 4. Notify Tenant
      await notificationRepository.create(
        NotificationModel(
          id: "",
          userId: application.tenantId,
          type: 'application_approved',
          title: 'Your Application Has Been Approved!',
          body:
              'Your application for Unit ${application.unitId} has been approved. Please review and sign the lease.',
          createdAt: DateTime.now(),
          relatedId: appId,
        ),
      );

      return Response.ok(
        jsonEncode({
          'message': 'Application approved and lease created successfully',
          'application': application.toMap(),
          'lease': createdLease.toMap(),
          'generatedLeasePdfUrl': generatedPdfUrl,
        }),
      );
    } catch (e, stack) {
      print('Approve application error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to approve application'}));
    }
  }

  /// PATCH /applications/<id>/reject - Manager/Landowner rejects
  Future<Response> rejectApplication(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final appId = request.params['id'];

      if (userId == null || appId == null) return _badRequest('Missing ID');

      if (!['manager', 'landowner'].contains(role)) {
        return Response(403, body: jsonEncode({'message': 'Only managers or landowners can reject'}));
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final reason = body['reason'] as String?;

      await applicationRepository.rejectApplication(appId, userId, reason);

      return Response.ok(jsonEncode({'message': 'Application rejected'}));
    } catch (e, stack) {
      print('Reject error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to reject application'}));
    }
  }

  /// DELETE /applications/<id>/delete - Tenant deletes
  Future<Response> deleteApplication(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final appId = request.params['id'];

      if (userId == null || appId == null) return _badRequest('Missing ID');

      if (!['tenant'].contains(role)) {
        return Response(403, body: jsonEncode({'message': 'Only tenant can delete their application'}));
      }

      await applicationRepository.deleteApplication(appId);

      return Response.ok(jsonEncode({'message': 'Application deleted'}));
    } catch (e, stack) {
      print('Delete error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to delete application'}));
    }
  }

  /// POST /applications/<id>/pay-fee - Pay ₦2,000 application fee
  Future<Response> payApplicationFee(Request request) async {
    try {
      final tenantId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final applicationId = request.params['id'];

      if (tenantId == null || role != 'tenant') {
        return Response(403, body: jsonEncode({'message': 'Only tenants can pay application fees'}));
      }

      if (applicationId == null) {
        return badRequest('Application ID is required');
      }

      final application = await applicationRepository.getApplicationById(applicationId);

      if (application.tenantId != tenantId) {
        return Response(403, body: jsonEncode({'message': 'This application does not belong to you'}));
      }

      if (application.status.toLowerCase() != 'fee_pending') {
        return Response(
          400,
          body: jsonEncode({'message': 'Application fee has already been paid or is not pending'}),
        );
      }

      // Generate unique reference
      final reference = 'appfee_${DateTime.now().millisecondsSinceEpoch}_${applicationId}';

      // Initialize Paystack payment for ₦2,000
      final paymentInit = await paystackService.initializeTransaction(
        email: (await userRepository.getUserById(tenantId)).email,
        amount: 2000.0,
        reference: reference,
        metadata: {
          'type': 'application_fee',
          'applicationId': application.id,
          'tenantId': tenantId,
          'unitId': application.unitId,
          'propertyId': application.propertyId,
        },
      );

      return Response.ok(
        jsonEncode({
          'message': 'Application fee payment initialized',
          'applicationId': application.id,
          'amount': 2000.0,
          'reference': reference,
          'paymentUrl': paymentInit['authorization_url'],
          'status': 'fee_pending',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Pay application fee error: $e\n$stack');
      return Response.internalServerError(
        body: jsonEncode({'message': 'Failed to initialize application fee payment'}),
      );
    }
  }

  Response _badRequest(String message) =>
      Response(400, body: jsonEncode({'message': message}), headers: {'Content-Type': 'application/json'});
}
