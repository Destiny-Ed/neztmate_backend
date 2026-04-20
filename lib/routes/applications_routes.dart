import 'package:neztmate_backend/features/applications/handler/application_handler.dart';
import 'package:shelf_router/shelf_router.dart';

Router applicationRoutes(ApplicationHandler handler) {
  final router = Router();

  router.post('/', handler.submitApplication);
  router.get('/me', handler.getMyApplications);
  router.get('/unit/<unitId>', handler.getApplicationsByUnit);
  router.get('/<id>', handler.getApplicationById);
  router.patch('/<id>/approve', handler.approveApplication);
  router.patch('/<id>/reject', handler.rejectApplication);

  router.patch('/<id>/withdraw', handler.withdrawApplication);

  return router;
}
