import 'package:neztmate_backend/features/payments/handler/payment_handler.dart';
import 'package:shelf_router/shelf_router.dart';

Router paymentRoutes(PaymentHandler handler) {
  final router = Router();

  // PAYMENTS

  /// Initialize payment (Tenant starts rent/task payment)
  router.post('/initialize_payment', handler.initializePayment);

  // router.post('/record_payment', handler.recordPayment);

  router.get('/my_payments', handler.getMyPayments);

  // router.patch('/<id>/mark-paid', handler.markAsPaid);

  // PAYMENTS BY ENTITY

  router.get('/property/<propertyId>', handler.getPaymentsByProperty);

  router.get('/unit/<unitId>', handler.getPaymentsByUnit);

  router.get('/lease/<leaseId>', handler.getPaymentsByLease);

  // SUMMARY & ANALYTICS

  router.get('/summary', handler.getPaymentSummary);

  router.get('/property/<propertyId>/summary', handler.getPropertyPaymentSummary);
  router.get('/unit/<propertyId>/summary', handler.getUnitPaymentSummary);
  router.get('/lease/<propertyId>/summary', handler.getLeasePaymentSummary);

  // WITHDRAWALS

  // router.post('/withdrawals', handler.requestWithdrawal);

  router.get('/withdrawals/me', handler.getMyWithdrawals);

  router.patch('/withdrawals/<id>/approve', handler.approveWithdrawal);

  router.patch('/withdrawals/<id>/reject', handler.rejectWithdrawal);

  // Admin Routes
  router.post('/admin/withdraw-platform-fees', handler.withdrawPlatformFees);

  router.post('/payout-accounts/save', handler.savePayoutAccount);

  /// Get all payout accounts for current user
  router.get('/payout-accounts', handler.getPayoutAccounts);

  /// Get payout accounts for a specific property
  router.get('/payout-accounts/property/<propertyId>', handler.getPayoutAccountsByProperty);

  /// Remove a payout account
  router.delete('/payout-accounts/<id>/remove', handler.removePayoutAccount);

  //Set default payout account
  router.patch('/payout-accounts/<id>/default', handler.setDefaultPayoutAccount);

  return router;
}
