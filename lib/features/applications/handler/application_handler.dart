import 'dart:convert';
import 'package:neztmate_backend/features/applications/models/application_model.dart';
import 'package:neztmate_backend/features/applications/repository/application_repo.dart';
import 'package:neztmate_backend/features/auth_user/repositories/user_repository.dart';
import 'package:neztmate_backend/features/leases/models/leases_model.dart';
import 'package:neztmate_backend/features/leases/repository/lease_repo.dart';
import 'package:neztmate_backend/features/leases/service/lease_pdf_service.dart';
import 'package:neztmate_backend/features/notifications/models/notification_model.dart';
import 'package:neztmate_backend/features/notifications/repository/notification_repo.dart';
import 'package:neztmate_backend/features/properties/repository/property_repo.dart';
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

  ApplicationHandler({
    required this.applicationRepository,
    required this.userRepository,
    required this.propertyRepository,
    required this.unitRepository,
    required this.leaseRepository,
    required this.notificationRepository,
  });

  /// POST /applications - Tenant submits application
  /// POST /applications - Tenant submits lease application
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
        status: 'Pending',
        message: body['message'] as String?,
        proposedRent: (body['proposedRent'] as num?)?.toDouble(),
        desiredStartDate: body['desiredStartDate'] != null
            ? DateTime.parse(body['desiredStartDate'] as String)
            : null,
        documents: (body['documents'] as List<dynamic>?)?.cast<String>(),
        landownerId: landownerId,
      );

      final created = await applicationRepository.createApplication(application);

      return Response.ok(
        jsonEncode({'message': 'Application submitted successfully', 'application': created.toMap()}),
        headers: {'Content-Type': 'application/json'},
      );
    } on NotFoundException catch (e) {
      return Response(404, body: jsonEncode({'message': e.message}));
    } on ValidationException catch (e) {
      return Response(400, body: jsonEncode({'message': e.message}));
    } catch (e, stack) {
      print('Submit application error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to submit application'}));
    }
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

      if (!['Landowner', 'Manager'].contains(role)) {
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
      final isManagerOrOwner = ['Manager', 'Landowner'].contains(role);

      if (!isApplicant && !isManagerOrOwner) {
        return Response(403, body: jsonEncode({'message': 'Forbidden'}));
      }

      // Enrich with related data
      final tenant = await userRepository.getUserById(application.tenantId);
      final property = await propertyRepository.getPropertyById(application.propertyId);
      final unit = await unitRepository.getUnitById(application.unitId);

      final enrichedApplication = {
        ...application.toMap(),
        'tenant': {
          'id': tenant.id,
          'fullName': tenant.fullName,
          'email': tenant.email,
          'phone': tenant.phone,
          'verifiedIdentity': tenant.verifiedIdentity,
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
      };

      return Response.ok(
        jsonEncode({'application': enrichedApplication}),
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

      if (approverId == null || appId == null) {
        return Response(400, body: jsonEncode({'message': 'Missing ID'}));
      }

      if (!['manager', 'landowner'].contains(role)) {
        return Response(403, body: jsonEncode({'message': 'Only managers or landowners can approve'}));
      }

      // 1. Approve the application
      final application = await applicationRepository.getApplicationById(appId);
      await applicationRepository.approveApplication(appId, approverId);

      // 2. Create Lease Record
      final leaseService = LeasePdfService();

      final lease = LeaseModel(
        id: '',
        applicationId: appId,
        unitId: application.unitId,
        tenantId: application.tenantId,
        landownerId: role == 'landowner' ? approverId : application.landownerId,
        managerId: role == 'manager' ? approverId : null,
        startDate: application.desiredStartDate ?? DateTime.now().add(const Duration(days: 7)),
        endDate: DateTime.now().add(const Duration(days: 365)), // 1 year default
        monthlyRent: application.proposedRent ?? 0.0,
        securityDeposit: null,
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

  Response _badRequest(String message) =>
      Response(400, body: jsonEncode({'message': message}), headers: {'Content-Type': 'application/json'});
}
