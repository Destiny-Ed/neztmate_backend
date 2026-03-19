class PropertyModel {
  final String id;
  final String name;
  final String type; // 'Apartment', 'House', 'Commercial'
  final String address;
  final String landownerId;
  final String? managerId;
  final String documentType;
  final String proofOfOwnershipUrl;
  final List<String>? photoUrls;
  final List<String>? amenities; // ['WiFi', 'Parking', 'Pool', ...]
  final int totalUnits;
  final double occupancyRate;
  DateTime createdAt;
  DateTime updatedAt;

  PropertyModel({
    required this.id,
    required this.name,
    required this.type,
    required this.address,
    required this.landownerId,
    this.managerId,
    this.photoUrls,
    this.amenities,
    this.totalUnits = 0,
    this.occupancyRate = 0.0,
    required this.createdAt,
    required this.updatedAt,
    required this.proofOfOwnershipUrl,
    required this.documentType,
  });

  factory PropertyModel.fromMap(Map<String, dynamic> map) {
    return PropertyModel(
      id: map['id'] as String,
      name: map['name'] as String,
      type: map['type'] as String,
      address: map['address'] as String,
      landownerId: map['landownerId'] as String,
      managerId: map['managerId'] as String?,
      photoUrls: (map['photoUrls'] as List<dynamic>?)?.cast<String>(),
      amenities: (map['amenities'] as List<dynamic>?)?.cast<String>(),
      totalUnits: map['totalUnits'] as int? ?? 0,
      occupancyRate: (map['occupancyRate'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      proofOfOwnershipUrl: map['proofOfOwnershipUrl'] as String,
      documentType: map['documentType'] as String,
    );
  }

  Map<String, dynamic> toMap() => {
    'id' : id,
    'name': name,
    'type': type,
    'address': address,
    'landownerId': landownerId,
    'managerId': managerId,
    'photoUrls': photoUrls,
    'amenities': amenities,
    'totalUnits': totalUnits,
    'occupancyRate': occupancyRate,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'proofOfOwnershipUrl': proofOfOwnershipUrl,
    'documentType': documentType,
  };

  PropertyModel copyWith({
    String? id,
    String? name,
    String? type,
    String? address,
    String? landownerId,
    String? managerId,
    String? proofOfOwnershipUrl,
    String? documentType,
    List<String>? photoUrls,
    List<String>? amenities,
    int? totalUnits,
    double? occupancyRate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PropertyModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      address: address ?? this.address,
      proofOfOwnershipUrl: proofOfOwnershipUrl ?? this.proofOfOwnershipUrl,
      landownerId: landownerId ?? this.landownerId,
      managerId: managerId ?? this.managerId,
      photoUrls: photoUrls ?? this.photoUrls,
      amenities: amenities ?? this.amenities,
      totalUnits: totalUnits ?? this.totalUnits,
      occupancyRate: occupancyRate ?? this.occupancyRate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      documentType: documentType ?? this.documentType,
    );
  }
}
