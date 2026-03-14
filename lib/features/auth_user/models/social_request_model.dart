class SocialRequestModel {
  final String idToken;
  final String fcmToken;
  final String fullName;
  final String platform;
  final String country;
  final String role; // "Tenant" | "Landowner" | "Manager" | "Artisan"

  SocialRequestModel({
    required this.idToken,
    required this.fullName,
    required this.role,
    required this.fcmToken,
    required this.country,
    required this.platform,
  });

  factory SocialRequestModel.fromJson(Map<String, dynamic> json) {
    return SocialRequestModel(
      idToken: json['idToken'] ?? "",
      fullName: json['fullName'] ?? "",
      role: json['role'] ?? "",
      fcmToken: json['fcmToken'] ?? "",
      country: json['country'] ?? "",
      platform: json['platform'] ?? "",
    );
  }
}
