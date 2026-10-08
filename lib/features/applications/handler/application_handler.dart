import 'dart:convert';
import 'dart:io';
import 'package:neztmate_backend/core/services/payment/paystack_service.dart';
import 'package:neztmate_backend/core/services/storage/storage_service.dart';
import 'package:neztmate_backend/core/services/subscription/partner_access_service.dart';
import 'package:neztmate_backend/core/utils.dart';
import 'package:neztmate_backend/features/applications/models/application_model.dart';
import 'package:neztmate_backend/features/applications/repository/application_repo.dart';
import 'package:neztmate_backend/features/auth_user/repositories/user_repository.dart';
import 'package:neztmate_backend/features/leases/models/leases_model.dart';
import 'package:neztmate_backend/features/leases/repository/lease_repo.dart';
import 'package:neztmate_backend/features/leases/service/lease_pdf_service.dart';
import 'package:neztmate_backend/features/notifications/models/notification_model.dart';
import 'package:neztmate_backend/features/notifications/repository/notification_repo.dart';
import 'package:neztmate_backend/features/payments/models/payments.dart';
import 'package:neztmate_backend/features/payments/repository/payment_repo.dart';
import 'package:neztmate_backend/features/properties/repository/property_repo.dart';
import 'package:neztmate_backend/features/reviews/repository/review_repository.dart';
import 'package:neztmate_backend/features/units/repository/unit_repo.dart';
import 'package:shelf/shelf.dart';
import 'package:neztmate_backend/core/error.dart';
import 'package:shelf_router/shelf_router.dart';

class ApplicationHandler {
  final ApplicationRepository applicationRepository;
  final UserRepository userRepository;
  final PropertyRepository propertyRepository;
  final UnitRepository unitRepository;
  final LeaseRepository leaseRepository;
  final NotificationRepository notificationRepository;
  final UserReviewRepository userReviewRepository;
  final PaymentRepository paymentRepository;
  final PartnerAccessService partnerAccess;
  final AppStorageService storageService;

  ApplicationHandler({
    required this.applicationRepository,
    required this.userRepository,
    required this.propertyRepository,
    required this.unitRepository,
    required this.leaseRepository,
    required this.notificationRepository,
    required this.userReviewRepository,
    required this.paymentRepository,
    required this.partnerAccess,
    required this.storageService,
  });

  final paystackService = PaystackService();

  // NOTE: Full handler body temporarily truncated during restore.
  // Pull this file from commit fecf2ad and re-apply AppStorageService changes if this marker is present.
  // RESTORE_MARKER_FULL_BODY_MISSING
}
