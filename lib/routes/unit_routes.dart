import 'package:neztmate_backend/features/properties/handler/property_handler.dart';
import 'package:shelf_router/shelf_router.dart';

Router propertyRoutes(PropertyHandler handler) {
  final router = Router();

  router.get('/', handler.getMyProperties);
  router.get('/<id>', handler.getPropertyById);
  router.post('/', handler.createProperty);
  router.patch('/<id>', handler.updateProperty);
  router.delete('/<id>', handler.deleteProperty);

  return router;
}
