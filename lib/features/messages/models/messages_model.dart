class MessageModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String? propertyId; // optional context
  final String content;
  final List<String>? attachmentUrls;
  final DateTime createdAt;
  final DateTime? readAt;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    this.propertyId,
    required this.content,
    this.attachmentUrls,
    required this.createdAt,
    this.readAt,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map, String id) {
    return MessageModel(
      id: id,
      senderId: map['senderId'] as String,
      receiverId: map['receiverId'] as String,
      propertyId: map['propertyId'] as String?,
      content: map['content'] as String,
      attachmentUrls: (map['attachmentUrls'] as List<dynamic>?)?.cast<String>(),
      createdAt: DateTime.parse(map['createdAt'] as String),
      readAt: map['readAt'] != null ? DateTime.parse(map['readAt'] as String) : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'senderId': senderId,
    'receiverId': receiverId,
    'propertyId': propertyId,
    'content': content,
    'attachmentUrls': attachmentUrls,
    'createdAt': createdAt.toIso8601String(),
    'readAt': readAt?.toIso8601String(),
  };

  MessageModel copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? propertyId,
    String? content,
    List<String>? attachmentUrls,
    DateTime? createdAt,
    DateTime? readAt,
  }) {
    return MessageModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      propertyId: propertyId ?? this.propertyId,
      content: content ?? this.content,
      attachmentUrls: attachmentUrls ?? this.attachmentUrls,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
    );
  }
}
