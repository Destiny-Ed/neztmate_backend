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
import 'package:neztmate_backend/features/community/handler/community_handler.dart';
import 'package:neztmate_backend/features/history/handler/history_handler.dart';
import 'package:neztmate_backend/features/invites/handler/invite_handler.dart';
import 'package:neztmate_backend/features/leases/handler/lease_handler.dart';
import 'package:neztmate_backend/features/maintenance/handler/maintenance_handler.dart';
import 'package:neztmate_backend/features/messages/handler/messages_handler.dart';
import 'package:neztmate_backend/features/notifications/handler/handler.dart';
import 'package:neztmate_backend/features/payments/handler/payment_handler.dart';
import 'package:neztmate_backend/features/properties/handler/property_handler.dart';
import 'package:neztmate_backend/features/reviews/handler/user_review_handler.dart';
import 'package:neztmate_backend/features/tenants/handler/tenant_handler.dart';
import 'package:neztmate_backend/features/units/handler/unit_handler.dart';
import 'package:neztmate_backend/features/verification/handler/verification_handler.dart';
import 'package:neztmate_backend/routes/applications_routes.dart';
import 'package:neztmate_backend/routes/auth_routes.dart';
import 'package:neztmate_backend/routes/community_routes.dart';
import 'package:neztmate_backend/routes/docs.dart';
import 'package:neztmate_backend/routes/history_routes.dart';
import 'package:neztmate_backend/routes/invites_route.dart';
import 'package:neztmate_backend/routes/lease_routes.dart';
import 'package:neztmate_backend/routes/maintenance_routes.dart';
import 'package:neztmate_backend/routes/message_routes.dart';
import 'package:neztmate_backend/routes/notifications_routes.dart';
import 'package:neztmate_backend/routes/payment_routes.dart';
import 'package:neztmate_backend/routes/property_routes.dart';
import 'package:neztmate_backend/routes/tenant_routes.dart';
import 'package:neztmate_backend/routes/unit_routes.dart';
import 'package:neztmate_backend/routes/user_review_routes.dart';
import 'package:neztmate_backend/routes/user_routes.dart';
import 'package:neztmate_backend/routes/verification_routes.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_swagger_ui/shelf_swagger_ui.dart';

void main() async {
  final env = DotEnv()..load();
  //   // Use any available host or container IP (usually `0.0.0.0`).
  final ip = InternetAddress.anyIPv4;
  final jwtSecret = Platform.environment['JWT_SECRET'] ?? env['JWT_SECRET'];
  final rawPort = Platform.environment['PORT'] ?? env['PORT'];

  final port = int.tryParse(rawPort ?? '8080') ?? 8080;
  if (jwtSecret == null || jwtSecret.isEmpty) {
    throw Exception("JWT_SECRET is required in .env");
  }

  await setupDependencies(jwtSecret: jwtSecret);

  // After server starts
  // final scheduler = SchedulerService(
  //   inviteRepository: injector<InviteRepository>(),
  //   leaseRepository: injector<LeaseRepository>(),
  //   notificationRepository: injector<NotificationRepository>(),
  //   historyRepository: injector<HistoryRepository>(),
  //   paymentRepository: injector<PaymentRepository>(),
  // );

  // scheduler.start();

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
    '/maintenance/',
    Pipeline()
        .addMiddleware(authMiddleware(jwtService))
        .addHandler(maintenanceRoutes(injector<MaintenanceHandler>()).call),
  );

  router.mount(
    '/community/',
    Pipeline()
        .addMiddleware(authMiddleware(jwtService))
        .addHandler(communityRoutes(injector<CommunityHandler>()).call),
  );

  router.mount(
    '/messages/',
    Pipeline()
        .addMiddleware(authMiddleware(jwtService))
        .addHandler(messageRoutes(injector<MessageHandler>()).call),
  );

  // WebSocket Route PUBLIC
  router.get('/ws/chat', injector<MessageHandler>().getWebSocketHandler);

  router.mount(
    '/notifications/',
    Pipeline()
        .addMiddleware(authMiddleware(jwtService))
        .addHandler(notificationRoutes(injector<NotificationHandler>()).call),
  );

  router.mount(
    '/payments/',
    Pipeline()
        .addMiddleware(authMiddleware(jwtService))
        .addHandler(paymentRoutes(injector<PaymentHandler>()).call),
  );

  router.mount(
    '/tenants/',
    Pipeline()
        .addMiddleware(authMiddleware(jwtService))
        .addHandler(tenantRoutes(injector<TenantHandler>()).call),
  );

  // Mount review routes
  router.mount(
    '/reviews/',
    Pipeline()
        .addMiddleware(authMiddleware(jwtService))
        .addHandler(reviewRoutes(injector<UserReviewHandler>()).call),
  );

  //verification
  router.mount(
    '/verification/',
    Pipeline()
        .addMiddleware(authMiddleware(jwtService))
        .addHandler(verificationRoutes(injector<VerificationHandler>()).call),
  );

  /// Webhook from Paystack (NO auth middleware - must be public)
  router.post('/webhook/paystack', injector<PaymentHandler>().paystackWebhook);

  /// Webhook from verification (NO auth middleware - must be public)
  router.post('/webhook/verification', injector<VerificationHandler>().handleWebhook);

  //  SWAGGER UI SETUP

  final swaggerHandler = SwaggerUI(
    openApiSpec,
    // specType: SpecType.yaml,
    title: 'Swagger Test',
    docExpansion: DocExpansion.list,
    syntaxHighlightTheme: SyntaxHighlightTheme.nord,
  );

  router.get('/docs', swaggerHandler.call);
  router.get('/docs/', (Request req) => Response.found('/docs')); // Nice redirect

  //  END SETUP

  final handler = Pipeline().addMiddleware(logRequests()).addHandler(router.call);

  final server = await serve(handler, ip, port);
  print('Serving served at http://${server.address.host}:${server.port}');
}
