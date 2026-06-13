class CommunityPostModel {
  final String id;
  final String propertyId;
  final String authorId; // Usually manager or landowner
  final String title;
  final String content;
  final String type; // 'Announcement', 'Event', 'Alert'
  final List<String>? photoUrls;
  final int likesCount;
  final int commentsCount;
  final DateTime? eventTime;
  final DateTime createdAt;
  final DateTime? updatedAt;

  CommunityPostModel({
    this.id = "",
    required this.propertyId,
    required this.authorId,
    required this.title,
    required this.content,
    required this.type,
    this.photoUrls,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.eventTime,
    required this.createdAt,
    this.updatedAt,
  });

  factory CommunityPostModel.fromMap(Map<String, dynamic> map) {
    return CommunityPostModel(
      id: map['id'] as String,
      propertyId: map['propertyId'] as String,
      authorId: map['authorId'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      type: map['type'] as String,
      photoUrls: (map['photoUrls'] as List?)?.cast<String>(),
      likesCount: map['likesCount'] as int? ?? 0,
      commentsCount: map['commentsCount'] as int? ?? 0,
      eventTime: map['eventTime'] != null ? DateTime.parse(map['eventTime'] as String) : null,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt'] as String) : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'propertyId': propertyId,
    'authorId': authorId,
    'title': title,
    'content': content,
    'type': type,
    'photoUrls': photoUrls,
    'likesCount': likesCount,
    'commentsCount': commentsCount,
    'eventTime': eventTime?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  CommunityPostModel copyWith({
    String? id,
    String? propertyId,
    String? authorId,
    String? title,
    String? content,
    String? type,
    List<String>? photoUrls,
    int? likesCount,
    int? commentsCount,
    DateTime? eventTime,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CommunityPostModel(
      id: id ?? this.id,
      propertyId: propertyId ?? this.propertyId,
      authorId: authorId ?? this.authorId,
      title: title ?? this.title,
      content: content ?? this.content,
      type: type ?? this.type,
      photoUrls: photoUrls ?? this.photoUrls,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      eventTime: eventTime ?? this.eventTime,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
