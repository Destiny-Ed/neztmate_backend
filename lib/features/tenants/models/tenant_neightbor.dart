class NeighborModel {
  final String userId;
  final String fullName;
  final String? profileImage;
  final String unitNumber;
  final String? phone;

  final String leaseId;

  NeighborModel({
    required this.userId,
    required this.fullName,
    this.profileImage,
    this.phone,

    required this.unitNumber,
    required this.leaseId,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'fullName': fullName,
      'profileImageUrl': profileImage,
      'unitNumber': unitNumber,
      'phone': phone,

      'leaseId': leaseId,
    };
  }

  factory NeighborModel.fromMap(Map<String, dynamic> map) {
    return NeighborModel(
      userId: map['userId'] ?? '',
      fullName: map['fullName'] ?? '',
      profileImage: map['profileImageUrl'],
      phone: map['phone'] ?? '',

      unitNumber: map['unitNumber'] ?? '',
      leaseId: map['leaseId'] ?? '',
    );
  }
}
