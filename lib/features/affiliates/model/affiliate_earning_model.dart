class AffiliateEarningModel {
  final String id;
  final String affiliateId;
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
      id: map['id'],
      affiliateId: map['affiliateId'],
      referredUserId: map['referredUserId'],
      applicationId: map['applicationId'],
      subscriptionId: map['subscriptionId'],
      amount: (map['amount'] as num).toDouble(),
      type: map['type'],
      status: map['status'] ?? 'pending',
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'affiliateId': affiliateId,
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
