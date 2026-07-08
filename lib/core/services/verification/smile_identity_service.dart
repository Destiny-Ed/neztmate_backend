import 'package:neztmate_backend/core/services/verification/verification_service.dart';
import 'package:neztmate_backend/features/auth_user/repositories/user_repository.dart';

class SmileIdentityService implements VerificationService {
  final UserRepository userRepository;

  SmileIdentityService(this.userRepository);

  @override
  String get providerName => 'SmileIdentity';

  @override
  Future<String> initiateVerification({
    required String userId,
    required String idNumber,
    required String firstName,
    required String lastName,
    String? phone,
    String? email,
  }) async {
    final jobId = 'smile_${DateTime.now().millisecondsSinceEpoch}';

    await userRepository.updateUserVerification(
      userId: userId,
      verificationId: jobId,
      provider: 'SmileIdentity',
      status: 'pending',
    );

    return jobId;
  }

  @override
  Future<void> handleWebhook(Map<String, dynamic> payload) async {
    final jobId = payload['job_id'] as String?;
    if (jobId == null) return;

    final user = await userRepository.getUserByVerificationId(jobId);
    if (user == null) return;

    final isApproved = payload['status'] == 'approved';

    await userRepository.updateUserVerification(
      userId: user.id,
      verificationId: jobId,
      provider: 'SmileIdentity',
      status: isApproved ? 'approved' : 'rejected',
    );
  }
}
