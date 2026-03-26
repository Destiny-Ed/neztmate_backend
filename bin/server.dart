import 'dart:convert';
import 'dart:io';
import 'package:dotenv/dotenv.dart';
import 'package:neztmate_backend/core/di/injector.dart';
import 'package:neztmate_backend/core/middleware/auth_middleware.dart';
import 'package:neztmate_backend/core/services/auth/jwt_service.dart';
import 'package:neztmate_backend/core/services/database/firebase/firebase.dart';
import 'package:neztmate_backend/features/applications/handler/application_handler.dart';
import 'package:neztmate_backend/features/auth_user/handler/auth_handler.dart';
import 'package:neztmate_backend/features/auth_user/handler/user_handler.dart';
import 'package:neztmate_backend/features/history/handler/history_handler.dart';
import 'package:neztmate_backend/features/invites/handler/invite_handler.dart';
import 'package:neztmate_backend/features/leases/handler/lease_handler.dart';
import 'package:neztmate_backend/features/properties/handler/property_handler.dart';
import 'package:neztmate_backend/features/tasks/handler/task_handler.dart';
import 'package:neztmate_backend/features/units/handler/unit_handler.dart';
import 'package:neztmate_backend/routes/applications_routes.dart';
import 'package:neztmate_backend/routes/auth_routes.dart';
import 'package:neztmate_backend/routes/history_routes.dart';
import 'package:neztmate_backend/routes/invites_route.dart';
import 'package:neztmate_backend/routes/lease_routes.dart';
import 'package:neztmate_backend/routes/property_routes.dart';
import 'package:neztmate_backend/routes/task_route.dart';
import 'package:neztmate_backend/routes/unit_routes.dart';
import 'package:neztmate_backend/routes/user_routes.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';

void main() async {
  final env = DotEnv()..load();
  //   // Use any available host or container IP (usually `0.0.0.0`).
  final ip = InternetAddress.anyIPv4;
  final port = int.tryParse(env['PORT'] ?? '8080') ?? 8080;
  final jwtSecret = env['JWT_SECRET'];
  if (jwtSecret == null || jwtSecret.isEmpty) {
    throw Exception("JWT_SECRET is required in .env");
  }

  await setupDependencies(jwtSecret: jwtSecret);

  final authHandler = injector<AuthHandler>();
  final userHandler = injector<UserHandler>();
  final jwtService = injector<JwtService>();
  final propertyHandler = injector<PropertyHandler>();

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

  router.get('/debug/firebase', (Request req) async {
    try {
      final version = injector<FirebaseService>().firestore.app.projectId;
      return Response.ok('Firebase connected to project: $version');
    } catch (e) {
      return Response.internalServerError(body: 'Firebase error: $e');
    }
  });

  /// routes
  router.mount('/auth', authRoutes(authHandler).call);
  router.mount(
    '/users',
    Pipeline()
        .addMiddleware(authMiddleware(jwtService)) // ← protects all /users/* routes
        .addHandler(userRoutes(userHandler).call),
  );

  router.mount(
    '/properties/',
    Pipeline().addMiddleware(authMiddleware(jwtService)).addHandler(propertyRoutes(propertyHandler).call),
  );

  router.mount(
    '/units/',
    Pipeline().addMiddleware(authMiddleware(jwtService)).addHandler(unitRoutes(injector<UnitHandler>()).call),
  );

  router.mount(
    '/history/',
    Pipeline()
        .addMiddleware(authMiddleware(jwtService))
        .addHandler(historyRoutes(injector<HistoryHandler>()).call),
  );

  router.mount(
    '/leases/',
    Pipeline()
        .addMiddleware(authMiddleware(jwtService))
        .addHandler(leaseRoutes(injector<LeaseHandler>()).call),
  );

  router.mount(
    '/applications/',
    Pipeline()
        .addMiddleware(authMiddleware(jwtService))
        .addHandler(applicationRoutes(injector<ApplicationHandler>()).call),
  );

  router.mount(
    '/invites/',
    Pipeline()
        .addMiddleware(authMiddleware(jwtService))
        .addHandler(inviteRoutes(injector<InviteHandler>()).call),
  );

  router.mount(
    '/tasks/',
    Pipeline().addMiddleware(authMiddleware(jwtService)).addHandler(taskRoutes(injector<TaskHandler>()).call),
  );

  

  final handler = Pipeline().addMiddleware(logRequests()).addHandler(router.call);

  final server = await serve(handler, ip, port);
  print('Server listening on port ${server.port}');
}
