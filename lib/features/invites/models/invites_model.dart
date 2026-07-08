class InviteModel {
  final String id;
  final String inviterId;
  final String inviteeEmail;
  final String role;
  final List<String>? propertyIds;
  final String? message;
  final String status;
  final String? inviteLink;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime expiresAt;

  // === NEW: Commission Structure ===
  final String commissionType; // "percentage", "flat_fee", "none"
  final double? commissionRate; // e.g., 0.05 for 5%
  final double? flatFeeAmount; // e.g., 50000
  final String? flatFeePeriod; // "yearly", "monthly"

  InviteModel({
    required this.id,
    required this.inviterId,
    required this.inviteeEmail,
    required this.role,
    this.propertyIds,
    this.message,
    this.status = 'Pending',
    this.inviteLink,
    required this.createdAt,
    required this.updatedAt,
    required this.expiresAt,

    this.commissionType = 'none',
    this.commissionRate,
    this.flatFeeAmount,
    this.flatFeePeriod,
  });

  factory InviteModel.fromMap(Map<String, dynamic> map) {
    return InviteModel(
      id: map['id'] ?? '',
      inviterId: map['inviterId'] as String,
      inviteeEmail: map['inviteeEmail'] as String,
      role: map['role'] as String,
      propertyIds: (map['propertyIds'] as List<dynamic>?)?.cast<String>(),
      message: map['message'] as String?,
      status: map['status'] as String? ?? 'Pending',
      inviteLink: map['inviteLink'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      expiresAt: DateTime.parse(map['expiresAt'] as String),

      commissionType: map['commissionType'] as String? ?? 'none',
      commissionRate: (map['commissionRate'] as num?)?.toDouble(),
      flatFeeAmount: (map['flatFeeAmount'] as num?)?.toDouble(),
      flatFeePeriod: map['flatFeePeriod'] as String?,
    );
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toMap() => {
    'id': id,
    'inviterId': inviterId,
    'inviteeEmail': inviteeEmail.toLowerCase(),
    'role': role,
    'propertyIds': propertyIds,
    'message': message,
    'status': status,
    'inviteLink': inviteLink,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': createdAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),

    'commissionType': commissionType,
    'commissionRate': commissionRate,
    'flatFeeAmount': flatFeeAmount,
    'flatFeePeriod': flatFeePeriod,
  };

  InviteModel copyWith({
    String? id,
    String? inviterId,
    String? inviteeEmail,
    String? inviteePhone,
    String? role,
    List<String>? propertyIds,
    String? message,
    String? status,
    String? inviteLink,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? expiresAt,

    String? commissionType,
    double? commissionRate,
    double? flatFeeAmount,
    String? flatFeePeriod,
  }) {
    return InviteModel(
      id: id ?? this.id,
      inviterId: inviterId ?? this.inviterId,
      inviteeEmail: inviteeEmail ?? this.inviteeEmail,
      role: role ?? this.role,
      propertyIds: propertyIds ?? this.propertyIds,
      message: message ?? this.message,
      status: status ?? this.status,
      inviteLink: inviteLink ?? this.inviteLink,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      expiresAt: expiresAt ?? this.expiresAt,

      commissionType: commissionType ?? this.commissionType,
      commissionRate: commissionRate ?? this.commissionRate,
      flatFeeAmount: flatFeeAmount ?? this.flatFeeAmount,
      flatFeePeriod: flatFeePeriod ?? this.flatFeePeriod,
    );
  }
}
