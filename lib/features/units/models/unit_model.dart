class UnitModel {
  String id;
  final String propertyId;
  final String unitNumber;
  final int? floorLevel;
  final double yearlyRent;
  final int? bedrooms;
  final double? bathrooms;
  final int likes;
  final int commentsCount;
  final int? squareFeet;
  final List<String>? features; // default features (balcony etc)
  final Map<String, bool>? customFeatures; // NEW
  final List<UnitFee>? fees; // NEW
  final List<String>? photoUrls;
  final String? videoUrl;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  UnitModel({
    required this.id,
    required this.propertyId,
    required this.unitNumber,
    this.floorLevel,
    required this.yearlyRent,
    this.bedrooms,
    this.bathrooms,
    this.likes = 0,
    this.commentsCount = 0,
    this.squareFeet,
    this.features,
    this.customFeatures,
    this.fees,
    this.photoUrls,
    this.videoUrl,
    this.status = 'vacant',
    required this.createdAt,
    required this.updatedAt,
  });

  factory UnitModel.fromMap(Map<String, dynamic> map) {
    return UnitModel(
      id: map['id'],
      propertyId: map['propertyId'],
      unitNumber: map['unitNumber'],
      floorLevel: map['floorLevel'],
      yearlyRent: (map['yearlyRent'] as num).toDouble(),
      bedrooms: map['bedrooms'],
      bathrooms: (map['bathrooms'] as num?)?.toDouble(),
      likes: map['likes'] as int? ?? 0,
      commentsCount: map['commentsCount'] as int? ?? 0,
      squareFeet: map['squareFeet'] as int?,
      features: (map['features'] as List?)?.cast<String>(),
      customFeatures: (map['customFeatures'] as Map?)?.map(
        (key, value) => MapEntry(key.toString(), value as bool),
      ),
      fees: (map['fees'] as List?)?.map((e) => UnitFee.fromMap(e)).toList(),
      photoUrls: (map['photoUrls'] as List?)?.cast<String>(),
      videoUrl: map['videoUrl'],
      status: map['status'] ?? 'Vacant',
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'propertyId': propertyId,
    'unitNumber': unitNumber,
    'floorLevel': floorLevel,
    'yearlyRent': yearlyRent,
    'bedrooms': bedrooms,
    'bathrooms': bathrooms,
    'likes': likes,
    'commentsCount': commentsCount,
    'squareFeet': squareFeet,
    'features': features,
    'customFeatures': customFeatures,
    'fees': fees?.map((e) => e.toMap()).toList(),
    'photoUrls': photoUrls,
    'videoUrl': videoUrl,
    'status': status,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  UnitModel copyWith({
    String? id,
    String? propertyId,
    String? unitNumber,
    int? floorLevel,
    double? yearlyRent,
    int? bedrooms,
    double? bathrooms,
    int? likes,
    int? commentsCount,
    int? squareFeet,
    List<String>? features,
    List<String>? photoUrls,
    String? videoUrl,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, bool>? customFeatures,
    List<UnitFee>? fees,
  }) {
    return UnitModel(
      id: id ?? this.id,
      propertyId: propertyId ?? this.propertyId,
      unitNumber: unitNumber ?? this.unitNumber,
      floorLevel: floorLevel ?? this.floorLevel,
      yearlyRent: yearlyRent ?? this.yearlyRent,
      bedrooms: bedrooms ?? this.bedrooms,
      bathrooms: bathrooms ?? this.bathrooms,
      likes: likes ?? this.likes,
      commentsCount: commentsCount ?? this.commentsCount,
      squareFeet: squareFeet ?? this.squareFeet,
      features: features ?? this.features,
      photoUrls: photoUrls ?? this.photoUrls,
      videoUrl: videoUrl ?? this.videoUrl,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      customFeatures: customFeatures ?? this.customFeatures,
      fees: fees ?? this.fees,
    );
  }
}

class UnitFee {
  final String name;
  final double amount;
  final bool isPercentage;
  final bool isOneTime;

  UnitFee({required this.name, required this.amount, required this.isPercentage, required this.isOneTime});

  factory UnitFee.fromMap(Map<String, dynamic> map) {
    return UnitFee(
      name: map['name'],
      amount: (map['amount'] as num).toDouble(),
      isPercentage: map['isPercentage'] ?? false,
      isOneTime: map['isOneTime'] ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'amount': amount,
    'isPercentage': isPercentage,
    'isOneTime': isOneTime,
  };
}
