import 'package:neztmate_backend/features/auth_user/handler/auth_handler.dart';
import 'package:shelf_router/shelf_router.dart';

Router authRoutes(AuthHandler handler) {
  final router = Router();

  router.post('/register', handler.register);
  router.post('/login', handler.login);
  router.post('/social', handler.social);

  router.post('/platform/google', handler.platformGoogleLogin);

  router.post('/change-password', handler.changePassword);

  // Email verification (OTP via Resend)
  router.post('/verify-email', handler.verifyEmail);
  router.post('/resend-verification', handler.resendVerification);

  return router;
}
