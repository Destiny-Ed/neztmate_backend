class HistoryEntryModel {
  final String id;
  final String userId;
  final String type; // e.g. "lease_signed", "task_completed", "payment_received", "withdrawal_completed"
  final String title; // short display title
  final String? description; // optional longer details
  final String? relatedId; // ID of lease, task, payment, withdrawal, etc.
  final String? relatedCollection; // "leases", "tasks", "payments", "withdrawals", etc.
  final DateTime timestamp;
  final Map<String, dynamic>? metadata; // extra context (e.g. amount, status, unitNumber)

  HistoryEntryModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    this.description,
    this.relatedId,
    this.relatedCollection,
    required this.timestamp,
    this.metadata,
  });

  factory HistoryEntryModel.fromMap(Map<String, dynamic> map, String id) {
    return HistoryEntryModel(
      id: id,
      userId: map['userId'] as String,
      type: map['type'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      relatedId: map['relatedId'] as String?,
      relatedCollection: map['relatedCollection'] as String?,
      timestamp: DateTime.parse(map['timestamp'] as String),
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
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
