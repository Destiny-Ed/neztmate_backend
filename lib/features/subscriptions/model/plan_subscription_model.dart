class SubscriptionPlanModel {
  final String id;
  final String name; // free, basic, premium, enterprise
  final double monthlyPrice;
  final double yearlyPrice;
  final int maxListings;
  final bool hasAgentAssignment;
  final bool hasAdvancedScreening;
  final bool hasAnalytics;
  final bool hasPrioritySupport;
  final bool isActive;

  SubscriptionPlanModel({
    required this.id,
    required this.name,
    required this.monthlyPrice,
    required this.yearlyPrice,
    required this.maxListings,
    this.hasAgentAssignment = false,
    this.hasAdvancedScreening = false,
    this.hasAnalytics = false,
    this.hasPrioritySupport = false,
    this.isActive = true,
  });

  factory SubscriptionPlanModel.fromMap(Map<String, dynamic> map) {
    return SubscriptionPlanModel(
      id: map['id'],
      name: map['name'],
      monthlyPrice: (map['monthlyPrice'] as num).toDouble(),
      yearlyPrice: (map['yearlyPrice'] as num).toDouble(),
      maxListings: map['maxListings'],
      hasAgentAssignment: map['hasAgentAssignment'] ?? false,
      hasAdvancedScreening: map['hasAdvancedScreening'] ?? false,
      hasAnalytics: map['hasAnalytics'] ?? false,
      hasPrioritySupport: map['hasPrioritySupport'] ?? false,
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'monthlyPrice': monthlyPrice,
    'yearlyPrice': yearlyPrice,
    'maxListings': maxListings,
    'hasAgentAssignment': hasAgentAssignment,
    'hasAdvancedScreening': hasAdvancedScreening,
    'hasAnalytics': hasAnalytics,
    'hasPrioritySupport': hasPrioritySupport,
    'isActive': isActive,
  };
}
