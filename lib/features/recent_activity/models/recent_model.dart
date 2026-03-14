class RecentActivityModel {
  final String id;
  final String userId; // who performed the action
  final String type; // activity type (see enum-like constants below)
  final String? title; // short display title (e.g. "Applied for Apt 4B")
  final String? description; // longer details (optional)
  final String? relatedId; // ID of related entity (unitId, leaseId, requestId, etc.)
  final String? relatedCollection; // 'units', 'leases', 'maintenance_requests', etc.
  final DateTime timestamp;
  final Map<String, dynamic>? metadata; // extra info (e.g. {"amount": 150000, "status": "Paid"})

  // Suggested activity type constants (you can use enum or string literals)
  static const String login = 'login';
  static const String register = 'register';
  static const String socialLogin = 'social_login';
  static const String leaseApplication = 'lease_application';
  static const String leaseSigned = 'lease_signed';
  static const String paymentMade = 'payment_made';
  static const String maintenanceRequest = 'maintenance_request';
  static const String taskAssigned = 'task_assigned';
  static const String taskCompleted = 'task_completed';
  static const String commentPosted = 'comment_posted';
  static const String withdrawalRequested = 'withdrawal_requested';
  static const String profileUpdated = 'profile_updated';
  static const String inviteSent = 'invite_sent';
  static const String certificationAdded = 'certification_added';

  RecentActivityModel({
    required this.id,
    required this.userId,
    required this.type,
    this.title,
    this.description,
    this.relatedId,
    this.relatedCollection,
    required this.timestamp,
    this.metadata,
  });

  factory RecentActivityModel.fromMap(Map<String, dynamic> map, String id) {
    return RecentActivityModel(
      id: id,
      userId: map['userId'] as String,
      type: map['type'] as String,
      title: map['title'] as String?,
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

  RecentActivityModel copyWith({
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
    return RecentActivityModel(
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

  // Helper to get a nice icon name or emoji for frontend (optional)
  String get iconSuggestion {
    switch (type) {
      case login:
      case register:
      case socialLogin:
        return 'login';
      case leaseApplication:
      case leaseSigned:
        return 'key';
      case paymentMade:
        return 'money';
      case maintenanceRequest:
        return 'tools';
      case taskAssigned:
      case taskCompleted:
        return 'wrench';
      case commentPosted:
        return 'message-circle';
      case withdrawalRequested:
        return 'download';
      case profileUpdated:
        return 'user';
      case inviteSent:
        return 'user-plus';
      case certificationAdded:
        return 'award';
      default:
        return 'activity';
    }
  }
}
