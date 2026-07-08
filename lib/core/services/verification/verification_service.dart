abstract class VerificationService {
  Future<String> initiateVerification({
    required String userId,
    required String idNumber,
    required String firstName,
    required String lastName,
    String? phone,
    String? email,
  });

  Future<void> handleWebhook(Map<String, dynamic> payload);

  String get providerName;
}
