class PaymentDisbursementModel {
  final String id;
  final String paymentId;
  final String recipientId;
  final String recipientType; // 'landowner' or 'artisan'
  final double originalAmount;
  final double platformFee;
  final double netAmount;
  final String status; // Held, Completed, Failed
  final DateTime scheduledDate;
  final DateTime? disbursedAt;
  final String? paystackTransferReference;
  final String? failureReason;

  PaymentDisbursementModel({
    required this.id,
    required this.paymentId,
    required this.recipientId,
    required this.recipientType,
    required this.originalAmount,
    required this.platformFee,
    required this.netAmount,
    this.status = 'Held',
    required this.scheduledDate,
    this.disbursedAt,
    this.paystackTransferReference,
    this.failureReason,
  });

  factory PaymentDisbursementModel.fromMap(Map<String, dynamic> map) {
    return PaymentDisbursementModel(
      id: map['id'],
      paymentId: map['paymentId'],
      recipientId: map['recipientId'],
      recipientType: map['recipientType'],
      originalAmount: (map['originalAmount'] as num).toDouble(),
      platformFee: (map['platformFee'] as num).toDouble(),
      netAmount: (map['netAmount'] as num).toDouble(),
      status: map['status'] ?? 'Held',
      scheduledDate: DateTime.parse(map['scheduledDate']),
      disbursedAt: map['disbursedAt'] != null ? DateTime.parse(map['disbursedAt']) : null,
      paystackTransferReference: map['paystackTransferReference'],
      failureReason: map['failureReason'],
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'paymentId': paymentId,
    'recipientId': recipientId,
    'recipientType': recipientType,
    'originalAmount': originalAmount,
    'platformFee': platformFee,
    'netAmount': netAmount,
    'status': status,
    'scheduledDate': scheduledDate.toIso8601String(),
    'disbursedAt': disbursedAt?.toIso8601String(),
    'paystackTransferReference': paystackTransferReference,
    'failureReason': failureReason,
  };

  PaymentDisbursementModel copyWith({
    String? id,
    String? paymentId,
    String? recipientId,
    String? recipientType,
    double? originalAmount,
    double? platformFee,
    double? netAmount,
    String? status,
    DateTime? scheduledDate,
    DateTime? disbursedAt,
    String? paystackTransferReference,
    String? failureReason,
  }) {
    return PaymentDisbursementModel(
      id: id ?? this.id,
      paymentId: paymentId ?? this.paymentId,
      recipientId: recipientId ?? this.recipientId,
      recipientType: recipientType ?? this.recipientType,
      originalAmount: originalAmount ?? this.originalAmount,
      platformFee: platformFee ?? this.platformFee,
      netAmount: netAmount ?? this.netAmount,
      status: status ?? this.status,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      disbursedAt: disbursedAt ?? this.disbursedAt,
      paystackTransferReference: paystackTransferReference ?? this.paystackTransferReference,
      failureReason: failureReason ?? this.failureReason,
    );
  }
}
