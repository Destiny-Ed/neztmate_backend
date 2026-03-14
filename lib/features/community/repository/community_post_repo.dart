import 'package:neztmate_backend/features/community/models/community_post_model.dart';

abstract class CommunityPostRepository {
  Future<CommunityPostModel> createPost(CommunityPostModel post);
  Future<CommunityPostModel> getPostById(String id);
  Future<List<CommunityPostModel>> getPostsByProperty(String propertyId);
  Future<void> updatePost(CommunityPostModel post);
  Future<void> deletePost(String id);
  Future<void> incrementLikes(String id);
}
