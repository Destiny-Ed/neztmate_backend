import 'dart:convert';
import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/core/services/payment/paystack_service.dart';
import 'package:neztmate_backend/core/services/reputation/reputation_service.dart';
import 'package:neztmate_backend/features/applications/repository/application_repo.dart';
import 'package:neztmate_backend/features/history/model/user_history_model.dart';
import 'package:neztmate_backend/features/history/repository/user_history_repo.dart';
import 'package:neztmate_backend/features/leases/models/leases_model.dart';
import 'package:neztmate_backend/features/leases/repository/lease_repo.dart';
import 'package:neztmate_backend/features/maintenance/repository/maintenance_repo.dart';
import 'package:neztmate_backend/features/notifications/models/notification_model.dart';
import 'package:neztmate_backend/features/notifications/repository/notification_repo.dart';
import 'package:neztmate_backend/features/payments/models/manager_commission_model.dart';
import 'package:neztmate_backend/features/payments/models/payment_disbursement_model.dart';
import 'package:neztmate_backend/features/payments/models/payment_summary_model.dart';
import 'package:neztmate_backend/features/payments/models/payments.dart';
import 'package:neztmate_backend/features/payments/models/payout_account_model.dart';
import 'package:neztmate_backend/features/payments/models/withdrawal_model.dart';
import 'package:neztmate_backend/features/payments/repository/payment_repo.dart';
import 'package:neztmate_backend/features/properties/repository/property_repo.dart';
import 'package:neztmate_backend/features/units/repository/unit_repo.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class PaymentHandler {
  final PaymentRepository paymentRepository;
  final LeaseRepository leaseRepository;
  final HistoryRepository historyRepository;
  final UnitRepository unitRepository;
  final NotificationRepository notificationRepository;
  final MaintenanceRepository maintenanceRepository;
  final ApplicationRepository applicationRepository;
  final UserReputationService userReputationService;
  final PropertyRepository propertyRepository;

  PaymentHandler(
    this.paymentRepository,
    this.leaseRepository,
    this.historyRepository,
    this.notificationRepository,
    this.unitRepository,
    this.maintenanceRepository,
    this.applicationRepository,
    this.userReputationService,
    this.propertyRepository,
  );

  final PaystackService paystackService = PaystackService();

  /// POST /payments/initialize - Tenant starts rent payment
  // Future<Response> initializePayment(Request request) async {
  //   try {
  //     final userId = request.context['userId'] as String?;
  //     if (userId == null) return unauthorized("User not found");

  //     final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
  //     final leaseId = body['leaseId'] as String?;
  //     final propertyId = body['propertyId'] as String?;
  //     final unitId = body['unitId'] as String?;
  //     final amount = (body['amount'] as num).toDouble();
  //     final email = (body['email'] as String?);
  //     final paymentType = (body['paymentType'] as String?);

  //     if (leaseId == null || email == null || propertyId == null || unitId == null || amount <= 0) {
  //       return badRequest('leaseId, propertyId, unitId, email and valid amount are required');
  //     }

  //     if (!['rent', 'task', 'rent-renewal'].contains(paymentType)) {
  //       return badRequest('Invalid paymentType');
  //     }

  //     final reference = 'nm_${DateTime.now().millisecondsSinceEpoch}';

  //     final initData = await paystackService.initializeTransaction(
  //       email: email,
  //       amount: amount,
  //       reference: reference,
  //       metadata: {
  //         'userId': userId,
  //         'leaseId': leaseId,
  //         'unitId': unitId,
  //         'propertyId': propertyId,
  //         'type': paymentType,
  //       },
  //     );

  // // Save pending payment
  // final pendingPayment = PaymentModel(
  //   id: '',
  //   leaseId: leaseId,
  //   payerId: userId,
  //   propertyId: propertyId,
  //   unitId: unitId,
  //   amount: amount,
  //   status: 'Pending',
  //   method: 'Paystack',
  //   transactionRef: reference,
  //   type: paymentType,
  //   createdAt: DateTime.now(),
  // );

  // await paymentRepository.createPayment(pendingPayment);

  //     return Response.ok(
  //       jsonEncode({'authorization_url': initData['authorization_url'], 'reference': reference}),
  //     );
  //   } catch (e) {
  //     print("Error initializing payment: $e");
  //     return Response.internalServerError();
  //   }
  // }

  /// POST /payments/webhook - Paystack Webhook Handler
  Future<Response> paystackWebhook(Request request) async {
    print("Webhook received - Starting processing");

    try {
      final signature = request.headers['x-paystack-signature'];
      final bodyString = await request.readAsString();

      if (!paystackService.verifySignature(bodyString, signature)) {
        print('❌ Invalid Paystack signature');
        return Response(400, body: jsonEncode({'message': 'Invalid signature'}));
      }

      final body = jsonDecode(bodyString);
      final event = body['event'] as String?;

      print(body);

      if (event != 'charge.success') {
        return Response.ok('Event ignored');
      }

      final data = body['data'] as Map<String, dynamic>;
      final metadata = data['metadata'] as Map<String, dynamic>;
      final reference = data['reference'] as String;
      final amount = (data['amount'] as num) / 100.0; // Convert from Kobo to Naira
      final receiptUrl = data['receipt_url'] as String?;

      print('✅ Charge Success - Reference: $reference, Amount: ₦$amount');

      print("metadata : $metadata");

      // === IDEMPOTENCY CHECK ===
      final alreadyProcessed = await paymentRepository.isPaymentAlreadyProcessed(reference);
      if (alreadyProcessed) {
        print('⚠️ Payment already processed: $reference');
        return Response.ok('Already processed');
      }

      final payment = await paymentRepository.getPaymentByReference(reference);

      // Mark as processed immediately
      await paymentRepository.markPaymentAsProcessed(reference);

      // Update main payment record
      await paymentRepository.markAsPaidByReference(reference, receiptUrl ?? '', reference);

      // final platformFee = amount * 0.05; // 5% platform fee
      // final netAmount = amount - platformFee;

      // String recipientId = '';
      // String recipientType = '';

      // double managerCommissionAmount = 0.0;
      // double managerCommissionRate = 0.0;
      // String? managerId;

      //  APPLICATION FEE
      if (payment.type == 'application_fee' && metadata['applicationId'] != null) {
        final appId = metadata['applicationId'] as String;

        final application = await applicationRepository.getApplicationById(appId);

        await applicationRepository.updateApplication(application.copyWith(status: 'Pending'));

        await notificationRepository.create(
          NotificationModel(
            userId: payment.payerId,
            type: 'application_fee_paid',
            title: 'Application Fee Paid',
            body: 'Your ₦2,000 application fee has been received. Your application is now under review.',
            relatedId: appId,
            relatedCollection: 'applications',
            createdAt: DateTime.now(),
            id: '',
          ),
        );
      }
      //  TASK PAYMENT
      // if (payment.type == 'task_payment' && payment.taskId != null) {
      //   final task = await maintenanceRepository.getTaskById(payment.taskId!);
      //   recipientId = task.artisanId;
      //   recipientType = 'artisan';
      //   final updatedTask = task.copyWith(
      //     paymentStatus: 'Paid',
      //     paymentMethod: 'Paystack',
      //     paymentReference: reference,
      //     actualCost: amount,
      //     paymentApprovedAt: DateTime.now(),
      //     paymentApprovedBy: 'system',
      //   );
      //   await maintenanceRepository.updateTask(updatedTask);
      //   // Manager Commission for Task (if assigned by manager)
      //   managerId = task.assignedBy;
      //   if (managerId != null) {
      //     managerCommissionAmount = amount * 0.10; // 10% for tasks
      //   }
      //   // Notifications & History
      //   await notificationRepository.create(
      //     NotificationModel(
      //       userId: task.artisanId,
      //       type: 'task_payment_success',
      //       title: 'Payment Received',
      //       body: '₦${amount.toStringAsFixed(0)} has been paid for your task.',
      //       relatedId: task.id,
      //       relatedCollection: 'maintenance_tasks',
      //       createdAt: DateTime.now(),
      //       id: '',
      //     ),
      //   );
      //   await historyRepository.createHistoryEntry(
      //     HistoryEntryModel(
      //       userId: task.artisanId,
      //       type: 'task_payment_received',
      //       title: 'Task Payment Received',
      //       description: '₦${amount.toStringAsFixed(0)} for ${task.title}',
      //       relatedId: task.id,
      //       relatedCollection: 'maintenance_tasks',
      //       timestamp: DateTime.now(),
      //       id: '',
      //     ),
      //   );
      // }
      //  RENT PAYMENT
      // else if (payment.leaseId != null) {
      //   final lease = await leaseRepository.getLeaseById(payment.leaseId!);

      //   recipientId = lease.landownerId;
      //   recipientType = 'landowner';
      //   managerId = lease.managerId;

      //   // Update lease & unit
      //   if (payment.type?.toLowerCase() == 'rent-renewal') {
      //     await leaseRepository.renewLeaseAfterPayment(payment.leaseId!);
      //   } else {
      //     await leaseRepository.updateLeaseStatus(payment.leaseId!, 'Active');
      //   }

      //   await unitRepository.updateUnitStatus(
      //     unitId: lease.unitId,
      //     status: 'occupied',
      //     currentTenantId: lease.tenantId,
      //     isListedForRent: false,
      //   );

      //   // Reputation updates
      //   await userReputationService.updateUserReputation(payment.payerId);
      //   await userReputationService.updateUserReputation(lease.landownerId);

      //   // Manager Commission for Rent
      //   if (managerId != null) {
      //     final property = await propertyRepository.getPropertyById(lease.propertyId ?? '');

      //     if (property.managerCommissionType == 'percentage' && property.managerCommissionRate != null) {
      //       managerCommissionAmount = amount * property.managerCommissionRate!;
      //       managerCommissionRate = property.managerCommissionRate!;
      //     } else if (property.managerCommissionType == 'flat' && property.managerFlatFeeAmount != null) {
      //       managerCommissionAmount = property.managerFlatFeeAmount!;
      //     }
      //   }

      //   await _sendRentSuccessNotifications(payment, lease, amount);
      // }

      //  CREATE DISBURSEMENT (3 Days Holding)
      // if (recipientId.isNotEmpty) {
      //   final disbursement = PaymentDisbursementModel(
      //     id: '',
      //     paymentId: payment.id,
      //     recipientId: recipientId,
      //     recipientType: recipientType,
      //     originalAmount: amount,
      //     platformFee: platformFee,
      //     netAmount: netAmount,
      //     status: 'Held',
      //     scheduledDate: DateTime.now().add(const Duration(days: 3)),
      //   );

      //   await paymentRepository.createDisbursement(disbursement);
      //   await paymentRepository.recordPlatformFee(payment.id, platformFee, payment.type ?? 'payment');

      //   print('📅 Disbursement scheduled for $recipientType after 3 days');
      // }

      //  RECORD MANAGER COMMISSION
      // if (managerId != null && managerCommissionAmount > 0) {
      //   final commission = ManagerCommissionModel(
      //     id: '',
      //     paymentId: payment.id,
      //     managerId: managerId,
      //     relatedId: payment.leaseId ?? payment.taskId ?? '',
      //     type: payment.type ?? 'rent',
      //     commissionRate: managerCommissionRate,
      //     commissionAmount: managerCommissionAmount,
      //     createdAt: DateTime.now(),
      //   );

      //   await paymentRepository.recordManagerCommission(commission);
      //   print('💰 Manager commission recorded: ₦$managerCommissionAmount');
      // }

      return Response.ok('Webhook processed successfully');
    } catch (e, stack) {
      print('❌ Webhook error: $e\n$stack');
      return Response.ok('Webhook received with internal errors');
    }
  }

  /// POST /payments - Record a new payment (rent or task)
  // Future<Response> recordPayment(Request request) async {
  //   try {
  //     final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
  //     final payment = PaymentModel.fromMap(body);

  //     final created = await paymentRepository.createPayment(payment);

  //     return Response.ok(
  //       jsonEncode({'message': 'Payment recorded successfully', 'payment': created.toMap()}),
  //       headers: {'Content-Type': 'application/json'},
  //     );
  //   } catch (e) {
  //     return Response.internalServerError(body: jsonEncode({'message': 'Failed to record payment'}));
  //   }
  // }

  /// GET /payments/me - User views their payment history
  Future<Response> getMyPayments(Request request) async {
    try {
      final userId = request.context['userId'] as String?;

      if (userId == null) return unauthorized('Unauthorized');

      final payments = await paymentRepository.getPaymentsByUser(userId);

      return Response.ok(
        jsonEncode({'payments': payments.map((p) => p.toMap()).toList()}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError();
    }
  }

  /// GET /payments/property/<propertyId>
  Future<Response> getPaymentsByProperty(Request request) async {
    try {
      final propertyId = request.params['propertyId'];
      if (propertyId == null) return badRequest('propertyId required');

      final payments = await paymentRepository.getPaymentsByProperty(propertyId);

      return Response.ok(
        jsonEncode({
          'payments': payments.map((p) => p.toMap()).toList(),
          "message": "Payments fetched successfully",
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError();
    }
  }

  /// GET /payments/unit/<unitId>
  Future<Response> getPaymentsByUnit(Request request) async {
    try {
      final unitId = request.params['unitId'];
      if (unitId == null) return badRequest('unitId required');

      final payments = await paymentRepository.getPaymentsByUnit(unitId);

      return Response.ok(jsonEncode({'payments': payments.map((p) => p.toMap()).toList()}));
    } catch (e) {
      return Response.internalServerError();
    }
  }

  /// GET /payments/lease/<leaseId>
  Future<Response> getPaymentsByLease(Request request) async {
    try {
      final leaseId = request.params['leaseId'];
      if (leaseId == null) return badRequest('leaseId required');

      final payments = await paymentRepository.getPaymentsByLease(leaseId);

      return Response.ok(jsonEncode({'payments': payments.map((p) => p.toMap()).toList()}));
    } catch (e) {
      return Response.internalServerError();
    }
  }

  /// PATCH /withdrawals/<id>/approve - Approve and complete withdrawal
  Future<Response> approveWithdrawal(Request request) async {
    try {
      final withdrawalId = request.params['id'];
      final processedBy = request.context['userId'] as String?;
      final role = request.context['role'] as String?;

      if (withdrawalId == null || processedBy == null) {
        return badRequest('Withdrawal ID is required');
      }

      if (!['admin'].contains(role)) {
        return Response(403, body: jsonEncode({'message': 'Insufficient permission'}));
      }

      final withdrawal = await paymentRepository.getWithdrawalById(withdrawalId);

      if (withdrawal.status != 'Pending') {
        return Response(400, body: jsonEncode({'message': 'Only pending withdrawals can be approved'}));
      }

      // Approve and mark as Completed
      await paymentRepository.approveWithdrawal(withdrawalId, processedBy);

      // Log history for the user
      await historyRepository.createHistoryEntry(
        HistoryEntryModel(
          userId: withdrawal.userId,
          type: 'withdrawal_completed',
          title: 'Withdrawal Completed',
          description: '₦${withdrawal.amount} has been processed successfully',
          relatedId: withdrawalId,
          relatedCollection: 'withdrawals',
          timestamp: DateTime.now(),
          id: '',
          metadata: {'propertyId': withdrawal.propertyId, 'amount': withdrawal.amount},
        ),
      );

      return Response.ok(
        jsonEncode({
          'message': 'Withdrawal approved and completed successfully',
          'withdrawalId': withdrawalId,
          'amount': withdrawal.amount,
          'status': 'Completed',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Approve withdrawal error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to approve withdrawal'}));
    }
  }

  /// POST /admin/withdraw-platform-fees
  Future<Response> withdrawPlatformFees(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;

      if (!['admin'].contains(role) && userId == null) {
        return Response(403, body: jsonEncode({'message': 'Insufficient permission. Admin access required'}));
      }

      final totalFees = await paymentRepository.getTotalUnwithdrawnPlatformFees();

      if (totalFees <= 0) {
        return Response(400, body: jsonEncode({'message': 'No pending platform fees to withdraw'}));
      }

      final reference = 'platform_withdrawal_${DateTime.now().millisecondsSinceEpoch}';

      final success = await paystackService.transferToBank(
        amount: totalFees,
        accountNumber: const String.fromEnvironment('ADMIN_ACCOUNT_NUMBER'),
        bankCode: const String.fromEnvironment('ADMIN_BANK_CODE'),
        reference: reference,
        reason: 'NeztMate Platform fees withdrawal',
      );

      if (success) {
        await paymentRepository.markPlatformFeesAsWithdrawn(reference);

        return Response.ok(
          jsonEncode({
            'message': 'Platform fees withdrawn successfully',
            'amount': totalFees,
            'reference': reference,
          }),
        );
      } else {
        return Response(500, body: jsonEncode({'message': 'Withdrawal failed on Paystack'}));
      }
    } catch (e, stack) {
      print('Admin withdrawal error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  /// PATCH /withdrawals/<id>/reject
  Future<Response> rejectWithdrawal(Request request) async {
    try {
      final withdrawalId = request.params['id'];
      final processedBy = request.context['userId'] as String?;
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final reason = body['reason'] as String?;

      if (withdrawalId == null || processedBy == null) {
        return badRequest('Withdrawal ID is required');
      }

      final withdrawal = await paymentRepository.getWithdrawalById(withdrawalId);

      if (withdrawal.status != 'Pending') {
        return Response(400, body: jsonEncode({'message': 'Only pending withdrawals can be rejected'}));
      }

      await paymentRepository.rejectWithdrawal(withdrawalId, processedBy, reason);

      // Log history
      await historyRepository.createHistoryEntry(
        HistoryEntryModel(
          userId: withdrawal.userId,
          type: 'withdrawal_rejected',
          title: 'Withdrawal Rejected',
          description: reason ?? 'Withdrawal request was rejected',
          relatedId: withdrawalId,
          relatedCollection: 'withdrawals',
          timestamp: DateTime.now(),
          id: '',
        ),
      );

      return Response.ok(
        jsonEncode({
          'message': 'Withdrawal rejected. Reserved amount has been released back.',
          'withdrawalId': withdrawalId,
        }),
      );
    } catch (e, stack) {
      print('Reject withdrawal error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  /// PATCH /payments/<id>/mark-paid - Mark payment as paid (manager/landowner)
  Future<Response> markAsPaid(Request request) async {
    try {
      final id = request.params['id'];
      if (id == null) return Response(400, body: jsonEncode({'message': 'Missing ID'}));

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final receiptUrl = body['receiptUrl'] as String?;
      final transactionRef = body['transactionRef'] as String?;

      await paymentRepository.markAsPaid(id, receiptUrl ?? '', transactionRef);

      return Response.ok(jsonEncode({'message': 'Payment marked as paid'}));
    } catch (e) {
      return Response.internalServerError();
    }
  }

  /// POST /withdrawals - Request withdrawal with immediate reservation
  Future<Response> requestWithdrawal(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;

      if (userId == null || !['landowner', 'manager'].contains(role)) {
        return Response(
          403,
          body: jsonEncode({'message': 'Only landowners and managers can request withdrawals'}),
        );
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;

      final propertyId = body['propertyId'] as String?;
      final amount = (body['amount'] as num?)?.toDouble();
      final notes = body['notes'] as String?;

      if (propertyId == null) return badRequest('propertyId is required');
      if (amount == null || amount <= 0) return badRequest('Valid amount is required');

      // Check if user has payout account
      final payoutAccounts = await paymentRepository.getPayoutAccounts(userId);
      if (payoutAccounts.isEmpty) {
        return Response(
          400,
          body: jsonEncode({
            'message': 'No payout account found. Please add a bank account first.',
            'action': 'add_payout_account',
          }),
        );
      }

      // Check available commission for managers
      if (role == 'Manager') {
        final pendingCommission = await paymentRepository.getTotalPendingCommission(userId);
        if (amount > pendingCommission) {
          return Response(
            400,
            body: jsonEncode({'message': 'Insufficient commission balance', 'available': pendingCommission}),
          );
        }
      }

      // Get current withdrawable balance
      final payments = await paymentRepository.getPaymentsByProperty(propertyId);
      final summary = await _calculatePropertySummary(payments, propertyId);
      if (amount > summary.withdrawableAmount) {
        return Response(
          400,
          body: jsonEncode({
            'message': 'Insufficient balance. Available: ₦${summary.withdrawableAmount.toStringAsFixed(0)}',
          }),
        );
      }

      // Create withdrawal (Pending = amount is now reserved)
      final withdrawal = WithdrawalModel(
        id: '',
        userId: userId,
        propertyId: propertyId,
        amount: amount,
        currency: 'NGN',
        status: 'Pending',
        method: 'Bank Transfer',
        requestedAt: DateTime.now(),
        notes: notes,
      );

      final created = await paymentRepository.createWithdrawal(withdrawal);

      return Response.ok(
        jsonEncode({
          'message': 'Withdrawal request submitted. Amount has been reserved.',
          'withdrawal': created.toMap(),
          'previouslyAvailable': summary.withdrawableAmount,
          'nowReserved': amount,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Request withdrawal error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  /// GET /withdrawals/me - View own withdrawal history
  Future<Response> getMyWithdrawals(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      if (userId == null) return Response(401, body: jsonEncode({'message': 'Unauthorized'}));

      final withdrawals = await paymentRepository.getWithdrawalsByUser(userId);

      return Response.ok(jsonEncode({'withdrawals': withdrawals.map((w) => w.toMap()).toList()}));
    } catch (e) {
      return Response.internalServerError();
    }
  }

  /// GET /payments/summary - User dashboard (Tenant or Landowner/Manager)
  Future<Response> getPaymentSummary(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;

      if (userId == null || role == null) return unauthorized('Unauthorized');

      final payments = await paymentRepository.getPaymentsByUser(userId);
      final withdrawals = await paymentRepository.getWithdrawalsByUser(userId);

      final summary = _calculateUserSummary(payments, withdrawals, role, userId);

      return Response.ok(
        jsonEncode({'summary': summary.toMap(), 'message': 'Payment summary fetched successfully'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Get user payment summary error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  /// GET /payments/property/<propertyId>/summary
  Future<Response> getPropertyPaymentSummary(Request request) async {
    try {
      final propertyId = request.params['propertyId'];
      if (propertyId == null) return badRequest('propertyId is required');

      final payments = await paymentRepository.getPaymentsByProperty(propertyId);

      final summary = await _calculatePropertySummary(payments, propertyId);

      return Response.ok(
        jsonEncode({
          'summary': summary.toMap(),
          'payments': payments.map((e) => e.toMap()).toList(),
          'message': 'Property summary fetched successfully',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Get property payment summary error: $e\n$stack');

      return Response.internalServerError();
    }
  }

  /// GET /payments/lease/<leaseId>/summary
  Future<Response> getLeasePaymentSummary(Request request) async {
    try {
      final leaseId = request.params['leaseId'];
      if (leaseId == null) return badRequest('leaseId is required');

      final payments = await paymentRepository.getPaymentsByLease(leaseId);
      final summary = await _calculateLeaseSummary(payments, leaseId);

      return Response.ok(
        jsonEncode({
          'summary': summary.toMap(),
          'payments': payments.map((e) => e.toMap()),

          'message': 'Lease summary fetched successfully',
        }),
      );
    } catch (e, stack) {
      print('Get lease payment summary error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  /// GET /payments/unit/<unitId>/summary
  Future<Response> getUnitPaymentSummary(Request request) async {
    try {
      final unitId = request.params['unitId'];
      if (unitId == null) return badRequest('unitId is required');

      final payments = await paymentRepository.getPaymentsByUnit(unitId);
      final summary = await _calculateUnitSummary(payments, unitId);

      return Response.ok(
        jsonEncode({
          'summary': summary.toMap(),
          'payments': payments.map((e) => e.toMap()),
          'message': 'Unit summary fetched successfully',
        }),
      );
    } catch (e, stack) {
      print('Get lease payment summary error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  PaymentSummaryModel _calculateUserSummary(
    List<PaymentModel> payments,
    List<WithdrawalModel> withdrawals,
    String role,
    String userId,
  ) {
    double totalReceived = 0.0;
    double totalPaid = 0.0;
    double totalWithdrawn = 0.0;
    int totalTransactions = 0;
    int pendingPayments = 0;
    int rentPaymentsCount = 0;
    double totalRentPaid = 0.0;

    for (var p in payments) {
      final lwStatus = p.status.toLowerCase();
      if (lwStatus == 'paid') {
        totalTransactions++;

        if (p.payerId == userId) {
          totalPaid += p.amount;

          if (p.type == 'rent' || p.type == 'rent-renewal') {
            rentPaymentsCount++;
            totalRentPaid += p.amount;
          }
        } else if (['landowner', 'manager'].contains(role)) {
          // We consider it received if it's a rent payment for properties they manage/own
          // (We'll improve this further when we have property ownership checks)
          totalReceived += p.amount;
        }
      } else if (lwStatus == 'pending payment') {
        pendingPayments++;
      }
    }

    for (var w in withdrawals) {
      if (w.status.toLowerCase() == 'completed') {
        totalWithdrawn += w.amount;
      }
    }

    return PaymentSummaryModel(
      totalReceived: totalReceived,
      totalPaid: totalPaid,
      totalWithdrawn: totalWithdrawn,
      balance: totalReceived - totalWithdrawn,
      totalTransactions: totalTransactions,
      pendingPayments: pendingPayments,
      avgRent: rentPaymentsCount > 0 ? totalRentPaid / rentPaymentsCount : 0.0,
      withdrawableAmount: totalReceived - totalWithdrawn,
      rentPaymentsCount: rentPaymentsCount,
      totalRentPaid: totalRentPaid,
      entityType: 'user',
      entityId: userId,
    );
  }

  Future<PaymentSummaryModel> _calculatePropertySummary(
    List<PaymentModel> payments,
    String propertyId,
  ) async {
    double totalRevenue = 0.0;
    double totalTaskPayments = 0.0;
    double totalWithdrawn = 0.0;
    double pendingWithdrawals = 0.0; // NEW: Reserved amount
    int totalPayments = 0;
    int pendingPayments = 0;
    int rentPaymentsCount = 0;

    // Process Payments
    for (var p in payments) {
      final status = p.status.toLowerCase();
      final amount = p.amount;

      if (status == 'paid') {
        totalPayments++;
        if (p.type == 'rent' || p.type == 'rent-renewal') {
          totalRevenue += amount;
          rentPaymentsCount++;
        } else if (p.type == 'task') {
          totalTaskPayments += amount;
        }
      } else if (status == 'pending' || status == 'pending payment') {
        pendingPayments++;
      }
    }
    // Get withdrawals linked to this property
    final withdrawals = await paymentRepository.getWithdrawalsByProperty(propertyId);
    // Process Withdrawals
    for (var w in withdrawals) {
      final status = w.status.toLowerCase();
      if (status == 'completed') {
        totalWithdrawn += w.amount;
      } else if (status == 'pending') {
        pendingWithdrawals += w.amount; // Reserved
      }
    }

    final availableBalance = totalRevenue - totalWithdrawn - pendingWithdrawals;

    return PaymentSummaryModel(
      totalReceived: totalRevenue,
      totalPaid: totalTaskPayments,
      totalWithdrawn: totalWithdrawn,
      balance: availableBalance,
      totalTransactions: totalPayments,
      pendingPayments: pendingPayments,
      avgRent: rentPaymentsCount > 0 ? totalRevenue / rentPaymentsCount : 0.0,
      withdrawableAmount: availableBalance,
      rentPaymentsCount: rentPaymentsCount,
      totalRentPaid: totalRevenue,
      entityType: 'property',
      entityId: propertyId,
    );
  }

  Future<PaymentSummaryModel> _calculateLeaseSummary(List<PaymentModel> payments, String leaseId) async {
    final summary = await _calculatePropertySummary(payments, leaseId);

    return summary.copyWith(entityType: 'lease');
  }

  Future<PaymentSummaryModel> _calculateUnitSummary(List<PaymentModel> payments, String unitId) async {
    final summary = await _calculatePropertySummary(payments, unitId);

    return summary.copyWith(entityType: 'unit');
  }

  /// POST /payout-accounts - Save bank account for withdrawals
  Future<Response> savePayoutAccount(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;

      if (userId == null || !['landowner', 'manager'].contains(role)) {
        return Response(
          403,
          body: jsonEncode({'message': 'Only landowners/managers can save payout accounts'}),
        );
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;

      final propertyId = body['propertyId'] as String?;
      final accountName = body['accountName'] as String?;
      final accountNumber = body['accountNumber'] as String?;
      final bankName = body['bankName'] as String?;
      final bankCode = body['bankCode'] as String?;
      final isDefault = body['isDefault'] as bool? ?? false;

      if (accountName == null || accountNumber == null || bankName == null || bankCode == null) {
        return badRequest('accountName, accountNumber, bankName and bankCode are required');
      }

      final accounts = await paymentRepository.getPayoutAccounts(userId);

      if (accounts.length == 5) {
        return badRequest('You can only add a total of 5 accounts');
      }

      String? subaccountId;

      // Create Paystack Subaccount
      subaccountId = await paystackService.createSubaccount(
        businessName: "${body['accountName']} - ${userId.substring(0, 8)}",
        bankCode: body['bankCode'],
        accountNumber: body['accountNumber'],
      );

      // Verify with Paystack
      final resolved = await paystackService.resolveBankAccount(
        accountNumber: accountNumber,
        bankCode: bankCode,
      );

      final String? verifiedName = resolved['account_name'];

      final account = PayoutAccountModel(
        id: '',
        userId: userId,
        propertyId: propertyId,
        accountName: verifiedName ?? accountName,
        accountNumber: accountNumber,
        paystackSubaccountId: subaccountId,
        bankName: bankName,
        bankCode: bankCode,
        isDefault: isDefault,
        createdAt: DateTime.now(),
      );

      final saved = await paymentRepository.savePayoutAccount(account);

      return Response.ok(
        jsonEncode({'message': 'Payout account saved successfully', 'account': saved.toMap()}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Save payout account error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  /// DELETE /payout-accounts/<id>
  Future<Response> removePayoutAccount(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final accountId = request.params['id'];

      if (userId == null || accountId == null) {
        return badRequest('Account ID is required');
      }

      final account = await paymentRepository.getPayoutAccountById(accountId);
      if (account == null || account.userId != userId) {
        return Response(403, body: jsonEncode({'message': 'Payout account not found or unauthorized'}));
      }

      if (account.isDefault) {
        return Response(
          400,
          body: jsonEncode({
            'message':
                'Cannot delete the default payout account. Please set another account as default first.',
          }),
        );
      }

      // Delete subaccount from Paystack if it exists
      if (account.paystackSubaccountId != null) {
        final deleted = await paystackService.deleteSubaccount(account.paystackSubaccountId!);
        if (!deleted) {
          print('⚠️ Failed to delete subaccount from Paystack: ${account.paystackSubaccountId}');
        }
      }

      await paymentRepository.removePayoutAccount(accountId);

      return Response.ok(jsonEncode({'message': 'Payout account removed successfully'}));
    } catch (e, stack) {
      print('Remove payout account error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  /// PATCH /payout-accounts/<id>/default - Set an account as default
  Future<Response> setDefaultPayoutAccount(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final accountId = request.params['id'];

      if (userId == null || accountId == null) {
        return badRequest('Account ID is required');
      }

      // Verify the account belongs to the user
      final accounts = await paymentRepository.getPayoutAccounts(userId);
      final targetAccount = accounts.where((a) => a.id == accountId).firstOrNull;

      if (targetAccount == null) {
        return Response(
          404,
          body: jsonEncode({'message': 'Payout account not found or does not belong to you'}),
        );
      }

      if (targetAccount.paystackSubaccountId == null) {
        // Create subaccount if not already created
        final subaccountId = await paystackService.createSubaccount(
          businessName: targetAccount.accountName,
          bankCode: targetAccount.bankCode,
          accountNumber: targetAccount.accountNumber,
        );

        if (subaccountId != null) {
          // Update account with subaccountId
          await paymentRepository.updatePayoutAccount(
            targetAccount.copyWith(paystackSubaccountId: subaccountId),
          );
        }
      }

      // Set the selected account as default and unset others
      await paymentRepository.setDefaultPayoutAccount(accountId, userId);

      return Response.ok(
        jsonEncode({'message': 'Account set as default successfully', 'accountId': accountId}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Set default payout account error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to set default account'}));
    }
  }

  /// PATCH /payout-accounts/<id> - Update payout account
  Future<Response> updatePayoutAccount(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final accountId = request.params['id'];

      if (userId == null || accountId == null) {
        return badRequest('Account ID is required');
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;

      final existing = await paymentRepository.getPayoutAccountById(accountId);
      if (existing == null || existing.userId != userId) {
        return Response(403, body: jsonEncode({'message': 'Payout account not found or unauthorized'}));
      }

      String? newSubaccountId;

      // If bank details changed, create new subaccount
      if (body['bankCode'] != null || body['accountNumber'] != null) {
        newSubaccountId = await paystackService.createSubaccount(
          businessName: body['accountName'] ?? existing.accountName,
          bankCode: body['bankCode'] ?? existing.bankCode,
          accountNumber: body['accountNumber'] ?? existing.accountNumber,
        );
      }

      final updatedAccount = existing.copyWith(
        accountName: body['accountName'],
        bankCode: body['bankCode'],
        accountNumber: body['accountNumber'],
        isDefault: body['isDefault'],
        paystackSubaccountId: newSubaccountId ?? existing.paystackSubaccountId,
        updatedAt: DateTime.now(),
      );

      await paymentRepository.updatePayoutAccount(updatedAccount);

      return Response.ok(
        jsonEncode({'message': 'Payout account updated successfully', 'account': updatedAccount.toMap()}),
      );
    } catch (e, stack) {
      print('Update payout account error: $e\n$stack');
      return Response.internalServerError();
    }
  }

  /// GET /payout-accounts - Get all payout accounts for current user
  Future<Response> getPayoutAccounts(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      if (userId == null) return unauthorized("Unauthorized");

      final accounts = await paymentRepository.getPayoutAccounts(userId);

      return Response.ok(
        jsonEncode({'accounts': accounts.map((a) => a.toMap()).toList()}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Get payout account error: $e\n$stack');

      return Response.internalServerError();
    }
  }

  /// GET /payout-accounts/property/<propertyId>
  Future<Response> getPayoutAccountsByProperty(Request request) async {
    try {
      final propertyId = request.params['propertyId'];
      if (propertyId == null) return badRequest('propertyId required');

      final accounts = await paymentRepository.getPayoutAccounts(
        request.context['userId'] as String,
        propertyId: propertyId,
      );

      return Response.ok(jsonEncode({'accounts': accounts.map((a) => a.toMap()).toList()}));
    } catch (e) {
      return Response.internalServerError();
    }
  }

  /// POST /resolve-bank-account - Verify account without saving
  Future<Response> resolveBankAccount(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;

      final accountNumber = body['accountNumber'] as String?;
      final bankCode = body['bankCode'] as String?;

      if (accountNumber == null || bankCode == null) {
        return badRequest('accountNumber and bankCode required');
      }

      final result = await paystackService.resolveBankAccount(
        accountNumber: accountNumber,
        bankCode: bankCode,
      );

      return Response.ok(
        jsonEncode({
          'message': 'Account resolved successfully',
          'accountName': result['account_name'],
          'bankName': result['bank_name'],
        }),
      );
    } catch (e, s) {
      print("error :::: $e\n$s");
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to resolve account'}));
    }
  }

  /// GET /banks - Fetch all Nigerian banks (for frontend dropdown)
  Future<Response> getAllBanks(Request request) async {
    try {
      final banks = await paystackService.getAllBanks(country: 'nigeria');

      return Response.ok(
        jsonEncode({'message': 'Banks fetched successfully', 'banks': banks}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Get banks error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to fetch banks'}));
    }
  }

  Future<void> _sendRentSuccessNotifications(PaymentModel payment, LeaseModel lease, double amount) async {
    // Tenant notification
    await notificationRepository.create(
      NotificationModel(
        userId: payment.payerId,
        type: 'rent_payment_success',
        title: 'Rent Payment Successful',
        body: '₦${amount.toStringAsFixed(0)} paid successfully.',
        relatedId: payment.id,
        relatedCollection: 'payments',
        createdAt: DateTime.now(),
        id: '',
      ),
    );

    // Landowner notification
    await notificationRepository.create(
      NotificationModel(
        userId: lease.landownerId,
        type: 'rent_received',
        title: 'Rent Payment Received',
        body: '₦${amount.toStringAsFixed(0)} received from tenant.',
        relatedId: payment.id,
        relatedCollection: 'payments',
        createdAt: DateTime.now(),
        id: '',
      ),
    );

    // History entries
    await historyRepository.createHistoryEntry(
      HistoryEntryModel(
        userId: payment.payerId,
        type: payment.type ?? "payment-made",
        title: 'Rent Payment Successful',
        description: '₦${amount.toStringAsFixed(0)} paid for lease ${payment.leaseId}',
        relatedId: payment.id,
        relatedCollection: 'payments',
        timestamp: DateTime.now(),
        id: '',
      ),
    );
    await historyRepository.createHistoryEntry(
      HistoryEntryModel(
        userId: payment.receiverId!,
        type: payment.type ?? "rent-received",
        title: 'Rent Payment Received',
        description: '₦${amount.toStringAsFixed(0)} received from tenant',
        relatedId: payment.id,
        relatedCollection: 'payments',
        timestamp: DateTime.now(),
        id: '',
      ),
    );
  }
}
