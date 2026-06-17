class MaintenanceRequestModel {
  final String id;
  final String tenantId;
  final String propertyId;
  final String unitId;
  final String title;
  final String description;
  final String category;
  final String priority;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  MaintenanceRequestModel({
    required this.id,
    required this.tenantId,
    required this.propertyId,
    required this.unitId,
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    this.status = 'Pending',
    required this.createdAt,
    this.updatedAt,
  });

  factory MaintenanceRequestModel.fromMap(Map<String, dynamic> map) {
    return MaintenanceRequestModel(
      id: map['id'],
      tenantId: map['tenantId'],
      propertyId: map['propertyId'],
      unitId: map['unitId'],
      title: map['title'],
      description: map['description'],
      category: map['category'],
      priority: map['priority'],
      status: map['status'] ?? 'Pending',
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'tenantId': tenantId,
    'propertyId': propertyId,
    'unitId': unitId,
    'title': title,
    'description': description,
    'category': category,
    'priority': priority,
    'status': status,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  MaintenanceRequestModel copyWith({
    String? id,
    String? tenantId,
    String? propertyId,
    String? unitId,
    String? title,
    String? description,
    String? category,
    String? priority,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MaintenanceRequestModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      propertyId: propertyId ?? this.propertyId,
      unitId: unitId ?? this.unitId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
