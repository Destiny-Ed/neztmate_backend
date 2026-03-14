class Certification {
  final String id;
  final String artisanId; // reference to user (role = Artisan)
  final String name; // e.g. "Certified Plumber", "Electrical Installation"
  final String? issuingAuthority;
  final String? documentUrl; // PDF/image of certificate
  final DateTime? issuedDate;
  final DateTime? expiryDate;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? status; // 'Active', 'Expired', 'Pending Verification'

  Certification({
    required this.id,
    required this.artisanId,
    required this.name,
    this.issuingAuthority,
    this.documentUrl,
    this.issuedDate,
    this.expiryDate,
    required this.createdAt,
    this.updatedAt,
    this.status = 'Active',
  });

  factory Certification.fromMap(Map<String, dynamic> map, String id) {
    return Certification(
      id: id,
      artisanId: map['artisanId'] as String,
      name: map['name'] as String,
      issuingAuthority: map['issuingAuthority'] as String?,
      documentUrl: map['documentUrl'] as String?,
      issuedDate: map['issuedDate'] != null ? DateTime.parse(map['issuedDate'] as String) : null,
      expiryDate: map['expiryDate'] != null ? DateTime.parse(map['expiryDate'] as String) : null,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt'] as String) : null,
      status: map['status'] as String? ?? 'Active',
    );
  }

  Map<String, dynamic> toMap() => {
    'artisanId': artisanId,
    'name': name,
    'issuingAuthority': issuingAuthority,
    'documentUrl': documentUrl,
    'issuedDate': issuedDate?.toIso8601String(),
    'expiryDate': expiryDate?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'status': status,
  };

  Certification copyWith({
    String? id,
    String? artisanId,
    String? name,
    String? issuingAuthority,
    String? documentUrl,
    DateTime? issuedDate,
    DateTime? expiryDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? status,
  }) {
    return Certification(
      id: id ?? this.id,
      artisanId: artisanId ?? this.artisanId,
      name: name ?? this.name,
      issuingAuthority: issuingAuthority ?? this.issuingAuthority,
      documentUrl: documentUrl ?? this.documentUrl,
      issuedDate: issuedDate ?? this.issuedDate,
      expiryDate: expiryDate ?? this.expiryDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
    );
  }
}
