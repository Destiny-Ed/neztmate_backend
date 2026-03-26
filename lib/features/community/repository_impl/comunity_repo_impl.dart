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
  Future<void> likePost(String postId) => dataSource.incrementLikes(postId);

  @override
  Future<CommentModel> createComment(CommentModel comment) => dataSource.createComment(comment);

  @override
  Future<List<CommentModel>> getCommentsByPost(String postId) => dataSource.getCommentsByPost(postId);

  @override
  Future<void> deleteComment(String id) => dataSource.deleteComment(id);
}
