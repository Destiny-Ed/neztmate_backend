class LeaseSettlementAgreement {
  final String id;
  final String leaseId;

  /// tenant | landowner | manager | system
  final String initiatedBy;
  final String? initiatedById;

  /// Net amount tenant should pay (positive = tenant owes)
  final double amountDueFromTenant;

  /// Net refund to tenant if any
  final double refundToTenant;

  /// Optional agreed net after negotiation (defaults to amountDueFromTenant - refund)
  final double? agreedAmount;

  /// bank_transfer | cash | app_wallet | offline
  final String? paymentMethod;

  /// Pending | Proposed | Agreed | Finalized | Paid | Disputed | Rejected
  final String status;

  final String? notes;

  /// Full calculator breakdown
  final Map<String, dynamic> breakdown;

  final int? remainingDays;
  final double? proratedRentDue;
  final double? additionalFeesDue;
  final double? penalty;
  final bool hasReplacement;

  final DateTime createdAt;
  final DateTime? agreedAt;
  final String? agreedBy;
  final DateTime? disputedAt;
  final String? disputedBy;
  final String? disputeReason;
  final DateTime? finalizedAt;
  final String? finalizedBy;
  final DateTime? paidAt;
  final String? terminationReason;

  LeaseSettlementAgreement({
    required this.id,
    required this.leaseId,
    required this.initiatedBy,
    this.initiatedById,
    this.amountDueFromTenant = 0,
    this.refundToTenant = 0,
    this.agreedAmount,
    this.paymentMethod,
    this.status = 'pending',
    this.notes,
    this.breakdown = const {},
    this.remainingDays,
    this.proratedRentDue,
    this.additionalFeesDue,
    this.penalty,
    this.hasReplacement = false,
    required this.createdAt,
    this.agreedAt,
    this.agreedBy,
    this.disputedAt,
    this.disputedBy,
    this.disputeReason,
    this.finalizedAt,
    this.finalizedBy,
    this.paidAt,
    this.terminationReason,
  });

  factory LeaseSettlementAgreement.fromMap(Map<String, dynamic> map, [String? id]) {
    final breakdown = map['breakdown'] != null
        ? Map<String, dynamic>.from(map['breakdown'] as Map)
        : <String, dynamic>{};

    return LeaseSettlementAgreement(
      id: id ?? map['id'] as String? ?? '',
      leaseId: map['leaseId'] as String,
      initiatedBy: map['initiatedBy'] as String? ?? 'system',
      initiatedById: map['initiatedById'] as String?,
      amountDueFromTenant:
          (map['amountDueFromTenant'] as num?)?.toDouble() ??
          (map['agreedAmount'] as num?)?.toDouble() ??
          (breakdown['netBalanceDueFromTenant'] as num?)?.toDouble() ??
          0,
      refundToTenant:
          (map['refundToTenant'] as num?)?.toDouble() ??
          (breakdown['netRefundToTenant'] as num?)?.toDouble() ??
          0,
      agreedAmount: (map['agreedAmount'] as num?)?.toDouble(),
      paymentMethod: map['paymentMethod'] as String?,
      status: map['status'] as String? ?? 'Pending',
      notes: map['notes'] as String?,
      breakdown: breakdown,
      remainingDays: map['remainingDays'] as int? ?? breakdown['remainingDays'] as int?,
      proratedRentDue:
          (map['proratedRentDue'] as num?)?.toDouble() ?? (breakdown['proratedRentDue'] as num?)?.toDouble(),
      additionalFeesDue:
          (map['additionalFeesDue'] as num?)?.toDouble() ??
          (breakdown['additionalFeesDue'] as num?)?.toDouble(),
      penalty: (map['penalty'] as num?)?.toDouble() ?? (breakdown['penalty'] as num?)?.toDouble(),
      hasReplacement: map['hasReplacement'] as bool? ?? breakdown['hasReplacement'] as bool? ?? false,
      createdAt: DateTime.parse(map['createdAt'] as String),
      agreedAt: map['agreedAt'] != null ? DateTime.parse(map['agreedAt'] as String) : null,
      agreedBy: map['agreedBy'] as String?,
      disputedAt: map['disputedAt'] != null ? DateTime.parse(map['disputedAt'] as String) : null,
      disputedBy: map['disputedBy'] as String?,
      disputeReason: map['disputeReason'] as String?,
      finalizedAt: map['finalizedAt'] != null ? DateTime.parse(map['finalizedAt'] as String) : null,
      finalizedBy: map['finalizedBy'] as String?,
      paidAt: map['paidAt'] != null ? DateTime.parse(map['paidAt'] as String) : null,
      terminationReason: map['terminationReason'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'leaseId': leaseId,
    'initiatedBy': initiatedBy,
    'initiatedById': initiatedById,
    'amountDueFromTenant': amountDueFromTenant,
    'refundToTenant': refundToTenant,
    'agreedAmount': agreedAmount ?? amountDueFromTenant,
    'paymentMethod': paymentMethod,
    'status': status,
    'notes': notes,
    'breakdown': breakdown,
    'remainingDays': remainingDays,
    'proratedRentDue': proratedRentDue,
    'additionalFeesDue': additionalFeesDue,
    'penalty': penalty,
    'hasReplacement': hasReplacement,
    'createdAt': createdAt.toIso8601String(),
    'agreedAt': agreedAt?.toIso8601String(),
    'agreedBy': agreedBy,
    'disputedAt': disputedAt?.toIso8601String(),
    'disputedBy': disputedBy,
    'disputeReason': disputeReason,
    'finalizedAt': finalizedAt?.toIso8601String(),
    'finalizedBy': finalizedBy,
    'paidAt': paidAt?.toIso8601String(),
    'terminationReason': terminationReason,
  };

  LeaseSettlementAgreement copyWith({
    String? id,
    String? leaseId,
    String? initiatedBy,
    String? initiatedById,
    double? amountDueFromTenant,
    double? refundToTenant,
    double? agreedAmount,
    String? paymentMethod,
    String? status,
    String? notes,
    Map<String, dynamic>? breakdown,
    int? remainingDays,
    double? proratedRentDue,
    double? additionalFeesDue,
    double? penalty,
    bool? hasReplacement,
    DateTime? createdAt,
    DateTime? agreedAt,
    String? agreedBy,
    DateTime? disputedAt,
    String? disputedBy,
    String? disputeReason,
    DateTime? finalizedAt,
    String? finalizedBy,
    DateTime? paidAt,
    String? terminationReason,
  }) {
    return LeaseSettlementAgreement(
      id: id ?? this.id,
      leaseId: leaseId ?? this.leaseId,
      initiatedBy: initiatedBy ?? this.initiatedBy,
      initiatedById: initiatedById ?? this.initiatedById,
      amountDueFromTenant: amountDueFromTenant ?? this.amountDueFromTenant,
      refundToTenant: refundToTenant ?? this.refundToTenant,
      agreedAmount: agreedAmount ?? this.agreedAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      breakdown: breakdown ?? this.breakdown,
      remainingDays: remainingDays ?? this.remainingDays,
      proratedRentDue: proratedRentDue ?? this.proratedRentDue,
      additionalFeesDue: additionalFeesDue ?? this.additionalFeesDue,
      penalty: penalty ?? this.penalty,
      hasReplacement: hasReplacement ?? this.hasReplacement,
      createdAt: createdAt ?? this.createdAt,
      agreedAt: agreedAt ?? this.agreedAt,
      agreedBy: agreedBy ?? this.agreedBy,
      disputedAt: disputedAt ?? this.disputedAt,
      disputedBy: disputedBy ?? this.disputedBy,
      disputeReason: disputeReason ?? this.disputeReason,
      finalizedAt: finalizedAt ?? this.finalizedAt,
      finalizedBy: finalizedBy ?? this.finalizedBy,
      paidAt: paidAt ?? this.paidAt,
      terminationReason: terminationReason ?? this.terminationReason,
    );
  }
}
