import '../../domain/entities/user.dart';

class UserModel extends User {
  UserModel({
    required super.id,
    required super.email,
    super.phone,
    required super.fullName,
    super.profilePhotoUrl,
    required super.role,
    super.verifiedIdentity,
    super.verifiedEmployment,
    super.yearsExperience,
    super.primarySkill,
    super.rating,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      email: json['email'],
      phone: json['phone'],
      fullName: json['full_name'],
      profilePhotoUrl: json['profile_photo_url'],
      role: json['role'],
      verifiedIdentity: json['verified_identity'] ?? false,
      verifiedEmployment: json['verified_employment'] ?? false,
      yearsExperience: json['years_experience'],
      primarySkill: json['primary_skill'],
      rating: (json['rating'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "email": email,
      "phone": phone,
      "full_name": fullName,
      "profile_photo_url": profilePhotoUrl,
      "role": role,
      "verified_identity": verifiedIdentity,
      "verified_employment": verifiedEmployment,
      "years_experience": yearsExperience,
      "primary_skill": primarySkill,
      "rating": rating,
    };
  }
}