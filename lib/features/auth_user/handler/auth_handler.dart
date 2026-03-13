import 'dart:convert';
import 'dart:developer';
import 'package:neztmate_backend/features/auth_user/models/social_request_model.dart';
import 'package:neztmate_backend/features/auth_user/repositories/user_repository.dart';
import 'package:shelf/shelf.dart';
import 'package:neztmate_backend/core/services/auth/jwt_service.dart';
import 'package:neztmate_backend/core/services/auth/password_service.dart';
import 'package:neztmate_backend/features/auth_user/models/login_request_model.dart';
import 'package:neztmate_backend/features/auth_user/models/register_request_model.dart';
import 'package:neztmate_backend/features/auth_user/repositories/auth_repository.dart';

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
      if (request.email.isEmpty || !request.email.contains('@') || request.password.length < 6) {
        return Response(400, body: jsonEncode({'message': 'Invalid email or password (min 6 chars)'}));
      }

      if (!['Tenant', 'Landowner', 'Manager', 'Artisan'].contains(request.role)) {
        return Response(400, body: jsonEncode({'message': 'Invalid role'}));
      }

      // Check if email already exists
      final existing = await userRepository.getUserByEmail(request.email);
      if (existing != null) {
        return Response(409, body: jsonEncode({'message': 'Email already in use'}));
      }

      final created = await authRepository.registerNewUser(request);

      if (created == null) {
        return Response(500, body: jsonEncode({'message': 'Failed to create user'}));
      }

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
          'message': "Account created successfully",
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Register error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Server error'}));
    }
  }

  Future<Response> login(Request req) async {
    try {
      final body = jsonDecode(await req.readAsString());
      final request = LoginRequest.fromJson(body);

      log(request.email);
      log(request.password);

      final user = await authRepository.loginUser(request);
      if (user == null) {
        return Response(401, body: jsonEncode({'message': 'Invalid credentials'}));
      }

      final accessToken = jwtService.generateAccessToken(user.id, user.role);
      final refreshToken = jwtService.generateRefreshToken(user.id);

      await authRepository.saveRefreshToken(user.id, refreshToken);

      return Response.ok(
        jsonEncode({
          'accessToken': accessToken,
          'refreshToken': refreshToken,
          'message': "Login successfully",
          'user': {'id': user.id, 'email': user.email, 'fullName': user.fullName, 'role': user.role},
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Login error: $e\n$stack');
      return Response(401, body: jsonEncode({'message': 'Authentication failed'}));
    }
  }

  Future<Response> social(Request req) async {
    try {
      final body = jsonDecode(await req.readAsString());

      final request = SocialRequestModel.fromJson(body);

      // Basic validation
      if (request.idToken.isEmpty || request.role.isEmpty) {
        return Response(400, body: jsonEncode({'message': 'idToken and role are required'}));
      }

      if (!['Tenant', 'Landowner', 'Manager', 'Artisan'].contains(request.role)) {
        return Response(400, body: jsonEncode({'message': 'Invalid role'}));
      }

      if (request.fullName.isEmpty) {
        return Response(400, body: jsonEncode({'message': 'fullName is required'}));
      }
      final user = await authRepository.socialLogin(req: request);

      if (user == null) {
        return Response(500, body: jsonEncode({'message': 'Social login failed'}));
      }

      final accessToken = jwtService.generateAccessToken(user.id, user.role);
      final refreshToken = jwtService.generateRefreshToken(user.id);

      await authRepository.saveRefreshToken(user.id, refreshToken);

      return Response.ok(
        jsonEncode({
          'accessToken': accessToken,
          'refreshToken': refreshToken,
          'message': "Login successfully",
          'user': {'id': user.id, 'email': user.email, 'fullName': user.fullName, 'role': user.role},
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Social login error: $e\n$stack');
      return Response(401, body: jsonEncode({'message': 'Invalid or expired token'}));
    }
  }
}
