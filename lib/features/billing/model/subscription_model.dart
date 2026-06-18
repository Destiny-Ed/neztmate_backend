class SubscriptionPlanModel {
  final String id;
  final String name; // Free, Basic, Pro, Enterprise
  final double monthlyPrice;
  final double yearlyPrice;
  final int maxProperties;
  final bool hasAnalytics;
  final bool hasPrioritySupport;
  final bool hasAutoReminders;
  final DateTime createdAt;

  SubscriptionPlanModel({
    required this.id,
    required this.name,
    required this.monthlyPrice,
    required this.yearlyPrice,
    required this.maxProperties,
    this.hasAnalytics = false,
    this.hasPrioritySupport = false,
    this.hasAutoReminders = false,
    required this.createdAt,
  });

  factory SubscriptionPlanModel.fromMap(Map<String, dynamic> map) {
    return SubscriptionPlanModel(
      id: map['id'],
      name: map['name'],
      monthlyPrice: (map['monthlyPrice'] as num).toDouble(),
      yearlyPrice: (map['yearlyPrice'] as num).toDouble(),
      maxProperties: map['maxProperties'] as int,
      hasAnalytics: map['hasAnalytics'] ?? false,
      hasPrioritySupport: map['hasPrioritySupport'] ?? false,
      hasAutoReminders: map['hasAutoReminders'] ?? false,
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'monthlyPrice': monthlyPrice,
    'yearlyPrice': yearlyPrice,
    'maxProperties': maxProperties,
    'hasAnalytics': hasAnalytics,
    'hasPrioritySupport': hasPrioritySupport,
    'hasAutoReminders': hasAutoReminders,
    'createdAt': createdAt.toIso8601String(),
  };
}
