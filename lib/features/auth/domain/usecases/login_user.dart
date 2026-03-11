import 'package:neztmate_backend/features/auth/data/models/login_request_model.dart';
import 'package:neztmate_backend/features/auth/domain/entities/user.dart';
import 'package:neztmate_backend/features/auth/domain/repositories/auth_repository.dart';
import 'package:neztmate_backend/infrastructure/auth/password_service.dart';

class LoginUser {
  final AuthRepository repository;
  final PasswordService passwordService;

  LoginUser(this.repository, this.passwordService);

  Future<User> execute(LoginRequest request) async {
    final user = await repository.getUserByEmail(request.email);

    if (user == null) {
      throw Exception("Invalid credentials");
    }

    final valid = passwordService.verify(request.password, user.passwordHash);

    if (!valid) {
      throw Exception("Invalid credentials");
    }

    return user;
  }
}
