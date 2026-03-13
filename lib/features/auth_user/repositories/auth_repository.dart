import 'package:neztmate_backend/features/auth_user/models/login_request_model.dart';
import 'package:neztmate_backend/features/auth_user/models/register_request_model.dart';
import 'package:neztmate_backend/features/auth_user/models/social_request_model.dart';
import 'package:neztmate_backend/features/auth_user/models/user_model.dart';

abstract class AuthRepository {
  /// Email + password registration
  Future<User?> registerNewUser(RegisterRequest req);

  /// Email + password login
  Future<User?> loginUser(LoginRequest req);

  /// Social login (Google, Apple, etc.) via Firebase ID token
  Future<User?> socialLogin({required SocialRequestModel req});

  Future<bool?> logoutUser(String refreshToken);

  Future<void> saveRefreshToken(String userId, String token);
}
