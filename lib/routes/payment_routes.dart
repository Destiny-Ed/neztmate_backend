import 'package:neztmate_backend/features/payments/handler/payment_handler.dart';
import 'package:shelf_router/shelf_router.dart';

Router paymentRoutes(PaymentHandler handler) {
  final router = Router();

  router.post('/', handler.recordPayment);
  router.post('/initialize/', handler.initializePayment);
  router.get('/me', handler.getMyPayments);
  router.patch('/<id>/mark-paid', handler.markAsPaid);

  router.post('/withdrawals', handler.requestWithdrawal);
  router.get('/withdrawals/me', handler.getMyWithdrawals);

  // /// Webhook from Paystack (NO auth middleware - must be public)
  // router.post('/webhook', handler.paystackWebhook);

  return router;
}
