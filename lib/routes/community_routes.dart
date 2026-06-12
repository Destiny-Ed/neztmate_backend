import 'package:neztmate_backend/features/community/handler/community_handler.dart';
import 'package:shelf_router/shelf_router.dart';

Router communityRoutes(CommunityHandler handler) {
  final router = Router();

  // POSTS
  router.post('/posts', handler.createPost);
  router.get('/posts/<postId>', handler.getPostById);
  router.get('/posts/property/<propertyId>', handler.getPostsByProperty);
  router.get('/feed', handler.getFeed);
  router.patch('/posts/<postId>', handler.updatePost);
  router.delete('/posts/<postId>', handler.deletePost);

  // LIKES
  router.post('/posts/<postId>/like', handler.likePost);

  // COMMENTS
  router.post('/posts/<postId>/comments', handler.addComment);
  router.get('/posts/<postId>/comments', handler.getComments);
  router.delete('/posts/<postId>/comments/<commentId>', handler.deleteComment);

  // POLLS
  router.post('/posts/<postId>/poll', handler.createPoll);
  router.post('/polls/<pollId>/vote', handler.votePoll);

  // REPORTS
  // router.post('/posts/<postId>/report', handler.reportPost);
  // router.post('/posts/<postId>/comments/<commentId>/report', handler.reportComment);

  return router;
}
