class TenantSummary {
  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String? profilePhotoUrl;
  final String unitId;
  final String unitNumber;
  final double monthlyRent;
  final DateTime leaseStartDate;
  final DateTime? leaseEndDate;
  final String leaseStatus;

  TenantSummary({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    this.profilePhotoUrl,
    required this.unitId,
    required this.unitNumber,
    required this.monthlyRent,
    required this.leaseStartDate,
    this.leaseEndDate,
    required this.leaseStatus,
  });

  factory TenantSummary.fromMap(Map<String, dynamic> map) {
    return TenantSummary(
      id: map['id'],
      fullName: map['fullName'],
      email: map['email'],
      phone: map['phone'],
      profilePhotoUrl: map['profilePhotoUrl'],
      unitId: map['unitId'],
      unitNumber: map['unitNumber'],
      monthlyRent: (map['monthlyRent'] as num).toDouble(),
      leaseStartDate: DateTime.parse(map['leaseStartDate']),
      leaseEndDate: map['leaseEndDate'] != null ? DateTime.parse(map['leaseEndDate']) : null,
      leaseStatus: map['leaseStatus'],
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'fullName': fullName,
    'email': email,
    'phone': phone,
    'profilePhotoUrl': profilePhotoUrl,
    'unitId': unitId,
    'unitNumber': unitNumber,
    'monthlyRent': monthlyRent,
    'leaseStartDate': leaseStartDate.toIso8601String(),
    'leaseEndDate': leaseEndDate?.toIso8601String(),
    'leaseStatus': leaseStatus,
  };
}
