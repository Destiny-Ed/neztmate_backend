// features/maintenance/models/maintenance_task_model.dart

class MaintenanceTaskModel {
  final String id;
  final String maintenanceRequestId;
  final String artisanId;
  final String propertyId;

  final String title;
  final String? description;
  final String category;
  final String priority; // Low, Medium, High, Emergency

  final String status; // Pending, Accepted, InProgress, Completed, Rejected, Cancelled

  // Progress & Timeline
  final String? progressNotes;
  final DateTime? assignedAt;
  final String? assignedBy;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Payment Related
  final double? quotationAmount;
  final String? summary;
  final double? actualCost;

  final String? paymentStatus; // Pending, Approved, Paid, Rejected
  final String? paymentMethod; // Wallet, External, Link
  final String? paymentReference;
  final DateTime? paymentApprovedAt;
  final String? paymentApprovedBy;

  MaintenanceTaskModel({
    required this.id,
    required this.maintenanceRequestId,
    required this.artisanId,
    required this.propertyId,
    required this.title,
    this.description,
    required this.category,
    required this.priority,
    this.status = 'Pending',
    this.progressNotes,
    this.assignedAt,
    this.assignedBy,
    this.startedAt,
    this.completedAt,
    required this.createdAt,
    this.updatedAt,
    this.quotationAmount,
    this.summary,
    this.actualCost,
    this.paymentStatus,
    this.paymentMethod,
    this.paymentReference,
    this.paymentApprovedAt,
    this.paymentApprovedBy,
  });

  factory MaintenanceTaskModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return MaintenanceTaskModel(
      id: id ?? map['id'] as String,
      maintenanceRequestId: map['maintenanceRequestId'] as String,
      artisanId: map['artisanId'] as String,
      propertyId: map['propertyId'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      category: map['category'] as String,
      priority: map['priority'] as String,
      status: map['status'] as String? ?? 'Pending',
      progressNotes: map['progressNotes'] as String?,
      assignedAt: map['assignedAt'] != null ? DateTime.parse(map['assignedAt']) : null,
      assignedBy: map['assignedBy'] as String?,
      startedAt: map['startedAt'] != null ? DateTime.parse(map['startedAt']) : null,
      completedAt: map['completedAt'] != null ? DateTime.parse(map['completedAt']) : null,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : null,

      // Payment fields
      quotationAmount: (map['quotationAmount'] as num?)?.toDouble(),
      summary: map['summary'] as String?,
      actualCost: (map['actualCost'] as num?)?.toDouble(),
      paymentStatus: map['paymentStatus'] as String?,
      paymentMethod: map['paymentMethod'] as String?,
      paymentReference: map['paymentReference'] as String?,
      paymentApprovedAt: map['paymentApprovedAt'] != null ? DateTime.parse(map['paymentApprovedAt']) : null,
      paymentApprovedBy: map['paymentApprovedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'maintenanceRequestId': maintenanceRequestId,
      'artisanId': artisanId,
      'propertyId': propertyId,
      'title': title,
      'description': description,
      'category': category,
      'priority': priority,
      'status': status,
      'progressNotes': progressNotes,
      'assignedAt': assignedAt?.toIso8601String(),
      'assignedBy': assignedBy,
      'startedAt': startedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),

      // Payment fields
      'quotationAmount': quotationAmount,
      'summary': summary,
      'actualCost': actualCost,
      'paymentStatus': paymentStatus,
      'paymentMethod': paymentMethod,
      'paymentReference': paymentReference,
      'paymentApprovedAt': paymentApprovedAt?.toIso8601String(),
      'paymentApprovedBy': paymentApprovedBy,
    };
  }

  MaintenanceTaskModel copyWith({
    String? id,
    String? status,
    String? progressNotes,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? updatedAt,
    double? quotationAmount,
    String? summary,
    double? actualCost,
    String? paymentStatus,
    String? paymentMethod,
    String? paymentReference,
    DateTime? paymentApprovedAt,
    String? paymentApprovedBy,
  }) {
    return MaintenanceTaskModel(
      id: id ?? this.id,
      maintenanceRequestId: maintenanceRequestId,
      artisanId: artisanId,
      propertyId: propertyId,
      title: title,
      description: description,
      category: category,
      priority: priority,
      status: status ?? this.status,
      progressNotes: progressNotes ?? this.progressNotes,
      assignedAt: assignedAt,
      assignedBy: assignedBy,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      quotationAmount: quotationAmount ?? this.quotationAmount,
      summary: summary ?? this.summary,
      actualCost: actualCost ?? this.actualCost,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentReference: paymentReference ?? this.paymentReference,
      paymentApprovedAt: paymentApprovedAt ?? this.paymentApprovedAt,
      paymentApprovedBy: paymentApprovedBy ?? this.paymentApprovedBy,
    );
  }
}
