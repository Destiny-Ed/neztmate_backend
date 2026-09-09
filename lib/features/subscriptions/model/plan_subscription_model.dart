class SubscriptionPlanModel {
  final String id;
  final String name; // free, basic, pro, premium, business, enterprise
  final String? description;
  final double monthlyPrice;
  final double yearlyPrice;
  final int maxUnits; // -1 unlimited
  final int maxListings; // -1 unlimited
  final int maxProperties; // -1 unlimited
  final int maxManagers; // 0 = off, -1 unlimited
  final int maxArtisans; // 0 = off, -1 unlimited
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
    this.description,
    required this.monthlyPrice,
    required this.yearlyPrice,
    this.maxUnits = 3,
    required this.maxListings,
    this.maxProperties = 1,
    this.maxManagers = 0,
    this.maxArtisans = 0,
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
    final maxListings = (map['maxListings'] as num?)?.toInt() ?? 3;
    return SubscriptionPlanModel(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      description: map['description'] as String?,
      monthlyPrice: (map['monthlyPrice'] as num?)?.toDouble() ?? 0,
      yearlyPrice: (map['yearlyPrice'] as num?)?.toDouble() ?? 0,
      maxUnits: (map['maxUnits'] as num?)?.toInt() ?? maxListings,
      maxListings: maxListings,
      maxProperties: (map['maxProperties'] as num?)?.toInt() ?? 1,
      maxManagers: (map['maxManagers'] as num?)?.toInt() ?? 0,
      maxArtisans: (map['maxArtisans'] as num?)?.toInt() ?? 0,
      hasAgentAssignment: map['hasAgentAssignment'] as bool? ?? false,
      hasAdvancedScreening: map['hasAdvancedScreening'] as bool? ?? false,
      hasAnalytics: map['hasAnalytics'] as bool? ?? false,
      hasPrioritySupport: map['hasPrioritySupport'] as bool? ?? false,
      isActive: map['isActive'] as bool? ?? true,
      createdAt: map['createdAt'] != null ? DateTime.tryParse(map['createdAt'].toString()) : null,
      updatedAt: map['updatedAt'] != null ? DateTime.tryParse(map['updatedAt'].toString()) : null,
      partnerId: map['partnerId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'description': description,
    'monthlyPrice': monthlyPrice,
    'yearlyPrice': yearlyPrice,
    'maxUnits': maxUnits,
    'maxListings': maxListings,
    'maxProperties': maxProperties,
    'maxManagers': maxManagers,
    'maxArtisans': maxArtisans,
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
    String? description,
    double? monthlyPrice,
    double? yearlyPrice,
    int? maxUnits,
    int? maxListings,
    int? maxProperties,
    int? maxManagers,
    int? maxArtisans,
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
      description: description ?? this.description,
      monthlyPrice: monthlyPrice ?? this.monthlyPrice,
      yearlyPrice: yearlyPrice ?? this.yearlyPrice,
      maxUnits: maxUnits ?? this.maxUnits,
      maxListings: maxListings ?? this.maxListings,
      maxProperties: maxProperties ?? this.maxProperties,
      maxManagers: maxManagers ?? this.maxManagers,
      maxArtisans: maxArtisans ?? this.maxArtisans,
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
