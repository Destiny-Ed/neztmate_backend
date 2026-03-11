import 'package:neztmate_backend/features/auth/data/models/user_model.dart';

abstract class UserRepository {
  Future<UserModel?> getUser(String id);

  Future<List<UserModel>> getUsers();

  Future<void> updateUser(UserModel user);

  Future<void> deleteUser(String id);
}
