import 'package:neztmate_backend/features/tenants/handler/tenant_handler.dart';
import 'package:shelf_router/shelf_router.dart';

Router tenantRoutes(TenantHandler handler) {
  final router = Router();

  router.get('/search', handler.searchTenants);
  router.get('/neighbors/<propertyId>/<tenantId>', handler.searchTenants);

  return router;
}
