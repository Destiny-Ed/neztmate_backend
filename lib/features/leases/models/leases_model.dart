class LeaseModel {
  final String id;
  final String unitId;
  final String tenantId;
  final String landownerId;
  final DateTime startDate;
  final DateTime endDate;
  final double monthlyRent;
  final double? securityDeposit;
  final String? signedPdfUrl;
  final String status; // 'Active', 'Expired', 'Terminated'
  final DateTime createdAt;

  LeaseModel({
    required this.id,
    required this.unitId,
    required this.tenantId,
    required this.landownerId,
    required this.startDate,
    required this.endDate,
    required this.monthlyRent,
    this.securityDeposit,
    this.signedPdfUrl,
    this.status = 'Active',
    required this.createdAt,
  });

  factory LeaseModel.fromMap(Map<String, dynamic> map, String id) {
    return LeaseModel(
      id: id,
      unitId: map['unitId'] as String,
      tenantId: map['tenantId'] as String,
      landownerId: map['landownerId'] as String,
      startDate: DateTime.parse(map['startDate'] as String),
      endDate: DateTime.parse(map['endDate'] as String),
      monthlyRent: (map['monthlyRent'] as num).toDouble(),
      securityDeposit: (map['securityDeposit'] as num?)?.toDouble(),
      signedPdfUrl: map['signedPdfUrl'] as String?,
      status: map['status'] as String? ?? 'Active',
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
    'unitId': unitId,
    'tenantId': tenantId,
    'landownerId': landownerId,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'monthlyRent': monthlyRent,
    'securityDeposit': securityDeposit,
    'signedPdfUrl': signedPdfUrl,
    'status': status,
    'createdAt': createdAt.toIso8601String(),
  };

  LeaseModel copyWith({
    String? id,
    String? unitId,
    String? tenantId,
    String? landownerId,
    DateTime? startDate,
    DateTime? endDate,
    double? monthlyRent,
    double? securityDeposit,
    String? signedPdfUrl,
    String? status,
    DateTime? createdAt,
  }) {
    return LeaseModel(
      id: id ?? this.id,
      unitId: unitId ?? this.unitId,
      tenantId: tenantId ?? this.tenantId,
      landownerId: landownerId ?? this.landownerId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      monthlyRent: monthlyRent ?? this.monthlyRent,
      securityDeposit: securityDeposit ?? this.securityDeposit,
      signedPdfUrl: signedPdfUrl ?? this.signedPdfUrl,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
