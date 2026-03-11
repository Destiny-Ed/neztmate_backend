// ignore_for_file: prefer_conditional_assignment

import 'dart:convert';

import 'package:neztmate_backend/features/auth/data/models/login_request_model.dart';
import 'package:neztmate_backend/features/auth/data/models/register_request_model.dart';
import 'package:neztmate_backend/features/auth/data/models/user_model.dart';
import 'package:neztmate_backend/features/auth/domain/entities/user.dart';
import 'package:neztmate_backend/features/auth/domain/repositories/auth_repository.dart';
import 'package:neztmate_backend/features/auth/domain/usecases/login_user.dart';
import 'package:neztmate_backend/features/auth/domain/usecases/register_user.dart';
import 'package:neztmate_backend/infrastructure/auth/jwt_service.dart';
import 'package:neztmate_backend/infrastructure/auth/social_auth_service.dart';
import 'package:shelf/shelf.dart';

class AuthHandler {
  final RegisterUser registerUser;
  final LoginUser loginUser;
  final AuthRepository userRepository;
  final SocialAuthService socialAuthService;
  final JwtService jwtService;

  AuthHandler(
    this.registerUser,
    this.loginUser,
    this.jwtService, {
    required this.socialAuthService,
    required this.userRepository,
  });

  Future<Response> register(Request request) async {
    final body = await request.readAsString();
    final data = jsonDecode(body);

    final req = RegisterRequest.fromJson(data);

    final user = await registerUser.execute(req);

    final access = jwtService.generateAccessToken(user.id, user.role);
    final refresh = jwtService.generateRefreshToken(user.id);

    return Response.ok(
      jsonEncode({"access_token": access, "refresh_token": refresh, "user_id": user.id}),
      headers: {"Content-Type": "application/json"},
    );
  }

  Future<Response> login(Request request) async {
    final body = await request.readAsString();
    final data = jsonDecode(body);

    final req = LoginRequest.fromJson(data);

    final user = await loginUser.execute(req);

    final access = jwtService.generateAccessToken(user.id, user.role);
    final refresh = jwtService.generateRefreshToken(user.id);

    return Response.ok(
      jsonEncode({"access_token": access, "refresh_token": refresh}),
      headers: {"Content-Type": "application/json"},
    );
  }

  Future<Response> socialLogin(Request request) async {
    final body = await request.readAsString();
    final data = jsonDecode(body);

    final idToken = data["id_token"];
    final role = data["role"];

    /// verify firebase token
    final decoded = await socialAuthService.verifyFirebaseToken(idToken);

    final firebaseUid = decoded;

    /// check if user exists
    var user = await userRepository.getUserById(firebaseUid);

    if (user == null) {
      final userRecord = await socialAuthService.getFirebaseUser(firebaseUid);

      if (userRecord.email == null) {
        return Response.notFound({"error": "Social auth failed"});
      }

      user = await userRepository.createUser(
        UserModel(id: decoded, email: userRecord.email!, fullName: userRecord.displayName!, role: role),
        "no hash",
      );
    }

    /// issue jwt
    final accessToken = jwtService.generateAccessToken(user.id, user.role);
    final refreshToken = jwtService.generateRefreshToken(user.id);

    return Response.ok(
      jsonEncode({"access_token": accessToken, "refresh_token": refreshToken, "user": user.toJson()}),
      headers: {"Content-Type": "application/json"},
    );
  }
}
