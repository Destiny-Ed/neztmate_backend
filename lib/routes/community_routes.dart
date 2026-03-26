import 'package:neztmate_backend/features/community/handler/community_handler.dart';
import 'package:shelf_router/shelf_router.dart';

Router communityRoutes(CommunityHandler handler) {
  final router = Router();

  router.post('/posts', handler.createPost);
  router.get('/posts/property/<propertyId>', handler.getPostsByProperty);
  router.post('/posts/<postId>/comments', handler.addComment);

  return router;
}
