import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/core/services/verification/verification_service.dart';
import 'package:neztmate_backend/features/auth_user/models/user_model.dart';
import 'package:neztmate_backend/features/auth_user/repositories/user_repository.dart';

class VeriffService implements VerificationService {
  final UserRepository userRepository;
  final String apiKey;
  final String sharedSecret;
  final String baseUrl;
  final String? callbackUrl;

  VeriffService({
    required this.userRepository,
    required this.apiKey,
    required this.sharedSecret,
    this.baseUrl = 'https://stationapi.veriff.com',
    this.callbackUrl,
  });

  @override
  String get providerName => 'veriff';

  /// Returns the Veriff session URL for the client to open.
  @override
  Future<Map<String, String>> initiateVerification({
    required String userId,
    required String idNumber,
    required String firstName,
    required String lastName,
    String? phone,
    String? email,
  }) async {
    final payload = {
      'verification': {
        'callback': callbackUrl,
        'person': {
          'firstName': firstName,
          'lastName': lastName,
          if (idNumber.isNotEmpty) 'idNumber': idNumber,
        },
        'vendorData': userId, // returned in webhooks — map back to user
        'endUserId': userId,
      },
    };

    final body = jsonEncode(payload);

    final response = await http.post(
      Uri.parse('$baseUrl/v1/sessions'),
      headers: {
        'Content-Type': 'application/json',
        'X-AUTH-CLIENT': apiKey,
        // POST /sessions does not require X-HMAC-SIGNATURE
      },
      body: body,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      print('Veriff session error: ${response.statusCode} ${response.body}');
      throw ValidationException('Failed to start identity verification. Please try again.');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final verification = data['verification'] as Map<String, dynamic>?;
    final sessionId = verification?['id'] as String?;
    final sessionUrl = verification?['url'] as String?;

    if (sessionId == null || sessionUrl == null) {
      throw ValidationException('Invalid response from verification provider');
    }

    // Store provider-agnostic verification id on user
    final user = await userRepository.getUserById(userId);
    await userRepository.updateUser(
      user.copyWith(
        verificationId: sessionId,
        verificationProvider: providerName,
        verificationStatus: 'pending',
        // keep verifiedIdentity false until webhook approved
      ),
    );

    return {'sessionId': sessionId, 'sessionUrl': sessionUrl};
  }

  bool verifyWebhookSignature(String rawBody, String? signature) {
    if (signature == null || signature.isEmpty) return false;

    final digest = Hmac(sha256, utf8.encode(sharedSecret)).convert(utf8.encode(rawBody));
    final expected = digest.toString(); // hex

    return signature.toLowerCase() == expected.toLowerCase();
  }

  @override
  Future<void> handleWebhook(Map<String, dynamic> payload) async {
    // Decision webhook shape: { status, verification: { id, status, code, vendorData, endUserId, ... } }
    final verification = payload['verification'] as Map<String, dynamic>?;
    if (verification == null) return;

    final sessionId = verification['id'] as String?;
    final status = (verification['status'] as String?)?.toLowerCase();
    final vendorData = verification['vendorData'] as String?;
    final endUserId = verification['endUserId'] as String?;
    final reason = verification['reason'] as String?;
    final reasonCode = verification['reasonCode'];

    final userId = endUserId ?? vendorData;
    if (userId == null || userId.isEmpty || sessionId == null || status == null) {
      print('Veriff webhook missing identifiers: $payload');
      return;
    }

    User user;
    try {
      user = await userRepository.getUserById(userId);
    } catch (_) {
      // Fallback: find by verificationId if userId mapping failed
      print('Veriff webhook: user not found for $userId');
      return;
    }

    switch (status) {
      case 'approved':
        await userRepository.updateUser(
          user.copyWith(
            verifiedIdentity: true,
            identityVerifiedAt: DateTime.now(),
            verificationId: sessionId,
            verificationProvider: providerName,
            verificationStatus: 'approved',
            verificationReason: null,
          ),
        );
        break;

      case 'declined':
        await userRepository.updateUser(
          user.copyWith(
            verifiedIdentity: false,
            verificationId: sessionId,
            verificationProvider: providerName,
            verificationStatus: 'declined',
            verificationReason: reason ?? reasonCode?.toString(),
          ),
        );
        break;

      case 'resubmission_requested':
        await userRepository.updateUser(
          user.copyWith(
            verifiedIdentity: false,
            verificationId: sessionId,
            verificationProvider: providerName,
            verificationStatus: 'resubmission_requested',
            verificationReason: reason ?? reasonCode?.toString(),
          ),
        );
        break;

      case 'expired':
      case 'abandoned':
        await userRepository.updateUser(
          user.copyWith(
            verificationId: sessionId,
            verificationProvider: providerName,
            verificationStatus: status,
            verificationReason: reason,
          ),
        );
        break;

      case 'review':
        await userRepository.updateUser(
          user.copyWith(
            verificationId: sessionId,
            verificationProvider: providerName,
            verificationStatus: 'review',
          ),
        );
        break;

      default:
        print('Veriff unhandled status: $status');
    }
  }
}
