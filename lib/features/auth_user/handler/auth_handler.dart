import 'dart:convert';
import 'package:dart_firebase_admin/auth.dart';
import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/core/services/email/resend_email_service.dart';
import 'package:neztmate_backend/core/services/subscription/partner_access_service.dart';
import 'package:neztmate_backend/features/partners/repository/partner_repository.dart';
import 'package:shelf/shelf.dart';
import 'package:neztmate_backend/core/services/auth/jwt_service.dart';
import 'package:neztmate_backend/core/services/auth/password_service.dart';
import 'package:neztmate_backend/features/auth_user/models/login_request_model.dart';
import 'package:neztmate_backend/features/auth_user/models/register_request_model.dart';
import 'package:neztmate_backend/features/auth_user/models/social_request_model.dart';
import 'package:neztmate_backend/features/auth_user/repositories/auth_repository.dart';
import 'package:neztmate_backend/features/auth_user/repositories/user_repository.dart';
import 'package:neztmate_backend/features/auth_user/repository_impl/firestore/auth_repository_impl.dart';

class AuthHandler {
  final AuthRepository authRepository;
  final UserRepository userRepository;
  final PasswordService passwordService;
  final JwtService jwtService;
  final PartnerRepository partnerRepository;
  final Auth firebaseAuth;
  final PartnerAccessService partnerAccess;
  final ResendEmailService emailService;

  AuthHandler(
    this.authRepository,
    this.passwordService,
    this.jwtService,
    this.userRepository,
    this.partnerRepository,
    this.firebaseAuth,
    this.partnerAccess,
    this.emailService,
  );

  Future<Response> register(Request req) async {
    try {
      final body = jsonDecode(await req.readAsString());
      final request = RegisterRequest.fromJson(body);

      if (request.email.isEmpty || !request.email.contains('@')) {
        return badRequest('Invalid email format');
      }
      if (request.password.length < 6) {
        return badRequest('Password must be at least 6 characters');
      }
      if (!['tenant', 'landowner', 'manager', 'artisan'].contains(request.role)) {
        throw InvalidRoleException(request.role);
      }
      if (request.country.isEmpty) {
        throw ValidationException('User country is required ');
      }
      if (request.platform.isEmpty) {
        throw ValidationException('Platform type of device is required ');
      }
      if (request.fcmToken.isEmpty) {
        throw ValidationException('FcmToken is required ');
      }

      final partnerSlug = body['partnerSlug'] as String? ?? req.headers['x-partner-slug'];
      if (partnerSlug == null || partnerSlug.isEmpty) {
        throw ValidationException('partner slug header is required');
      }

      final partner = await partnerRepository.getPartnerBySlug(partnerSlug);
      if (partner == null) {
        throw NotFoundException('Partner', partnerSlug);
      }

      try {
        await partnerAccess.assertAppEnabled(partner.id);
        if (request.role.toLowerCase() == 'landowner') {
          await partnerAccess.assertCanRegisterLandowner(partner.id);
        }
      } on PartnerAccessException catch (e) {
        return e.toResponse();
      }

      final created = await authRepository.registerNewUser(request.copyWith(partnerSlug: partner.id));

      final accessToken = jwtService.generateAccessToken(
        created.id,
        created.role,
        partnerId: created.partnerId,
      );
      final refreshToken = jwtService.generateRefreshToken(created.id);
      await authRepository.saveRefreshToken(created.id, refreshToken);

      try {
        await _issueAndSendOtp(email: created.email, fullName: created.fullName);
      } catch (e) {
        print('[AuthHandler] OTP send error on register: $e');
      }

      emailService
          .sendWelcomeEmail(
            to: created.email,
            fullName: created.fullName,
            role: created.role,
          )
          .catchError((e) => print('[AuthHandler] welcome email error: $e'));

      return Response.ok(
        jsonEncode({
          'accessToken': accessToken,
          'refreshToken': refreshToken,
          'emailVerified': false,
          'user': {
            'id': created.id,
            'email': created.email,
            'fullName': created.fullName,
            'role': created.role,
            'emailVerified': false,
          },
          'message': 'Account created successfully. Please verify your email with the code we sent.',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } on AppException catch (e, stack) {
      return handleAppException(e, stack);
    } catch (e, stack) {
      return handleAppException(e, stack);
    }
  }

  Future<Response> login(Request req) async {
    try {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final request = LoginRequest.fromJson(body);

      if (request.email.isEmpty || !request.email.contains('@')) {
        return badRequest('Invalid email format');
      }
      if (request.password.length < 6) {
        return badRequest('Password must be at least 6 characters');
      }
      if (request.fcmToken.isEmpty) {
        throw ValidationException('Fcm Token is required');
      }

      final loginAs = (body['loginAs'] as String?)?.toLowerCase().trim();
      final isPlatformLogin = loginAs == 'platform_admin' || loginAs == 'super_admin';
      final rawPartnerKey =
          (body['partnerId'] as String?)?.trim() ?? (body['partnerSlug'] as String?)?.trim();

      final user = await authRepository.loginUser(request);

      final roleLower = user.role.toLowerCase();
      final rolesLower = user.roles.map((r) => r.toLowerCase()).toList();
      final userIsPlatform = roleLower == 'platform_admin' ||
          roleLower == 'super_admin' ||
          rolesLower.contains('platform_admin') ||
          rolesLower.contains('super_admin');

      if (isPlatformLogin) {
        if (!userIsPlatform) {
          return Response(403, body: jsonEncode({'message': 'This account is not a platform admin'}));
        }
        final accessToken = jwtService.generateAccessToken(user.id, 'platform_admin');
        final refreshToken = jwtService.generateRefreshToken(user.id);
        await authRepository.saveRefreshToken(user.id, refreshToken);
        return Response.ok(
          jsonEncode({
            'accessToken': accessToken,
            'refreshToken': refreshToken,
            'emailVerified': user.emailVerified,
            'user': {
              'id': user.id,
              'email': user.email,
              'fullName': user.fullName,
              'role': 'platform_admin',
              'roles': user.roles,
              'emailVerified': user.emailVerified,
            },
            'message': 'Login successful',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final needsPartner = roleLower == 'partner_admin' || roleLower == 'admin' || rawPartnerKey != null;
      if (needsPartner && (rawPartnerKey == null || rawPartnerKey.isEmpty)) {
        throw ValidationException('partnerId or partnerSlug is required');
      }

      String? resolvedPartnerId = user.partnerId;
      String? partnerSlugOut;
      String? partnerNameOut;

      if (rawPartnerKey != null && rawPartnerKey.isNotEmpty) {
        var partner = await partnerRepository.getPartnerById(rawPartnerKey);
        partner ??= await partnerRepository.getPartnerBySlug(rawPartnerKey);
        if (partner == null) throw NotFoundException('Partner', rawPartnerKey);
        if (partner.isActive == false) throw ValidationException('This workspace is inactive');
        try {
          await partnerAccess.assertAppEnabled(partner.id);
        } on PartnerAccessException catch (e) {
          return e.toResponse();
        }
        resolvedPartnerId = partner.id;
        partnerSlugOut = partner.slug;
        partnerNameOut = partner.name;
        if (user.partnerId == null || user.partnerId.isEmpty) {
          throw ValidationException('This account is not linked to any workspace');
        }
        if (user.partnerId != partner.id) {
          return Response(403, body: jsonEncode({'message': 'This account does not belong to the selected workspace'}));
        }
      } else if (user.partnerId != null && user.partnerId.isNotEmpty) {
        final partner = await partnerRepository.getPartnerById(user.partnerId);
        if (partner != null) {
          try {
            await partnerAccess.assertAppEnabled(partner.id);
          } on PartnerAccessException catch (e) {
            return e.toResponse();
          }
          resolvedPartnerId = partner.id;
          partnerSlugOut = partner.slug;
          partnerNameOut = partner.name;
        }
      }

      if ((roleLower == 'partner_admin' || roleLower == 'admin') &&
          (resolvedPartnerId == null || resolvedPartnerId.isEmpty)) {
        throw ValidationException('Partner workspace could not be resolved');
      }

      final accessToken = jwtService.generateAccessToken(user.id, user.role, partnerId: resolvedPartnerId);
      final refreshToken = jwtService.generateRefreshToken(user.id);
      await authRepository.saveRefreshToken(user.id, refreshToken);

      return Response.ok(
        jsonEncode({
          'accessToken': accessToken,
          'refreshToken': refreshToken,
          'partnerId': resolvedPartnerId,
          'emailVerified': user.emailVerified,
          'user': {
            'id': user.id,
            'email': user.email,
            'fullName': user.fullName,
            'role': user.role,
            'roles': user.roles,
            'partnerId': resolvedPartnerId,
            'partnerSlug': partnerSlugOut,
            'partnerName': partnerNameOut,
            'emailVerified': user.emailVerified,
          },
          'message': 'Login successful',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } on AppException catch (e, stack) {
      return handleAppException(e, stack);
    } catch (e, stack) {
      return handleAppException(e, stack);
    }
  }

  Future<Response> social(Request req) async {
    try {
      final body = jsonDecode(await req.readAsString());
      final request = SocialRequestModel.fromJson(body);
      if (request.idToken.isEmpty) return badRequest('idToken is required');
      if (request.fcmToken.isEmpty) throw ValidationException('Fcm Token is required ');

      final partnerSlug = req.headers['x-partner-slug'] ?? request.partnerSlug as String?;
      if (partnerSlug == null || partnerSlug.isEmpty) {
        throw ValidationException('partner slug header is required');
      }

      final partner = await partnerRepository.getPartnerBySlug(partnerSlug);
      if (partner == null) throw NotFoundException('Partner', partnerSlug);
      try {
        await partnerAccess.assertAppEnabled(partner.id);
      } on PartnerAccessException catch (e) {
        return e.toResponse();
      }

      final user = await authRepository.socialLogin(req: request.copyWith(partnerSlug: partnerSlug));
      final accessToken = jwtService.generateAccessToken(user.id, user.role, partnerId: user.partnerId);
      final refreshToken = jwtService.generateRefreshToken(user.id);
      await authRepository.saveRefreshToken(user.id, refreshToken);

      return Response.ok(
        jsonEncode({
          'accessToken': accessToken,
          'refreshToken': refreshToken,
          'emailVerified': user.emailVerified,
          'user': {
            'id': user.id,
            'email': user.email,
            'fullName': user.fullName,
            'role': user.role,
            'profilePhotoUrl': user.profilePhotoUrl ?? '',
            'emailVerified': user.emailVerified,
          },
          'message': 'Social login successful',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } on AppException catch (e, stack) {
      return handleAppException(e, stack);
    } catch (e, stack) {
      return handleAppException(e, stack);
    }
  }

  Future<Response> platformGoogleLogin(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final idToken = (body['idToken'] as String?)?.trim() ?? '';
      final fcmToken = (body['fcmToken'] as String?)?.trim() ?? '';
      if (idToken.isEmpty) return Response(400, body: jsonEncode({'message': 'idToken is required'}));
      if (fcmToken.isEmpty) return Response(400, body: jsonEncode({'message': 'fcmToken is required'}));

      final decoded = await firebaseAuth.verifyIdToken(idToken);
      final email = (decoded.email ?? '').toLowerCase();
      if (email.isEmpty) {
        return Response(401, body: jsonEncode({'message': 'Email missing on Google account'}));
      }

      final user = await userRepository.getUserByEmail(email);
      final role = user.role.toLowerCase();
      final isPlatform = role == 'platform_admin' ||
          role == 'super_admin' ||
          (user.roles.map((r) => r.toLowerCase()).contains('platform_admin'));
      if (!isPlatform) {
        return Response(403, body: jsonEncode({'message': 'Google sign-in is only allowed for platform admins'}));
      }

      final accessToken = jwtService.generateAccessToken(user.id, 'platform_admin');
      final refreshToken = jwtService.generateRefreshToken(user.id);
      await authRepository.saveRefreshToken(user.id, refreshToken);
      return Response.ok(
        jsonEncode({
          'accessToken': accessToken,
          'refreshToken': refreshToken,
          'message': 'Login successfully',
          'user': {'id': user.id, 'email': user.email, 'fullName': user.fullName, 'role': 'platform_admin'},
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, s) {
      print('platformGoogleLogin: $e\n$s');
      return Response(401, body: jsonEncode({'message': 'Invalid or expired Google token'}));
    }
  }

  Future<Response> changePassword(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      if (userId == null) return Response(401, body: jsonEncode({'message': 'Unauthorized'}));

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final currentPassword = (body['currentPassword'] as String?)?.trim() ?? '';
      final newPassword = (body['newPassword'] as String?)?.trim() ?? '';
      if (currentPassword.isEmpty || newPassword.isEmpty) {
        return Response(400, body: jsonEncode({'message': 'currentPassword and newPassword are required'}));
      }
      if (newPassword.length < 8) {
        return Response(400, body: jsonEncode({'message': 'New password must be at least 8 characters'}));
      }
      if (currentPassword == newPassword) {
        return Response(400, body: jsonEncode({'message': 'New password must be different from current password'}));
      }

      final user = await userRepository.getUserById(userId);
      final hash = user.passwordHash ?? '';
      if (hash.isEmpty) {
        return Response(400, body: jsonEncode({
          'message': 'This account uses social login only. Set a password via a different flow or contact support.',
        }));
      }
      if (!passwordService.verify(currentPassword, hash)) {
        return Response(400, body: jsonEncode({'message': 'Current password is incorrect'}));
      }

      final newHash = passwordService.hash(newPassword);
      await userRepository.updateUser(user.copyWith(passwordHash: newHash));
      return Response.ok(
        jsonEncode({'message': 'Password updated successfully'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, s) {
      print('changePassword: $e\n$s');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to change password'}));
    }
  }

  /// POST /auth/verify-email  Body: { email, code }
  Future<Response> verifyEmail(Request req) async {
    try {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final email = (body['email'] as String?)?.trim().toLowerCase() ?? '';
      final code = (body['code'] as String?)?.trim() ?? '';

      if (email.isEmpty || !email.contains('@')) {
        return badRequest('Valid email is required');
      }
      if (code.length != 6) {
        return badRequest('A valid 6-digit verification code is required');
      }

      final user = await userRepository.getUserByEmail(email);
      if (user.emailVerified) {
        return Response.ok(
          jsonEncode({'message': 'Email is already verified', 'emailVerified': true}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final ok = await authRepository.verifyEmailOtp(email: email, code: code);
      if (!ok) {
        return Response(400, body: jsonEncode({'message': 'Invalid or expired verification code'}));
      }

      await authRepository.markEmailVerified(email);
      return Response.ok(
        jsonEncode({'message': 'Email verified successfully', 'emailVerified': true}),
        headers: {'Content-Type': 'application/json'},
      );
    } on AppException catch (e, stack) {
      return handleAppException(e, stack);
    } catch (e, stack) {
      return handleAppException(e, stack);
    }
  }

  /// POST /auth/resend-verification  Body: { email }
  Future<Response> resendVerification(Request req) async {
    try {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final email = (body['email'] as String?)?.trim().toLowerCase() ?? '';
      if (email.isEmpty || !email.contains('@')) {
        return badRequest('Valid email is required');
      }

      final user = await userRepository.getUserByEmail(email);
      if (user.emailVerified) {
        return Response.ok(
          jsonEncode({'message': 'Email is already verified', 'emailVerified': true}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      await _issueAndSendOtp(email: user.email, fullName: user.fullName);
      return Response.ok(
        jsonEncode({'message': 'Verification code sent to $email'}),
        headers: {'Content-Type': 'application/json'},
      );
    } on AppException catch (e, stack) {
      return handleAppException(e, stack);
    } catch (e, stack) {
      return handleAppException(e, stack);
    }
  }

  /// POST /auth/forgot-password  Body: { email }
  /// Always returns a generic success message (does not leak whether the email exists).
  Future<Response> forgotPassword(Request req) async {
    try {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final email = (body['email'] as String?)?.trim().toLowerCase() ?? '';

      if (email.isEmpty || !email.contains('@')) {
        return badRequest('Valid email is required');
      }

      const genericMessage =
          'If an account exists for this email, a password reset code has been sent.';

      try {
        final user = await userRepository.getUserByEmail(email);
        final hash = user.passwordHash ?? '';
        if (hash.isNotEmpty) {
          await _issueAndSendPasswordResetOtp(email: user.email, fullName: user.fullName);
        }
      } on NotFoundException {
        // swallow — same response
      } catch (e) {
        print('[AuthHandler] forgotPassword send error: $e');
      }

      return Response.ok(
        jsonEncode({'message': genericMessage}),
        headers: {'Content-Type': 'application/json'},
      );
    } on AppException catch (e, stack) {
      return handleAppException(e, stack);
    } catch (e, stack) {
      return handleAppException(e, stack);
    }
  }

  /// POST /auth/reset-password  Body: { email, code, newPassword }
  Future<Response> resetPassword(Request req) async {
    try {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final email = (body['email'] as String?)?.trim().toLowerCase() ?? '';
      final code = (body['code'] as String?)?.trim() ?? '';
      final newPassword = (body['newPassword'] as String?)?.trim() ?? '';

      if (email.isEmpty || !email.contains('@')) {
        return badRequest('Valid email is required');
      }
      if (code.length != 6) {
        return badRequest('A valid 6-digit reset code is required');
      }
      if (newPassword.length < 6) {
        return badRequest('Password must be at least 6 characters');
      }

      final ok = await authRepository.verifyPasswordResetOtp(email: email, code: code);
      if (!ok) {
        return Response(400, body: jsonEncode({'message': 'Invalid or expired reset code'}));
      }

      final newHash = passwordService.hash(newPassword);
      await authRepository.updatePasswordByEmail(email: email, passwordHash: newHash);

      return Response.ok(
        jsonEncode({'message': 'Password reset successfully. You can sign in with your new password.'}),
        headers: {'Content-Type': 'application/json'},
      );
    } on AppException catch (e, stack) {
      return handleAppException(e, stack);
    } catch (e, stack) {
      return handleAppException(e, stack);
    }
  }

  Future<void> _issueAndSendOtp({required String email, required String fullName}) async {
    final code = AuthRepositoryImpl.generateOtp();
    final expiresAt = DateTime.now().add(const Duration(minutes: 15));
    await authRepository.saveEmailOtp(email: email, code: code, expiresAt: expiresAt);
    await emailService.sendVerificationOtp(to: email, fullName: fullName, code: code);
  }

  Future<void> _issueAndSendPasswordResetOtp({
required String email, required String fullName}) async {
    final code = AuthRepositoryImpl.generateOtp();
    final expiresAt = DateTime.now().add(const Duration(minutes: 15));
    await authRepository.savePasswordResetOtp(email: email, code: code, expiresAt: expiresAt);
    await emailService.sendPasswordResetOtp(to: email, fullName: fullName, code: code);
  }
}
