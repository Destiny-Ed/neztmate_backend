import 'dart:convert';
import 'package:neztmate_backend/features/applications/models/application_model.dart';
import 'package:neztmate_backend/features/applications/repository/application_repo.dart';
import 'package:shelf/shelf.dart';
import 'package:neztmate_backend/core/error.dart';
import 'package:shelf_router/shelf_router.dart';

class ApplicationHandler {
  final ApplicationRepository repository;

  ApplicationHandler(this.repository);

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

      final created = await repository.createApplication(application);

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

  /// GET /applications/me - Tenant views their applications
  Future<Response> getMyApplications(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;

      if (userId == null || role != 'tenant') {
        return Response(403, body: jsonEncode({'message': 'Only tenants can view their applications'}));
      }

      final applications = await repository.getApplicationsByTenant(userId);

      return Response.ok(
        jsonEncode({
          'applications': applications.map((a) => a.toMap()).toList(),
          'message': 'Your applications loaded',
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

      final applications = await repository.getApplicationsByUnit(unitId);

      return Response.ok(
        jsonEncode({
          'applications': applications.map((a) => a.toMap()).toList(),
          'message': 'Applications for this unit',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Get applications by unit error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to load applications'}));
    }
  }

  /// GET /applications/<id> - View single application (tenant or manager/landowner)
  Future<Response> getApplicationById(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final appId = request.params['id'];

      if (userId == null || appId == null) {
        return Response(400, body: jsonEncode({'message': 'Missing ID'}));
      }

      final application = await repository.getApplicationById(appId);

      // Authorization: tenant who applied or manager/landowner
      final isApplicant = application.tenantId == userId;
      final isManagerOrOwner = ['manager', 'landowner'].contains(role);

      if (!isApplicant && !isManagerOrOwner) {
        return Response(403, body: jsonEncode({'message': 'Forbidden'}));
      }

      return Response.ok(
        jsonEncode({'application': application.toMap()}),
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

      await repository.approveApplication(appId, userId);

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

      await repository.rejectApplication(appId, userId, reason);

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

      await repository.deleteApplication(appId);

      return Response.ok(jsonEncode({'message': 'Application deleted'}));
    } catch (e, stack) {
      print('Reject error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to delete application'}));
    }
  }

  Response _badRequest(String message) =>
      Response(400, body: jsonEncode({'message': message}), headers: {'Content-Type': 'application/json'});
}
