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
  final int? yearsExperience;
  final String? primarySkill;
  final double rating;
  final DateTime createdAt;
  final DateTime lastLogin;
  final String? passwordHash;
  final String? authProvider;
  final String platform;
  final String country;

  User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.phone,
    this.profilePhotoUrl,
    this.verifiedIdentity = false,
    this.verifiedEmployment = false,
    this.yearsExperience,
    this.primarySkill,
    this.rating = 0.0,
    required this.createdAt,
    required this.lastLogin,
    this.passwordHash = '',
    this.authProvider = 'email',
    required this.fcmToken,
    required this.platform,
    required this.country,
  });

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map["id"] as String,
      email: map['email'] as String? ?? '',
      fullName: map['fullName'] as String? ?? '',
      role: map['role'] as String? ?? 'Tenant',
      phone: map['phone'] as String?,
      profilePhotoUrl: map['profilePhotoUrl'] as String?,
      verifiedIdentity: map['verifiedIdentity'] as bool? ?? false,
      verifiedEmployment: map['verifiedEmployment'] as bool? ?? false,
      yearsExperience: map['yearsExperience'] as int?,
      primarySkill: map['primarySkill'] as String?,
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(map['createdAt'] as String),
      lastLogin: DateTime.parse(map['lastLogin'] as String),
      passwordHash: map["passwordHash"] as String?,
      authProvider: map['authProvider'] as String? ?? 'email',
      fcmToken: map["fcmToken"],
      platform: map['platform'],
      country: map['country'],
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
    'verifiedEmployment': verifiedEmployment,
    'yearsExperience': yearsExperience,
    'primarySkill': primarySkill,
    'rating': rating,
    'createdAt': createdAt.toIso8601String(),
    'lastLogin': lastLogin.toIso8601String(),
    'passwordHash': passwordHash,
    'authProvider': authProvider,
    'fcmToken': fcmToken,
    'platform': platform,
    'country': country,
  };

  /// Creates a copy of this User with the specified fields replaced with new values.
  User copyWith({
    String? id,
    String? email,
    String? fullName,
    String? role,
    String? phone,
    String? profilePhotoUrl,
    bool? verifiedIdentity,
    bool? verifiedEmployment,
    int? yearsExperience,
    String? primarySkill,
    double? rating,
    DateTime? createdAt,
    DateTime? lastLogin,
    String? passwordHash,
    String? authProvider,
    String? platform,
    String? country,
    String? fcmToken,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      verifiedIdentity: verifiedIdentity ?? this.verifiedIdentity,
      verifiedEmployment: verifiedEmployment ?? this.verifiedEmployment,
      yearsExperience: yearsExperience ?? this.yearsExperience,
      primarySkill: primarySkill ?? this.primarySkill,
      rating: rating ?? this.rating,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      passwordHash: passwordHash ?? this.passwordHash,
      authProvider: authProvider ?? this.authProvider,
      fcmToken: fcmToken ?? this.fcmToken,
      platform: platform ?? this.platform,
      country: country ?? this.country,
    );
  }
}
