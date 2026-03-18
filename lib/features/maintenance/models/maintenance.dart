class MaintenanceRequestModel {
  final String id;
  final String unitId;
  final String tenantId;
  final String description;
  final String priority; // Low, Medium, High, Emergency
  final String status; // Pending, Assigned, InProgress, Completed, Rejected
  final DateTime createdAt;
  final List<String>? photoUrls;
  final String? assignedTo; // artisan ID
  final String? assignedBy; // manager ID
  final DateTime? assignedAt;
  final DateTime? resolvedAt;
  final String? resolutionNotes;

  MaintenanceRequestModel({
    required this.id,
    required this.unitId,
    required this.tenantId,
    required this.description,
    required this.priority,
    this.status = 'Pending',
    required this.createdAt,
    this.photoUrls,
    this.assignedTo,
    this.assignedBy,
    this.assignedAt,
    this.resolvedAt,
    this.resolutionNotes,
  });

  factory MaintenanceRequestModel.fromMap(Map<String, dynamic> map, String id) {
    return MaintenanceRequestModel(
      id: id,
      unitId: map['unitId'] as String,
      tenantId: map['tenantId'] as String,
      description: map['description'] as String,
      priority: map['priority'] as String,
      status: map['status'] as String? ?? 'Pending',
      createdAt: DateTime.parse(map['createdAt'] as String),
      photoUrls: (map['photoUrls'] as List?)?.cast<String>(),
      assignedTo: map['assignedTo'] as String?,
      assignedBy: map['assignedBy'] as String?,
      assignedAt: map['assignedAt'] != null ? DateTime.parse(map['assignedAt'] as String) : null,
      resolvedAt: map['resolvedAt'] != null ? DateTime.parse(map['resolvedAt'] as String) : null,
      resolutionNotes: map['resolutionNotes'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'unitId': unitId,
    'tenantId': tenantId,
    'description': description,
    'priority': priority,
    'status': status,
    'createdAt': createdAt.toIso8601String(),
    'photoUrls': photoUrls,
    'assignedTo': assignedTo,
    'assignedBy': assignedBy,
    'assignedAt': assignedAt?.toIso8601String(),
    'resolvedAt': resolvedAt?.toIso8601String(),
    'resolutionNotes': resolutionNotes,
  };

  MaintenanceRequestModel copyWith({
    String? id,
    String? unitId,
    String? tenantId,
    String? description,
    String? priority,
    String? status,
    DateTime? createdAt,
    List<String>? photoUrls,
    String? assignedTo,
    String? assignedBy,
    DateTime? assignedAt,
    DateTime? resolvedAt,
    String? resolutionNotes,
  }) {
    return MaintenanceRequestModel(
      id: id ?? this.id,
      unitId: unitId ?? this.unitId,
      tenantId: tenantId ?? this.tenantId,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      photoUrls: photoUrls ?? this.photoUrls,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedBy: assignedBy ?? this.assignedBy,
      assignedAt: assignedAt ?? this.assignedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolutionNotes: resolutionNotes ?? this.resolutionNotes,
    );
  }
}
