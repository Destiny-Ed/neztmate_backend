import 'dart:convert';

import 'package:neztmate_backend/core/services/auth/jwt_service.dart';
import 'package:neztmate_backend/features/subscriptions/repository/subscription_repository.dart';
import 'package:shelf/shelf.dart';

bool _isPlatformAdmin(String? role) {
  final r = (role ?? '').toLowerCase().trim();
  return r == 'platform_admin' || r == 'super_admin';
}

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

      // Accept "Bearer <token>" with any casing on "Bearer"
      final token = authHeader.substring(authHeader.indexOf(' ') + 1).trim();
      if (token.isEmpty) {
        return Response.forbidden(
          jsonEncode({'message': 'Missing token'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      try {
        final jwt = jwtService.verify(token);
        final payload = jwt.payload;

        final userId = payload['sub'] as String?;
        final role = payload['role'] as String?;
        final partnerId = (payload['partnerId'] as String?)?.trim() ?? '';
        final isPlatformAdmin = _isPlatformAdmin(role);

        if (userId == null || userId.isEmpty) {
          return Response.unauthorized(
            jsonEncode({'message': 'Invalid token: missing subject'}),
            headers: {'Content-Type': 'application/json'},
          );
        }

        // Partner context required for everyone except platform / super admin
        if (!isPlatformAdmin && partnerId.isEmpty) {
          return Response(
            403,
            body: jsonEncode({
              'message': 'Partner context required. partnerId is missing from token. Please sign in again.',
              'code': 'PARTNER_REQUIRED',
            }),
            headers: {'Content-Type': 'application/json'},
          );
        }

        // Subscription is partner-scoped — skip for platform admins
        String subscriptionPlan = 'free';
        if (!isPlatformAdmin && partnerId.isNotEmpty) {
          final subscription = await subscriptionRepository.getActiveSubscription(
            userId,
            partnerId: partnerId,
          );
          subscriptionPlan = subscription?.planId ?? 'free';
        }

        final updated = request.change(
          context: {
            'userId': userId,
            'role': role,
            'partnerId': isPlatformAdmin ? (partnerId.isEmpty ? null : partnerId) : partnerId,
            'isPlatformAdmin': isPlatformAdmin,
            'subscriptionPlan': subscriptionPlan,
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
