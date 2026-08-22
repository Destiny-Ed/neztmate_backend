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
  final bool isActive;
  final Map<String, dynamic> features;
  final Map<String, dynamic> fees;
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
    this.isActive = true,
    this.features = const {},
    this.fees = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory PartnerModel.fromMap(Map<String, dynamic> map, [String? id]) {
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
      isActive: map['isActive'] as bool? ?? true,
      features: map['features'] != null ? Map<String, dynamic>.from(map['features'] as Map) : {},
      fees: map['fees'] != null ? Map<String, dynamic>.from(map['fees'] as Map) : {},
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
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
    'isActive': isActive,
    'features': features,
    'fees': fees,
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
    bool? isActive,
    Map<String, dynamic>? features,
    Map<String, dynamic>? fees,
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
      isActive: isActive ?? this.isActive,
      features: features ?? this.features,
      fees: fees ?? this.fees,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Used by web + mobile branding
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
    'features': features,
    'isActive': isActive,
  };
}
