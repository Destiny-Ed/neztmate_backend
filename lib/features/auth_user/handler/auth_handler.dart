import 'dart:convert';
import 'package:neztmate_backend/core/error.dart';
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

  AuthHandler(this.authRepository, this.passwordService, this.jwtService, this.userRepository);

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
      if (!['Tenant', 'Landowner', 'Manager', 'Artisan'].contains(request.role)) {
        return badRequest('Invalid role. Allowed: Tenant, Landowner, Manager, Artisan');
      }

      if (request.country.isEmpty) {
        throw ValidationException('User country is required ');
      }

      if (request.platform.isEmpty) {
        throw ValidationException('Platform type of device is required ');
      }

      if (request.fcmToken.isEmpty) {
        throw ValidationException('Fcm Token is required ');
      }

      final created = await authRepository.registerNewUser(request);

      final accessToken = jwtService.generateAccessToken(created.id, created.role);
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

      final user = await authRepository.loginUser(request);

      final accessToken = jwtService.generateAccessToken(user.id, user.role);
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

      final user = await authRepository.socialLogin(req: request);

      final accessToken = jwtService.generateAccessToken(user.id, user.role);
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
}
