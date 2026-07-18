class User {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final String fcmToken;
  final String? phone;
  final String? profilePhotoUrl;
  final bool verifiedIdentity;
  final bool verifiedEmployment;
  final String occupation;
  final String? verificationId; // Generic ID from any provider
  final String? verificationProvider; // "SmileIdentity", "Veriff", "Onfido", etc.
  final String? verificationStatus; // 'pending', 'approved', 'rejected', 'failed'
  final DateTime? identityVerifiedAt;
  final int? yearsExperience;
  final String? primarySkill;

  // === Existing Rating ===
  final double rating; // Legacy overall rating

  // === NEW: Reputation System ===
  final double averageRating; // Overall rating from reviews (1.0 - 5.0)
  final int totalReviews;
  final int totalRatings;

  // Payment Reliability (mainly for Tenants)
  final double paymentOnTimeRate; // 0.0 - 1.0 (e.g., 0.95 = 95%)
  final int totalPaymentsMade;
  final int onTimePayments;

  // Role-specific Reputation
  final double tenantReputation;
  final double landlordReputation;
  final double artisanReputation;

  final DateTime createdAt;
  final DateTime lastLogin;
  final DateTime? lastReviewedAt;

  final List<String> badges; // e.g., "Reliable_Payer", "Trusted_Landlord"

  final String? passwordHash;
  final String? authProvider;
  final String platform;
  final String country;

  final String primaryRole; // Main role for UI
  final List<String> roles; // All roles user has

  final String? referralCode;
  final String? referredBy;

  User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.phone,
    this.profilePhotoUrl,
    this.occupation = '',
    this.verifiedIdentity = false,
    this.verifiedEmployment = false,
    this.yearsExperience,
    this.primarySkill,
    this.rating = 0.0,
    this.averageRating = 0.0,
    this.totalReviews = 0,
    this.totalRatings = 0,
    this.paymentOnTimeRate = 1.0,
    this.totalPaymentsMade = 0,
    this.onTimePayments = 0,
    this.tenantReputation = 0.0,
    this.landlordReputation = 0.0,
    this.artisanReputation = 0.0,
    this.verificationId,
    this.verificationProvider,
    this.verificationStatus = 'pending',
    this.identityVerifiedAt,
    required this.createdAt,
    required this.lastLogin,
    this.lastReviewedAt,
    this.badges = const [],
    this.passwordHash = '',
    this.authProvider = 'email',
    required this.fcmToken,
    required this.platform,
    required this.country,

    required this.primaryRole,
    this.roles = const [],

    this.referralCode,
    this.referredBy,
  });

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map["id"] as String,
      email: map['email'] as String? ?? '',
      fullName: map['fullName'] as String? ?? '',
      role: map['role'] as String? ?? 'Tenant',
      phone: map['phone'] as String?,
      occupation: map['occupation'] ?? '',
      profilePhotoUrl: map['profilePhotoUrl'] as String?,
      verifiedIdentity: map['verifiedIdentity'] as bool? ?? false,
      verifiedEmployment: map['verifiedEmployment'] as bool? ?? false,
      yearsExperience: map['yearsExperience'] as int?,
      primarySkill: map['primarySkill'] as String?,
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,

      verificationId: map['verificationId'] as String?,
      verificationProvider: map['verificationProvider'] as String?,
      verificationStatus: map['verificationStatus'] as String? ?? 'pending',
      identityVerifiedAt: map['identityVerifiedAt'] != null
          ? DateTime.parse(map['identityVerifiedAt'])
          : null,

      // New reputation fields
      averageRating: (map['averageRating'] as num?)?.toDouble() ?? 0.0,
      totalReviews: map['totalReviews'] as int? ?? 0,
      totalRatings: map['totalRatings'] as int? ?? 0,
      paymentOnTimeRate: (map['paymentOnTimeRate'] as num?)?.toDouble() ?? 1.0,
      totalPaymentsMade: map['totalPaymentsMade'] as int? ?? 0,
      onTimePayments: map['onTimePayments'] as int? ?? 0,
      tenantReputation: (map['tenantReputation'] as num?)?.toDouble() ?? 0.0,
      landlordReputation: (map['landlordReputation'] as num?)?.toDouble() ?? 0.0,
      artisanReputation: (map['artisanReputation'] as num?)?.toDouble() ?? 0.0,
      lastReviewedAt: map['lastReviewedAt'] != null ? DateTime.parse(map['lastReviewedAt']) : null,
      badges: (map['badges'] as List<dynamic>?)?.cast<String>() ?? [],

      createdAt: DateTime.parse(map['createdAt'] as String),
      lastLogin: DateTime.parse(map['lastLogin'] as String),
      passwordHash: map["passwordHash"] as String?,
      authProvider: map['authProvider'] as String? ?? 'email',
      fcmToken: map["fcmToken"] ?? '',
      platform: map['platform'] ?? '',
      country: map['country'] ?? '',

      primaryRole: map['primaryRole'] as String? ?? 'Tenant',
      roles: (map['roles'] as List<dynamic>?)?.cast<String>() ?? [map['role'] ?? 'tenant'],

      referralCode: map['referralCode'] as String?,
      referredBy: map['referredBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'email': email,
    'fullName': fullName,
    'role': role,
    'phone': phone,
    'profilePhotoUrl': profilePhotoUrl,
    'verifiedIdentity': verifiedIdentity,
    'occupation': occupation,
    'verifiedEmployment': verifiedEmployment,
    'yearsExperience': yearsExperience,
    'primarySkill': primarySkill,
    'rating': rating,
    'verificationId': verificationId,
    'verificationProvider': verificationProvider,
    'verificationStatus': verificationStatus,
    'identityVerifiedAt': identityVerifiedAt?.toIso8601String(),

    // New reputation fields
    'averageRating': averageRating,
    'totalReviews': totalReviews,
    'totalRatings': totalRatings,
    'paymentOnTimeRate': paymentOnTimeRate,
    'totalPaymentsMade': totalPaymentsMade,
    'onTimePayments': onTimePayments,
    'tenantReputation': tenantReputation,
    'landlordReputation': landlordReputation,
    'artisanReputation': artisanReputation,
    'lastReviewedAt': lastReviewedAt?.toIso8601String(),
    'badges': badges,

    'createdAt': createdAt.toIso8601String(),
    'lastLogin': lastLogin.toIso8601String(),
    'passwordHash': passwordHash,
    'authProvider': authProvider,
    'fcmToken': fcmToken,
    'platform': platform,
    'country': country,
    'primaryRole': primaryRole,
    'roles': roles,

    'referralCode': referralCode,
    'referredBy': referredBy,
  };

  User copyWith({
    String? id,
    String? email,
    String? fullName,
    String? role,
    String? phone,
    String? profilePhotoUrl,
    bool? verifiedIdentity,
    bool? verifiedEmployment,
    String? verificationId,
    String? verificationProvider,
    String? verificationStatus,
    DateTime? identityVerifiedAt,
    String? occupation,
    int? yearsExperience,
    String? primarySkill,
    double? rating,
    double? averageRating,
    int? totalReviews,
    int? totalRatings,
    double? paymentOnTimeRate,
    int? totalPaymentsMade,
    int? onTimePayments,
    double? tenantReputation,
    double? landlordReputation,
    double? artisanReputation,
    DateTime? createdAt,
    DateTime? lastLogin,
    DateTime? lastReviewedAt,
    List<String>? badges,
    String? passwordHash,
    String? authProvider,
    String? platform,
    String? country,
    String? fcmToken,
    String? primaryRole,
    List<String>? roles,

    String? referralCode,
    String? referredBy,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      verifiedIdentity: verifiedIdentity ?? this.verifiedIdentity,
      verificationId: verificationId ?? this.verificationId,
      verificationProvider: verificationProvider ?? this.verificationProvider,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      identityVerifiedAt: identityVerifiedAt ?? this.identityVerifiedAt,
      verifiedEmployment: verifiedEmployment ?? this.verifiedEmployment,
      yearsExperience: yearsExperience ?? this.yearsExperience,
      primarySkill: primarySkill ?? this.primarySkill,
      rating: rating ?? this.rating,
      occupation: occupation ?? this.occupation,
      averageRating: averageRating ?? this.averageRating,
      totalReviews: totalReviews ?? this.totalReviews,
      totalRatings: totalRatings ?? this.totalRatings,
      paymentOnTimeRate: paymentOnTimeRate ?? this.paymentOnTimeRate,
      totalPaymentsMade: totalPaymentsMade ?? this.totalPaymentsMade,
      onTimePayments: onTimePayments ?? this.onTimePayments,
      tenantReputation: tenantReputation ?? this.tenantReputation,
      landlordReputation: landlordReputation ?? this.landlordReputation,
      artisanReputation: artisanReputation ?? this.artisanReputation,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      badges: badges ?? this.badges,
      passwordHash: passwordHash ?? this.passwordHash,
      authProvider: authProvider ?? this.authProvider,
      fcmToken: fcmToken ?? this.fcmToken,
      platform: platform ?? this.platform,
      country: country ?? this.country,
      primaryRole: primaryRole ?? this.primaryRole,
      roles: roles ?? this.roles,

      referralCode: referralCode ?? this.referralCode,
      referredBy: referredBy ?? this.referredBy,
    );
  }
}
