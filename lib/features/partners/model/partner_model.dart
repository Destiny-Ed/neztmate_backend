class PartnerModel {
  final String id;
  final String slug; // neztmate, acme_pm
  final String name;
  final String? logoUrl;
  final String primaryColor;
  final String? secondaryColor;
  final String? supportEmail;
  final String? domain; // optional custom domain later
  final bool isActive;
  final Map<String, dynamic> features; // feature flags
  final Map<String, dynamic> fees; // applicationFee, etc.
  final DateTime createdAt;
  final DateTime updatedAt;

  PartnerModel({
    required this.id,
    required this.slug,
    required this.name,
    this.logoUrl,
    this.primaryColor = '#008080',
    this.secondaryColor,
    this.supportEmail,
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
      logoUrl: map['logoUrl'] as String?,
      primaryColor: map['primaryColor'] as String? ?? '#008080',
      secondaryColor: map['secondaryColor'] as String?,
      supportEmail: map['supportEmail'] as String?,
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
    'logoUrl': logoUrl,
    'primaryColor': primaryColor,
    'secondaryColor': secondaryColor,
    'supportEmail': supportEmail,
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
    String? logoUrl,
    String? primaryColor,
    String? secondaryColor,
    String? supportEmail,
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
      logoUrl: logoUrl ?? this.logoUrl,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      supportEmail: supportEmail ?? this.supportEmail,
      domain: domain ?? this.domain,
      isActive: isActive ?? this.isActive,
      features: features ?? this.features,
      fees: fees ?? this.fees,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Public branding payload for mobile apps
  Map<String, dynamic> toPublicMap() => {
    'id': id,
    'slug': slug,
    'name': name,
    'logoUrl': logoUrl,
    'primaryColor': primaryColor,
    'secondaryColor': secondaryColor,
    'supportEmail': supportEmail,
    'features': features,
  };
}
