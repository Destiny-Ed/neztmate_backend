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
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String partnerId;

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
    this.createdAt,
    this.updatedAt,
    this.partnerId = '',
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
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : null,
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : null,
      partnerId: map['partnerId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'monthlyPrice': monthlyPrice,
    'yearlyPrice': yearlyPrice,
    'maxListings': maxListings,
    'hasAgentAssignment': hasAgentAssignment,
    'hasAdvancedScreening': hasAdvancedScreening,
    'hasAnalytics': hasAnalytics,
    'hasPrioritySupport': hasPrioritySupport,
    'isActive': isActive,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'partnerId': partnerId,
  };

  SubscriptionPlanModel copyWith({
    String? id,
    String? name,
    double? monthlyPrice,
    double? yearlyPrice,
    int? maxListings,
    bool? hasAgentAssignment,
    bool? hasAdvancedScreening,
    bool? hasAnalytics,
    bool? hasPrioritySupport,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? partnerId,
  }) {
    return SubscriptionPlanModel(
      id: id ?? this.id,
      name: name ?? this.name,
      monthlyPrice: monthlyPrice ?? this.monthlyPrice,
      yearlyPrice: yearlyPrice ?? this.yearlyPrice,
      maxListings: maxListings ?? this.maxListings,
      hasAgentAssignment: hasAgentAssignment ?? this.hasAgentAssignment,
      hasAdvancedScreening: hasAdvancedScreening ?? this.hasAdvancedScreening,
      hasAnalytics: hasAnalytics ?? this.hasAnalytics,
      hasPrioritySupport: hasPrioritySupport ?? this.hasPrioritySupport,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      partnerId: partnerId ?? this.partnerId,
    );
  }
}
