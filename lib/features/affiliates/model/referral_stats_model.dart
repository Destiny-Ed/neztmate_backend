class ReferralStatsModel {
  final String userId;
  final String partnerId;
  final String referralCode;
  final int totalReferrals;
  final int successfulApplications;
  final double totalEarnings;
  final double paidEarnings;

  ReferralStatsModel({
    required this.userId,
    this.partnerId = 'neztmate',
    required this.referralCode,
    this.totalReferrals = 0,
    this.successfulApplications = 0,
    this.totalEarnings = 0.0,
    this.paidEarnings = 0.0,
  });

  double get pendingEarnings => totalEarnings - paidEarnings;

  /// Doc id: userId_partnerId (one stats doc per partner)
  static String docId(String userId, String partnerId) => '${userId}_$partnerId';

  factory ReferralStatsModel.fromMap(Map<String, dynamic> map) {
    return ReferralStatsModel(
      userId: map['userId'] as String,
      partnerId: map['partnerId'] as String? ?? 'neztmate',
      referralCode: map['referralCode'] as String,
      totalReferrals: map['totalReferrals'] as int? ?? 0,
      successfulApplications: map['successfulApplications'] as int? ?? 0,
      totalEarnings: (map['totalEarnings'] as num?)?.toDouble() ?? 0.0,
      paidEarnings: (map['paidEarnings'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'partnerId': partnerId,
    'referralCode': referralCode,
    'totalReferrals': totalReferrals,
    'successfulApplications': successfulApplications,
    'totalEarnings': totalEarnings,
    'paidEarnings': paidEarnings,
  };

  ReferralStatsModel copyWith({
    String? userId,
    String? partnerId,
    String? referralCode,
    int? totalReferrals,
    int? successfulApplications,
    double? totalEarnings,
    double? paidEarnings,
  }) {
    return ReferralStatsModel(
      userId: userId ?? this.userId,
      partnerId: partnerId ?? this.partnerId,
      referralCode: referralCode ?? this.referralCode,
      totalReferrals: totalReferrals ?? this.totalReferrals,
      successfulApplications: successfulApplications ?? this.successfulApplications,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      paidEarnings: paidEarnings ?? this.paidEarnings,
    );
  }
}
