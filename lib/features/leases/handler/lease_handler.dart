import 'dart:convert';
import 'package:neztmate_backend/features/leases/repository/lease_repo.dart';
import 'package:shelf/shelf.dart';
import 'package:neztmate_backend/core/error.dart';
import 'package:shelf_router/shelf_router.dart';

class LeaseHandler {
  final LeaseRepository leaseRepository;

  LeaseHandler(this.leaseRepository);

  /// GET /leases/me → Tenant sees their active/current leases
  Future<Response> getMyLeases(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;

      if (userId == null) return _unauthorized();

      if (role != 'tenant') {
        return Response(403, body: jsonEncode({'message': 'Only tenants can view personal leases'}));
      }

      final leases = await leaseRepository.getActiveLeasesByTenant(userId);

      return Response.ok(
        jsonEncode({'leases': leases.map((l) => l.toMap()).toList(), 'message': 'Your active leases'}),
        headers: {'Content-Type': 'application/json'},
      );
    } on AppException catch (e) {
      return Response(400, body: jsonEncode({'message': e.message}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to load leases'}));
    }
  }

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

      return Response.ok(
        jsonEncode({'leases': leases.map((l) => l.toMap()).toList(), 'message': 'Leases for this property'}),
      );
    } catch (e) {
      return Response.internalServerError();
    }
  }

  /// GET /leases/<id> → View single lease (tenant/owner/manager)
  Future<Response> getLeaseById(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final leaseId = request.params['id'];

      if (userId == null || leaseId == null) return _unauthorized();

      final lease = await leaseRepository.getLeaseById(leaseId);

      // Simple authorization: tenant or landowner/manager
      final isTenant = lease.tenantId == userId;
      final isOwnerOrManager = lease.landownerId == userId || role == 'manager';

      if (!isTenant && !isOwnerOrManager) {
        return Response(403, body: jsonEncode({'message': 'Forbidden'}));
      }

      return Response.ok(jsonEncode({'lease': lease.toMap()}));
    } on NotFoundException catch (e) {
      return Response(404, body: jsonEncode({'message': e.message}));
    } catch (e) {
      return Response.internalServerError();
    }
  }

  // Optional: POST /leases (usually created automatically from approved application)
  // You can add later if you want manual lease creation

  Response _unauthorized() => Response(401, body: jsonEncode({'message': 'Unauthorized'}));
}
