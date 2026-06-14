class PaymentSummaryModel {
  final double totalReceived; // For Landlords/Managers (money coming in)
  final double totalPaid; // For Tenants (money going out) - NEW
  final double totalWithdrawn;
  final double balance;
  final int totalTransactions;
  final int pendingPayments;
  final double avgRent;
  final double withdrawableAmount;

  final String? entityId;
  final String? entityType; // 'user', 'property', 'lease', 'unit'

  // Tenant specific
  final int rentPaymentsCount;
  final double totalRentPaid;

  PaymentSummaryModel({
    required this.totalReceived,
    required this.totalPaid,
    required this.totalWithdrawn,
    required this.balance,
    required this.totalTransactions,
    required this.pendingPayments,
    required this.avgRent,
    required this.withdrawableAmount,
    this.entityId,
    this.entityType,
    this.rentPaymentsCount = 0,
    this.totalRentPaid = 0.0,
  });

  factory PaymentSummaryModel.fromMap(Map<String, dynamic> map, {String? entityId, String? entityType}) {
    return PaymentSummaryModel(
      totalReceived: (map['totalReceived'] as num?)?.toDouble() ?? 0.0,
      totalPaid: (map['totalPaid'] as num?)?.toDouble() ?? 0.0,
      totalWithdrawn: (map['totalWithdrawn'] as num?)?.toDouble() ?? 0.0,
      balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
      totalTransactions: map['totalTransactions'] as int? ?? 0,
      pendingPayments: map['pendingPayments'] as int? ?? 0,
      avgRent: (map['avgRent'] as num?)?.toDouble() ?? 0.0,
      withdrawableAmount: (map['withdrawableAmount'] as num?)?.toDouble() ?? 0.0,
      entityId: entityId ?? map['entityId'] as String?,
      entityType: entityType ?? map['entityType'] as String?,
      rentPaymentsCount: map['rentPaymentsCount'] as int? ?? 0,
      totalRentPaid: (map['totalRentPaid'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() => {
    'totalReceived': totalReceived,
    'totalPaid': totalPaid,
    'totalWithdrawn': totalWithdrawn,
    'balance': balance,
    'totalTransactions': totalTransactions,
    'pendingPayments': pendingPayments,
    'avgRent': avgRent,
    'withdrawableAmount': withdrawableAmount,
    'rentPaymentsCount': rentPaymentsCount,
    'totalRentPaid': totalRentPaid,
    if (entityId != null) 'entityId': entityId,
    if (entityType != null) 'entityType': entityType,
  };

  PaymentSummaryModel copyWith({
    double? totalReceived,
    double? totalPaid,
    double? totalWithdrawn,
    double? balance,
    int? totalTransactions,
    int? pendingPayments,
    double? avgRent,
    double? withdrawableAmount,
    String? entityId,
    String? entityType,
    int? rentPaymentsCount,
    double? totalRentPaid,
  }) {
    return PaymentSummaryModel(
      totalReceived: totalReceived ?? this.totalReceived,
      totalPaid: totalPaid ?? this.totalPaid,
      totalWithdrawn: totalWithdrawn ?? this.totalWithdrawn,
      balance: balance ?? this.balance,
      totalTransactions: totalTransactions ?? this.totalTransactions,
      pendingPayments: pendingPayments ?? this.pendingPayments,
      avgRent: avgRent ?? this.avgRent,
      withdrawableAmount: withdrawableAmount ?? this.withdrawableAmount,
      entityId: entityId ?? this.entityId,
      entityType: entityType ?? this.entityType,
      rentPaymentsCount: rentPaymentsCount ?? this.rentPaymentsCount,
      totalRentPaid: totalRentPaid ?? this.totalRentPaid,
    );
  }
}
