class SocialRequestModel {
  final String idToken;
  final String fcmToken;
  final String fullName;
  final String platform;
  final String country;
  final String role; // "Tenant" | "Landowner" | "Manager" | "Artisan"
  final String partnerSlug;

  SocialRequestModel({
    required this.idToken,
    required this.fullName,
    required this.role,
    required this.fcmToken,
    required this.country,
    required this.platform,
    this.partnerSlug = '',
  });

  factory SocialRequestModel.fromJson(Map<String, dynamic> json) {
    return SocialRequestModel(
      idToken: json['idToken'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      role: json['role'] as String? ?? '',
      fcmToken: json['fcmToken'] as String? ?? '',
      country: json['country'] as String? ?? '',
      platform: json['platform'] as String? ?? '',
      partnerSlug: (json['partnerSlug'] as String?)?.trim().toLowerCase() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'idToken': idToken,
    'fullName': fullName,
    'role': role,
    'fcmToken': fcmToken,
    'country': country,
    'platform': platform,
    'partnerSlug': partnerSlug,
  };

  SocialRequestModel copyWith({
    String? idToken,
    String? fcmToken,
    String? fullName,
    String? platform,
    String? country,
    String? role,
    String? partnerSlug,
  }) {
    return SocialRequestModel(
      idToken: idToken ?? this.idToken,
      fcmToken: fcmToken ?? this.fcmToken,
      fullName: fullName ?? this.fullName,
      platform: platform ?? this.platform,
      country: country ?? this.country,
      role: role ?? this.role,
      partnerSlug: partnerSlug ?? this.partnerSlug,
    );
  }
}
