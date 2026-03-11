class User {
  final String id;
  final String email;
  final String? phone;
  final String fullName;
  final String? profilePhotoUrl;
  final String role;
  final String passwordHash;
  final bool verifiedIdentity;
  final bool verifiedEmployment;
  final int? yearsExperience;
  final String? primarySkill;
  final double rating;

  User({
    required this.id,
    required this.email,
    this.phone,
    required this.fullName,
    this.profilePhotoUrl,
    required this.role,
    this.verifiedIdentity = false,
    this.verifiedEmployment = false,
    this.yearsExperience,
    this.primarySkill,
    this.rating = 0.0,
    this.passwordHash = "",
  });
}
