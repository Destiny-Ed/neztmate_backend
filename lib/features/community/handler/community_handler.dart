import 'dart:convert';
import 'package:neztmate_backend/features/community/models/comments_model.dart';
import 'package:neztmate_backend/features/community/models/community_post_model.dart';
import 'package:neztmate_backend/features/community/repository/community_post_repo.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class CommunityHandler {
  final CommunityRepository repository;

  CommunityHandler(this.repository);

  /// POST /community/posts - Manager/Landowner creates a post
  Future<Response> createPost(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;

      if (userId == null || !['Manager', 'Landowner'].contains(role)) {
        return Response(403, body: jsonEncode({'message': 'Only managers or landowners can create posts'}));
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final post = CommunityPostModel.fromMap(body, '').copyWith(authorId: userId, createdAt: DateTime.now());

      final created = await repository.createPost(post);

      return Response.ok(
        jsonEncode({'message': 'Post created', 'post': created.toMap()}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError();
    }
  }

  /// GET /community/posts/property/<propertyId>
  Future<Response> getPostsByProperty(Request request) async {
    try {
      final propertyId = request.params['propertyId'];
      if (propertyId == null) return Response(400, body: jsonEncode({'message': 'Missing property ID'}));

      final posts = await repository.getPostsByProperty(propertyId);

      return Response.ok(
        jsonEncode({'posts': posts.map((p) => p.toMap()).toList()}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError();
    }
  }

  /// POST /community/posts/<postId>/comments - Add comment
  Future<Response> addComment(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final postId = request.params['postId'];

      if (userId == null || postId == null)
        return Response(400, body: jsonEncode({'message': 'Missing data'}));

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final comment = CommentModel.fromMap(
        body,
        '',
      ).copyWith(authorId: userId, postId: postId, createdAt: DateTime.now());

      final created = await repository.createComment(comment);

      return Response.ok(jsonEncode({'comment': created.toMap()}));
    } catch (e) {
      return Response.internalServerError();
    }
  }

  // Add more methods as needed (likePost, deletePost, etc.)
}
