import 'dart:math';

import 'package:dart_firebase_admin/auth.dart';
import 'package:dart_firebase_admin/firestore.dart';
import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/core/services/auth/password_service.dart';
import 'package:neztmate_backend/core/services/email/resend_email_service.dart';
import 'package:neztmate_backend/features/auth_user/models/login_request_model.dart';
import 'package:neztmate_backend/features/auth_user/models/register_request_model.dart';
import 'package:neztmate_backend/features/auth_user/models/social_request_model.dart';
import 'package:neztmate_backend/features/auth_user/models/user_model.dart';
import 'package:neztmate_backend/features/auth_user/repositories/auth_repository.dart';
import 'package:neztmate_backend/features/auth_user/repositories/user_repository.dart';
import 'package:neztmate_backend/features/partners/repository/partner_repository.dart';
import 'package:uuid/v4.dart';

class AuthRepositoryImpl implements AuthRepository {
  final UserRepository userRepository;
  final PartnerRepository partnerRepository;
  final PasswordService passwordService;
  final Auth firebaseAuth;
  final Firestore firestore;
  final ResendEmailService emailService;

  AuthRepositoryImpl({
    required this.userRepository,
    required this.partnerRepository,
    required this.firebaseAuth,
    required this.passwordService,
    required this.firestore,
    required this.emailService,
  });

  CollectionReference get _otps => firestore.collection('email_verifications');
  CollectionReference get _passwordResets => firestore.collection('password_resets');

  @override
  Future<User> registerNewUser(RegisterRequest req) async {
    try {
      await userRepository.getUserByEmail(req.email);
      throw EmailAlreadyExistsException(req.email);
    } on NotFoundException {
      // proceed
    }

    final hash = passwordService.hash(req.password);
    final id = UuidV4().generate();

    final user = User(
      id: id,
      email: req.email.toLowerCase().trim(),
      fullName: req.fullName,
      role: req.role,
      passwordHash: hash,
      partnerId: req.partnerSlug,
      verifiedIdentity: false,
      verifiedEmployment: false,
      emailVerified: false,
      rating: 0.0,
      createdAt: DateTime.now(),
      lastLogin: DateTime.now(),
      fcmToken: req.fcmToken,
      platform: req.platform,
      country: req.country,
      primaryRole: req.role,
    );

    return await userRepository.createUser(user);
  }

  @override
  Future<User> loginUser(LoginRequest req) async {
    final user = await userRepository.getUserByEmail(req.email.toLowerCase().trim());
    final isValid = passwordService.verify(req.password, user.passwordHash ?? '');
    if (!isValid) throw InvalidCredentialsException();
    await userRepository.updateUser(user.copyWith(lastLogin: DateTime.now()));
    return user;
  }

  @override
  Future<User> socialLogin({required SocialRequestModel req}) async {
    final decodedToken = await firebaseAuth.verifyIdToken(req.idToken);
    final email = (decodedToken.email ?? '').toLowerCase();

    try {
      final existing = await userRepository.getUserByEmail(email);
      await userRepository.updateUser(existing.copyWith(lastLogin: DateTime.now()));
      return existing;
    } on NotFoundException {
      // create
    }

    if (req.role.isEmpty || req.role == 'none') {
      throw ValidationException('User does not exist. Please register a new account');
    }
    if (!['tenant', 'landowner', 'manager', 'artisan'].contains(req.role)) {
      throw InvalidRoleException(req.role);
    }
    if (req.fullName.isEmpty) {
      throw ValidationException('fullName is required for first-time social registration');
    }
    if (req.country.isEmpty) throw ValidationException('User country is required ');
    if (req.platform.isEmpty) throw ValidationException('Platform type of device is required ');

    final partnerSlug = req.partnerSlug as String?;
    if (partnerSlug == null || partnerSlug.isEmpty) {
      throw ValidationException('partner slug header is required');
    }

    final partner = await partnerRepository.getPartnerBySlug(partnerSlug);
    if (partner == null) throw NotFoundException('Partner', partnerSlug);

    final id = UuidV4().generate();
    final newUser = User(
      id: id,
      email: email,
      fullName: req.fullName,
      role: req.role,
      profilePhotoUrl: decodedToken.picture,
      phone: decodedToken.phoneNumber,
      partnerId: partner.id,
      verifiedIdentity: false,
      verifiedEmployment: false,
      emailVerified: true,
      rating: 0.0,
      createdAt: DateTime.now(),
      lastLogin: DateTime.now(),
      authProvider: decodedToken.firebase.signInProvider,
      fcmToken: req.fcmToken,
      platform: req.platform,
      country: req.country,
      primaryRole: req.role,
    );

    final created = await userRepository.createUser(newUser);
    emailService
        .sendWelcomeEmail(to: created.email, fullName: created.fullName, role: created.role)
        .catchError((e) => print('[AuthRepository] welcome email error: $e'));
    return newUser;
  }

  @override
  Future<bool> logoutUser(String refreshToken) async => true;

  @override
  Future<void> saveRefreshToken(String userId, String token) async {
    await firestore.collection('refresh_tokens').add({
      'userId': userId,
      'token': token,
      'createdAt': DateTime.now().toIso8601String(),
      'expiresAt': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
    });
  }

  @override
  Future<void> saveEmailOtp({
    required String email,
    required String code,
    required DateTime expiresAt,
  }) async {
    final key = email.toLowerCase().trim();
    await _otps.doc(key).set({
      'email': key,
      'code': code,
      'expiresAt': expiresAt.toIso8601String(),
      'createdAt': DateTime.now().toIso8601String(),
      'attempts': 0,
    });
  }

  @override
  Future<bool> verifyEmailOtp({required String email, required String code}) async {
    final key = email.toLowerCase().trim();
    final doc = await _otps.doc(key).get();
    if (!doc.exists) return false;

    final data = doc.data() as Map<String, dynamic>;
    final storedCode = (data['code'] as String?) ?? '';
    final expiresAt = DateTime.tryParse((data['expiresAt'] as String?) ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final attempts = (data['attempts'] as int?) ?? 0;

    if (DateTime.now().isAfter(expiresAt)) {
      await _otps.doc(key).delete();
      return false;
    }
    if (attempts >= 5) {
      await _otps.doc(key).delete();
      return false;
    }
    if (storedCode != code.trim()) {
      await _otps.doc(key).update({'attempts': attempts + 1});
      return false;
    }

    await _otps.doc(key).delete();
    return true;
  }

  @override
  Future<void> markEmailVerified(String email) async {
    final user = await userRepository.getUserByEmail(email.toLowerCase().trim());
    await userRepository.updateUser(user.copyWith(emailVerified: true));
  }

  @override
  Future<void> savePasswordResetOtp({
    required String email,
    required String code,
    required DateTime expiresAt,
  }) async {
    final key = email.toLowerCase().trim();
    await _passwordResets.doc(key).set({
      'email': key,
      'code': code,
      'expiresAt': expiresAt.toIso8601String(),
      'createdAt': DateTime.now().toIso8601String(),
      'attempts': 0,
    });
  }

  @override
  Future<bool> verifyPasswordResetOtp({required String email, required String code}) async {
    final key = email.toLowerCase().trim();
    final doc = await _passwordResets.doc(key).get();
    if (!doc.exists) return false;

    final data = doc.data() as Map<String, dynamic>;
    final storedCode = (data['code'] as String?) ?? '';
    final expiresAt = DateTime.tryParse((data['expiresAt'] as String?) ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final attempts = (data['attempts'] as int?) ?? 0;

    if (DateTime.now().isAfter(expiresAt)) {
      await _passwordResets.doc(key).delete();
      return false;
    }
    if (attempts >= 5) {
      await _passwordResets.doc(key).delete();
      return false;
    }
    if (storedCode != code.trim()) {
      await _passwordResets.doc(key).update({'attempts': attempts + 1});
      return false;
    }

    await _passwordResets.doc(key).delete();
    return true;
  }

  @override
  Future<void> updatePasswordByEmail({equired String email, required String passwordHash}) async {
    final user = await userRepository.getUserByEmail(email.toLowerCase().trim());
    await userRepository.updateUser(user.copyWith(passwordHash: passwordHash));
  }

  static String generateOtp() {
    final r = Random.secure();
    return List.generate(6, (_) => r.nextInt(10)).join();
  }
}
