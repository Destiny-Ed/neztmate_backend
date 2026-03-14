class Comment {
  final String id;
  final String postId; // reference to CommunityPost.id (or unitId if used for units)
  final String authorId; // user who commented
  final String content;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? parentId; // for threaded/replies (optional)
  final int likes;

  Comment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.content,
    required this.createdAt,
    this.updatedAt,
    this.parentId,
    this.likes = 0,
  });

  factory Comment.fromMap(Map<String, dynamic> map, String id) {
    return Comment(
      id: id,
      postId: map['postId'] as String,
      authorId: map['authorId'] as String,
      content: map['content'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt'] as String) : null,
      parentId: map['parentId'] as String?,
      likes: map['likes'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'postId': postId,
    'authorId': authorId,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'parentId': parentId,
    'likes': likes,
  };

  Comment copyWith({
    String? id,
    String? postId,
    String? authorId,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? parentId,
    int? likes,
  }) {
    return Comment(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      authorId: authorId ?? this.authorId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      parentId: parentId ?? this.parentId,
      likes: likes ?? this.likes,
    );
  }
}
