class HistoryEntryModel {
  final String id;
  final String userId;
  final String partnerId;
  final String type;
  final String title;
  final String? description;
  final String? relatedId;
  final String? relatedCollection;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  HistoryEntryModel({
    required this.id,
    required this.userId,
    this.partnerId = 'neztmate',
    required this.type,
    required this.title,
    this.description,
    this.relatedId,
    this.relatedCollection,
    required this.timestamp,
    this.metadata,
  });

  factory HistoryEntryModel.fromMap(Map<String, dynamic> map, [String? id]) {
    return HistoryEntryModel(
      id: id ?? map['id'] as String? ?? '',
      userId: map['userId'] as String,
      partnerId: map['partnerId'] as String? ?? 'neztmate',
      type: map['type'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      relatedId: map['relatedId'] as String?,
      relatedCollection: map['relatedCollection'] as String?,
      timestamp: DateTime.parse(map['timestamp'] as String),
      metadata: map['metadata'] != null ? Map<String, dynamic>.from(map['metadata'] as Map) : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'partnerId': partnerId,
    'type': type,
    'title': title,
    'description': description,
    'relatedId': relatedId,
    'relatedCollection': relatedCollection,
    'timestamp': timestamp.toIso8601String(),
    'metadata': metadata,
  };

  HistoryEntryModel copyWith({
    String? id,
    String? userId,
    String? partnerId,
    String? type,
    String? title,
    String? description,
    String? relatedId,
    String? relatedCollection,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return HistoryEntryModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      partnerId: partnerId ?? this.partnerId,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      relatedId: relatedId ?? this.relatedId,
      relatedCollection: relatedCollection ?? this.relatedCollection,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
    );
  }
}
