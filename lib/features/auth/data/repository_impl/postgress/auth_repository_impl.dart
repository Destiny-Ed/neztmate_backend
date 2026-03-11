import 'package:neztmate_backend/features/auth/data/models/user_model.dart';
import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../../../infrastructure/database/postgres/postgres_service.dart';

class AuthRepositoryImpl implements AuthRepository {
  final PostgresService db;

  AuthRepositoryImpl(this.db);

  @override
  Future<UserModel?> getUserByEmail(String email) async {
    final result = await db.connection.execute(
      Sql.named('''
        SELECT * FROM users
        WHERE email = @email
        LIMIT 1
        '''),
      parameters: {"email": email},
    );

    if (result.isEmpty) return null;

    final row = result.first.toColumnMap();

    return UserModel(
      id: row["id"],
      email: row["email"],
      phone: row["phone"],
      fullName: row["full_name"],
      profilePhotoUrl: row["profile_photo_url"],
      role: row["role"],
      verifiedIdentity: row["verified_identity"] ?? false,
      verifiedEmployment: row["verified_employment"] ?? false,
      yearsExperience: row["years_experience"],
      primarySkill: row["primary_skill"],
      rating: (row["rating"] ?? 0).toDouble(),
    );
  }

  @override
  Future<UserModel?> getUserById(String id) async {
    final result = await db.connection.execute(
      Sql.named('''
        SELECT * FROM users
        WHERE id = @id
        LIMIT 1
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
      profilePhotoUrl: row["profile_photo_url"],
      role: row["role"],
    );
  }

  @override
  Future<UserModel> createUser(UserModel user, String passwordHash) async {
    final id = const Uuid().v4();

    await db.connection.execute(
      Sql.named('''
        INSERT INTO users (
          id,
          email,
          phone,
          password_hash,
          full_name,
          profile_photo_url,
          role
        )
        VALUES (
          @id,
          @email,
          @phone,
          @password,
          @name,
          @photo,
          @role
        )
        '''),
      parameters: {
        "id": id,
        "email": user.email,
        "phone": user.phone,
        "password": passwordHash,
        "name": user.fullName,
        "photo": user.profilePhotoUrl,
        "role": user.role,
      },
    );

    return user;
  }

  @override
  Future<void> saveRefreshToken(String userId, String token) async {
    await db.connection.execute(
      Sql.named('''
        INSERT INTO refresh_tokens (
          user_id,
          token
        )
        VALUES (
          @user_id,
          @token
        )
        '''),
      parameters: {"user_id": userId, "token": token},
    );
  }
}
