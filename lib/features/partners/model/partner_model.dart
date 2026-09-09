class PartnerModel {
  final String id;
  final String slug;
  final String name;
  final String? tagline;
  final String? logoUrl;
  final String primaryColor;
  final String? secondaryColor;
  final String? supportEmail;
  final String? supportPhone;
  final String? website;
  final String? domain;
  final String? playStoreUrl;
  final String? appStoreUrl;
  final String? privacyUrl;
  final String? termsUrl;
  final String? copyright;
  final bool isActive;
  final Map<String, dynamic> features;
  final Map<String, dynamic> fees;

  /// Platform → partner workspace gates (not landowner subscription plans)
  /// {
  ///   appEnabled, subscriptionsEnabled, applicationsEnabled,
  ///   maxLandowners, maxProperties, maxUnits  // -1 = unlimited
  /// }
  final Map<String, dynamic> limits;

  final DateTime createdAt;
  final DateTime updatedAt;

  PartnerModel({
    required this.id,
    required this.slug,
    required this.name,
    this.tagline,
    this.logoUrl,
    this.primaryColor = '#0d9488',
    this.secondaryColor,
    this.supportEmail,
    this.supportPhone,
    this.website,
    this.domain,
    this.playStoreUrl,
    this.appStoreUrl,
    this.privacyUrl,
    this.termsUrl,
    this.copyright,
    this.isActive = true,
    this.features = const {},
    this.fees = const {},
    this.limits = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory PartnerModel.fromMap(Map<String, dynamic> map, [String? id]) {
    DateTime parseDt(dynamic v) {
      if (v is DateTime) return v;
      return DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();
    }

    Map<String, dynamic> asMap(dynamic v) {
      if (v is Map) return Map<String, dynamic>.from(v);
      return {};
    }

    return PartnerModel(
      id: id ?? map['id'] as String? ?? '',
      slug: map['slug'] as String? ?? '',
      name: map['name'] as String? ?? '',
      tagline: map['tagline'] as String?,
      logoUrl: map['logoUrl'] as String?,
      primaryColor: map['primaryColor'] as String? ?? '#0d9488',
      secondaryColor: map['secondaryColor'] as String?,
      supportEmail: map['supportEmail'] as String?,
      supportPhone: map['supportPhone'] as String?,
      website: map['website'] as String?,
      domain: map['domain'] as String?,
      playStoreUrl: map['playStoreUrl'] as String?,
      appStoreUrl: map['appStoreUrl'] as String?,
      privacyUrl: map['privacyUrl'] as String?,
      termsUrl: map['termsUrl'] as String?,
      copyright: map['copyright'] as String?,
      isActive: map['isActive'] as bool? ?? true,
      features: asMap(map['features']),
      fees: asMap(map['fees']),
      limits: asMap(map['limits']),
      createdAt: parseDt(map['createdAt']),
      updatedAt: parseDt(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'slug': slug,
    'name': name,
    'tagline': tagline,
    'logoUrl': logoUrl,
    'primaryColor': primaryColor,
    'secondaryColor': secondaryColor,
    'supportEmail': supportEmail,
    'supportPhone': supportPhone,
    'website': website,
    'domain': domain,
    'playStoreUrl': playStoreUrl,
    'appStoreUrl': appStoreUrl,
    'privacyUrl': privacyUrl,
    'termsUrl': termsUrl,
    'copyright': copyright,
    'isActive': isActive,
    'features': features,
    'fees': fees,
    'limits': limits,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  PartnerModel copyWith({
    String? id,
    String? slug,
    String? name,
    String? tagline,
    String? logoUrl,
    String? primaryColor,
    String? secondaryColor,
    String? supportEmail,
    String? supportPhone,
    String? website,
    String? domain,
    String? playStoreUrl,
    String? appStoreUrl,
    String? privacyUrl,
    String? termsUrl,
    String? copyright,
    bool? isActive,
    Map<String, dynamic>? features,
    Map<String, dynamic>? fees,
    Map<String, dynamic>? limits,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PartnerModel(
      id: id ?? this.id,
      slug: slug ?? this.slug,
      name: name ?? this.name,
      tagline: tagline ?? this.tagline,
      logoUrl: logoUrl ?? this.logoUrl,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      supportEmail: supportEmail ?? this.supportEmail,
      supportPhone: supportPhone ?? this.supportPhone,
      website: website ?? this.website,
      domain: domain ?? this.domain,
      playStoreUrl: playStoreUrl ?? this.playStoreUrl,
      appStoreUrl: appStoreUrl ?? this.appStoreUrl,
      privacyUrl: privacyUrl ?? this.privacyUrl,
      termsUrl: termsUrl ?? this.termsUrl,
      copyright: copyright ?? this.copyright,
      isActive: isActive ?? this.isActive,
      features: features ?? this.features,
      fees: fees ?? this.fees,
      limits: limits ?? this.limits,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toPublicMap() => {
    'id': id,
    'slug': slug,
    'name': name,
    'tagline': tagline,
    'logoUrl': logoUrl,
    'primaryColor': primaryColor,
    'secondaryColor': secondaryColor,
    'supportEmail': supportEmail,
    'supportPhone': supportPhone,
    'website': website,
    'playStoreUrl': playStoreUrl,
    'appStoreUrl': appStoreUrl,
    'privacyUrl': privacyUrl,
    'termsUrl': termsUrl,
    'copyright': copyright,
    'features': features,
    'isActive': isActive,
    // Optional: expose soft flags to clients (not max caps)
    'appEnabled': isActive && (limits['appEnabled'] != false),
    'subscriptionsEnabled': limits['subscriptionsEnabled'] != false,
    'applicationsEnabled': limits['applicationsEnabled'] != false,
  };
}

extension PartnerFeesX on PartnerModel {
  bool get applicationFeeEnabled => fees['applicationFeeEnabled'] == true;
  double get applicationFeeAmount => (fees['applicationFeeAmount'] as num?)?.toDouble() ?? 0.0;

  PartnerModel withApplicationFee({required bool enabled, required double amount}) {
    final next = Map<String, dynamic>.from(fees)
      ..['applicationFeeEnabled'] = enabled
      ..['applicationFeeAmount'] = amount;
    return copyWith(fees: next, updatedAt: DateTime.now());
  }
}

extension PartnerLimitsX on PartnerModel {
  bool get appEnabled => isActive && limits['appEnabled'] != false;
  bool get subscriptionsEnabled => limits['subscriptionsEnabled'] != false;
  bool get applicationsEnabled => limits['applicationsEnabled'] != false;

  int get maxLandowners => (limits['maxLandowners'] as num?)?.toInt() ?? -1;
  int get maxProperties => (limits['maxProperties'] as num?)?.toInt() ?? -1;
  int get maxUnits => (limits['maxUnits'] as num?)?.toInt() ?? -1;

  PartnerModel withLimits({
    bool? appEnabled,
    bool? subscriptionsEnabled,
    bool? applicationsEnabled,
    int? maxLandowners,
    int? maxProperties,
    int? maxUnits,
    bool? isActive,
  }) {
    final next = Map<String, dynamic>.from(limits);
    if (appEnabled != null) next['appEnabled'] = appEnabled;
    if (subscriptionsEnabled != null) next['subscriptionsEnabled'] = subscriptionsEnabled;
    if (applicationsEnabled != null) next['applicationsEnabled'] = applicationsEnabled;
    if (maxLandowners != null) next['maxLandowners'] = maxLandowners;
    if (maxProperties != null) next['maxProperties'] = maxProperties;
    if (maxUnits != null) next['maxUnits'] = maxUnits;

    return copyWith(
      limits: next,
      isActive: isActive ?? (appEnabled == false ? false : this.isActive),
      updatedAt: DateTime.now(),
    );
  }
}
