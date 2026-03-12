import 'package:dart_firebase_admin/auth.dart';
import 'package:dart_firebase_admin/firestore.dart';
import 'package:neztmate_backend/core/services/auth/password_service.dart';
import 'package:neztmate_backend/features/auth/models/login_request_model.dart';
import 'package:neztmate_backend/features/auth/models/register_request_model.dart';
import 'package:neztmate_backend/features/auth/models/user_model.dart';
import 'package:neztmate_backend/features/auth/repositories/auth_repository.dart';
import 'package:neztmate_backend/features/auth/repositories/user_repository.dart';
import 'package:uuid/v4.dart';

class AuthRepositoryImpl implements AuthRepository {
  final UserRepository userRepository;
  final PasswordService passwordService;
  final Auth firebaseAuth;
  final Firestore firestore;

  AuthRepositoryImpl({
    required this.userRepository,
    required this.firebaseAuth,
    required this.passwordService,
    required this.firestore,
  });

  @override
  Future<User?> registerNewUser(RegisterRequest req) async {
    final hash = passwordService.hash(req.password);
    final id = UuidV4().generate();
    final user = User(
      id: id,
      email: req.email,
      fullName: req.fullName,
      role: req.role,
      passwordHash: hash,
      verifiedIdentity: false,
      verifiedEmployment: false,
      rating: 0.0,
      createdAt: DateTime.now(),
      lastLogin: DateTime.now(),
    );
    final createdUser = await userRepository.createUser(user);
    return createdUser;
  }

  @override
  Future<User?> loginUser(LoginRequest req) async {
    final user = await userRepository.getUserByEmail(req.email);
    if (user == null) return null;

    final isValid = passwordService.verify(req.password, user.passwordHash ?? '');
    if (!isValid) return null;
    // Optional: update last login
    await userRepository.updateUser(user.copyWith(lastLogin: DateTime.now()));
    return user;
  }

  @override
  Future<User?> socialLogin({required String idToken, required String role, String? fullName}) async {
    final decodedToken = await firebaseAuth.verifyIdToken(idToken);
    final email = decodedToken.email ?? '';

    var user = await userRepository.getUserByEmail(email);
    if (user != null) {
      await userRepository.updateUser(user.copyWith(lastLogin: DateTime.now()));

      return user;
    }

    final displayName = fullName ?? '';
    final photoUrl = decodedToken.picture;

    final id = UuidV4().generate();

    final newUser = User(
      id: id,
      email: email,
      fullName: displayName,
      role: role,
      profilePhotoUrl: photoUrl,
      phone: decodedToken.phoneNumber,
      verifiedIdentity: false,
      verifiedEmployment: false,
      rating: 0.0,
      createdAt: DateTime.now(),
      lastLogin: DateTime.now(),
      authProvider: decodedToken.firebase.signInProvider,
    );

    await userRepository.createUser(newUser);

    return newUser;
  }

  @override
  Future<bool?> logoutUser(String refreshToken) async {
    // For custom refresh tokens → you could delete or mark invalid
    // Here we just return success (real invalidation needs more logic)
    return true;
  }

  @override
  Future<void> saveRefreshToken(String userId, String token) async {
    await firestore.collection('refresh_tokens').add({
      'user_id': userId,
      'token': token,
      'created_at': DateTime.now().toIso8601String(),
      'expires_at': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
    });
  }
}
