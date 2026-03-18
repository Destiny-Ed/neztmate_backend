class InviteModel {
  final String id;
  final String inviterId;
  final String inviteeEmail;
  final String? inviteePhone;
  final String role; // Tenant, Landowner, Manager, Artisan
  final List<String>? propertyIds; // properties they will manage/own
  final String? message;
  final String status; // Pending, Accepted, Declined, Expired
  final String? inviteLink; // unique shareable link
  final DateTime createdAt;
  final DateTime? expiresAt;

  InviteModel({
    required this.id,
    required this.inviterId,
    required this.inviteeEmail,
    this.inviteePhone,
    required this.role,
    this.propertyIds,
    this.message,
    this.status = 'Pending',
    this.inviteLink,
    required this.createdAt,
    this.expiresAt,
  });

  factory InviteModel.fromMap(Map<String, dynamic> map, String id) {
    return InviteModel(
      id: id,
      inviterId: map['inviterId'] as String,
      inviteeEmail: map['inviteeEmail'] as String,
      inviteePhone: map['inviteePhone'] as String?,
      role: map['role'] as String,
      propertyIds: (map['propertyIds'] as List<dynamic>?)?.cast<String>(),
      message: map['message'] as String?,
      status: map['status'] as String? ?? 'Pending',
      inviteLink: map['inviteLink'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      expiresAt: map['expiresAt'] != null ? DateTime.parse(map['expiresAt'] as String) : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'inviterId': inviterId,
    'inviteeEmail': inviteeEmail,
    'inviteePhone': inviteePhone,
    'role': role,
    'propertyIds': propertyIds,
    'message': message,
    'status': status,
    'inviteLink': inviteLink,
    'createdAt': createdAt.toIso8601String(),
    'expiresAt': expiresAt?.toIso8601String(),
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
    DateTime? expiresAt,
  }) {
    return InviteModel(
      id: id ?? this.id,
      inviterId: inviterId ?? this.inviterId,
      inviteeEmail: inviteeEmail ?? this.inviteeEmail,
      inviteePhone: inviteePhone ?? this.inviteePhone,
      role: role ?? this.role,
      propertyIds: propertyIds ?? this.propertyIds,
      message: message ?? this.message,
      status: status ?? this.status,
      inviteLink: inviteLink ?? this.inviteLink,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}
