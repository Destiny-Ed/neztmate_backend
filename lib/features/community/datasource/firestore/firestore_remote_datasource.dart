import 'package:dart_firebase_admin/firestore.dart';
import 'package:neztmate_backend/core/error.dart';
import 'package:neztmate_backend/features/community/datasource/remote_datasource.dart';
import 'package:neztmate_backend/features/community/models/comments_model.dart';
import 'package:neztmate_backend/features/community/models/community_post_model.dart';

class FirestoreCommunityDataSource implements CommunityRemoteDataSource {
  final Firestore firestore;

  FirestoreCommunityDataSource(this.firestore);

  CollectionReference get _posts => firestore.collection('community_posts');

  @override
  Future<CommunityPostModel> createPost(CommunityPostModel post) async {
    final docRef = _posts.doc(post.id.isNotEmpty ? post.id : null);
    final newPost = post.copyWith(id: docRef.id);
    await docRef.set(newPost.toMap());
    return newPost;
  }

  @override
  Future<CommunityPostModel> getPostById(String id) async {
    final doc = await _posts.doc(id).get();
    if (!doc.exists) throw NotFoundException('Community post', id);
    return CommunityPostModel.fromMap(doc.data() as Map<String, dynamic>, id);
  }

  @override
  Future<List<CommunityPostModel>> getPostsByProperty(String propertyId) async {
    final snap = await _posts
        .where('propertyId', WhereFilter.equal, propertyId)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => CommunityPostModel.fromMap(d.data(), d.id)).toList();
  }

  @override
  Future<void> updatePost(CommunityPostModel post) async {
    await _posts.doc(post.id).update(post.toMap());
  }

  @override
  Future<void> deletePost(String id) async {
    await _posts.doc(id).delete();
  }

  @override
  Future<void> incrementLikes(String postId) async {
    await _posts.doc(postId).update({'likes': FieldValue.increment(1)});
  }

  // Comments
  @override
  Future<CommentModel> createComment(CommentModel comment) async {
    final docRef = _posts.doc(comment.postId).collection('comments').doc();
    final newComment = comment.copyWith(id: docRef.id);
    await docRef.set(newComment.toMap());
    return newComment;
  }

  @override
  Future<List<CommentModel>> getCommentsByPost(String postId) async {
    final snap = await _posts.doc(postId).collection('comments').orderBy('createdAt', descending: true).get();
    return snap.docs.map((d) => CommentModel.fromMap(d.data(), d.id)).toList();
  }

  @override
  Future<void> deleteComment(String id) async {
    // Note: For subcollection, you need postId + commentId. For simplicity, assuming you pass full path or adjust logic.
    // This is a simplified version — you can enhance it.
    // For now, we assume you delete by comment ID if you store comment ID globally.
    await firestore.collectionGroup('comments').where('__name__', WhereFilter.equal, id).get().then((snap) {
      for (var doc in snap.docs) {
        doc.ref.delete();
      }
    });
  }
}
