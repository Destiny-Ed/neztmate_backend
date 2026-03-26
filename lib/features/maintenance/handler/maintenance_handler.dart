import 'dart:convert';
import 'package:neztmate_backend/features/maintenance/repository/maintenance_repo.dart';
import 'package:shelf/shelf.dart';
import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/features/maintenance/models/maintenance.dart';
import 'package:shelf_router/shelf_router.dart';

class MaintenanceRequestHandler {
  final MaintenanceRequestRepository repository;

  MaintenanceRequestHandler(this.repository);

  /// POST /maintenance-requests - Tenant submits a new request
  Future<Response> submitRequest(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;

      if (userId == null || role != 'tenant') {
        return Response(403, body: jsonEncode({'message': 'Only tenants can submit maintenance requests'}));
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;

      // Required fields validation
      if (!body.containsKey('unitId') || !body.containsKey('description') || !body.containsKey('priority')) {
        return Response(400, body: jsonEncode({'message': 'unitId, description, and priority are required'}));
      }

      final requestModel = MaintenanceRequestModel.fromMap(
        body,
        '',
      ).copyWith(tenantId: userId, createdAt: DateTime.now(), status: 'Pending');

      final created = await repository.createRequest(requestModel);

      return Response.ok(
        jsonEncode({'message': 'Maintenance request submitted successfully', 'request': created.toMap()}),
        headers: {'Content-Type': 'application/json'},
      );
    } on ValidationException catch (e) {
      return Response(400, body: jsonEncode({'message': e.message}));
    } catch (e, stack) {
      print('Submit maintenance request error: $e\n$stack');
      return Response.internalServerError(
        body: jsonEncode({'message': 'Failed to submit maintenance request'}),
      );
    }
  }

  /// GET /maintenance-requests/me - Tenant views their own requests
  Future<Response> getMyRequests(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;

      if (userId == null || role != 'tenant') {
        return Response(403, body: jsonEncode({'message': 'Only tenants can view their own requests'}));
      }

      final requests = await repository.getRequestsByTenant(userId);

      return Response.ok(
        jsonEncode({
          'requests': requests.map((r) => r.toMap()).toList(),
          'message': 'Your maintenance requests',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Get my requests error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to load your requests'}));
    }
  }

  /// GET /maintenance-requests/unit/<unitId> - Manager/Landowner views requests for a unit
  Future<Response> getRequestsByUnit(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final unitId = request.params['unitId'];

      if (userId == null || unitId == null) {
        return Response(400, body: jsonEncode({'message': 'Missing user or unit ID'}));
      }

      if (!['manager', 'landowner'].contains(role)) {
        return Response(403, body: jsonEncode({'message': 'Unauthorized'}));
      }

      final requests = await repository.getRequestsByUnit(unitId);

      return Response.ok(
        jsonEncode({
          'requests': requests.map((r) => r.toMap()).toList(),
          'message': 'Maintenance requests for this unit',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Get requests by unit error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to load requests'}));
    }
  }

  /// GET /maintenance-requests/<id> - View single request (tenant or manager)
  Future<Response> getRequestById(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final requestId = request.params['id'];

      if (userId == null || requestId == null) {
        return Response(400, body: jsonEncode({'message': 'Missing ID'}));
      }

      final requestModel = await repository.getRequestById(requestId);

      // Authorization: tenant who submitted or manager/landowner
      final isTenant = requestModel.tenantId == userId;
      final isManagerOrOwner = ['manager', 'landowner'].contains(role);

      if (!isTenant && !isManagerOrOwner) {
        return Response(403, body: jsonEncode({'message': 'Forbidden'}));
      }

      return Response.ok(
        jsonEncode({'request': requestModel.toMap()}),
        headers: {'Content-Type': 'application/json'},
      );
    } on NotFoundException catch (e) {
      return Response(404, body: jsonEncode({'message': e.message}));
    } catch (e, stack) {
      print('Get request error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to load request'}));
    }
  }

  /// PATCH /maintenance-requests/<id>/assign - Manager assigns to artisan
  Future<Response> assignRequest(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final requestId = request.params['id'];

      if (userId == null || requestId == null) {
        return Response(400, body: jsonEncode({'message': 'Missing ID'}));
      }

      if (role != 'manager') {
        return Response(403, body: jsonEncode({'message': 'Only managers can assign requests'}));
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final artisanId = body['artisanId'] as String?;

      if (artisanId == null || artisanId.isEmpty) {
        return Response(400, body: jsonEncode({'message': 'artisanId is required'}));
      }

      await repository.assignRequest(requestId, artisanId);

      return Response.ok(jsonEncode({'message': 'Request assigned to artisan'}));
    } catch (e, stack) {
      print('Assign request error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to assign request'}));
    }
  }

  /// PATCH /maintenance-requests/<id>/update - General update (status, notes, photos)
  Future<Response> updateRequest(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final requestId = request.params['id'];

      if (userId == null || requestId == null) {
        return Response(400, body: jsonEncode({'message': 'Missing ID'}));
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final currentRequest = await repository.getRequestById(requestId);

      // Authorization: tenant (if pending), assigned artisan, or manager
      final isTenant = currentRequest.tenantId == userId && currentRequest.status == 'Pending';
      final isArtisan = currentRequest.assignedTo == userId;
      final isManager = role == 'manager';

      if (!isTenant && !isArtisan && !isManager) {
        return Response(403, body: jsonEncode({'message': 'Forbidden'}));
      }

      final updated = currentRequest.copyWith(
        description: body['description'] as String?,
        photoUrls: (body['photoUrls'] as List?)?.cast<String>(),
        status: body['status'] as String?,
        resolutionNotes: body['resolutionNotes'] as String?,
      );

      await repository.updateRequest(updated);

      return Response.ok(jsonEncode({'message': 'Request updated'}));
    } catch (e, stack) {
      print('Update request error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to update request'}));
    }
  }

  /// DELETE /maintenance-requests/<id> - Tenant cancels pending request
  Future<Response> deleteRequest(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final requestId = request.params['id'];

      if (userId == null || requestId == null) {
        return Response(400, body: jsonEncode({'message': 'Missing ID'}));
      }

      final currentRequest = await repository.getRequestById(requestId);

      if (currentRequest.tenantId != userId || currentRequest.status != 'Pending') {
        return Response(403, body: jsonEncode({'message': 'You can only cancel your own pending requests'}));
      }

      await repository.deleteRequest(requestId);

      return Response.ok(jsonEncode({'message': 'Request cancelled'}));
    } catch (e, stack) {
      print('Delete request error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to cancel request'}));
    }
  }
}
