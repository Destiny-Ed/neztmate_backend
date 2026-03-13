import 'package:neztmate_backend/features/auth_user/models/login_request_model.dart';
import 'package:neztmate_backend/features/auth_user/models/register_request_model.dart';
import 'package:neztmate_backend/features/auth_user/models/social_request_model.dart';
import 'package:neztmate_backend/features/auth_user/models/user_model.dart';

abstract class AuthRepository {
  Future<User> registerNewUser(RegisterRequest req);
  Future<User> loginUser(LoginRequest req);
  Future<User> socialLogin({required SocialRequestModel req});
  Future<void> saveRefreshToken(String userId, String token);
  Future<bool> logoutUser(String refreshToken);
}
