import 'package:neztmate_backend/features/auth/data/models/user_model.dart';
 

abstract class AuthRepository {
  Future<UserModel?> getUserByEmail(String email);

  Future<UserModel?> getUserById(String id);

  Future<UserModel> createUser(UserModel user, String passwordHash);

  Future<void> saveRefreshToken(String userId, String token);
}
