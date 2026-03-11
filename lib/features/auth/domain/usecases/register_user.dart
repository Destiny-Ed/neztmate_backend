import 'package:neztmate_backend/features/auth/data/models/register_request_model.dart';
import 'package:neztmate_backend/features/auth/data/models/user_model.dart';
import 'package:neztmate_backend/features/auth/domain/entities/user.dart';
import 'package:neztmate_backend/features/auth/domain/repositories/auth_repository.dart';
import 'package:neztmate_backend/infrastructure/auth/password_service.dart';
import 'package:uuid/uuid.dart';

class RegisterUser {
  final AuthRepository repository;
  final PasswordService passwordService;

  RegisterUser(this.repository, this.passwordService);

  Future<User> execute(RegisterRequest request) async {
    final existing = await repository.getUserByEmail(request.email);

    if (existing != null) {
      throw Exception("User already exists");
    }

    final hash = passwordService.hash(request.password);

    final user = UserModel(
      id: const Uuid().v4(),
      email: request.email,
      fullName: request.fullName,
      role: request.role,
    );

    return repository.createUser(user, hash);
  }
}
