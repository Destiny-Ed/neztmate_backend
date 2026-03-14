class PropertyModel {
  final String id;
  final String name;
  final String type; // 'Apartment', 'House', 'Commercial'
  final String address;
  final String landownerId;
  final String? managerId;
  final List<String>? photoUrls;
  final List<String>? amenities; // ['WiFi', 'Parking', 'Pool', ...]
  final int totalUnits;
  final double occupancyRate;
  final DateTime createdAt;

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
  });

  factory PropertyModel.fromMap(Map<String, dynamic> map, String id) {
    return PropertyModel(
      id: id,
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
    );
  }

  Map<String, dynamic> toMap() => {
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
  };

  PropertyModel copyWith({
    String? id,
    String? name,
    String? type,
    String? address,
    String? landownerId,
    String? managerId,
    List<String>? photoUrls,
    List<String>? amenities,
    int? totalUnits,
    double? occupancyRate,
    DateTime? createdAt,
  }) {
    return PropertyModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      address: address ?? this.address,
      landownerId: landownerId ?? this.landownerId,
      managerId: managerId ?? this.managerId,
      photoUrls: photoUrls ?? this.photoUrls,
      amenities: amenities ?? this.amenities,
      totalUnits: totalUnits ?? this.totalUnits,
      occupancyRate: occupancyRate ?? this.occupancyRate,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
