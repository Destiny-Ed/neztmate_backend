class User {
  final String id;
  final String email;
  final String fullName;
  final String role;
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
  });

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map["id"] as String,
      email: map['email'] as String? ?? '',
      fullName: map['full_name'] as String? ?? '',
      role: map['role'] as String? ?? 'Tenant',
      phone: map['phone'] as String?,
      profilePhotoUrl: map['profile_photo_url'] as String?,
      verifiedIdentity: map['verified_identity'] as bool? ?? false,
      verifiedEmployment: map['verified_employment'] as bool? ?? false,
      yearsExperience: map['years_experience'] as int?,
      primarySkill: map['primary_skill'] as String?,
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(map['created_at'] as String),
      lastLogin: DateTime.parse(map['last_login'] as String),
      passwordHash: map["password_hash"] as String?,
      authProvider: map['auth_provider'] as String? ?? 'email',
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'email': email,
    'full_name': fullName,
    'role': role,
    'phone': phone,
    'profile_photo_url': profilePhotoUrl,
    'verified_identity': verifiedIdentity,
    'verified_employment': verifiedEmployment,
    'years_experience': yearsExperience,
    'primary_skill': primarySkill,
    'rating': rating,
    'created_at': createdAt.toIso8601String(),
    'last_login': lastLogin.toIso8601String(),
    'password_hash': passwordHash,
    'auth_provider': authProvider,
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
    );
  }
}
