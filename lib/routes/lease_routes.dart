import 'package:neztmate_backend/features/leases/handler/lease_handler.dart';
import 'package:shelf_router/shelf_router.dart';

Router leaseRoutes(LeaseHandler handler) {
  final router = Router();

  // View
  router.get('/me', handler.getMyLeases);
  router.get('/property/<propertyId>', handler.getLeasesByProperty);
  router.get('/application/<id>', handler.getLeaseByApplicationId);
  router.get('/<id>', handler.getLeaseById);

  // Sign / payment / status
  router.patch('/<id>/sign', handler.signLease);
  router.patch('/<id>/confirm-payment', handler.confirmPaymentReceived);
  router.patch('/<id>/status', handler.updateLeaseStatus);

  // Renewal
  router.post('/<id>/request-renewal', handler.requestRenewal);
  router.post('/<id>/offer-renewal', handler.offerRenewal);
  router.post('/<id>/confirm-renewal-payment', handler.confirmRenewalPayment);
  router.post('/<id>/approve-renewal-payment', handler.approveRenewalPayment);

  // Manual
  router.post('/manual', handler.createManualLease);

  // Requests (create on lease)
  router.post('/<id>/transfer', handler.requestLeaseTransfer);
  router.post('/<id>/early-termination', handler.requestEarlyTermination);
  router.post('/<id>/adjust-rent', handler.proposeRentAdjustment);
  router.patch('/<id>/terminate', handler.terminateLeaseByLandowner);

  router.get('/<id>/renewal-payment-summary', handler.getRenewalPaymentSummary);

  // Requests (act by requestId) — register BEFORE /<id> catch-alls if needed
  router.get('/requests/my-request', handler.getMyLeaseRequests);
  router.get('/requests/incoming', handler.getIncomingLeaseRequests);
  router.get('/requests/<requestId>', handler.getLeaseRequestById);
  router.patch('/requests/<requestId>/approve', handler.approveLeaseRequest);
  router.patch('/requests/<requestId>/reject', handler.rejectLeaseRequest);
  router.patch('/requests/<requestId>/cancel', handler.cancelLeaseRequest);

  // Settlement
  router.patch('/<id>/settlement/accept', handler.acceptSettlement);
  router.patch('/<id>/settlement/dispute', handler.disputeSettlement);
  router.patch('/<id>/settlement/resolve', handler.resolveSettlementDispute);

  /// Preview calculator only (no write)
  router.get('/<id>/settlement/preview', handler.previewTerminationSettlement);

  /// Create / propose settlement (saves on lease + lease_settlements)
  // router.post('/<id>/propose-settlement', handler.proposeTerminationSettlement);

  return router;
}
