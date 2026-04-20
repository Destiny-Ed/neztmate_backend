class ApplicationModel {
  final String id;
  final String unitId;
  final String tenantId;
  final String propertyId;
  final DateTime appliedAt;
  final String status; // 'Pending', 'Approved', 'Rejected', 'Withdrawn'

  final String? message; // Optional tenant note
  final double? proposedRent; // If tenant negotiates
  final DateTime? desiredStartDate;
  final List<String>? documents; // Uploaded documents URLs

  final DateTime? reviewedAt;
  final String? reviewedBy; // Manager or Landowner ID

  final ScreeningData? screeningData;

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
    this.screeningData,
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

      // Parse screening data if present
      screeningData: map['screeningData'] != null
          ? ScreeningData.fromMap(map['screeningData'] as Map<String, dynamic>)
          : null,
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
    'screeningData': screeningData?.toMap(),
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
    ScreeningData? screeningData,
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
      screeningData: screeningData ?? this.screeningData,
    );
  }
}

class ScreeningData {
  final bool hasPets;
  final String? petType;
  final String monthlyIncomeRange;
  final int occupants;
  final String reasonForMoving;

  ScreeningData({
    required this.hasPets,
    this.petType,
    required this.monthlyIncomeRange,
    required this.occupants,
    required this.reasonForMoving,
  });

  factory ScreeningData.fromMap(Map<String, dynamic> map) {
    return ScreeningData(
      hasPets: map['hasPets'] as bool? ?? false,
      petType: map['petType'] as String?,
      monthlyIncomeRange: map['monthlyIncomeRange'] as String? ?? 'Not provided',
      occupants: map['occupants'] as int? ?? 1,
      reasonForMoving: map['reasonForMoving'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'hasPets': hasPets,
    'petType': petType,
    'monthlyIncomeRange': monthlyIncomeRange,
    'occupants': occupants,
    'reasonForMoving': reasonForMoving,
  };
}
