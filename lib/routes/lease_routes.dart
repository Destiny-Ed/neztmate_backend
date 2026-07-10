import 'package:neztmate_backend/features/leases/handler/lease_handler.dart';
import 'package:shelf_router/shelf_router.dart';

Router leaseRoutes(LeaseHandler handler) {
  final router = Router();

  router.get('/me', handler.getMyLeases);
  router.get('/landowner/me', handler.getLandownerLeases);
  router.get('/<id>', handler.getLeaseById);
  router.get('/application/<id>', handler.getLeaseByApplicationId);
  router.patch('/<id>/sign', handler.signLease);
  router.patch('/<id>/terminate', handler.terminateLeaseByLandowner);
  router.get('/property/<propertyId>', handler.getLeasesByProperty);
  router.patch('/<id>/status', handler.updateLeaseStatus);

  router.patch('/<id>/confirm-payment', handler.confirmPaymentReceived);

  // Lease Transfer (Tenant-initiated)
  router.post('/<id>/transfer', handler.requestLeaseTransfer);
  router.patch('/<id>/approve-transfer', handler.approveLeaseTransfer);
  router.patch('/<id>/reject-transfer', handler.rejectLeaseTransfer);

  // Early Termination (Tenant-initiated)
  router.post('/<id>/early-termination', handler.requestEarlyTermination);

  router.patch('/<id>/settlement/dispute', handler.disputeSettlement);
  router.patch('/<id>/settlement/resolve', handler.resolveSettlementDispute);

  return router;
}
