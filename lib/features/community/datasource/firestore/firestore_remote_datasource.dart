import 'package:dart_firebase_admin/firestore.dart';
import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/features/community/datasource/remote_datasource.dart';
import 'package:neztmate_backend/features/community/models/comments_model.dart';
import 'package:neztmate_backend/features/community/models/community_post_model.dart';

class FirestoreCommunityDataSource implements CommunityRemoteDataSource {
  final Firestore firestore;

  FirestoreCommunityDataSource(this.firestore);

  CollectionReference get _posts => firestore.collection('community_posts');

  // POSTS

  @override
  Future<CommunityPostModel> createPost(CommunityPostModel post) async {
    final docRef = post.id.isNotEmpty ? _posts.doc(post.id) : _posts.doc();

    final newPost = post.copyWith(id: docRef.id);
    await docRef.set(newPost.toMap());

    return newPost;
  }

  @override
  Future<CommunityPostModel> getPostById(String id) async {
    final doc = await _posts.doc(id).get();

    if (!doc.exists) {
      throw NotFoundException('Community post', id);
    }

    return CommunityPostModel.fromMap(doc.data() as Map<String, dynamic>);
  }

  @override
  Future<List<CommunityPostModel>> getPostsByProperty(String propertyId) async {
    final snap = await _posts
        .where('propertyId', WhereFilter.equal, propertyId)
        .orderBy('createdAt', descending: true)
        .get();

    return snap.docs.map((d) => CommunityPostModel.fromMap(d.data())).toList();
  }

  @override
  Future<void> updatePost(CommunityPostModel post) async {
    await _posts.doc(post.id).update(post.toMap());
  }

  @override
  Future<void> deletePost(String id) async {
    await _posts.doc(id).delete();
  }

  // FEED

  @override
  Future<List<CommunityPostModel>> getFeed({required List<String> propertyIds, int limit = 20}) async {
    if (propertyIds.isEmpty) return [];

    final snap = await _posts
        .where('propertyId', WhereFilter.arrayContains, propertyIds)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snap.docs.map((e) => CommunityPostModel.fromMap(e.data())).toList();
  }

  // LIKES

  @override
  Future<void> toggleLikePost({required String postId, required String userId}) async {
    final likeRef = _posts.doc(postId).collection('likes').doc(userId);
    final likeDoc = await likeRef.get();

    if (likeDoc.exists) {
      await likeRef.delete();

      await _posts.doc(postId).update({'likesCount': FieldValue.increment(-1)});
    } else {
      await likeRef.set({'userId': userId, 'createdAt': DateTime.now()});

      await _posts.doc(postId).update({'likesCount': FieldValue.increment(1)});
    }
  }

  @override
  Future<bool> hasLikedPost({required String postId, required String userId}) async {
    final doc = await _posts.doc(postId).collection('likes').doc(userId).get();
    return doc.exists;
  }

  @override
  Future<int> getPostLikeCount(String postId) async {
    final post = await _posts.doc(postId).get();
    return (post.data()?['likesCount'] ?? 0) as int;
  }

  @override
  Future<void> pinPost(String postId) async {
    await _posts.doc(postId).update({'pinned': true});
  }

  @override
  Future<void> unpinPost(String postId) async {
    await _posts.doc(postId).update({'pinned': false});
  }

  // COMMENTS

  @override
  Future<CommentModel> createComment(CommentModel comment) async {
    final docRef = _posts.doc(comment.postId).collection('comments').doc();

    final newComment = comment.copyWith(id: docRef.id);

    await docRef.set(newComment.toMap());

    await _posts.doc(comment.postId).update({'commentsCount': FieldValue.increment(1)});

    return newComment;
  }

  @override
  Future<List<CommentModel>> getCommentsByPost(String postId) async {
    final snap = await _posts.doc(postId).collection('comments').orderBy('createdAt', descending: true).get();

    return snap.docs.map((d) => CommentModel.fromMap(d.data())).toList();
  }

  @override
  Future<void> deleteComment({required String postId, required String commentId}) async {
    await _posts.doc(postId).collection('comments').doc(commentId).delete();

    await _posts.doc(postId).update({'commentsCount': FieldValue.increment(-1)});
  }

  @override
  Future<int> getCommentCount(String postId) async {
    final post = await _posts.doc(postId).get();
    return (post.data()?['commentsCount'] ?? 0) as int;
  }

  // REPORTING (NEW)

  // @override
  // Future<void> reportPost({required String postId, required String userId, required String reason}) async {
  //   final ref = _posts.doc(postId).collection('reports').doc();

  //   await ref.set({'userId': userId, 'reason': reason, 'createdAt': DateTime.now()});

  //   await _posts.doc(postId).update({'reportsCount': FieldValue.increment(1)});
  // }

  // Future<void> reportComment({
  //   required String postId,
  //   required String commentId,
  //   required String userId,
  //   required String reason,
  // }) async {
  //   final ref = _posts.doc(postId).collection('comments').doc(commentId).collection('reports').doc();

  //   await ref.set({'userId': userId, 'reason': reason, 'createdAt': DateTime.now()});
  // }

  // POLLS (STUB READY)

  @override
  Future<void> createPoll(String postId, Map data) async {
    final ref = _posts.doc(postId).collection('polls').doc();
    await ref.set({...data, 'createdAt': DateTime.now()});
  }

  @override
  Future<void> votePoll(String pollId, Map data) async {
    await firestore.collection('polls').doc(pollId).collection('votes').add({
      ...data,
      'createdAt': DateTime.now(),
    });
  }

  // EVENTS (STUB READY)

  @override
  Future<void> createEvent(Map data) async {
    final ref = firestore.collection('community_events').doc();
    await ref.set({...data, 'createdAt': DateTime.now()});
  }

  @override
  Future<void> rsvpEvent(String eventId, String userId) async {
    await firestore.collection('community_events').doc(eventId).collection('rsvps').doc(userId).set({
      'userId': userId,
      'createdAt': DateTime.now(),
    });
  }

  // ANNOUNCEMENTS (STUB READY)

  @override
  Future<void> markAnnouncementRead(String announcementId, String userId) async {
    await firestore.collection('announcements').doc(announcementId).collection('reads').doc(userId).set({
      'userId': userId,
      'readAt': DateTime.now(),
    });
  }
}
