class AffiliateEarningModel {
  final String id;
  final String affiliateId;
  final String partnerId;
  final String referredUserId;
  final String? applicationId;
  final String? subscriptionId;
  final double amount;
  final String type; // application_fee, subscription, lease_bonus
  final String status; // pending, paid
  final DateTime createdAt;

  AffiliateEarningModel({
    required this.id,
    required this.affiliateId,
    this.partnerId = 'neztmate',
    required this.referredUserId,
    this.applicationId,
    this.subscriptionId,
    required this.amount,
    required this.type,
    this.status = 'pending',
    required this.createdAt,
  });

  factory AffiliateEarningModel.fromMap(Map<String, dynamic> map) {
    return AffiliateEarningModel(
      id: map['id'] as String? ?? '',
      affiliateId: map['affiliateId'] as String,
      partnerId: map['partnerId'] as String? ?? 'neztmate',
      referredUserId: map['referredUserId'] as String,
      applicationId: map['applicationId'] as String?,
      subscriptionId: map['subscriptionId'] as String?,
      amount: (map['amount'] as num).toDouble(),
      type: map['type'] as String,
      status: map['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'affiliateId': affiliateId,
    'partnerId': partnerId,
    'referredUserId': referredUserId,
    'applicationId': applicationId,
    'subscriptionId': subscriptionId,
    'amount': amount,
    'type': type,
    'status': status,
    'createdAt': createdAt.toIso8601String(),
  };

  AffiliateEarningModel copyWith({
    String? id,
    String? affiliateId,
    String? partnerId,
    String? referredUserId,
    String? applicationId,
    String? subscriptionId,
    double? amount,
    String? type,
    String? status,
    DateTime? createdAt,
  }) {
    return AffiliateEarningModel(
      id: id ?? this.id,
      affiliateId: affiliateId ?? this.affiliateId,
      partnerId: partnerId ?? this.partnerId,
      referredUserId: referredUserId ?? this.referredUserId,
      applicationId: applicationId ?? this.applicationId,
      subscriptionId: subscriptionId ?? this.subscriptionId,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
