class ReferralStatsModel {
  final String userId;
  final String referralCode;
  final int totalReferrals;
  final int successfulApplications;
  final double totalEarnings;

  final double paidEarnings;

  ReferralStatsModel({
    required this.userId,
    required this.referralCode,
    this.totalReferrals = 0,
    this.successfulApplications = 0,
    this.totalEarnings = 0.0,
    this.paidEarnings = 0.0,
  });

  double get pendingEarnings => totalEarnings - paidEarnings;

  factory ReferralStatsModel.fromMap(Map<String, dynamic> map) {
    return ReferralStatsModel(
      userId: map['userId'],
      referralCode: map['referralCode'],
      totalReferrals: map['totalReferrals'] ?? 0,
      successfulApplications: map['successfulApplications'] ?? 0,
      totalEarnings: (map['totalEarnings'] as num?)?.toDouble() ?? 0.0,
      paidEarnings: (map['paidEarnings'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'referralCode': referralCode,
    'totalReferrals': totalReferrals,
    'successfulApplications': successfulApplications,
    'totalEarnings': totalEarnings,
    'paidEarnings': paidEarnings,
  };
}
