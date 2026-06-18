class ApplicationFeeModel {
  final String id;
  final String tenantId;
  final String propertyId;
  final String unitId;
  final double amount;
  final String status; // Paid, Pending, Refunded
  final String paymentReference;
  final DateTime paidAt;
  final DateTime createdAt;

  ApplicationFeeModel({
    required this.id,
    required this.tenantId,
    required this.propertyId,
    required this.unitId,
    this.amount = 2000.0,
    this.status = 'Paid',
    required this.paymentReference,
    required this.paidAt,
    required this.createdAt,
  });

  factory ApplicationFeeModel.fromMap(Map<String, dynamic> map, String id) {
    return ApplicationFeeModel(
      id: id,
      tenantId: map['tenantId'],
      propertyId: map['propertyId'],
      unitId: map['unitId'],
      amount: (map['amount'] as num).toDouble(),
      status: map['status'] ?? 'Paid',
      paymentReference: map['paymentReference'],
      paidAt: DateTime.parse(map['paidAt']),
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'tenantId': tenantId,
    'propertyId': propertyId,
    'unitId': unitId,
    'amount': amount,
    'status': status,
    'paymentReference': paymentReference,
    'paidAt': paidAt.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };
}
