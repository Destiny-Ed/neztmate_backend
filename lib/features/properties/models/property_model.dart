class PropertyModel {
  final String id;
  final String name;
  final String type; // 'Apartment', 'House', 'Commercial'
  final String address;
  final String partnerId;
  final String landownerId;
  final String? managerId;
  final List<String>? photoUrls;
  final List<String>? amenities; // ['WiFi', 'Parking', 'Pool', ...]
  final int totalUnits;
  final double occupancyRate;
  DateTime createdAt;
  DateTime updatedAt;
  final String rentPaymentMode; // 'offline' | 'online'
  List<String>? artisanIds;
  final List<Map<String, dynamic>> documents;

  final String? managerCommissionType; // "percentage", "flat_fee", "none"
  final double? managerCommissionRate; // e.g. 0.05
  final double? managerFlatFeeAmount;
  final String? managerFlatFeePeriod; // "yearly", "monthly"

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
    this.rentPaymentMode = 'offline',
    required this.createdAt,
    required this.updatedAt,

    this.artisanIds,
    required this.documents,
    this.partnerId = '',

    this.managerCommissionType,
    this.managerCommissionRate,
    this.managerFlatFeeAmount,
    this.managerFlatFeePeriod,
  });

  factory PropertyModel.fromMap(Map<String, dynamic> map) {
    return PropertyModel(
      id: map['id'] as String,
      name: map['name'] as String,
      type: map['type'] as String,
      address: map['address'] as String,
      landownerId: map['landownerId'] as String,
      managerId: map['managerId'] as String?,
      rentPaymentMode: map['rentPaymentMode'] as String? ?? 'offline',
      photoUrls: (map['photoUrls'] as List<dynamic>?)?.cast<String>(),
      amenities: (map['amenities'] as List<dynamic>?)?.cast<String>(),
      artisanIds: (map['artisanIds'] as List<dynamic>?)?.cast<String>(),
      totalUnits: map['totalUnits'] as int? ?? 0,
      occupancyRate: (map['occupancyRate'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      documents: (map['documents'] as List<dynamic>).cast<Map<String, dynamic>>(),

      managerCommissionType: map['managerCommissionType'] as String?,
      managerCommissionRate: (map['managerCommissionRate'] as num?)?.toDouble(),
      managerFlatFeeAmount: (map['managerFlatFeeAmount'] as num?)?.toDouble(),
      managerFlatFeePeriod: map['managerFlatFeePeriod'] as String?,
      partnerId: map['partnerId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'type': type,
    'address': address,
    'landownerId': landownerId,
    'managerId': managerId,
    'photoUrls': photoUrls,
    'amenities': amenities,
    'rentPaymentMode': rentPaymentMode,
    'artisanIds': artisanIds,
    'totalUnits': totalUnits,
    'occupancyRate': occupancyRate,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'documents': documents,
    'partnerId': partnerId,

    'managerCommissionType': managerCommissionType,
    'managerCommissionRate': managerCommissionRate,
    'managerFlatFeeAmount': managerFlatFeeAmount,
    'managerFlatFeePeriod': managerFlatFeePeriod,
  };

  PropertyModel copyWith({
    String? id,
    String? name,
    String? type,
    String? address,
    String? landownerId,
    String? managerId,
    String? rentPaymentMode,

    List<String>? photoUrls,
    List<String>? amenities,
    List<String>? artisanIds,
    int? totalUnits,
    double? occupancyRate,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Map<String, dynamic>>? documents,

    String? managerCommissionType,
    double? managerCommissionRate,
    double? managerFlatFeeAmount,
    String? managerFlatFeePeriod,
    String? partnerId,
  }) {
    return PropertyModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      rentPaymentMode: rentPaymentMode ?? this.rentPaymentMode,
      address: address ?? this.address,
      documents: documents ?? this.documents,
      landownerId: landownerId ?? this.landownerId,
      managerId: managerId ?? this.managerId,
      photoUrls: photoUrls ?? this.photoUrls,
      amenities: amenities ?? this.amenities,
      artisanIds: artisanIds ?? this.artisanIds,
      totalUnits: totalUnits ?? this.totalUnits,
      occupancyRate: occupancyRate ?? this.occupancyRate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,

      managerCommissionType: managerCommissionType ?? this.managerCommissionType,
      managerCommissionRate: managerCommissionRate ?? this.managerCommissionRate,
      managerFlatFeeAmount: managerFlatFeeAmount ?? this.managerFlatFeeAmount,
      managerFlatFeePeriod: managerFlatFeePeriod ?? this.managerFlatFeePeriod,
      partnerId: partnerId ?? this.partnerId,
    );
  }
}
