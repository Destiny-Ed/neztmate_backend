class AnnouncementModel {
  final String id;
  final String title;
  final String body;
  final String audience; // all | partner
  final String? partnerId;
  final List<String> roles;
  final String displayMode; // marquee | dialog
  final String priority; // normal | high
  final bool isActive;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String? linkUrl;
  final String? linkLabel;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  AnnouncementModel({
    required this.id,
    required this.title,
    required this.body,
    this.audience = 'partner',
    this.partnerId,
    this.roles = const [],
    this.displayMode = 'dialog',
    this.priority = 'normal',
    this.isActive = true,
    required this.startsAt,
    this.endsAt,
    this.linkUrl,
    this.linkLabel,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AnnouncementModel.fromMap(Map<String, dynamic> map, [String? id]) {
    return AnnouncementModel(
      id: id ?? map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      audience: map['audience'] as String? ?? 'partner',
      partnerId: map['partnerId'] as String?,
      roles: (map['roles'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      displayMode: map['displayMode'] as String? ?? 'dialog',
      priority: map['priority'] as String? ?? 'normal',
      isActive: map['isActive'] as bool? ?? true,
      startsAt: DateTime.parse(map['startsAt'] as String),
      endsAt: map['endsAt'] != null ? DateTime.parse(map['endsAt'] as String) : null,
      linkUrl: map['linkUrl'] as String?,
      linkLabel: map['linkLabel'] as String?,
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'body': body,
    'audience': audience,
    'partnerId': partnerId,
    'roles': roles,
    'displayMode': displayMode,
    'priority': priority,
    'isActive': isActive,
    'startsAt': startsAt.toIso8601String(),
    'endsAt': endsAt?.toIso8601String(),
    'linkUrl': linkUrl,
    'linkLabel': linkLabel,
    'createdBy': createdBy,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  AnnouncementModel copyWith({
    String? id,
    String? title,
    String? body,
    String? audience,
    String? partnerId,
    List<String>? roles,
    String? displayMode,
    String? priority,
    bool? isActive,
    DateTime? startsAt,
    DateTime? endsAt,
    String? linkUrl,
    String? linkLabel,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AnnouncementModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      audience: audience ?? this.audience,
      partnerId: partnerId ?? this.partnerId,
      roles: roles ?? this.roles,
      displayMode: displayMode ?? this.displayMode,
      priority: priority ?? this.priority,
      isActive: isActive ?? this.isActive,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      linkUrl: linkUrl ?? this.linkUrl,
      linkLabel: linkLabel ?? this.linkLabel,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
