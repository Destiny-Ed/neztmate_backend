class UserSubscriptionModel {
  final String id;
  final String userId;
  final String planId;
  final String status; // active, cancelled, expired
  final DateTime startDate;
  final DateTime endDate;
  final String billingCycle; // monthly, yearly
  final double amountPaid;
  final String? paystackSubscriptionCode;

  UserSubscriptionModel({
    required this.id,
    required this.userId,
    required this.planId,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.billingCycle,
    required this.amountPaid,
    this.paystackSubscriptionCode,
  });

  factory UserSubscriptionModel.fromMap(Map<String, dynamic> map) {
    return UserSubscriptionModel(
      id: map['id'],
      userId: map['userId'],
      planId: map['planId'],
      status: map['status'],
      startDate: DateTime.parse(map['startDate']),
      endDate: DateTime.parse(map['endDate']),
      billingCycle: map['billingCycle'],
      amountPaid: (map['amountPaid'] as num).toDouble(),
      paystackSubscriptionCode: map['paystackSubscriptionCode'],
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'planId': planId,
    'status': status,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'billingCycle': billingCycle,
    'amountPaid': amountPaid,
    'paystackSubscriptionCode': paystackSubscriptionCode,
  };

  UserSubscriptionModel copyWith({
    String? id,
    String? userId,
    String? planId,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    String? billingCycle,
    double? amountPaid,
    String? paystackSubscriptionCode,
  }) {
    return UserSubscriptionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      planId: planId ?? this.planId,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      billingCycle: billingCycle ?? this.billingCycle,
      amountPaid: amountPaid ?? this.amountPaid,
      paystackSubscriptionCode: paystackSubscriptionCode ?? this.paystackSubscriptionCode,
    );
  }
}
