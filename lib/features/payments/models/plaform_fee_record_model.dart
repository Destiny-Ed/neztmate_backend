class PlatformFeeRecord {
  final String id;
  final String paymentId;
  final String type; // 'application_fee', 'rent', 'task_payment'
  final double amount;
  final String status; // 'Collected', 'Withdrawn', 'Failed'
  final DateTime collectedAt;
  final DateTime? withdrawnAt;
  final String? withdrawalReference;

  PlatformFeeRecord({
    required this.id,
    required this.paymentId,
    required this.type,
    required this.amount,
    this.status = 'Collected',
    required this.collectedAt,
    this.withdrawnAt,
    this.withdrawalReference,
  });

  factory PlatformFeeRecord.fromMap(Map<String, dynamic> map, String id) {
    return PlatformFeeRecord(
      id: id,
      paymentId: map['paymentId'] as String,
      type: map['type'] as String,
      amount: (map['amount'] as num).toDouble(),
      status: map['status'] as String? ?? 'Collected',
      collectedAt: DateTime.parse(map['collectedAt'] as String),
      withdrawnAt: map['withdrawnAt'] != null ? DateTime.parse(map['withdrawnAt']) : null,
      withdrawalReference: map['withdrawalReference'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'paymentId': paymentId,
    'type': type,
    'amount': amount,
    'status': status,
    'collectedAt': collectedAt.toIso8601String(),
    'withdrawnAt': withdrawnAt?.toIso8601String(),
    'withdrawalReference': withdrawalReference,
  };
}
