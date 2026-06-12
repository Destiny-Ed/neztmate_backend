import 'package:neztmate_backend/features/community/models/comments_model.dart';
import 'package:neztmate_backend/features/community/models/community_post_model.dart';

abstract class CommunityRemoteDataSource {
  Future<CommunityPostModel> createPost(CommunityPostModel post);
  Future<CommunityPostModel> getPostById(String id);
  Future<List<CommunityPostModel>> getPostsByProperty(String propertyId);
  Future<List<CommunityPostModel>> getFeed({required List<String> propertyIds, int limit = 20});
  Future<void> updatePost(CommunityPostModel post);
  Future<void> deletePost(String id);
  Future<void> pinPost(String postId);

  Future<void> unpinPost(String postId);

  Future<bool> toggleLikePost({required String postId, required String userId});

  Future<bool> hasLikedPost({required String postId, required String userId});

  Future<int> getPostLikeCount(String postId);

  Future<CommentModel> createComment(CommentModel comment);
  Future<List<CommentModel>> getCommentsByPost(String postId);
  Future<void> deleteComment({required String postId, required String commentId});
  Future<int> getCommentCount(String postId);

  Future<void> createPoll(String postId, Map data);
  Future<void> votePoll(String pollId, Map data);
  // Future<void> reportPost(String postId, Map data);
  // Future<void> reportComment(String commentId, Map data);
  Future<void> markAnnouncementRead(String announcementId, String userId);
  Future<void> createEvent(Map data);
  Future<void> rsvpEvent(String eventId, String userId);
}
