class WithdrawalModel {
  final String id;
  final String userId; // Landowner/Manager requesting withdrawal
  final double amount;
  final String currency;
  final String status; // 'Pending', 'Approved', 'Completed', 'Rejected'
  final String? method;
  final String? reference;
  final DateTime requestedAt;
  final DateTime? processedAt;
  final String? processedBy;

  WithdrawalModel({
    required this.id,
    required this.userId,
    required this.amount,
    this.currency = 'NGN',
    this.status = 'Pending',
    this.method,
    this.reference,
    required this.requestedAt,
    this.processedAt,
    this.processedBy,
  });

  factory WithdrawalModel.fromMap(Map<String, dynamic> map, String id) {
    return WithdrawalModel(
      id: id,
      userId: map['userId'] as String,
      amount: (map['amount'] as num).toDouble(),
      currency: map['currency'] as String? ?? 'NGN',
      status: map['status'] as String? ?? 'Pending',
      method: map['method'] as String?,
      reference: map['reference'] as String?,
      requestedAt: DateTime.parse(map['requestedAt'] as String),
      processedAt: map['processedAt'] != null ? DateTime.parse(map['processedAt'] as String) : null,
      processedBy: map['processedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'amount': amount,
    'currency': currency,
    'status': status,
    'method': method,
    'reference': reference,
    'requestedAt': requestedAt.toIso8601String(),
    'processedAt': processedAt?.toIso8601String(),
    'processedBy': processedBy,
  };

  WithdrawalModel copyWith({
    String? id,
    String? userId,
    double? amount,
    String? currency,
    String? status,
    String? method,
    String? reference,
    DateTime? requestedAt,
    DateTime? processedAt,
    String? processedBy,
  }) {
    return WithdrawalModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      method: method ?? this.method,
      reference: reference ?? this.reference,
      requestedAt: requestedAt ?? this.requestedAt,
      processedAt: processedAt ?? this.processedAt,
      processedBy: processedBy ?? this.processedBy,
    );
  }
}
