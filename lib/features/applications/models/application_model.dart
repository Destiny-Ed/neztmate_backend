class ApplicationModel {
  final String id;
  final String unitId; // references unit
  final String tenantId; // who applied
  final String propertyId; // for faster queries
  final DateTime appliedAt;
  final String status; // 'Pending', 'Approved', 'Rejected', 'Withdrawn'
  final String? message; // optional tenant note
  final double? proposedRent; // if tenant wants to negotiate
  final DateTime? desiredStartDate;
  final List<String>? documents; // e.g. ["id_card_url", "payslip_url"]
  final DateTime? reviewedAt;
  final String? reviewedBy; // manager or landowner ID

  ApplicationModel({
    required this.id,
    required this.unitId,
    required this.tenantId,
    required this.propertyId,
    required this.appliedAt,
    this.status = 'Pending',
    this.message,
    this.proposedRent,
    this.desiredStartDate,
    this.documents,
    this.reviewedAt,
    this.reviewedBy,
  });

  factory ApplicationModel.fromMap(Map<String, dynamic> map, String id) {
    return ApplicationModel(
      id: id,
      unitId: map['unitId'] as String,
      tenantId: map['tenantId'] as String,
      propertyId: map['propertyId'] as String,
      appliedAt: DateTime.parse(map['appliedAt'] as String),
      status: map['status'] as String? ?? 'Pending',
      message: map['message'] as String?,
      proposedRent: (map['proposedRent'] as num?)?.toDouble(),
      desiredStartDate: map['desiredStartDate'] != null
          ? DateTime.parse(map['desiredStartDate'] as String)
          : null,
      documents: (map['documents'] as List<dynamic>?)?.cast<String>(),
      reviewedAt: map['reviewedAt'] != null ? DateTime.parse(map['reviewedAt'] as String) : null,
      reviewedBy: map['reviewedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'unitId': unitId,
    'tenantId': tenantId,
    'propertyId': propertyId,
    'appliedAt': appliedAt.toIso8601String(),
    'status': status,
    'message': message,
    'proposedRent': proposedRent,
    'desiredStartDate': desiredStartDate?.toIso8601String(),
    'documents': documents,
    'reviewedAt': reviewedAt?.toIso8601String(),
    'reviewedBy': reviewedBy,
  };

  ApplicationModel copyWith({
    String? id,
    String? unitId,
    String? tenantId,
    String? propertyId,
    DateTime? appliedAt,
    String? status,
    String? message,
    double? proposedRent,
    DateTime? desiredStartDate,
    List<String>? documents,
    DateTime? reviewedAt,
    String? reviewedBy,
  }) {
    return ApplicationModel(
      id: id ?? this.id,
      unitId: unitId ?? this.unitId,
      tenantId: tenantId ?? this.tenantId,
      propertyId: propertyId ?? this.propertyId,
      appliedAt: appliedAt ?? this.appliedAt,
      status: status ?? this.status,
      message: message ?? this.message,
      proposedRent: proposedRent ?? this.proposedRent,
      desiredStartDate: desiredStartDate ?? this.desiredStartDate,
      documents: documents ?? this.documents,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
    );
  }
}
