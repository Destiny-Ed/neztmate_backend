import 'package:neztmate_backend/core/services/auth/jwt_service.dart';
import 'package:neztmate_backend/core/services/subscription/partner_access_service.dart';
import 'package:neztmate_backend/features/subscriptions/repository/subscription_repository.dart';
import 'package:shelf/shelf.dart';

bool _isPlatformAdmin(String? role) {
  final r = (role ?? '').toLowerCase().trim();
  return r == 'platform_admin' || r == 'super_admin';
}

/// When a valid Bearer token is present, attaches user context.
/// When missing or invalid, continues as anonymous (for public listings).
Middleware optionalAuthMiddleware(
  JwtService jwtService,
  SubscriptionRepository subscriptionRepository,
  PartnerAccessService partnerAccess,
) {
  return (Handler innerHandler) {
    return (Request request) async {
      final authHeader = request.headers['authorization'] ?? request.headers['Authorization'];

      if (authHeader == null || !authHeader.toLowerCase().startsWith('bearer ')) {
        return innerHandler(request);
      }

      final token = authHeader.substring(authHeader.indexOf(' ') + 1).trim();
      if (token.isEmpty) {
        return innerHandler(request);
      }

      try {
        final jwt = jwtService.verify(token);
        final payload = jwt.payload;

        final userId = payload['sub'] as String?;
        final role = payload['role'] as String?;
        final partnerId = (payload['partnerId'] as String?)?.trim() ?? '';
        final isPlatformAdmin = _isPlatformAdmin(role);

        if (userId == null || userId.isEmpty) {
          return innerHandler(request);
        }

        // Soft partner gate — do not block public listing if partner check fails
        if (!isPlatformAdmin && partnerId.isNotEmpty) {
          try {
            await partnerAccess.assertAppEnabled(partnerId);
          } catch (_) {}
        }

        String subscriptionPlan = 'free';
        if (!isPlatformAdmin && partnerId.isNotEmpty) {
          try {
            final subscription = await subscriptionRepository.getActiveSubscription(
              userId,
              partnerId: partnerId,
            );
            subscriptionPlan = subscription?.planId ?? 'free';
          } catch (_) {}
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
      } catch (_) {
        return innerHandler(request);
      }
    };
  };
}
