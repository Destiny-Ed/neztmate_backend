import 'package:neztmate_backend/features/auth/data/models/user_model.dart';

abstract class Database {
  Future<UserModel?> findUserByEmail(String email);
  Future<void> createUser(UserModel user);
}
