class RegisterRequest {
  final String email;
  final String password;
  final String fcmToken;
  final String fullName;
  final String platform;
  final String country;
  final String role; // "Tenant" | "Landowner" | "Manager" | "Artisan"
  final String partnerSlug;

  RegisterRequest({
    required this.email,
    required this.password,
    required this.fullName,
    required this.role,
    required this.fcmToken,
    required this.country,
    required this.platform,
    this.partnerSlug = '',
  });

  factory RegisterRequest.fromJson(Map<String, dynamic> json) {
    return RegisterRequest(
      email: json['email'] as String? ?? '',
      password: json['password'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      role: json['role'] as String? ?? 'Tenant',
      fcmToken: json['fcmToken'] as String? ?? '',
      country: json['country'] as String? ?? '',
      platform: json['platform'] as String? ?? '',
      partnerSlug: (json['partnerSlug'] as String?)?.trim().toLowerCase() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
    'fullName': fullName,
    'role': role,
    'fcmToken': fcmToken,
    'country': country,
    'platform': platform,
    'partnerSlug': partnerSlug,
  };

  RegisterRequest copyWith({
    String? email,
    String? password,
    String? fcmToken,
    String? fullName,
    String? platform,
    String? country,
    String? role,
    String? partnerSlug,
  }) {
    return RegisterRequest(
      email: email ?? this.email,
      password: password ?? this.password,
      fcmToken: fcmToken ?? this.fcmToken,
      fullName: fullName ?? this.fullName,
      platform: platform ?? this.platform,
      country: country ?? this.country,
      role: role ?? this.role,
      partnerSlug: partnerSlug ?? this.partnerSlug,
    );
  }
}
