class User {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final String fcmToken;
  final String? phone;
  final String? profilePhotoUrl;
  final String? bio;
  final String? address;
  final bool verifiedIdentity;
  final bool verifiedEmployment;
  final bool emailVerified;
  final String occupation;
  final String? verificationId;
  final String? verificationProvider;
  final String? verificationStatus;
  final String? verificationReason;
  final DateTime? identityVerifiedAt;
  final int? yearsExperience;
  final String? primarySkill;

  final double rating;
  final double averageRating;
  final int totalReviews;
  final int totalRatings;

  final double paymentOnTimeRate;
  final int totalPaymentsMade;
  final int onTimePayments;

  final double tenantReputation;
  final double landlordReputation;
  final double artisanReputation;

  final DateTime createdAt;
  final DateTime lastLogin;
  final DateTime? lastReviewedAt;

  final List<String> badges;

  final String? passwordHash;
  final String? authProvider;
  final String platform;
  final String country;

  final String primaryRole;
  final List<String> roles;

  final String? referralCode;
  final String? referredBy;

  /// White-label partner document id (default NeztMate partner)
  final String partnerId;

  User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.phone,
    this.profilePhotoUrl,
    this.bio,
    this.address,
    this.occupation = '',
    this.verifiedIdentity = false,
    this.verifiedEmployment = false,
    this.emailVerified = false,
    this.yearsExperience,
    this.primarySkill,
    this.rating = 0.0,
    self.averageRating = 0.0,
