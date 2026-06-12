import 'dart:convert';
import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/features/auth_user/repositories/user_repository.dart';
import 'package:neztmate_backend/features/community/repository/community_post_repo.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../models/comments_model.dart';
import '../models/community_post_model.dart';

class CommunityHandler {
  final CommunityRepository communityRepository;
  final UserRepository userRepository;

  CommunityHandler(this.communityRepository, this.userRepository);

  // POSTS

  /// POST /community/posts - Create a new community post
  Future<Response> createPost(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;

      if (userId == null || !['manager', 'landowner'].contains(role)) {
        return Response.forbidden(jsonEncode({'message': 'Only managers or landowners can create posts'}));
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;

      if (body['propertyId'] == null) {
        return Response.badRequest(body: jsonEncode({'message': 'PropertyId is required'}));
      }

      if (body['title'] == null) {
        return Response.badRequest(body: jsonEncode({'message': 'Post title is required'}));
      }
      if (body['content'] == null) {
        return Response.badRequest(body: jsonEncode({'message': 'Post Content is required'}));
      }

      if (body['type'] == null) {
        return Response.badRequest(body: jsonEncode({'message': 'Post Type is required'}));
      }

      final post = CommunityPostModel.fromMap(
        body,
      ).copyWith(authorId: userId, createdAt: DateTime.now(), updatedAt: DateTime.now());

      final created = await communityRepository.createPost(post);

      return Response.ok(
        jsonEncode({'message': 'Post created successfully', 'post': created.toMap()}),
        headers: {'Content-Type': 'application/json'},
      );
    } on AppException catch (e) {
      return Response.badRequest(body: jsonEncode({'message': e.message}));
    } catch (e, stack) {
      print('Create post error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to create post'}));
    }
  }

  /// GET /community/posts/<postId>
  Future<Response> getPostById(Request request) async {
    try {
      final postId = request.params['postId'];
      if (postId == null) {
        return Response.badRequest(body: jsonEncode({'message': 'postId is required'}));
      }

      final post = await communityRepository.getPostById(postId);

      return Response.ok(jsonEncode({'post': post.toMap()}), headers: {'Content-Type': 'application/json'});
    } catch (e, stack) {
      print('Get post error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to fetch post'}));
    }
  }

  /// GET /community/posts/property/<propertyId>
  Future<Response> getPostsByProperty(Request request) async {
    try {
      final propertyId = request.params['propertyId'];
      if (propertyId == null) {
        return Response.badRequest(body: jsonEncode({'message': 'propertyId is required'}));
      }

      final posts = await communityRepository.getPostsByProperty(propertyId);

      return Response.ok(
        jsonEncode({'posts': posts.map((e) => e.toMap()).toList()}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Get posts by property error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to fetch posts'}));
    }
  }

  /// GET /community/feed?propertyIds=prop1,prop2
  Future<Response> getFeed(Request request) async {
    try {
      final ids = request.url.queryParameters['propertyIds'];
      final propertyIds =
          ids?.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList() ?? <String>[];

      final posts = await communityRepository.getFeed(propertyIds: propertyIds);

      return Response.ok(
        jsonEncode({'posts': posts.map((e) => e.toMap()).toList()}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Get feed error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to load feed'}));
    }
  }

  /// PATCH /community/posts/<postId>
  Future<Response> updatePost(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final postId = request.params['postId'];

      if (userId == null || postId == null) {
        return Response.unauthorized(jsonEncode({'message': 'Unauthorized'}));
      }

      if (!['Manager', 'Landowner'].contains(role)) {
        return Response.forbidden(jsonEncode({'message': 'Insufficient permissions'}));
      }

      final existing = await communityRepository.getPostById(postId);
      if (existing.authorId != userId) {
        return Response.forbidden(jsonEncode({'message': 'You can only edit your own posts'}));
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;

      final updated = existing.copyWith(
        title: body['title'],
        content: body['content'],
        updatedAt: DateTime.now(),
      );

      await communityRepository.updatePost(updated);

      return Response.ok(jsonEncode({'message': 'Post updated successfully'}));
    } catch (e, stack) {
      print('Update post error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to update post'}));
    }
  }

  /// DELETE /community/posts/<postId>
  Future<Response> deletePost(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final postId = request.params['postId'];

      if (userId == null || postId == null) {
        return Response.unauthorized(jsonEncode({'message': 'Unauthorized'}));
      }

      final post = await communityRepository.getPostById(postId);

      final isAuthor = post.authorId == userId;
      final isAdmin = ['Manager', 'Landowner'].contains(role);

      if (!isAuthor && !isAdmin) {
        return Response.forbidden(jsonEncode({'message': 'You do not have permission to delete this post'}));
      }

      await communityRepository.deletePost(postId);

      return Response.ok(jsonEncode({'message': 'Post deleted successfully'}));
    } catch (e, stack) {
      print('Delete post error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to delete post'}));
    }
  }

  // LIKES

  /// POST /community/posts/<postId>/like
  Future<Response> likePost(Request request) async {
    try {
      final postId = request.params['postId'];
      final userId = request.context['userId'] as String?;

      if (postId == null || userId == null) {
        return Response.unauthorized(jsonEncode({'message': 'Unauthorized'}));
      }

      final liked = await communityRepository.toggleLikePost(postId: postId, userId: userId);

      return Response.ok(jsonEncode({'message': liked ? 'Post liked' : 'Post unliked', 'liked': liked}));
    } catch (e, stack) {
      print('Like post error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to toggle like'}));
    }
  }

  // COMMENTS

  /// POST /community/posts/<postId>/comments
  Future<Response> addComment(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final postId = request.params['postId'];

      if (userId == null || postId == null) {
        return Response.badRequest(body: jsonEncode({'message': 'Missing userId or postId'}));
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;

      final comment = CommentModel.fromMap(
        body,
      ).copyWith(authorId: userId, postId: postId, createdAt: DateTime.now());

      final created = await communityRepository.createComment(comment);

      return Response.ok(
        jsonEncode({'message': 'Comment added', 'comment': created.toMap()}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Add comment error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to add comment'}));
    }
  }

  /// GET /community/posts/<postId>/comments
  Future<Response> getComments(Request request) async {
    try {
      final postId = request.params['postId'];
      if (postId == null) {
        return Response.badRequest(body: jsonEncode({'message': 'postId is required'}));
      }

      final comments = await communityRepository.getCommentsByPost(postId);

      final enrichedComments = await Future.wait(
        comments.map((comment) async {
          final user = await userRepository.getUserById(comment.authorId);
          return {
            ...comment.toMap(),
            'author': {'id': user.id, 'fullName': user.fullName, 'profilePhotoUrl': user.profilePhotoUrl},
          };
        }),
      );

      return Response.ok(
        jsonEncode({'comments': enrichedComments}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Get comments error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to load comments'}));
    }
  }

  /// DELETE /community/posts/<postId>/comments/<commentId>
  Future<Response> deleteComment(Request request) async {
    try {
      final postId = request.params['postId'];
      final commentId = request.params['commentId'];
      final userId = request.context['userId'] as String?;

      if (postId == null || commentId == null || userId == null) {
        return Response.badRequest(body: jsonEncode({'message': 'Missing required parameters'}));
      }

      await communityRepository.deleteComment(postId: postId, commentId: commentId);

      return Response.ok(jsonEncode({'message': 'Comment deleted successfully'}));
    } catch (e, stack) {
      print('Delete comment error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to delete comment'}));
    }
  }

  // POLLS

  /// POST /community/posts/<postId>/poll
  Future<Response> createPoll(Request request) async {
    try {
      final postId = request.params['postId'];
      if (postId == null) {
        return Response.badRequest(body: jsonEncode({'message': 'postId is required'}));
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;

      await communityRepository.createPoll(postId, body);

      return Response.ok(jsonEncode({'message': 'Poll created successfully'}));
    } catch (e, stack) {
      print('Create poll error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to create poll'}));
    }
  }

  /// POST /community/polls/<pollId>/vote
  Future<Response> votePoll(Request request) async {
    try {
      final pollId = request.params['pollId'];
      final userId = request.context['userId'] as String?;

      if (pollId == null || userId == null) {
        return Response.unauthorized(jsonEncode({'message': 'Unauthorized'}));
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;

      await communityRepository.votePoll(pollId, body);

      return Response.ok(jsonEncode({'message': 'Vote recorded successfully'}));
    } catch (e, stack) {
      print('Vote poll error: $e\n$stack');
      return Response.internalServerError(body: jsonEncode({'message': 'Failed to record vote'}));
    }
  }
}
