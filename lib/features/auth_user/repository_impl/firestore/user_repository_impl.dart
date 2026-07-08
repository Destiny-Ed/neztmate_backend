import 'package:neztmate_backend/features/auth_user/datasources/user_remote_datasource.dart';
import 'package:neztmate_backend/features/auth_user/models/user_model.dart';
import 'package:neztmate_backend/features/auth_user/models/user_stats_model.dart';
import 'package:neztmate_backend/features/auth_user/repositories/user_repository.dart';

class UserRepositoryImpl implements UserRepository {
  final UserRemoteDataSource dataSource;

  UserRepositoryImpl(this.dataSource);

  @override
  Future<User> getUserById(String id) async {
    return await dataSource.getUserById(id);
  }

  @override
  Future<User> getUserByEmail(String email) async {
    return await dataSource.getUserByEmail(email);
  }

  @override
  Future<User> createUser(User user) async {
    return await dataSource.createUser(user);
  }

  @override
  Future<void> updateUser(User user) async {
    await dataSource.updateUser(user);
  }

  @override
  Future<void> deleteUser(String id) async {
    await dataSource.deleteUser(id);
  }

  @override
  Future<UserStatsModel> getUserStats(String userId, String role) async {
    return await dataSource.getUserStats(userId, role);
  }

  @override
  Future<User?> getUserByVerificationId(String verificationId) =>
      dataSource.getUserByVerificationId(verificationId);

  @override
  Future<void> updateUserVerification({
    required String userId,
    required String verificationId,
    required String provider,
    required String status,
  }) async {
    final user = await dataSource.getUserById(userId);

    final updatedUser = user.copyWith(
      verificationId: verificationId,
      verificationProvider: provider,
      verificationStatus: status,
      identityVerifiedAt: status == 'approved' ? DateTime.now() : user.identityVerifiedAt,
      verifiedIdentity: status == 'approved',
    );

    await dataSource.updateUser(updatedUser);
  }
}
