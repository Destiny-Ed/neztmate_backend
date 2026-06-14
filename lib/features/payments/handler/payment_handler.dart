import 'dart:convert';
import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/core/services/payment/paystack_service.dart';
import 'package:neztmate_backend/features/history/model/user_history_model.dart';
import 'package:neztmate_backend/features/history/repository/user_history_repo.dart';
import 'package:neztmate_backend/features/leases/repository/lease_repo.dart';
import 'package:neztmate_backend/features/notifications/models/notification_model.dart';
import 'package:neztmate_backend/features/notifications/repository/notification_repo.dart';
import 'package:neztmate_backend/features/payments/models/payment_summary_model.dart';
import 'package:neztmate_backend/features/payments/models/payments.dart';
import 'package:neztmate_backend/features/payments/models/withdrawal_model.dart';
import 'package:neztmate_backend/features/payments/repository/payment_repo.dart';
import 'package:neztmate_backend/features/units/repository/unit_repo.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class PaymentHandler {
  final PaymentRepository paymentRepository;
  final LeaseRepository leaseRepository;
  final HistoryRepository historyRepository;
  final UnitRepository unitRepository;
  final NotificationRepository notificationRepository;

  PaymentHandler(
    this.paymentRepository,
    this.leaseRepository,
    this.historyRepository,
    this.notificationRepository,
    this.unitRepository,
  );

  final PaystackService paystackService = PaystackService();

  /// POST /payments/initialize - Tenant starts rent payment
  Future<Response> initializePayment(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      if (userId == null) return unauthorized("User not found");

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final leaseId = body['leaseId'] as String?;
      final propertyId = body['propertyId'] as String?;
      final unitId = body['unitId'] as String?;
      final amount = (body['amount'] as num).toDouble();
      final email = (body['email'] as String?);
      final paymentType = (body['paymentType'] as String?);

      if (leaseId == null || email == null || propertyId == null || unitId == null || amount <= 0) {
        return badRequest('leaseId, propertyId, unitId, email and valid amount are required');
      }

      if (!['rent', 'task', 'rent-renewal'].contains(paymentType)) {
        return badRequest('Invalid paymentType');
      }

      final reference = 'nm_${DateTime.now().millisecondsSinceEpoch}';

      final initData = await paystackService.initializeTransaction(
        email: email,
        amount: amount,
        reference: reference,
        metadata: {
          'userId': userId,
          'leaseId': leaseId,
          'unitId': unitId,
          'propertyId': propertyId,
          'type': paymentType,
        },
      );

      // Save pending payment
      final pendingPayment = PaymentModel(
        id: '',
        leaseId: leaseId,
        payerId: userId,
        propertyId: propertyId,
        unitId: unitId,
        amount: amount,
        status: 'Pending',
        method: 'Paystack',
        transactionRef: reference,
        type: paymentType,
        createdAt: DateTime.now(),
      );

      await paymentRepository.createPayment(pendingPayment);

      return Response.ok(
        jsonEncode({'authorization_url': initData['authorization_url'], 'reference': reference}),
      );
    } catch (e) {
      print("Error initializing payment: $e");
      return Response.internalServerError();
    }
  }

  /// POST /payments/webhook - Paystack sends confirmation
  Future<Response> paystackWebhook(Request request) async {
    print("starting webhook");

    try {
      final signature = request.headers['x-paystack-signature'];
      final bodyString = await request.readAsString();

      print("Paystack event received $bodyString");

      if (!paystackService.verifySignature(bodyString, signature)) {
        print('Invalid Paystack signature $signature');
        return Response(400, body: jsonEncode({'message': 'Invalid signature'}));
      }
      print('✅ Signature validation PASSED');

      final body = jsonDecode(bodyString);
      final event = body['event'] as String?;

      if (event == 'charge.success') {
        final data = body['data'] as Map<String, dynamic>;
        final reference = data['reference'] as String;
        final receiptUrl = data['receipt_url'] as String?;
        final amount = (data['amount'] as num) / 100; // from kobo to Naira

        // === IDEMPOTENCY CHECK ===
        final alreadyProcessed = await paymentRepository.isPaymentAlreadyProcessed(reference);
        if (alreadyProcessed) {
          print('Payment already processed (idempotency): $reference');
          return Response.ok('Already processed');
        }

        // Mark as processed first (to prevent duplicates)
        await paymentRepository.markPaymentAsProcessed(reference);

        // 1. Update payment status
        await paymentRepository.markAsPaidByReference(reference, receiptUrl ?? '', reference);

        // 2. Get the payment to know leaseId and tenant

        final payment = await paymentRepository.getPaymentByReference(reference);

        if (payment.leaseId != null) {
          // 3. Update Lease status to Active (since payment was made)
          if (payment.type?.toLowerCase() == 'rent-renewal') {
            await leaseRepository.renewLeaseAfterPayment(payment.leaseId!);
          } else if (payment.type?.toLowerCase() == 'rent') {
            //Set as 'Active' if it's a first rent payment, but for task payments we don't change lease status
            await leaseRepository.updateLeaseStatus(payment.leaseId!, "Active");
          } else {
            //task payment - no lease update needed
          }

          final lease = await leaseRepository.getLeaseById(payment.leaseId!);

          await unitRepository.updateUnitStatus(
            unitId: lease.unitId,
            status: 'occupied',
            currentTenantId: lease.tenantId,
            isListedForRent: false,
          );

          // 4. Log History for Tenant
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

          // 5. Log History for Landowner (if you have landownerId in payment)
          if (payment.receiverId != null) {
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

          // 6. Send Notifications
          await notificationRepository.create(
            NotificationModel(
              userId: payment.payerId,
              type: payment.type ?? "payment-success",
              title: 'Payment Successful',
              body: 'Your rent payment of ₦${amount.toStringAsFixed(0)} has been confirmed.',
              relatedId: payment.id,
              relatedCollection: 'payments',
              createdAt: DateTime.now(),
              id: '',
            ),
          );

          if (payment.receiverId != null) {
            await notificationRepository.create(
              NotificationModel(
                userId: payment.receiverId!,
                type: payment.type ?? "rent-received",
                title: 'Rent Payment Received',
                body: 'You received ₦${amount.toStringAsFixed(0)} from tenant.',
                relatedId: payment.id,
                relatedCollection: 'payments',
                createdAt: DateTime.now(),
                id: '',
              ),
            );
          }
        }
      }

      return Response.ok('Webhook received successfully');
    } catch (e, stack) {
      print('Webhook error: $e\n$stack');
      return Response.ok('Webhook received with errors');
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

  /// PATCH /withdrawals/<id>/approve
  Future<Response> approveWithdrawal(Request request) async {
    try {
      final withdrawalId = request.params['id'];
      final processedBy = request.context['userId'] as String?;
      final role = request.context['role'] as String?;

      if (withdrawalId == null || processedBy == null) {
        return badRequest('Withdrawal ID is required');
      }

      if (!['landowner', 'manager'].contains(role)) {
        return Response(403, body: jsonEncode({'message': 'Insufficient permission'}));
      }

      final withdrawal = await paymentRepository.getWithdrawalById(withdrawalId);

      // Check if already processed
      if (withdrawal.status != 'Pending') {
        return Response(400, body: jsonEncode({'message': 'This withdrawal has already been processed'}));
      }

      await paymentRepository.approveWithdrawal(withdrawalId, processedBy);

      // Log history
      await historyRepository.createHistoryEntry(
        HistoryEntryModel(
          userId: withdrawal.userId,
          type: 'withdrawal_approved',
          title: 'Withdrawal Approved',
          description: '₦${withdrawal.amount} withdrawal request approved',
          relatedId: withdrawalId,
          relatedCollection: 'withdrawals',
          timestamp: DateTime.now(),
          id: '',
        ),
      );

      return Response.ok(
        jsonEncode({
          'message': 'Withdrawal approved and funds released successfully',
          'withdrawalId': withdrawalId,
        }),
      );
    } catch (e, stack) {
      print('Approve withdrawal error: $e\n$stack');
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
        return Response(400, body: jsonEncode({'message': 'This withdrawal has already been processed'}));
      }

      await paymentRepository.rejectWithdrawal(withdrawalId, processedBy, reason);

      await historyRepository.createHistoryEntry(
        HistoryEntryModel(
          userId: withdrawal.userId,
          type: 'withdrawal_rejected',
          title: 'Withdrawal Rejected',
          description: reason ?? 'Withdrawal request rejected',
          relatedId: withdrawalId,
          relatedCollection: 'withdrawals',
          timestamp: DateTime.now(),
          id: '',
        ),
      );

      return Response.ok(
        jsonEncode({'message': 'Withdrawal request rejected', 'withdrawalId': withdrawalId}),
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

  /// POST /withdrawals - Landowner/Manager requests withdrawal from a specific property
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
      final method = body['method'] as String?;
      final notes = body['notes'] as String?;

      if (propertyId == null) {
        return badRequest('propertyId is required');
      }

      if (amount == null || amount <= 0) {
        return badRequest('Valid amount is required');
      }

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

      final withdrawal = WithdrawalModel(
        id: '',
        userId: userId,
        propertyId: propertyId,
        amount: amount,
        currency: 'NGN',
        status: 'Pending',
        method: method ?? 'Bank Transfer',
        requestedAt: DateTime.now(),
        notes: notes,
      );

      final created = await paymentRepository.createWithdrawal(withdrawal);

      return Response.ok(
        jsonEncode({'message': 'Withdrawal request submitted successfully', 'withdrawal': created.toMap()}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Request withdrawal error: $e\n$stack');
      return Response.internalServerError(
        body: jsonEncode({'message': 'Failed to submit withdrawal request'}),
      );
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
        jsonEncode({'summary': summary.toMap(), 'message': 'Property summary fetched successfully'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
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
        jsonEncode({'summary': summary.toMap(), 'message': 'Lease summary fetched successfully'}),
      );
    } catch (e) {
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
        jsonEncode({'summary': summary.toMap(), 'message': 'Unit summary fetched successfully'}),
      );
    } catch (e) {
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
    int totalPayments = 0;
    int pendingCount = 0;
    int rentPaymentsCount = 0;

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
        pendingCount++;
      }
    }

    // Get withdrawals linked to this property
    final withdrawals = await paymentRepository.getWithdrawalsByProperty(propertyId);

    totalWithdrawn = withdrawals.fold(0.0, (sum, w) {
      if (w.status.toLowerCase() == 'completed') {
        return sum + w.amount;
      }
      return sum;
    });

    return PaymentSummaryModel(
      totalReceived: totalRevenue,
      totalPaid: totalTaskPayments,
      totalWithdrawn: totalWithdrawn,
      balance: totalRevenue - totalWithdrawn,
      totalTransactions: totalPayments,
      pendingPayments: pendingCount,
      avgRent: rentPaymentsCount > 0 ? totalRevenue / rentPaymentsCount : 0.0,
      withdrawableAmount: totalRevenue - totalWithdrawn,
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
}
