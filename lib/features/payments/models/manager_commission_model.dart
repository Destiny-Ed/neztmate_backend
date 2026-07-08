class ManagerCommissionModel {
  final String id;
  final String paymentId;
  final String managerId;
  final String relatedId; // leaseId or taskId
  final String type; // 'rent', 'task_payment'
  final double commissionRate;
  final double commissionAmount;
  final String status; // Pending, Paid, Withdrawn
  final DateTime createdAt;
  final DateTime? paidAt;
  final String? payoutReference;

  ManagerCommissionModel({
    required this.id,
    required this.paymentId,
    required this.managerId,
    required this.relatedId,
    required this.type,
    required this.commissionRate,
    required this.commissionAmount,
    this.status = 'Pending',
    required this.createdAt,
    this.paidAt,
    this.payoutReference,
  });

  factory ManagerCommissionModel.fromMap(Map<String, dynamic> map, String id) {
    return ManagerCommissionModel(
      id: id,
      paymentId: map['paymentId'] as String,
      managerId: map['managerId'] as String,
      relatedId: map['relatedId'] as String,
      type: map['type'] as String,
      commissionRate: (map['commissionRate'] as num).toDouble(),
      commissionAmount: (map['commissionAmount'] as num).toDouble(),
      status: map['status'] as String? ?? 'Pending',
      createdAt: DateTime.parse(map['createdAt'] as String),
      paidAt: map['paidAt'] != null ? DateTime.parse(map['paidAt']) : null,
      payoutReference: map['payoutReference'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'paymentId': paymentId,
    'managerId': managerId,
    'relatedId': relatedId,
    'type': type,
    'commissionRate': commissionRate,
    'commissionAmount': commissionAmount,
    'status': status,
    'createdAt': createdAt.toIso8601String(),
    'paidAt': paidAt?.toIso8601String(),
    'payoutReference': payoutReference,
  };

  ManagerCommissionModel copyWith({String? id, String? status, DateTime? paidAt, String? payoutReference}) {
    return ManagerCommissionModel(
      id: id ?? this.id,
      paymentId: paymentId,
      managerId: managerId,
      relatedId: relatedId,
      type: type,
      commissionRate: commissionRate,
      commissionAmount: commissionAmount,
      status: status ?? this.status,
      createdAt: createdAt,
      paidAt: paidAt ?? this.paidAt,
      payoutReference: payoutReference ?? this.payoutReference,
    );
  }
}
