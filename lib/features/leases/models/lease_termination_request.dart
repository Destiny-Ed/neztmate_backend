class LeaseTerminationRequest {
  final String id;
  final String leaseId;
  final String tenantId;
  final String landownerId;
  final String? managerId;

  final String requestType; // 'early_termination' or 'transfer'
  final String status; // 'Pending', 'Approved', 'Rejected', 'Completed'
  final String reason;
  final String? newTenantId; // For transfer requests

  final double? proposedSettlementAmount;
  final String? settlementNotes;

  final DateTime requestedAt;
  final DateTime? resolvedAt;
  final String? resolvedBy;

  LeaseTerminationRequest({
    required this.id,
    required this.leaseId,
    required this.tenantId,
    required this.landownerId,
    this.managerId,
    required this.requestType,
    required this.status,
    required this.reason,
    this.newTenantId,
    this.proposedSettlementAmount,
    this.settlementNotes,
    required this.requestedAt,
    this.resolvedAt,
    this.resolvedBy,
  });

  factory LeaseTerminationRequest.fromMap(Map<String, dynamic> map) {
    return LeaseTerminationRequest(
      id: map['id'] as String,
      leaseId: map['leaseId'] as String,
      tenantId: map['tenantId'] as String,
      landownerId: map['landownerId'] as String,
      managerId: map['managerId'] as String?,
      requestType: map['requestType'] as String,
      status: map['status'] as String,
      reason: map['reason'] as String,
      newTenantId: map['newTenantId'] as String?,
      proposedSettlementAmount: (map['proposedSettlementAmount'] as num?)?.toDouble(),
      settlementNotes: map['settlementNotes'] as String?,
      requestedAt: DateTime.parse(map['requestedAt'] as String),
      resolvedAt: map['resolvedAt'] != null ? DateTime.parse(map['resolvedAt'] as String) : null,
      resolvedBy: map['resolvedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'leaseId': leaseId,
    'tenantId': tenantId,
    'landownerId': landownerId,
    'managerId': managerId,
    'requestType': requestType,
    'status': status,
    'reason': reason,
    'newTenantId': newTenantId,
    'proposedSettlementAmount': proposedSettlementAmount,
    'settlementNotes': settlementNotes,
    'requestedAt': requestedAt.toIso8601String(),
    'resolvedAt': resolvedAt?.toIso8601String(),
    'resolvedBy': resolvedBy,
  };

  LeaseTerminationRequest copyWith({
    String? id,
    String? status,
    String? reason,
    String? newTenantId,
    double? proposedSettlementAmount,
    String? settlementNotes,
    DateTime? resolvedAt,
    String? resolvedBy,
  }) {
    return LeaseTerminationRequest(
      id: id ?? this.id,
      leaseId: leaseId,
      tenantId: tenantId,
      landownerId: landownerId,
      managerId: managerId,
      requestType: requestType,
      status: status ?? this.status,
      reason: reason ?? this.reason,
      newTenantId: newTenantId ?? this.newTenantId,
      proposedSettlementAmount: proposedSettlementAmount ?? this.proposedSettlementAmount,
      settlementNotes: settlementNotes ?? this.settlementNotes,
      requestedAt: requestedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolvedBy: resolvedBy ?? this.resolvedBy,
    );
  }
}
