import 'package:neztmate_backend/features/auth_user/repositories/user_repository.dart';
import 'package:neztmate_backend/features/payments/models/payments.dart';
import 'package:neztmate_backend/features/payments/repository/payment_repo.dart';
import 'package:neztmate_backend/features/reviews/repository/review_repository.dart';

class UserReputationService {
  final UserRepository userRepository;
  final PaymentRepository paymentRepository;
  final UserReviewRepository reviewRepository;

  UserReputationService(this.userRepository, this.paymentRepository, this.reviewRepository);

  /// Full reputation update including payment on-time rate
  Future<void> updateUserReputation(String userId) async {
    final user = await userRepository.getUserById(userId);

    // 1. Calculate Average Rating from Reviews
    final reviews = await reviewRepository.getReviewsForUser(userId);
    final averageRating = reviews.isNotEmpty
        ? reviews.fold(0.0, (sum, r) => sum + r.rating) / reviews.length
        : 0.0;

    // 2. Calculate Payment On-Time Rate (for Tenants)
    double paymentOnTimeRate = 1.0;
    int totalPayments = 0;
    int onTimePayments = 0;

    if (user.role == 'tenant') {
      final payments = await paymentRepository.getPaymentsByUser(userId);

      for (var payment in payments) {
        if (payment.type == 'rent' || payment.type == 'rent-renewal') {
          totalPayments++;

          // Consider "on time" if paid within 5 days of due date
          final isOnTime = _isPaymentOnTime(payment);
          if (isOnTime) onTimePayments++;
        }
      }

      if (totalPayments > 0) {
        paymentOnTimeRate = onTimePayments / totalPayments;
      }
    }

    // 3. Update User
    final updatedUser = user.copyWith(
      averageRating: averageRating,
      totalReviews: reviews.length,
      totalRatings: reviews.length,
      paymentOnTimeRate: paymentOnTimeRate,
      totalPaymentsMade: totalPayments,
      onTimePayments: onTimePayments,
      lastReviewedAt: DateTime.now(),
    );

    await userRepository.updateUser(updatedUser);
  }

  /// Helper: Determine if payment was made on time
  bool _isPaymentOnTime(PaymentModel payment) {
    if (payment.paidDate == null || payment.dueDate == null) return false;

    final daysLate = payment.paidDate!.difference(payment.dueDate!).inDays;
    return daysLate <= 5; // Grace period of 5 days
  }
}
