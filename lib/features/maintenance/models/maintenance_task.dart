class MaintenanceTaskModel {
  final String id;
  final String maintenanceRequestId;
  final String artisanId;
  final String propertyId;
  final String title;
  final String? description;
  final String status;
  final double? quotationAmount;
  final String? quotationNotes;
  final double? actualCost;
  final List<String>? photoUrls;
  final DateTime createdAt;
  final DateTime? assignedAt;
  final String? assignedBy;
  final DateTime? updatedAt;
  final DateTime? completedAt;

  // Payment Fields
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
    this.status = 'Pending',
    this.quotationAmount,
    this.quotationNotes,
    this.actualCost,
    this.photoUrls,
    required this.createdAt,
    this.assignedAt,
    this.assignedBy,
    this.updatedAt,
    this.completedAt,

    this.paymentStatus,
    this.paymentMethod,
    this.paymentReference,
    this.paymentApprovedAt,
    this.paymentApprovedBy,
  });

  factory MaintenanceTaskModel.fromMap(Map<String, dynamic> map) {
    return MaintenanceTaskModel(
      id: map['id'],
      maintenanceRequestId: map['maintenanceRequestId'],
      artisanId: map['artisanId'],
      propertyId: map['propertyId'],
      title: map['title'],
      description: map['description'] as String?,
      status: map['status'] ?? 'Pending',
      quotationAmount: (map['quotationAmount'] as num?)?.toDouble(),
      quotationNotes: map['quotationNotes'] as String?,
      actualCost: (map['actualCost'] as num?)?.toDouble(),
      photoUrls: (map['photoUrls'] as List<dynamic>?)?.cast<String>(),
      createdAt: DateTime.parse(map['createdAt']),
      assignedAt: map['assignedAt'] != null ? DateTime.parse(map['assignedAt']) : null,
      assignedBy: map['assignedBy'] as String?,
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : null,
      completedAt: map['completedAt'] != null ? DateTime.parse(map['completedAt']) : null,

      paymentStatus: map['paymentStatus'] as String?,
      paymentMethod: map['paymentMethod'] as String?,
      paymentReference: map['paymentReference'] as String?,
      paymentApprovedAt: map['paymentApprovedAt'] != null ? DateTime.parse(map['paymentApprovedAt']) : null,
      paymentApprovedBy: map['paymentApprovedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'maintenanceRequestId': maintenanceRequestId,
    'artisanId': artisanId,
    'propertyId': propertyId,
    'title': title,
    'description': description,
    'status': status,
    'quotationAmount': quotationAmount,
    'quotationNotes': quotationNotes,
    'actualCost': actualCost,
    'photoUrls': photoUrls,
    'createdAt': createdAt.toIso8601String(),
    'assignedAt': assignedAt?.toIso8601String(),
    'assignedBy': assignedBy,
    'updatedAt': updatedAt?.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),

    'paymentApprovedAt': paymentApprovedAt?.toIso8601String(),
    'paymentStatus': paymentStatus,
    'paymentMethod': paymentMethod,
    'paymentReference': paymentReference,
    'paymentApprovedBy': paymentApprovedBy,
  };

  MaintenanceTaskModel copyWith({
    String? id,
    String? maintenanceRequestId,
    String? artisanId,
    String? propertyId,
    String? title,
    String? description,
    String? status,
    double? quotationAmount,
    String? quotationNotes,
    double? actualCost,
    List<String>? photoUrls,
    DateTime? createdAt,
    DateTime? assignedAt,
    String? assignedBy,
    DateTime? updatedAt,
    DateTime? completedAt,
    String? paymentStatus, // Pending, Approved, Paid, Rejected
    String? paymentMethod, // Wallet, External, Link
    String? paymentReference,
    DateTime? paymentApprovedAt,
    String? paymentApprovedBy,
  }) {
    return MaintenanceTaskModel(
      id: id ?? this.id,
      maintenanceRequestId: maintenanceRequestId ?? this.maintenanceRequestId,
      artisanId: artisanId ?? this.artisanId,
      propertyId: propertyId ?? this.propertyId,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      quotationAmount: quotationAmount ?? this.quotationAmount,
      quotationNotes: quotationNotes ?? this.quotationNotes,
      actualCost: actualCost ?? this.actualCost,
      photoUrls: photoUrls ?? this.photoUrls,
      createdAt: createdAt ?? this.createdAt,
      assignedAt: assignedAt ?? this.assignedAt,
      assignedBy: assignedBy ?? this.assignedBy,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,

      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentReference: paymentReference ?? this.paymentReference,
      paymentApprovedAt: paymentApprovedAt ?? this.paymentApprovedAt,
      paymentApprovedBy: paymentApprovedBy ?? this.paymentApprovedBy,
    );
  }
}
