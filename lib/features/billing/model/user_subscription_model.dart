class UserSubscriptionModel {
  final String id;
  final String userId;
  final String planId;
  final String planName;
  final double amountPaid;
  final String paymentInterval; // monthly, yearly
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final String? paymentReference;

  UserSubscriptionModel({
    required this.id,
    required this.userId,
    required this.planId,
    required this.planName,
    required this.amountPaid,
    required this.paymentInterval,
    required this.startDate,
    required this.endDate,
    this.isActive = true,
    this.paymentReference,
  });

  factory UserSubscriptionModel.fromMap(Map<String, dynamic> map, String id) {
    return UserSubscriptionModel(
      id: id,
      userId: map['userId'],
      planId: map['planId'],
      planName: map['planName'],
      amountPaid: (map['amountPaid'] as num).toDouble(),
      paymentInterval: map['paymentInterval'],
      startDate: DateTime.parse(map['startDate']),
      endDate: DateTime.parse(map['endDate']),
      isActive: map['isActive'] ?? true,
      paymentReference: map['paymentReference'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'planId': planId,
    'planName': planName,
    'amountPaid': amountPaid,
    'paymentInterval': paymentInterval,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'isActive': isActive,
    'paymentReference': paymentReference,
  };
}
