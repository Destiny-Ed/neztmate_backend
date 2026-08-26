import 'dart:convert';
import 'package:dart_firebase_admin/auth.dart';
import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/features/partners/repository/partner_repository.dart';
import 'package:shelf/shelf.dart';
import 'package:neztmate_backend/core/services/auth/jwt_service.dart';
import 'package:neztmate_backend/core/services/auth/password_service.dart';
import 'package:neztmate_backend/features/auth_user/models/login_request_model.dart';
import 'package:neztmate_backend/features/auth_user/models/register_request_model.dart';
import 'package:neztmate_backend/features/auth_user/models/social_request_model.dart';
import 'package:neztmate_backend/features/auth_user/repositories/auth_repository.dart';
import 'package:neztmate_backend/features/auth_user/repositories/user_repository.dart';

class AuthHandler {
  final AuthRepository authRepository;
  final UserRepository userRepository;
  final PasswordService passwordService;
  final JwtService jwtService;
  final PartnerRepository partnerRepository;
  final Auth firebaseAuth;

  AuthHandler(
    this.authRepository,
    this.passwordService,
    this.jwtService,
    this.userRepository,
    this.partnerRepository,
    this.firebaseAuth,
  );

  Future<Response> register(Request req) async {
    try {
      final body = jsonDecode(await req.readAsString());
      final request = RegisterRequest.fromJson(body);

      // Basic validation
      if (request.email.isEmpty || !request.email.contains('@')) {
        return badRequest('Invalid email format');
      }
      if (request.password.length < 6) {
        return badRequest('Password must be at least 6 characters');
      }
      if (!['tenant', 'landowner', 'manager', 'artisan'].contains(request.role)) {
        throw InvalidRoleException(request.role);
      }

      if (request.country.isEmpty) {
        throw ValidationException('User country is required ');
      }

      if (request.platform.isEmpty) {
        throw ValidationException('Platform type of device is required ');
      }

      if (request.fcmToken.isEmpty) {
        throw ValidationException('FcmToken is required ');
      }

      final partnerSlug = body['partnerSlug'] as String? ?? req.headers['x-partner-slug'];

      if (partnerSlug == null && partnerSlug!.isEmpty) {
        throw ValidationException('partner slug header is required');
      }

      final partner = await partnerRepository.getPartnerBySlug(partnerSlug);

      //resolve slug into partner Id
      final created = await authRepository.registerNewUser(request.copyWith(partnerSlug: partner.id));

      final accessToken = jwtService.generateAccessToken(
        created.id,
        created.role,
        partnerId: created.partnerId,
      );
      final refreshToken = jwtService.generateRefreshToken(created.id);

      await authRepository.saveRefreshToken(created.id, refreshToken);

      return Response.ok(
        jsonEncode({
          'accessToken': accessToken,
          'refreshToken': refreshToken,
          'user': {
            'id': created.id,
            'email': created.email,
            'fullName': created.fullName,
            'role': created.role,
          },
          'message': 'Account created successfully',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } on AppException catch (e, stack) {
      return handleAppException(e, stack);
    } catch (e, stack) {
      return handleAppException(e, stack);
    }
  }

  Future<Response> login(Request req) async {
    try {
      final body = jsonDecode(await req.readAsString());
      final request = LoginRequest.fromJson(body);

      // Basic validation
      if (request.email.isEmpty || !request.email.contains('@')) {
        return badRequest('Invalid email format');
      }
      if (request.password.length < 6) {
        return badRequest('Password must be at least 6 characters');
      }

      if (request.fcmToken.isEmpty) {
        throw ValidationException('Fcm Token is required ');
      }

      final user = await authRepository.loginUser(request);

      final accessToken = jwtService.generateAccessToken(user.id, user.role, partnerId: user.partnerId);
      final refreshToken = jwtService.generateRefreshToken(user.id);

      await authRepository.saveRefreshToken(user.id, refreshToken);

      return Response.ok(
        jsonEncode({
          'accessToken': accessToken,
          'refreshToken': refreshToken,
          'user': {'id': user.id, 'email': user.email, 'fullName': user.fullName, 'role': user.role},
          'message': 'Login successful',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } on AppException catch (e, stack) {
      return handleAppException(e, stack);
    } catch (e, stack) {
      return handleAppException(e, stack);
    }
  }

  Future<Response> social(Request req) async {
    try {
      final body = jsonDecode(await req.readAsString());
      final request = SocialRequestModel.fromJson(body);

      // Basic validation
      if (request.idToken.isEmpty) {
        return badRequest('idToken is required');
      }

      if (request.fcmToken.isEmpty) {
        throw ValidationException('Fcm Token is required ');
      }

      final partnerSlug = req.headers['x-partner-slug'] ?? request.partnerSlug as String?;

      if (partnerSlug == null && partnerSlug!.isEmpty) {
        throw ValidationException('partner slug header is required');
      }

      final partner = await partnerRepository.getPartnerBySlug(partnerSlug);

      final user = await authRepository.socialLogin(req: request.copyWith(partnerSlug: partnerSlug));

      final accessToken = jwtService.generateAccessToken(user.id, user.role, partnerId: user.partnerId);
      final refreshToken = jwtService.generateRefreshToken(user.id);

      await authRepository.saveRefreshToken(user.id, refreshToken);

      return Response.ok(
        jsonEncode({
          'accessToken': accessToken,
          'refreshToken': refreshToken,
          'user': {
            'id': user.id,
            'email': user.email,
            'fullName': user.fullName,
            'role': user.role,
            'profilePhotoUrl': user.profilePhotoUrl ?? '',
          },
          'message': 'Social login successful',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } on AppException catch (e, stack) {
      return handleAppException(e, stack);
    } catch (e, stack) {
      return handleAppException(e, stack);
    }
  }

  /// POST /auth/platform/google  (public)
  /// Body: { idToken, fcmToken, platform }
  Future<Response> platformGoogleLogin(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final idToken = (body['idToken'] as String?)?.trim() ?? '';
      final fcmToken = (body['fcmToken'] as String?)?.trim() ?? '';

      if (idToken.isEmpty) {
        return Response(400, body: jsonEncode({'message': 'idToken is required'}));
      }
      if (fcmToken.isEmpty) {
        return Response(400, body: jsonEncode({'message': 'fcmToken is required'}));
      }

      // Verify Google ID token (Firebase Admin or googleapis)
      final decoded = await firebaseAuth.verifyIdToken(idToken);
      // Or: verify with Google tokeninfo / jose against Google certs

      final email = (decoded.email ?? '').toLowerCase();
      if (email.isEmpty) {
        return Response(401, body: jsonEncode({'message': 'Email missing on Google account'}));
      }

      final user = await userRepository.getUserByEmail(email);
      // if (user == null) {
      //   return Response(
      //     403,
      //     body: jsonEncode({
      //       'message':
      //           'No platform admin account for this Google email. Ask an existing admin to grant access.',
      //     }),
      //   );
      // }

      final role = user.role.toLowerCase();
      final isPlatform =
          role == 'platform_admin' ||
          role == 'super_admin' ||
          (user.roles?.map((r) => r.toLowerCase()).contains('platform_admin') ?? false);

      if (!isPlatform) {
        return Response(
          403,
          body: jsonEncode({'message': 'Google sign-in is only allowed for platform admins'}),
        );
      }

      // Optional: update fcmToken / lastLogin
      // await userRepository.updateUser(user.copyWith(fcmToken: fcmToken, lastLogin: DateTime.now()));

      final accessToken = jwtService.generateAccessToken(user.id, 'platform_admin');
      final refreshToken = jwtService.generateRefreshToken(user.id);
      await authRepository.saveRefreshToken(user.id, refreshToken);

      return Response.ok(
        jsonEncode({
          'accessToken': accessToken,
          'refreshToken': refreshToken,
          'message': 'Login successfully',
          'user': {'id': user.id, 'email': user.email, 'fullName': user.fullName, 'role': 'platform_admin'},
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, s) {
      print('platformGoogleLogin: $e\n$s');
      return Response(401, body: jsonEncode({'message': 'Invalid or expired Google token'}));
    }
  }
}
