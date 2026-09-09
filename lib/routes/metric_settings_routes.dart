import 'package:neztmate_backend/features/metrics/handler/metric_settings_handler.dart';

import 'package:shelf_router/shelf_router.dart';

Router settingsRoutes(MetricsSettingsHandler handler) {
  final router = Router();

  router.get('/application-fee', handler.getApplicationFee);
  router.put('/application-fee', handler.updateApplicationFee);

  return router;
}

Router metricsRoutes(MetricsSettingsHandler handler) {
  final router = Router();
  router.get('/revenue', handler.getRevenueMetrics);
  return router;
}
