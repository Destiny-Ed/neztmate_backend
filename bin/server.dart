import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:neztmate_backend/core/di/injector.dart';
import 'package:neztmate_backend/features/auth/presentations/handlers/auth_handler.dart';
import 'package:neztmate_backend/routes/auth_routes.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';

void main() async {
  final env = DotEnv()..load();
  //   // Use any available host or container IP (usually `0.0.0.0`).
  final ip = InternetAddress.anyIPv4;
  final port = int.tryParse(env.env['PORT'] ?? '8080') ?? 8080;

  setupDependencies();

  final authHandler = injector<AuthHandler>();

  final router = Router();

  router.get('/', (Request req) {
    return Response.ok('NeztMate Backend Running');
  });

  // Healthcheck
  router.get('/health', (Request req) async {
    return Response.ok(
      jsonEncode({'status': 'Ok', 'message': 'All is well'}),
      headers: {'content-type': 'text/plain'},
    );
  });

  /// routes
  router.mount('/auth/', authRoutes(authHandler).call);

  final handler = Pipeline().addMiddleware(logRequests()).addHandler(router.call);

  final server = await serve(handler, ip, port);
  print('Server listening on port ${server.port}');
}
