import 'package:neztmate_backend/features/location/handler/location_handler.dart';
import 'package:shelf_router/shelf_router.dart';

Router locationRoutes(LocationHandler handler) {
  final router = Router();
  router.get('/states', handler.getStates);
  router.get('/cities', handler.getCities); // ?state=Lagos
  return router;
}
