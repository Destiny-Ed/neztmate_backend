import 'package:neztmate_backend/features/auth/data/models/user_model.dart';
import 'package:neztmate_backend/features/auth/domain/repositories/user_repository.dart';
import 'package:neztmate_backend/infrastructure/database/postgres/postgres_service.dart';
import 'package:postgres/postgres.dart';

class UserRepositoryImpl implements UserRepository {
  final PostgresService db;

  UserRepositoryImpl(this.db);

  @override
  Future<UserModel?> getUser(String id) async {
    final result = await db.connection.execute(
      Sql.named('''
        SELECT * FROM users
        WHERE id = @id
        '''),
      parameters: {"id": id},
    );

    if (result.isEmpty) return null;

    final row = result.first.toColumnMap();

    return UserModel(
      id: row["id"],
      email: row["email"],
      phone: row["phone"],
      fullName: row["full_name"],
      role: row["role"],
    );
  }

  @override
  Future<List<UserModel>> getUsers() async {
    final result = await db.connection.execute('SELECT * FROM users');

    return result.map((row) {
      final map = row.toColumnMap();

      return UserModel(
        id: map["id"],
        email: map["email"],
        phone: map["phone"],
        fullName: map["full_name"],
        role: map["role"],
      );
    }).toList();
  }

  @override
  Future<void> updateUser(UserModel user) async {
    await db.connection.execute(
      Sql.named('''
        UPDATE users
        SET
          full_name = @name,
          phone = @phone,
          profile_photo_url = @photo
        WHERE id = @id
        '''),
      parameters: {"id": user.id, "name": user.fullName, "phone": user.phone, "photo": user.profilePhotoUrl},
    );
  }

  @override
  Future<void> deleteUser(String id) async {
    await db.connection.execute(
      Sql.named('''
        DELETE FROM users
        WHERE id = @id
        '''),
      parameters: {"id": id},
    );
  }
}
