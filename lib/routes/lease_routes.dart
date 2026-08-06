import 'package:neztmate_backend/features/leases/handler/lease_handler.dart';
import 'package:shelf_router/shelf_router.dart';

Router leaseRoutes(LeaseHandler handler) {
  final router = Router();

  // ====================== VIEW ======================
  router.get('/me', handler.getMyLeases);
  router.get('/<id>', handler.getLeaseById);
  router.get('/application/<id>', handler.getLeaseByApplicationId);
  router.get('/property/<propertyId>', handler.getLeasesByProperty);

  // ====================== SIGNING ======================
  router.patch('/<id>/sign', handler.signLease);

  // ====================== MANUAL LEASE ======================
  router.post('/manual', handler.createManualLease);

  // ====================== PAYMENT ======================
  router.patch('/<id>/confirm-payment', handler.confirmPaymentReceived);

  // ====================== STATUS ======================
  router.patch('/<id>/status', handler.updateLeaseStatus);

  // ====================== RENEWAL (OFFLINE) ======================
  router.post('/<id>/request-renewal', handler.requestRenewal); // Tenant
  router.post('/<id>/offer-renewal', handler.offerRenewal); // Landlord
  router.post('/<id>/confirm-renewal-payment', handler.confirmRenewalPayment); // Tenant uploads receipt
  router.post('/<id>/approve-renewal-payment', handler.approveRenewalPayment); // Landlord confirms

  // ====================== TRANSFER ======================
  router.post('/<id>/transfer', handler.requestLeaseTransfer);
  router.patch('/<id>/approve-transfer', handler.approveLeaseTransfer);
  router.patch('/<id>/reject-transfer', handler.rejectLeaseTransfer);

  // ====================== EARLY TERMINATION ======================
  router.post('/<id>/early-termination', handler.requestEarlyTermination);
  router.patch('/<id>/terminate', handler.terminateLeaseByLandowner);

  // ====================== RENT ADJUSTMENT ======================
  router.post('/<id>/adjust-rent', handler.proposeRentAdjustment);
  router.patch('/<id>/approve-rent-adjustment', handler.approveRentAdjustment);
  router.patch('/<id>/reject-rent-adjustment', handler.rejectRentAdjustment);

  // ====================== SETTLEMENT ======================
  router.patch('/<id>/settlement/accept', handler.acceptSettlement);
  router.patch('/<id>/settlement/dispute', handler.disputeSettlement);
  router.patch('/<id>/settlement/resolve', handler.resolveSettlementDispute);

  // ====================== REQUESTS (UNIFIED) ======================
  router.get('/requests', handler.getMyLeaseRequests);
  router.get('/requests/incoming', handler.getIncomingLeaseRequests);
  router.get('/<id>/request-details', handler.getLeaseRequestDetails);
  router.patch('/<id>/approve-request', handler.approveLeaseRequest);
  router.patch('/<id>/reject-request', handler.rejectLeaseRequest);

  return router;
}
