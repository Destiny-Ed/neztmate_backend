class PartnerRequestModel {
  final String id;
  final String companyName;
  final String contactName;
  final String email;
  final String phone;
  final String proposedSlug;
  final String? website;
  final String cities;
  final String? portfolioSize;
  final String message;
  final String status; // pending | contacted | approved | rejected
  final String? notes;
  final String? partnerId; // set when approved
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  PartnerRequestModel({
    required this.id,
    required this.companyName,
    required this.contactName,
    required this.email,
    required this.phone,
    required this.proposedSlug,
    this.website,
    required this.cities,
    this.portfolioSize,
    required this.message,
    this.status = 'pending',
    this.notes,
    this.partnerId,
    this.reviewedBy,
    this.reviewedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PartnerRequestModel.fromMap(Map<String, dynamic> map, [String? id]) {
    DateTime? parseDt(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString());
    }

    return PartnerRequestModel(
      id: id ?? map['id'] as String? ?? '',
      companyName: map['companyName'] as String? ?? '',
      contactName: map['contactName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      proposedSlug: map['proposedSlug'] as String? ?? '',
      website: map['website'] as String?,
      cities: map['cities'] as String? ?? '',
      portfolioSize: map['portfolioSize'] as String?,
      message: map['message'] as String? ?? '',
      status: map['status'] as String? ?? 'pending',
      notes: map['notes'] as String?,
      partnerId: map['partnerId'] as String?,
      reviewedBy: map['reviewedBy'] as String?,
      reviewedAt: parseDt(map['reviewedAt']),
      createdAt: parseDt(map['createdAt']) ?? DateTime.now(),
      updatedAt: parseDt(map['updatedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'companyName': companyName,
    'contactName': contactName,
    'email': email,
    'phone': phone,
    'proposedSlug': proposedSlug,
    'website': website,
    'cities': cities,
    'portfolioSize': portfolioSize,
    'message': message,
    'status': status,
    'notes': notes,
    'partnerId': partnerId,
    'reviewedBy': reviewedBy,
    'reviewedAt': reviewedAt?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  PartnerRequestModel copyWith({
    String? id,
    String? companyName,
    String? contactName,
    String? email,
    String? phone,
    String? proposedSlug,
    String? website,
    String? cities,
    String? portfolioSize,
    String? message,
    String? status,
    String? notes,
    String? partnerId,
    String? reviewedBy,
    DateTime? reviewedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PartnerRequestModel(
      id: id ?? this.id,
      companyName: companyName ?? this.companyName,
      contactName: contactName ?? this.contactName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      proposedSlug: proposedSlug ?? this.proposedSlug,
      website: website ?? this.website,
      cities: cities ?? this.cities,
      portfolioSize: portfolioSize ?? this.portfolioSize,
      message: message ?? this.message,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      partnerId: partnerId ?? this.partnerId,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
