import 'package:neztmate_backend/features/properties/handler/property_handler.dart';
import 'package:shelf_router/shelf_router.dart';

Router propertyRoutes(PropertyHandler handler) {
  final router = Router();

  router.get('/all', handler.getMyProperties);
  router.get('/<id>', handler.getPropertyById);
  router.post('/create', handler.createProperty);
  router.patch('/<id>/update', handler.updateProperty);
  router.delete('/<id>/delete', handler.deleteProperty);

  return router;
}
