class AffiliatePayoutModel {
  final String id;
  final String affiliateId;
  final double amount;
  final String status; // pending, paid, failed
  final String? paystackTransferRef;
  final DateTime requestedAt;
  final DateTime? processedAt;
  final String? notes;

  AffiliatePayoutModel({
    required this.id,
    required this.affiliateId,
    required this.amount,
    this.status = 'pending',
    this.paystackTransferRef,
    required this.requestedAt,
    this.processedAt,
    this.notes,
  });

  factory AffiliatePayoutModel.fromMap(Map<String, dynamic> map) {
    return AffiliatePayoutModel(
      id: map['id'],
      affiliateId: map['affiliateId'],
      amount: (map['amount'] as num).toDouble(),
      status: map['status'] ?? 'pending',
      paystackTransferRef: map['paystackTransferRef'],
      requestedAt: DateTime.parse(map['requestedAt']),
      processedAt: map['processedAt'] != null ? DateTime.parse(map['processedAt']) : null,
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() => {
    'id' : id,
    'affiliateId': affiliateId,
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
      amount: amount ?? this.amount,
      status: status ?? this.status,
      paystackTransferRef: paystackTransferRef ?? this.paystackTransferRef,
      requestedAt: requestedAt ?? this.requestedAt,
      processedAt: processedAt ?? this.processedAt,
      notes: notes ?? this.notes,
    );
  }
}
