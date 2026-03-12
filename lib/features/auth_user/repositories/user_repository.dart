import 'package:neztmate_backend/features/auth_user/models/user_model.dart';

abstract class UserRepository {
  Future<User?> getUserById(String id);
  Future<User?> getUserByEmail(String email);
  Future<User> createUser(User user);
  Future<void> updateUser(User user);
  Future<void> deleteUser(String uid);
}
