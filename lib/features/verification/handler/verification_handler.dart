import 'dart:convert';
import 'dart:io';

import 'package:dotenv/dotenv.dart';
import 'package:neztmate_backend/core/services/verification/providers/veriff_service.dart';
import 'package:neztmate_backend/core/services/verification/providers/you_verify_service.dart';
import 'package:neztmate_backend/core/services/verification/verification_service.dart';
import 'package:neztmate_backend/features/auth_user/repositories/user_repository.dart';
import 'package:shelf/shelf.dart';

class VerificationHandler {
  final VerificationService verificationService;
  final UserRepository userRepository;

  VerificationHandler(this.verificationService, this.userRepository);

  final env = DotEnv()..load();

  /// POST /verification/initiate  (auth required)
  Future<Response> initiate(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      if (userId == null) {
        return Response(401, body: jsonEncode({'message': 'Unauthorized'}));
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;

      final user = await userRepository.getUserById(userId);

      final fullName = user.fullName.split(" ");

      final firstName = body['firstName'] as String? ?? fullName.first;
      final lastName = body['lastName'] as String? ?? fullName.last;
      final idNumber = body['idNumber'] as String? ?? '';
      final dateOfBirth = body['dateOfBirth'] as String? ?? '';
      final idType = body['idType'] as String? ?? '';

      if (firstName.isEmpty || lastName.isEmpty) {
        return Response(400, body: jsonEncode({'message': 'firstName and lastName are required'}));
      }

      if (idNumber.isEmpty || idType.isEmpty) {
        return Response(400, body: jsonEncode({'message': 'idNumber and idType are required'}));
      }

      if (user.verifiedIdentity == true) {
        return Response.ok(jsonEncode({'message': 'Already verified', 'verifiedIdentity': true}));
      }

      final result = await verificationService.initiateVerification(
        userId: userId,
        idNumber: idNumber,
        idType: idType,
        firstName: firstName,
        lastName: lastName,
        phone: user.phone,
        email: user.email,
        dateOfBirth: dateOfBirth,
      );

      // return Response.ok(
      //   jsonEncode({
      //     'message': 'Verification session created',
      //     'provider': verificationService.providerName,
      //     'sessionUrl': result,
      //   }),
      //   headers: {'Content-Type': 'application/json'},
      // );
      return Response.ok(
        jsonEncode({
          'message': 'Identity verified successfully',
          'provider': verificationService.providerName,
          'verifiedIdentity': true,
          'verificationId': result,
          // Veriff clients look for sessionUrl — omit or null for YouVerify
          'sessionUrl': null,
        }),
      );
    } catch (e, s) {
      print('Verification initiate error: $e\n$s');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to start verification'}));
    }
  }

  /// POST /verification/webhook/veriff  (PUBLIC — no auth middleware)
  Future<Response> veriffWebhook(Request request) async {
    try {
      final rawBody = await request.readAsString();
      final signature = request.headers['x-hmac-signature'];
      final authClient = request.headers['x-auth-client'];

      final service = verificationService;
      if (service is! VeriffService) {
        return Response(500, body: 'Provider misconfigured');
      }

      if (authClient != service.apiKey) {
        return Response(401, body: jsonEncode({'message': 'Invalid auth client'}));
      }
      if (!service.verifyWebhookSignature(rawBody, signature)) {
        return Response(401, body: jsonEncode({'message': 'Invalid signature'}));
      }

      final payload = jsonDecode(rawBody) as Map<String, dynamic>;
      await service.handleWebhook(payload);

      return Response.ok(jsonEncode({'status': 'ok'}));
    } catch (e, s) {
      print('Veriff webhook error: $e\n$s');
      // Still 200 so Veriff doesn't infinite-retry on app bugs (optional: 500 for real failures)
      return Response.ok(jsonEncode({'status': 'received'}));
    }
  }

  /// POST /verification/webhook/youverify  (PUBLIC — no auth middleware)
  Future<Response> youVerifyWebhook(Request request) async {
    try {
      final rawBody = await request.readAsString();

      if (rawBody.trim().isEmpty) {
        return Response(400, body: jsonEncode({'message': 'Empty body'}));
      }

      Map<String, dynamic> payload;
      try {
        payload = jsonDecode(rawBody) as Map<String, dynamic>;
      } catch (_) {
        return Response(400, body: jsonEncode({'message': 'Invalid JSON'}));
      }

      // Optional shared-secret header if you configure one in YouVerify dashboard
      final configuredSecret =
          Platform.environment['YOUVERIFY_WEBHOOK_SECRET'] ?? env['YOUVERIFY_WEBHOOK_SECRET'];
      if (configuredSecret != null && configuredSecret.isNotEmpty) {
        final incoming =
            request.headers['x-youverify-signature'] ??
            request.headers['x-webhook-secret'] ??
            request.headers['authorization'];
        if (incoming == null || (incoming != configuredSecret && incoming != 'Bearer $configuredSecret')) {
          return Response(401, body: jsonEncode({'message': 'Invalid webhook signature'}));
        }
      }

      final service = verificationService;
      if (service is YouVerifyService) {
        await service.handleWebhook(payload);
      } else {
        // Still process if interface is generic
        await verificationService.handleWebhook(payload);
      }

      return Response.ok(jsonEncode({'status': 'ok'}), headers: {'Content-Type': 'application/json'});
    } catch (e, stack) {
      print('YouVerify webhook error: $e\n$stack');
      // Acknowledge so provider does not hammer retries on app bugs
      return Response.ok(jsonEncode({'status': 'received'}));
    }
  }
}
