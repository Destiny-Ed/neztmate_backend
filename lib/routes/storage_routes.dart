import 'package:neztmate_backend/features/storage/handler/storage_handler.dart';
import 'package:shelf_router/shelf_router.dart';

Router storageRoutes(StorageHandler handler) {
  final router = Router();

  router.post('/upload', handler.upload);
  router.post('/upload-multiple', handler.uploadMultiple);
  // DELETE and POST both accepted (POST helps mobile clients send a JSON body)
  router.delete('/delete', handler.delete);
  router.post('/delete', handler.delete);

  return router;
}
