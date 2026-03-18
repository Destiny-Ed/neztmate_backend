import 'package:neztmate_backend/core/services/auth/jwt_service.dart';
import 'package:shelf/shelf.dart';

Middleware authMiddleware(JwtService jwtService) {
  return (Handler innerHandler) {
    return (Request request) async {
      final authHeader = request.headers['Authorization'];

      if (authHeader == null) {
        return Response.forbidden("Missing token");
      }

      final token = authHeader.replaceFirst("Bearer ", "");

      try {
        final jwt = jwtService.verify(token);

        final updated = request.change(context: {"userId": jwt.payload["sub"], "role": jwt.payload["role"]});

        return await innerHandler(updated);
      } catch (e) {
        return Response.unauthorized("Invalid token");
      }
    };
  };
}
