import 'package:neztmate_backend/features/history/handler/history_handler.dart';
import 'package:shelf_router/shelf_router.dart';

Router historyRoutes(HistoryHandler handler) {
  final router = Router();

  router.get('/', handler.getMyHistory);

  return router;
}
