import 'dart:convert';
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

  /// POST /community/posts - Create post
  Future createPost(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;

      if (userId == null || !['manager', 'landowner'].contains(role)) {
        return Response.forbidden(jsonEncode({'message': 'Only managers or landowners can create posts'}));
      }

      final body = jsonDecode(await request.readAsString());

      final post = CommunityPostModel.fromMap(
        body,
      ).copyWith(authorId: userId, createdAt: DateTime.now(), updatedAt: DateTime.now());

      final created = await communityRepository.createPost(post);

      return Response.ok(
        jsonEncode({'message': 'Post created', 'post': created.toMap()}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  /// GET /community/posts/<postId>
  Future getPostById(Request request) async {
    try {
      final postId = request.params['postId'];

      if (postId == null) {
        return Response.badRequest(body: jsonEncode({'message': 'postId required'}));
      }

      final post = await communityRepository.getPostById(postId);

      return Response.ok(jsonEncode(post.toMap()));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  /// GET /community/posts/property/<propertyId>
  Future getPostsByProperty(Request request) async {
    try {
      final propertyId = request.params['propertyId'];

      if (propertyId == null) {
        return Response.badRequest(body: jsonEncode({'message': 'propertyId required'}));
      }

      final posts = await communityRepository.getPostsByProperty(propertyId);

      return Response.ok(jsonEncode({'posts': posts.map((e) => e.toMap()).toList()}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  /// GET /community/feed?propertyIds=a,b,c
  Future getFeed(Request request) async {
    try {
      final ids = request.url.queryParameters['propertyIds'];

      final propertyIds = ids == null ? [] : ids.split(',').map((e) => e.trim()).toList();

      final posts = await communityRepository.getFeed(propertyIds: propertyIds.cast());

      return Response.ok(jsonEncode({'posts': posts.map((e) => e.toMap()).toList()}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  /// PATCH /community/posts/<postId>
  Future updatePost(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final postId = request.params['postId'];

      if (userId == null || postId == null) {
        return Response.unauthorized(jsonEncode({'message': 'Unauthorized'}));
      }

      if (!['manager', 'landowner'].contains(role)) {
        return Response.forbidden(jsonEncode({'message': 'No permission'}));
      }

      final existing = await communityRepository.getPostById(postId);
      if (existing.authorId != userId) {
        return Response.forbidden(jsonEncode({'message': 'Not post owner'}));
      }

      final body = jsonDecode(await request.readAsString());

      final updated = existing.copyWith(
        title: body['title'],
        content: body['content'],
        updatedAt: DateTime.now(),
      );

      await communityRepository.updatePost(updated);

      return Response.ok(jsonEncode({'message': 'Updated'}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  /// DELETE /community/posts/<postId>
  Future deletePost(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final role = request.context['role'] as String?;
      final postId = request.params['postId'];

      if (userId == null || postId == null) {
        return Response.unauthorized(jsonEncode({'message': 'Unauthorized'}));
      }

      final post = await communityRepository.getPostById(postId);

      final canDelete = post.authorId == userId || ['manager', 'landowner'].contains(role);

      if (!canDelete) {
        return Response.forbidden(jsonEncode({'message': 'Not allowed'}));
      }

      await communityRepository.deletePost(postId);

      return Response.ok(jsonEncode({'message': 'Deleted'}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  // LIKES

  /// POST /community/posts/<postId>/like
  Future likePost(Request request) async {
    try {
      final postId = request.params['postId'];
      final userId = request.context['userId'] as String?;

      if (postId == null || userId == null) {
        return Response.unauthorized(jsonEncode({'message': 'Unauthorized'}));
      }

      await communityRepository.toggleLikePost(postId: postId, userId: userId);

      return Response.ok(jsonEncode({'message': 'Toggled like'}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  // COMMENTS

  /// POST /community/posts/<postId>/comments
  Future addComment(Request request) async {
    try {
      final userId = request.context['userId'] as String?;
      final postId = request.params['postId'];

      if (userId == null || postId == null) {
        return Response.badRequest(body: jsonEncode({'message': 'Missing data'}));
      }

      final body = jsonDecode(await request.readAsString());

      final comment = CommentModel.fromMap(
        body,
      ).copyWith(authorId: userId, postId: postId, createdAt: DateTime.now());

      final created = await communityRepository.createComment(comment);

      return Response.ok(jsonEncode({'comment': created.toMap()}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  /// GET /community/posts/<postId>/comments
  Future getComments(Request request) async {
    try {
      final postId = request.params['postId'];

      if (postId == null) {
        return Response.badRequest(body: jsonEncode({'message': 'Missing PostId'}));
      }

      final comments = await communityRepository.getCommentsByPost(postId);

      final enrichedComments = await Future.wait(
        comments.map((comment) async {
          final user = await userRepository.getUserById(comment.authorId);
          return {'profilePhotoUrl': user.profilePhotoUrl, ...comment.toMap()};
        }),
      );

      return Response.ok(
        jsonEncode({'comments': enrichedComments, 'message': 'Post Comments'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  /// DELETE /community/posts/<postId>/comments/<commentId>
  Future deleteComment(Request request) async {
    try {
      final postId = request.params['postId'];
      final commentId = request.params['commentId'];

      await communityRepository.deleteComment(postId: postId!, commentId: commentId!);

      return Response.ok(jsonEncode({'message': 'Deleted'}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  // POLLS

  /// POST /community/posts/<postId>/poll
  Future createPoll(Request request) async {
    try {
      final postId = request.params['postId'];
      final body = jsonDecode(await request.readAsString());

      await communityRepository.createPoll(postId!, body);

      return Response.ok(jsonEncode({'message': 'Poll created'}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  /// POST /community/polls/<pollId>/vote
  Future votePoll(Request request) async {
    try {
      final pollId = request.params['pollId'];
      final body = jsonDecode(await request.readAsString());

      await communityRepository.votePoll(pollId!, body);

      return Response.ok(jsonEncode({'message': 'Vote recorded'}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  // REPORTS

  /// POST /community/posts/<postId>/report
  // Future reportPost(Request request) async {
  //   final postId = request.params['postId'];
  //   final userId = request.context['userId'] as String?;
  //   final body = jsonDecode(await request.readAsString());

  //   await communityRepository.reportPost(postId: postId!, userId: userId!, reason: body['reason']);

  //   return Response.ok(jsonEncode({'message': 'Reported'}));
  // }

  /// POST /community/comments/<commentId>/report
  // Future reportComment(Request request) async {
  //   final commentId = request.params['commentId'];
  //   final postId = request.params['postId'];
  //   final userId = request.context['userId'] as String?;
  //   final body = jsonDecode(await request.readAsString());

  //   await communityRepository.reportComment(
  //     postId: postId!,
  //     commentId: commentId!,
  //     userId: userId!,
  //     reason: body['reason'],
  //   );

  //   return Response.ok(jsonEncode({'message': 'Reported'}));
  // }
}
