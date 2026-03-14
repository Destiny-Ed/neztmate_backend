 
import 'package:dart_firebase_admin/auth.dart';
import 'package:dart_firebase_admin/firestore.dart';
import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/core/services/auth/password_service.dart';
import 'package:neztmate_backend/features/auth_user/models/login_request_model.dart';
import 'package:neztmate_backend/features/auth_user/models/register_request_model.dart';
import 'package:neztmate_backend/features/auth_user/models/social_request_model.dart';
import 'package:neztmate_backend/features/auth_user/models/user_model.dart';
import 'package:neztmate_backend/features/auth_user/repositories/auth_repository.dart';
import 'package:neztmate_backend/features/auth_user/repositories/user_repository.dart';
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
  Future<User> registerNewUser(RegisterRequest req) async {
    try {
      await userRepository.getUserByEmail(req.email);
      throw EmailAlreadyExistsException(req.email);
    } on NotFoundException {
      // good — user does NOT exist → proceed to create
    }

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
      fcmToken: req.fcmToken,
      platform: req.platform,
      country: req.country,
    );

    final created = await userRepository.createUser(user);
    return created;
  }

  @override
  Future<User> loginUser(LoginRequest req) async {
    final user = await userRepository.getUserByEmail(req.email);

    final isValid = passwordService.verify(req.password, user.passwordHash ?? '');
    if (!isValid) {
      throw InvalidCredentialsException();
    }

    await userRepository.updateUser(user.copyWith(lastLogin: DateTime.now()));
    return user;
  }

  @override
  Future<User> socialLogin({required SocialRequestModel req}) async {
    final decodedToken = await firebaseAuth.verifyIdToken(req.idToken);
    final email = decodedToken.email ?? '';

    print(decodedToken.email.toString());

    try {
      final existing = await userRepository.getUserByEmail(email);
      // exists → update last login & return
      await userRepository.updateUser(existing.copyWith(lastLogin: DateTime.now()));
      return existing;
    } on NotFoundException {
      // does NOT exist → create new
    }

    if (req.role.isEmpty || req.role == 'none') {
      throw ValidationException('User does not exist. Please register a new account');
    }

    if (req.role.isEmpty || !['tenant', 'landowner', 'manager', 'artisan'].contains(req.role)) {
      throw InvalidRoleException(req.role);
    }

    final displayName = req.fullName;
    if (displayName.isEmpty) {
      throw ValidationException('fullName is required for first-time social registration');
    }

    if (req.country.isEmpty) {
      throw ValidationException('User country is required ');
    }

    if (req.platform.isEmpty) {
      throw ValidationException('Platform type of device is required ');
    }

    final id = UuidV4().generate();

    final newUser = User(
      id: id,
      email: email,
      fullName: displayName,
      role: req.role,
      profilePhotoUrl: decodedToken.picture,
      phone: decodedToken.phoneNumber,
      verifiedIdentity: false,
      verifiedEmployment: false,
      rating: 0.0,
      createdAt: DateTime.now(),
      lastLogin: DateTime.now(),
      authProvider: decodedToken.firebase.signInProvider,
      fcmToken: req.fcmToken,
      platform: req.platform,
      country: req.country,
    );

    await userRepository.createUser(newUser);
    return newUser;
  }

  @override
  Future<bool> logoutUser(String refreshToken) async {
    // For custom refresh tokens → you could delete or mark invalid
    // Here we just return success (real invalidation needs more logic)
    return true;
  }

  @override
  Future<void> saveRefreshToken(String userId, String token) async {
    await firestore.collection('refresh_tokens').add({
      'userId': userId,
      'token': token,
      'createdAt': DateTime.now().toIso8601String(),
      'expiresAt': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
    });
  }
}
