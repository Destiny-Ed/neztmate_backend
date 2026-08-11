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

      final idType = body['idType'];

      final user = await userRepository.getUserById(userId);
      final userName = user.fullName.split(' ');
      final jobId = await verificationService.initiateVerification(
        userId: userId,
        idNumber: body['idNumber'],

        firstName: userName.first,
        lastName: userName.last,
        phone: user.phone,
        email: user.email,
      );

      return Response.ok(
        jsonEncode({
          'message': 'Verification initiated',
          'jobId': jobId,
          'provider': verificationService.providerName,
        }),
      );
    } catch (e, stack) {
      print("Error initializing verification $e/n$stack");
      return Response.internalServerError();
    }
  }

  /// POST /webhooks/verification - Generic webhook
  Future<Response> handleWebhook(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      await verificationService.handleWebhook(body);

      return Response.ok('Webhook processed');
    } catch (e, stack) {
      print('Webhook error: $e/n$stack');
      return Response.ok('Webhook received');
    }
  }
}
