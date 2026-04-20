import 'dart:convert';
import 'package:neztmate_backend/features/applications/models/application_model.dart';
import 'package:neztmate_backend/features/applications/repository/application_repo.dart';
import 'package:neztmate_backend/features/auth_user/repositories/user_repository.dart';
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

  ApplicationHandler({
    required this.applicationRepository,
    required this.userRepository,
    required this.propertyRepository,
    required this.unitRepository,
  });

  /// POST /applications - Tenant submits application
  Future<Response> submitApplication(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;

      if (userId == null || role != 'tenant') {
        return Response(403, body: jsonEncode({'message': 'Only tenants can submit applications'}));
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;

      // Required fields
      if (!body.containsKey('unitId') || !body.containsKey('propertyId')) {
        return Response(400, body: jsonEncode({'message': 'unitId and propertyId are required'}));
      }

      final application = ApplicationModel.fromMap(
        body,
        '',
      ).copyWith(tenantId: userId, appliedAt: DateTime.now(), status: 'Pending');

      final created = await applicationRepository.createApplication(application);

      return Response.ok(
        jsonEncode({'message': 'Application submitted successfully', 'application': created.toMap()}),
        headers: {'Content-Type': 'application/json'},
      );
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

  /// GET /applications/me - Tenant views their applications (enriched)
  Future<Response> getMyApplications(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;

      if (userId == null || role != 'Tenant') {
        return Response(403, body: jsonEncode({'message': 'Only tenants can view their applications'}));
      }

      final applications = await applicationRepository.getApplicationsByTenant(userId);

      // Enrich each application with tenant, property, and unit details
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
        jsonEncode({'applications': enrichedApplications, 'message': 'Your applications loaded'}),
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
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final appId = request.params['id'];

      if (userId == null || appId == null) return _badRequest('Missing ID');

      if (!['manager', 'landowner'].contains(role)) {
        return Response(403, body: jsonEncode({'message': 'Only managers or landowners can approve'}));
      }

      await applicationRepository.approveApplication(appId, userId);

      return Response.ok(jsonEncode({'message': 'Application approved'}));
    } catch (e, stack) {
      print('Approve error: $e\n$stack');
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
