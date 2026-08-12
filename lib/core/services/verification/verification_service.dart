abstract class VerificationService {
  Future<String> initiateVerification({
    required String userId,
    required String idNumber,
    required String idType,
    required String firstName,
    required String lastName,
    String? phone,
    String? email,
    String? dateOfBirth,
  });

  Future<void> handleWebhook(Map<String, dynamic> payload);

  String get providerName;
}
