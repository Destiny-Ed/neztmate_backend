class CommunityPostModel {
  final String id;
  final String propertyId;
  final String authorId; // usually manager or landowner
  final String title;
  final String content;
  final String type; // 'Announcement', 'Event', 'Alert'
  final List<String>? photoUrls;
  final int likes;
  final int commentsCount;
  final DateTime? eventTime;
  final DateTime createdAt;

  CommunityPostModel({
    required this.id,
    required this.propertyId,
    required this.authorId,
    required this.title,
    required this.content,
    required this.type,
    this.photoUrls,
    this.likes = 0,
    this.commentsCount = 0,
    this.eventTime,
    required this.createdAt,
  });

  factory CommunityPostModel.fromMap(Map<String, dynamic> map, String id) {
    return CommunityPostModel(
      id: id,
      propertyId: map['propertyId'] as String,
      authorId: map['authorId'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      type: map['type'] as String,
      photoUrls: (map['photoUrls'] as List<dynamic>?)?.cast<String>(),
      likes: map['likes'] as int? ?? 0,
      commentsCount: map['commentsCount'] as int? ?? 0,
      eventTime: map['eventTime'] != null ? DateTime.parse(map['eventTime'] as String) : null,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
    'propertyId': propertyId,
    'authorId': authorId,
    'title': title,
    'content': content,
    'type': type,
    'photoUrls': photoUrls,
    'likes': likes,
    'commentsCount': commentsCount,
    'eventTime': eventTime?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };

  CommunityPostModel copyWith({
    String? id,
    String? propertyId,
    String? authorId,
    String? title,
    String? content,
    String? type,
    List<String>? photoUrls,
    int? likes,
    int? commentsCount,
    DateTime? eventTime,
    DateTime? createdAt,
  }) {
    return CommunityPostModel(
      id: id ?? this.id,
      propertyId: propertyId ?? this.propertyId,
      authorId: authorId ?? this.authorId,
      title: title ?? this.title,
      content: content ?? this.content,
      type: type ?? this.type,
      photoUrls: photoUrls ?? this.photoUrls,
      likes: likes ?? this.likes,
      commentsCount: commentsCount ?? this.commentsCount,
      eventTime: eventTime ?? this.eventTime,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
