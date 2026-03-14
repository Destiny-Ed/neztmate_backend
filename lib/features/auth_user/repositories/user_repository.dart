import 'package:neztmate_backend/features/auth_user/models/user_model.dart';
import 'package:neztmate_backend/features/auth_user/models/user_stats_model.dart';

abstract class UserRepository {
  /// Throws NotFoundException if not found
  Future<User> getUserById(String id);

  /// Throws NotFoundException if not found
  Future<User> getUserByEmail(String email);

  Future<User> createUser(User user);

  Future<void> updateUser(User user);

  Future<void> deleteUser(String id);

  Future<UserStats> getUserStats(String userId, String role);
}
