// lib/features/unit/models/unit_model.dart
class UnitModel {
  final String id;
  final String propertyId;
  final String unitNumber;
  final int? floorLevel;
  final double yearlyRent;
  final int? bedrooms;
  final double? bathrooms;
  final int likes;
  final int commentsCount;
  final int? squareFeet;
  final List<String>? features;
  final Map<String, bool>? customFeatures;
  final List<UnitFee>? fees;
  final List<String>? photoUrls;
  final String? videoUrl;

  // New fields for listing system
  final bool isListedForRent; // Main field: Is this unit currently listed for rent?
  final DateTime? listedAt; // When it was last listed
  final DateTime? rentDueDate; // When the current tenant's rent is due
  final String? currentTenantId; // Who is currently occupying it (if any)

  final String status; // vacant, occupied, maintenance, etc.
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
    this.isListedForRent = false,
    this.listedAt,
    this.rentDueDate,
    this.currentTenantId,
    this.status = 'vacant',
    required this.createdAt,
    required this.updatedAt,
  });

  factory UnitModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return UnitModel(
      id: id ?? map['id'] ?? '',
      propertyId: map['propertyId'] ?? '',
      unitNumber: map['unitNumber'] ?? '',
      floorLevel: map['floorLevel'] as int?,
      yearlyRent: (map['yearlyRent'] as num).toDouble(),
      bedrooms: map['bedrooms'] as int?,
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
      videoUrl: map['videoUrl'] as String?,

      // New fields
      isListedForRent: map['isListedForRent'] as bool? ?? false,
      listedAt: map['listedAt'] != null ? DateTime.parse(map['listedAt'] as String) : null,
      rentDueDate: map['rentDueDate'] != null ? DateTime.parse(map['rentDueDate'] as String) : null,
      currentTenantId: map['currentTenantId'] as String?,

      status: map['status'] as String? ?? 'vacant',
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
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

    // New fields
    'isListedForRent': isListedForRent,
    'listedAt': listedAt?.toIso8601String(),
    'rentDueDate': rentDueDate?.toIso8601String(),
    'currentTenantId': currentTenantId,

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
    Map<String, bool>? customFeatures,
    List<UnitFee>? fees,
    List<String>? photoUrls,
    String? videoUrl,
    bool? isListedForRent,
    DateTime? listedAt,
    DateTime? rentDueDate,
    String? currentTenantId,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
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
      customFeatures: customFeatures ?? this.customFeatures,
      fees: fees ?? this.fees,
      photoUrls: photoUrls ?? this.photoUrls,
      videoUrl: videoUrl ?? this.videoUrl,
      isListedForRent: isListedForRent ?? this.isListedForRent,
      listedAt: listedAt ?? this.listedAt,
      rentDueDate: rentDueDate ?? this.rentDueDate,
      currentTenantId: currentTenantId ?? this.currentTenantId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
