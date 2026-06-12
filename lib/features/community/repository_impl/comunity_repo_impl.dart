import 'package:neztmate_backend/features/community/datasource/remote_datasource.dart';
import 'package:neztmate_backend/features/community/models/comments_model.dart';
import 'package:neztmate_backend/features/community/models/community_post_model.dart';
import 'package:neztmate_backend/features/community/repository/community_post_repo.dart';

class CommunityRepositoryImpl implements CommunityRepository {
  final CommunityRemoteDataSource dataSource;

  CommunityRepositoryImpl(this.dataSource);

  @override
  Future<CommunityPostModel> createPost(CommunityPostModel post) => dataSource.createPost(post);

  @override
  Future<CommunityPostModel> getPostById(String id) => dataSource.getPostById(id);

  @override
  Future<List<CommunityPostModel>> getPostsByProperty(String propertyId) =>
      dataSource.getPostsByProperty(propertyId);

  @override
  Future<void> updatePost(CommunityPostModel post) => dataSource.updatePost(post);

  @override
  Future<void> deletePost(String id) => dataSource.deletePost(id);

  @override
  Future<CommentModel> createComment(CommentModel comment) => dataSource.createComment(comment);

  @override
  Future<List<CommentModel>> getCommentsByPost(String postId) => dataSource.getCommentsByPost(postId);

  @override
  Future<int> getCommentCount(String postId) => dataSource.getCommentCount(postId);
  @override
  Future<List<CommunityPostModel>> getFeed({required List<String> propertyIds, int limit = 20}) =>
      dataSource.getFeed(propertyIds: propertyIds);

  @override
  Future<int> getPostLikeCount(String postId) => dataSource.getPostLikeCount(postId);

  @override
  Future<bool> hasLikedPost({required String postId, required String userId}) =>
      dataSource.hasLikedPost(postId: postId, userId: userId);

  @override
  Future<void> pinPost(String postId) => dataSource.pinPost(postId);

  @override
  Future<void> toggleLikePost({required String postId, required String userId}) =>
      dataSource.toggleLikePost(postId: postId, userId: userId);

  @override
  Future<void> unpinPost(String postId) => dataSource.unpinPost(postId);

  @override
  Future<void> deleteComment({required String postId, required String commentId}) =>
      dataSource.deleteComment(postId: postId, commentId: commentId);

  @override
  Future<void> createEvent(Map<dynamic, dynamic> data) {
    // TODO: implement createEvent
    throw UnimplementedError();
  }

  @override
  Future<void> createPoll(String postId, Map<dynamic, dynamic> data) {
    // TODO: implement createPoll
    throw UnimplementedError();
  }

  @override
  Future<void> markAnnouncementRead(String announcementId, String userId) {
    // TODO: implement markAnnouncementRead
    throw UnimplementedError();
  }

  // @override
  // Future<void> reportComment(String commentId, Map<dynamic, dynamic> data) {
  //   // TODO: implement reportComment
  //   throw UnimplementedError();
  // }

  // @override
  // Future<void> reportPost(String postId, Map<dynamic, dynamic> data) {
  //   // TODO: implement reportPost
  //   throw UnimplementedError();
  // }

  @override
  Future<void> rsvpEvent(String eventId, String userId) {
    // TODO: implement rsvpEvent
    throw UnimplementedError();
  }

  @override
  Future<void> votePoll(String pollId, Map<dynamic, dynamic> data) {
    // TODO: implement votePoll
    throw UnimplementedError();
  }
}
