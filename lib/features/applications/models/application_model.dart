class ApplicationModel {
  final String id;
  final String unitId;
  final String? leaseId;
  final String tenantId;
  final String landownerId;
  final String propertyId;
  final DateTime appliedAt;
  final String status; // 'Pending', 'Approved', 'Rejected', 'Withdrawn'
  final String? reason;

  final double applicationFee; // NEW: Should be 2000
  final String? feePaymentReference; // NEW
  final String? feePaymentStatus; // NEW: Pending, Paid, Failed

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
    required this.landownerId,
    required this.propertyId,
    required this.appliedAt,
    this.status = 'Pending',
    this.message,
    this.reason,
    this.leaseId,
    this.applicationFee = 2000.0, // Default application fee
    this.feePaymentReference,
    this.feePaymentStatus,
    this.proposedRent,
    this.desiredStartDate,
    this.documents,
    this.reviewedAt,
    this.reviewedBy,
    this.screeningData,
  });

  factory ApplicationModel.fromMap(Map<String, dynamic> map) {
    return ApplicationModel(
      id: map['id'] as String,
      unitId: map['unitId'] as String,
      tenantId: map['tenantId'] as String,
      leaseId: map['leaseId'] as String?,
      propertyId: map['propertyId'] as String,
      appliedAt: DateTime.parse(map['appliedAt'] as String),
      status: map['status'] as String? ?? 'Pending',
      message: map['message'] as String?,
      reason: map['reason'] as String?,
      applicationFee: (map['applicationFee'] as num?)?.toDouble() ?? 2000.0,
      feePaymentReference: map['feePaymentReference'] as String?,
      feePaymentStatus: map['feePaymentStatus'] as String?,
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
      landownerId: map['landownerId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    "id": id,
    'unitId': unitId,
    'tenantId': tenantId,
    'propertyId': propertyId,
    'appliedAt': appliedAt.toIso8601String(),
    'status': status,
    'message': message,
    'reason': reason,
    'leaseId': leaseId,
    'applicationFee': applicationFee,
    'feePaymentReference': feePaymentReference,
    'feePaymentStatus': feePaymentStatus,
    'proposedRent': proposedRent,
    'desiredStartDate': desiredStartDate?.toIso8601String(),
    'documents': documents,
    'reviewedAt': reviewedAt?.toIso8601String(),
    'reviewedBy': reviewedBy,
    'screeningData': screeningData?.toMap(),
    'landownerId': landownerId,
  };

  ApplicationModel copyWith({
    String? id,
    String? unitId,
    String? tenantId,
    String? propertyId,
    DateTime? appliedAt,
    String? status,
    String? message,
    String? leaseId,
    double? applicationFee,
    String? feePaymentReference,
    String? feePaymentStatus,
    String? reason,
    double? proposedRent,
    DateTime? desiredStartDate,
    List<String>? documents,
    DateTime? reviewedAt,
    String? reviewedBy,
    ScreeningData? screeningData,
    String? landownerId,
  }) {
    return ApplicationModel(
      id: id ?? this.id,
      unitId: unitId ?? this.unitId,
      tenantId: tenantId ?? this.tenantId,
      propertyId: propertyId ?? this.propertyId,
      appliedAt: appliedAt ?? this.appliedAt,
      applicationFee: applicationFee ?? this.applicationFee,
      feePaymentReference: feePaymentReference ?? this.feePaymentReference,
      feePaymentStatus: feePaymentStatus ?? this.feePaymentStatus,
      status: status ?? this.status,
      message: message ?? this.message,
      leaseId: leaseId ?? this.leaseId,
      reason: reason ?? this.reason,
      proposedRent: proposedRent ?? this.proposedRent,
      desiredStartDate: desiredStartDate ?? this.desiredStartDate,
      documents: documents ?? this.documents,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      screeningData: screeningData ?? this.screeningData,
      landownerId: landownerId ?? this.landownerId,
    );
  }
}

class ScreeningData {
  final bool hasPets;
  final String? petType;
  final String annualHouseholdIncomeRange;
  final int occupants;
  final String reasonForMoving;

  ScreeningData({
    required this.hasPets,
    this.petType,
    required this.annualHouseholdIncomeRange,
    required this.occupants,
    required this.reasonForMoving,
  });

  factory ScreeningData.fromMap(Map<String, dynamic> map) {
    return ScreeningData(
      hasPets: map['hasPets'] as bool? ?? false,
      petType: map['petType'] as String?,
      annualHouseholdIncomeRange: map['annualHouseholdIncomeRange'] as String? ?? 'Not provided',
      occupants: map['occupants'] as int? ?? 1,
      reasonForMoving: map['reasonForMoving'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'hasPets': hasPets,
    'petType': petType,
    'annualHouseholdIncomeRange': annualHouseholdIncomeRange,
    'occupants': occupants,
    'reasonForMoving': reasonForMoving,
  };
}
