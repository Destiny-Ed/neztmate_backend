import 'dart:convert';
import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/core/services/payment/paystack_service.dart';
import 'package:neztmate_backend/features/payments/models/payments.dart';
import 'package:neztmate_backend/features/payments/models/withdrawal_model.dart';
import 'package:neztmate_backend/features/payments/repository/payment_repo.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class PaymentHandler {
  final PaymentRepository repository;

  PaymentHandler(this.repository);

  final PaystackService paystackService = PaystackService("dotenv.env['PAYSTACK_SECRET_KEY']!");

  /// POST /payments/initialize - Tenant starts rent payment
  Future<Response> initializePayment(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      if (userId == null) return unauthorized("User not found");

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final leaseId = body['leaseId'] as String?;
      final amount = (body['amount'] as num).toDouble();
      final email = (body['email'] as String);

      if (leaseId == null) {
        return badRequest('leaseId is required');
      }

      final reference = 'nm_${DateTime.now().millisecondsSinceEpoch}';

      final initData = await paystackService.initializeTransaction(
        email: email,
        amount: amount,
        reference: reference,
        metadata: {'userId': userId, 'leaseId': leaseId, 'type': 'rent'},
      );

      // Save pending payment
      final pendingPayment = PaymentModel(
        id: '',
        leaseId: leaseId,
        payerId: userId,
        amount: amount,
        status: 'Pending',
        method: 'Paystack',
        transactionRef: reference,
        createdAt: DateTime.now(),
      );

      await repository.createPayment(pendingPayment);

      return Response.ok(
        jsonEncode({'authorization_url': initData['authorization_url'], 'reference': reference}),
      );
    } catch (e) {
      return Response.internalServerError();
    }
  }

  /// POST /payments/webhook - Paystack sends confirmation
  /// POST /payments/webhook - Paystack webhook
  Future<Response> paystackWebhook(Request request) async {
    try {
      final signature = request.headers['x-paystack-signature'];
      final bodyString = await request.readAsString();

      // Critical: Verify signature
      if (!paystackService.verifySignature(bodyString, signature)) {
        print('Invalid Paystack webhook signature');
        return Response(400, body: jsonEncode({'message': 'Invalid signature'}));
      }

      final body = jsonDecode(bodyString);
      final event = body['event'] as String?;

      if (event == 'charge.success') {
        final data = body['data'] as Map<String, dynamic>;
        final reference = data['reference'] as String;
        final receiptUrl = data['receipt_url'] as String?;

        // Update payment status using reference
        await repository.markAsPaidByReference(reference, receiptUrl ?? '', reference);

        // Log history for tenant
        // You can expand this with actual tenant and landowner IDs

        print('Payment successful for reference: $reference');
      }

      // Always return 200 OK to acknowledge receipt
      return Response.ok('Webhook received');
    } catch (e, stack) {
      print('Webhook processing error: $e\n$stack');
      // Still return 200 so Paystack doesn't keep retrying
      return Response.ok('Webhook received with errors');
    }
  }

  /// POST /payments - Record a new payment (rent or task)
  Future<Response> recordPayment(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final payment = PaymentModel.fromMap(body, '');

      final created = await repository.createPayment(payment);

      return Response.ok(
        jsonEncode({'message': 'Payment recorded successfully', 'payment': created.toMap()}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to record payment'}));
    }
  }

  /// GET /payments/me - User views their payment history
  Future<Response> getMyPayments(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      if (userId == null) return Response(401, body: jsonEncode({'message': 'Unauthorized'}));

      final payments = await repository.getPaymentsByUser(userId);

      return Response.ok(
        jsonEncode({'payments': payments.map((p) => p.toMap()).toList()}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
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

      await repository.markAsPaid(id, receiptUrl ?? '', transactionRef);

      return Response.ok(jsonEncode({'message': 'Payment marked as paid'}));
    } catch (e) {
      return Response.internalServerError();
    }
  }

  /// POST /withdrawals - Landowner requests withdrawal
  Future<Response> requestWithdrawal(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;

      if (userId == null || !['landowner', 'manager'].contains(role)) {
        return Response(403, body: jsonEncode({'message': 'Only landowners can request withdrawals'}));
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final withdrawal = WithdrawalModel.fromMap(
        body,
        '',
      ).copyWith(userId: userId, requestedAt: DateTime.now());

      final created = await repository.createWithdrawal(withdrawal);

      return Response.ok(
        jsonEncode({'message': 'Withdrawal request submitted', 'withdrawal': created.toMap()}),
      );
    } catch (e) {
      return Response.internalServerError();
    }
  }

  /// GET /withdrawals/me - View own withdrawal history
  Future<Response> getMyWithdrawals(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      if (userId == null) return Response(401, body: jsonEncode({'message': 'Unauthorized'}));

      final withdrawals = await repository.getWithdrawalsByUser(userId);

      return Response.ok(jsonEncode({'withdrawals': withdrawals.map((w) => w.toMap()).toList()}));
    } catch (e) {
      return Response.internalServerError();
    }
  }
}
