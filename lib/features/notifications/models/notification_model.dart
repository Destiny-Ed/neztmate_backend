class NotificationModel {
  final String id;
  final String userId;
  final String type; // e.g. "application_approved", "new_message", "payment_received", "task_assigned"
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final String? relatedId; // ID of related entity (application, message, lease, task, etc.)
  final String? relatedCollection; // "applications", "messages", "leases", "tasks"
  final Map<String, dynamic>? data; // extra payload for deep linking

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.isRead = false,
    required this.createdAt,
    this.relatedId,
    this.relatedCollection,
    this.data,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map, String id) {
    return NotificationModel(
      id: id,
      userId: map['userId'] as String,
      type: map['type'] as String,
      title: map['title'] as String,
      body: map['body'] as String,
      isRead: map['isRead'] as bool? ?? false,
      createdAt: DateTime.parse(map['createdAt'] as String),
      relatedId: map['relatedId'] as String?,
      relatedCollection: map['relatedCollection'] as String?,
      data: map['data'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'type': type,
    'title': title,
    'body': body,
    'isRead': isRead,
    'createdAt': createdAt.toIso8601String(),
    'relatedId': relatedId,
    'relatedCollection': relatedCollection,
    'data': data,
  };

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? type,
    String? title,
    String? body,
    bool? isRead,
    DateTime? createdAt,
    String? relatedId,
    String? relatedCollection,
    Map<String, dynamic>? data,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      relatedId: relatedId ?? this.relatedId,
      relatedCollection: relatedCollection ?? this.relatedCollection,
      data: data ?? this.data,
    );
  }
}
