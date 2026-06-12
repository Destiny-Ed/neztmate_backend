class NeighborModel {
  final String userId;
  final String fullName;
  final String? profileImage;
  final String unitNumber;
  final String leaseId;

  NeighborModel({
    required this.userId,
    required this.fullName,
    this.profileImage,
    required this.unitNumber,
    required this.leaseId,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'fullName': fullName,
      'profileImageUrl': profileImage,
      'unitNumber': unitNumber,
      'leaseId': leaseId,
    };
  }

  factory NeighborModel.fromMap(Map<String, dynamic> map) {
    return NeighborModel(
      userId: map['userId'] ?? '',
      fullName: map['fullName'] ?? '',
      profileImage: map['profileImageUrl'],
      unitNumber: map['unitNumber'] ?? '',
      leaseId: map['leaseId'] ?? '',
    );
  }
}
