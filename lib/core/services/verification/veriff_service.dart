import 'package:neztmate_backend/core/services/verification/verification_service.dart';

class VeriffService implements VerificationService {
  @override
  Future<void> handleWebhook(Map<String, dynamic> payload) {
    // TODO: implement handleWebhook
    throw UnimplementedError();
  }

  @override
  Future<String> initiateVerification({
    required String userId,
    required String idNumber,
    required String firstName,
    required String lastName,
    String? phone,
    String? email,
  }) {
    // TODO: implement initiateVerification
    throw UnimplementedError();
  }

  @override
  // TODO: implement providerName
  String get providerName => 'Veriff';
  // implement methods
}
