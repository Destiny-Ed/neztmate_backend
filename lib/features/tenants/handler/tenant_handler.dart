import 'dart:convert';
import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/features/tenants/repository/tenant_respository.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class TenantHandler {
  final TenantRepository tenantRepository;

  TenantHandler(this.tenantRepository);

  /// GET /tenants/search?q=keyword - Search tenants by name or email
  Future<Response> searchTenants(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final query = request.url.queryParameters['q']?.trim();

      if (userId == null || role == null) {
        return Response(401, body: jsonEncode({'message': 'Unauthorized'}));
      }

      if (!['landowner', 'manager'].contains(role)) {
        return Response(
          403,
          body: jsonEncode({'message': 'Only landowners and managers can search tenants'}),
        );
      }

      if (query == null || query.isEmpty) {
        return Response(400, body: jsonEncode({'message': 'Search query is required'}));
      }

      final tenants = await tenantRepository.searchTenants(query: query, userId: userId, role: role);

      return Response.ok(
        jsonEncode({
          'tenants': tenants.map((t) => t.toMap()).toList(),
          'message': 'Search completed',
          'count': tenants.length,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Tenant search error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to search tenants'}));
    }
  }

  Future<Response> getTenantNeighbors(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final propertyId = request.params['propertyId'];
      final tenantId = request.params['tenantId'];

      if (userId == null || role == null) {
        return Response(401, body: jsonEncode({'message': 'Unauthorized'}));
      }

      if (!['landowner', 'manager', 'tenant'].contains(role)) {
        return Response(
          403,
          body: jsonEncode({'message': 'Only landowners, tenants and managers can view neighbors'}),
        );
      }

      if (propertyId == null) {
        return badRequest("Property Id is required");
      }

      if (tenantId == null) {
        return badRequest("Tenant Id is required");
      }

      final tenantNeighbors = await tenantRepository.getTenantNeighbors(propertyId, tenantId);

      return Response.ok(
        jsonEncode({
          'neighbors': tenantNeighbors.map((t) => t.toMap()).toList(),
          'message': 'Neighbors fetched successfully',
          'count': tenantNeighbors.length,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Neighbors fetch error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to fetch neighbors'}));
    }
  }
}
