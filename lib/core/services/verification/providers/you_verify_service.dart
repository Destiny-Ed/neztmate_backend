import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/core/services/verification/verification_service.dart';
import 'package:neztmate_backend/features/auth_user/repositories/user_repository.dart';

class YouVerifyService implements VerificationService {
  final UserRepository userRepository;
  final String apiToken;
  final String baseUrl;
  final String defaultIdType; // nin | bvn

  YouVerifyService({
    required this.userRepository,
    required this.apiToken,
    this.baseUrl = 'https://api.youverify.co',
    this.defaultIdType = 'nin',
  });

  @override
  String get providerName => 'youverify';

  /// Sync NIN/BVN check. Returns verification record id on success.
  /// [idNumber] = NIN or BVN. Optional: pass type via phone field as "type:nin" is ugly —
  /// prefer extending body in handler with idType.
  @override
  Future<String> initiateVerification({
    required String userId,
    required String idNumber,
    required String firstName,
    required String lastName,
    String? phone,
    String? email,
    String? idType, // nin | bvn — extra param if you widen the interface
    String? dateOfBirth, // YYYY-MM-DD
  }) async {
    if (idNumber.trim().isEmpty) {
      throw ValidationException('ID number (NIN or BVN) is required');
    }

    final type = (idType ?? _guessIdType(idNumber) ?? defaultIdType).toLowerCase();
    if (type != 'nin' && type != 'bvn') {
      throw ValidationException('idType must be nin or bvn');
    }

    final path = type == 'bvn' ? '/v2/api/identity/ng/bvn' : '/v2/api/identity/ng/nin';

    final payload = <String, dynamic>{
      'id': idNumber.trim(),
      'isSubjectConsent': true,
      'validation': {
        'data': {
          if (firstName.trim().isNotEmpty) 'firstName': firstName.trim(),
          if (lastName.trim().isNotEmpty) 'lastName': lastName.trim(),
          if (dateOfBirth != null && dateOfBirth.isNotEmpty) 'dateOfBirth': dateOfBirth,
        },
      },
      'metadata': {'userId': userId, 'email': email, 'phone': phone},
    };

    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: {'Content-Type': 'application/json', 'token': apiToken},
      body: jsonEncode(payload),
    );

    final body = response.body;
    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      print('YouVerify bad response: ${response.statusCode} $body');
      throw ValidationException('Verification provider error. Please try again.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300 || decoded['success'] != true) {
      final msg = decoded['message']?.toString() ?? 'Identity verification failed';
      print('YouVerify error: ${response.statusCode} $body');
      throw ValidationException(msg);
    }

    final data = decoded['data'] as Map<String, dynamic>? ?? {};
    final status = (data['status'] as String?)?.toLowerCase() ?? '';
    final verificationId = data['id']?.toString() ?? '';
    final dataValidation = data['dataValidation'] == true;
    // If no name sent, dataValidation may be false even when ID exists
    final found = status == 'found';

    final user = await userRepository.getUserById(userId);

    if (!found) {
      await userRepository.updateUser(
        user.copyWith(
          verificationId: verificationId.isNotEmpty ? verificationId : null,
          verificationProvider: providerName,
          verificationStatus: 'declined',
          verificationReason: 'ID not found',
          verifiedIdentity: false,
        ),
      );
      throw ValidationException('We could not verify this ID number. Check and try again.');
    }

    // Require name match when names were provided
    final nameProvided = firstName.trim().isNotEmpty || lastName.trim().isNotEmpty;
    if (nameProvided && data.containsKey('dataValidation') && !dataValidation) {
      await userRepository.updateUser(
        user.copyWith(
          verificationId: verificationId.isNotEmpty ? verificationId : null,
          verificationProvider: providerName,
          verificationStatus: 'declined',
          verificationReason: 'Name does not match ID records',
          verifiedIdentity: false,
        ),
      );
      throw ValidationException('Name does not match the ID on record.');
    }

    await userRepository.updateUser(
      user.copyWith(
        verifiedIdentity: true,
        verificationId: verificationId.isNotEmpty ? verificationId : idNumber,
        verificationProvider: providerName,
        verificationStatus: 'approved',
        verificationReason: null,
      ),
    );

    // Interface returns String: use verification id (client can show success modal)
    return verificationId.isNotEmpty ? verificationId : 'approved';
  }

  String? _guessIdType(String id) {
    final digits = id.replaceAll(RegExp(r'\D'), '');
    // NIN and BVN are both 11 digits in NG — cannot reliably guess; prefer explicit idType
    if (digits.length == 11) return null;
    return null;
  }

  /// YouVerify ID checks are usually sync. Keep for dashboard/async callbacks if enabled.
  @override
  Future<void> handleWebhook(Map<String, dynamic> payload) async {
    final data = payload['data'] is Map ? Map<String, dynamic>.from(payload['data'] as Map) : payload;

    final metadata = data['metadata'] is Map
        ? Map<String, dynamic>.from(data['metadata'] as Map)
        : <String, dynamic>{};

    final userId =
        metadata['userId'] as String? ??
        payload['userId'] as String? ??
        payload['metadata']?['userId'] as String?;

    final status = (data['status'] as String?)?.toLowerCase();
    final verificationId = data['id']?.toString();
    final dataValidation = data['dataValidation'];

    if (userId == null || userId.isEmpty) {
      print('YouVerify webhook: missing userId. payload=$payload');
      return;
    }

    final user = await userRepository.getUserById(userId);

    final approved =
        status == 'found' ||
        status == 'approved' ||
        status == 'verified' ||
        (status == 'found' && dataValidation == true);

    await userRepository.updateUser(
      user.copyWith(
        verifiedIdentity: approved,
        verificationId: verificationId ?? user.verificationId,
        verificationProvider: providerName,
        verificationStatus: approved ? 'approved' : (status ?? 'declined'),
        verificationReason: approved ? null : (data['message']?.toString() ?? status),
      ),
    );
  }
}
