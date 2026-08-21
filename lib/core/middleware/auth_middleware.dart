import 'dart:convert';

import 'package:neztmate_backend/core/services/auth/jwt_service.dart';
import 'package:neztmate_backend/features/subscriptions/repository/subscription_repository.dart';
import 'package:shelf/shelf.dart';

Middleware authMiddleware(JwtService jwtService, SubscriptionRepository subscriptionRepository) {
  return (Handler innerHandler) {
    return (Request request) async {
      final authHeader = request.headers['authorization'] ?? request.headers['Authorization'];

      if (authHeader == null || !authHeader.toLowerCase().startsWith('bearer ')) {
        return Response.forbidden(
          jsonEncode({'message': 'Missing token'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final token = authHeader.replaceFirst("Bearer ", "");

      try {
        final jwt = jwtService.verify(token);
        final payload = jwt.payload;

        final userId = payload['sub'] as String?;
        final role = payload['role'] as String?;
        final partnerId = (payload['partnerId'] as String?)?.trim() ?? '';

        if (userId == null || userId.isEmpty) {
          return Response.unauthorized(
            jsonEncode({'message': 'Invalid token: missing subject'}),
            headers: {'Content-Type': 'application/json'},
          );
        }

        // Block if partnerId is missing entirely
        if (partnerId.isEmpty) {
          return Response(
            403,
            body: jsonEncode({
              'message': 'Partner context required. partnerId is missing from token. Please sign in again.',
              'code': 'PARTNER_REQUIRED',
            }),
            headers: {'Content-Type': 'application/json'},
          );
        }

        // Optional: platform_admin may use header override later; still require a partnerId
        // for normal product routes, or skip subscription lookup for platform_admin.

        final subscription = await subscriptionRepository.getActiveSubscription(userId, partnerId: partnerId);

        final updated = request.change(
          context: {
            'userId': userId,
            'role': role,
            'partnerId': partnerId,
            'subscriptionPlan': subscription?.planId ?? 'free',
          },
        );

        return await innerHandler(updated);
      } catch (e) {
        return Response.unauthorized(
          jsonEncode({'message': 'Invalid token'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    };
  };
}
