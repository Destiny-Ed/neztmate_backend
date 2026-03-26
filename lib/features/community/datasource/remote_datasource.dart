import 'package:neztmate_backend/features/community/models/comments_model.dart';
import 'package:neztmate_backend/features/community/models/community_post_model.dart';

abstract class CommunityRemoteDataSource {
  Future<CommunityPostModel> createPost(CommunityPostModel post);
  Future<CommunityPostModel> getPostById(String id);
  Future<List<CommunityPostModel>> getPostsByProperty(String propertyId);
  Future<void> updatePost(CommunityPostModel post);
  Future<void> deletePost(String id);
  Future<void> incrementLikes(String postId);

  // Comments
  Future<CommentModel> createComment(CommentModel comment);
  Future<List<CommentModel>> getCommentsByPost(String postId);
  Future<void> deleteComment(String id);
}
