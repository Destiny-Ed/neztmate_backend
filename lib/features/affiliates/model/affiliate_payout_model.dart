class AffiliatePayoutModel {
  final String id;
  final String affiliateId;
  final String partnerId;
  final double amount;
  final String status; // pending, paid, failed
  final String? paystackTransferRef;
  final DateTime requestedAt;
  final DateTime? processedAt;
  final String? notes;

  AffiliatePayoutModel({
    required this.id,
    required this.affiliateId,
    this.partnerId = 'neztmate',
    required this.amount,
    this.status = 'pending',
    this.paystackTransferRef,
    required this.requestedAt,
    this.processedAt,
    this.notes,
  });

  factory AffiliatePayoutModel.fromMap(Map<String, dynamic> map) {
    return AffiliatePayoutModel(
      id: map['id'] as String? ?? '',
      affiliateId: map['affiliateId'] as String,
      partnerId: map['partnerId'] as String? ?? 'neztmate',
      amount: (map['amount'] as num).toDouble(),
      status: map['status'] as String? ?? 'pending',
      paystackTransferRef: map['paystackTransferRef'] as String?,
      requestedAt: DateTime.parse(map['requestedAt'] as String),
      processedAt: map['processedAt'] != null ? DateTime.parse(map['processedAt'] as String) : null,
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'affiliateId': affiliateId,
    'partnerId': partnerId,
    'amount': amount,
    'status': status,
    'paystackTransferRef': paystackTransferRef,
    'requestedAt': requestedAt.toIso8601String(),
    'processedAt': processedAt?.toIso8601String(),
    'notes': notes,
  };

  AffiliatePayoutModel copyWith({
    String? id,
    String? affiliateId,
    String? partnerId,
    double? amount,
    String? status,
    String? paystackTransferRef,
    DateTime? requestedAt,
    DateTime? processedAt,
    String? notes,
  }) {
    return AffiliatePayoutModel(
      id: id ?? this.id,
      affiliateId: affiliateId ?? this.affiliateId,
      partnerId: partnerId ?? this.partnerId,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      paystackTransferRef: paystackTransferRef ?? this.paystackTransferRef,
      requestedAt: requestedAt ?? this.requestedAt,
      processedAt: processedAt ?? this.processedAt,
      notes: notes ?? this.notes,
    );
  }
}
