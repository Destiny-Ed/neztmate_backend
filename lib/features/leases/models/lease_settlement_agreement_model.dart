class LeaseSettlementAgreement {
  final String id;
  final String leaseId;
  final String initiatedBy; // 'tenant' or 'landowner'
  final double agreedAmount;
  final String paymentMethod; // 'bank_transfer', 'cash', 'app_wallet'
  final String status; // Pending, Agreed, Paid, Disputed
  final String? notes;
  final DateTime createdAt;
  final DateTime? agreedAt;
  final String? agreedBy;

  LeaseSettlementAgreement({
    required this.id,
    required this.leaseId,
    required this.initiatedBy,
    required this.agreedAmount,
    required this.paymentMethod,
    this.status = 'Pending',
    this.notes,
    required this.createdAt,
    this.agreedAt,
    this.agreedBy,
  });

  factory LeaseSettlementAgreement.fromMap(Map<String, dynamic> map) {
    return LeaseSettlementAgreement(
      id: map['id'] as String,
      leaseId: map['leaseId'] as String,
      initiatedBy: map['initiatedBy'] as String,
      agreedAmount: (map['agreedAmount'] as num).toDouble(),
      paymentMethod: map['paymentMethod'] as String,
      status: map['status'] as String? ?? 'Pending',
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      agreedAt: map['agreedAt'] != null ? DateTime.parse(map['agreedAt'] as String) : null,
      agreedBy: map['agreedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'leaseId': leaseId,
    'initiatedBy': initiatedBy,
    'agreedAmount': agreedAmount,
    'paymentMethod': paymentMethod,
    'status': status,
    'notes': notes,
    'createdAt': createdAt.toIso8601String(),
    'agreedAt': agreedAt?.toIso8601String(),
    'agreedBy': agreedBy,
  };

  LeaseSettlementAgreement copyWith({
    String? id,
    String? status,
    String? notes,
    DateTime? agreedAt,
    String? agreedBy,
    double? agreedAmount,
    String? paymentMethod,
  }) {
    return LeaseSettlementAgreement(
      id: id ?? this.id,
      leaseId: leaseId,
      initiatedBy: initiatedBy,
      agreedAmount: agreedAmount ?? this.agreedAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      agreedAt: agreedAt ?? this.agreedAt,
      agreedBy: agreedBy ?? this.agreedBy,
    );
  }
}
