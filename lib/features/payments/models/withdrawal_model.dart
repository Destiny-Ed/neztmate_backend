class WithdrawalModel {
  final String id;
  final String userId; // Landowner or Manager
  final String? propertyId; // ← NEW: Link to specific property
  final double amount;
  final String currency;
  final String status; // Pending, Approved, Completed, Rejected
  final String? method;
  final String? reference;
  final DateTime requestedAt;
  final DateTime? processedAt;
  final String? processedBy;
  final String? notes;

  WithdrawalModel({
    required this.id,
    required this.userId,
    this.propertyId,
    required this.amount,
    this.currency = 'NGN',
    this.status = 'Pending',
    this.method,
    this.reference,
    required this.requestedAt,
    this.processedAt,
    this.processedBy,
    this.notes,
  });

  factory WithdrawalModel.fromMap(Map<String, dynamic> map) {
    return WithdrawalModel(
      id: map['id'] as String,
      userId: map['userId'] as String,
      propertyId: map['propertyId'] as String?,
      amount: (map['amount'] as num).toDouble(),
      currency: map['currency'] as String? ?? 'NGN',
      status: map['status'] as String? ?? 'Pending',
      method: map['method'] as String?,
      reference: map['reference'] as String?,
      requestedAt: DateTime.parse(map['requestedAt'] as String),
      processedAt: map['processedAt'] != null ? DateTime.parse(map['processedAt'] as String) : null,
      processedBy: map['processedBy'] as String?,
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'propertyId': propertyId,
    'amount': amount,
    'currency': currency,
    'status': status,
    'method': method,
    'reference': reference,
    'requestedAt': requestedAt.toIso8601String(),
    'processedAt': processedAt?.toIso8601String(),
    'processedBy': processedBy,
    'notes': notes,
  };

  WithdrawalModel copyWith({
    String? id,
    String? userId,
    String? propertyId,
    double? amount,
    String? currency,
    String? status,
    String? method,
    String? reference,
    DateTime? requestedAt,
    DateTime? processedAt,
    String? processedBy,
    String? notes,
  }) {
    return WithdrawalModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      propertyId: propertyId ?? this.propertyId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      method: method ?? this.method,
      reference: reference ?? this.reference,
      requestedAt: requestedAt ?? this.requestedAt,
      processedAt: processedAt ?? this.processedAt,
      processedBy: processedBy ?? this.processedBy,
      notes: notes ?? this.notes,
    );
  }
}
