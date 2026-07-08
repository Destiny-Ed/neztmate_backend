import 'dart:convert';

import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/core/services/verification/verification_service.dart';
import 'package:neztmate_backend/features/auth_user/repositories/user_repository.dart';
import 'package:shelf/shelf.dart';

class VerificationHandler {
  final VerificationService verificationService;
  final UserRepository userRepository;

  VerificationHandler(this.verificationService, this.userRepository);

  /// POST /verification/initiate - Start KYC verification
  Future<Response> initiateVerification(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      if (userId == null) return unauthorized("Missing authentication");

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;

      final jobId = await verificationService.initiateVerification(
        userId: userId,
        idNumber: body['idNumber'],
        firstName: body['firstName'],
        lastName: body['lastName'],
        phone: body['phone'],
        email: body['email'],
      );

      return Response.ok(
        jsonEncode({
          'message': 'Verification initiated',
          'jobId': jobId,
          'provider': verificationService.providerName,
        }),
      );
    } catch (e) {
      return Response.internalServerError();
    }
  }

  /// POST /webhooks/verification - Generic webhook
  Future<Response> handleWebhook(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      await verificationService.handleWebhook(body);

      return Response.ok('Webhook processed');
    } catch (e) {
      print('Webhook error: $e');
      return Response.ok('Webhook received');
    }
  }
}
