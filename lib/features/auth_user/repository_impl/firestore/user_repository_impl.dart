import 'package:neztmate_backend/features/auth_user/datasources/user_remote_datasource.dart';
import 'package:neztmate_backend/features/auth_user/models/user_model.dart';
import 'package:neztmate_backend/features/auth_user/repositories/user_repository.dart';

class UserRepositoryImpl implements UserRepository {
  final UserRemoteDataSource dataSource;

  UserRepositoryImpl(this.dataSource);

  @override
  Future<User?> getUserById(String id) => dataSource.getUserById(id);

  @override
  Future<User?> getUserByEmail(String email) => dataSource.getUserByEmail(email);

  @override
  Future<User> createUser(User user) => dataSource.createUser(user);

  @override
  Future<void> updateUser(User user) => dataSource.updateUser(user);

  @override
  Future<void> deleteUser(String id) => dataSource.deleteUser(id);
}
