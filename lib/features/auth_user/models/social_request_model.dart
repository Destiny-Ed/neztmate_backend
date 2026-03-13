class SocialRequestModel {
  final String idToken;
  final String password;
  final String fcmToken;
  final String fullName;
  final String platform;
  final String country;
  final String role; // "Tenant" | "Landowner" | "Manager" | "Artisan"

  SocialRequestModel({
    required this.idToken,
    required this.password,
    required this.fullName,
    required this.role,
    required this.fcmToken,
    required this.country,
    required this.platform,
  });

  factory SocialRequestModel.fromJson(Map<String, dynamic> json) {
    return SocialRequestModel(
      idToken: json['idToken'] as String,
      password: json['password'] as String,
      fullName: json['fullName'] as String,
      role: json['role'] as String,
      fcmToken: json['fcmToken'],
      country: json['country'],
      platform: json['platform'],
    );
  }
}
