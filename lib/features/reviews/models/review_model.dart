class UserReviewModel {
  final String id;

  /// Reviewer
  final String reviewerId;
  final String reviewerName;
  final String? reviewerPhotoUrl;
  final String reviewerRole;

  /// Reviewed Entity
  final String reviewedUserId;
  final String reviewedEntityType; // user, property, artisan, manager, landlord

  /// tenant_to_landlord, landlord_to_tenant, tenant_to_artisan...
  final String reviewType;

  /// 1 - 5
  final double rating;

  /// Optional review text
  final String comment;

  /// Selected chips
  final List<String> tags;

  /// Review is backed by an actual completed interaction
  final bool isVerified;

  /// Future "Helpful" feature
  final int helpfulCount;

  /// Explicit edit state
  final bool edited;

  final String? relatedLeaseId;
  final String? relatedTaskId;

  final DateTime createdAt;
  final DateTime updatedAt;

  const UserReviewModel({
    required this.id,
    required this.reviewerId,
    required this.reviewerName,
    this.reviewerPhotoUrl,
    required this.reviewedUserId,
    required this.reviewedEntityType,
    required this.reviewType,
    required this.rating,
    required this.comment,
    required this.tags,
    required this.reviewerRole,
    this.relatedLeaseId,
    this.relatedTaskId,
    this.isVerified = true,
    this.helpfulCount = 0,
    this.edited = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserReviewModel.fromMap(Map<String, dynamic> map) {
    return UserReviewModel(
      id: map["id"] ?? "",
      reviewerId: map["reviewerId"] ?? "",
      reviewerName: map["reviewerName"] ?? "",
      reviewerPhotoUrl: map["reviewerPhotoUrl"],
      reviewedUserId: map["reviewedUserId"] ?? "",
      reviewedEntityType: map["reviewedEntityType"] ?? "user",
      reviewType: map["reviewType"] ?? "",
      rating: (map["rating"] as num).toDouble(),
      comment: map["comment"] ?? "",
      reviewerRole: map["reviewerRole"] ?? "",
      tags: List<String>.from(map["tags"] ?? []),
      isVerified: map["isVerified"] ?? true,
      helpfulCount: map["helpfulCount"] ?? 0,
      edited: map["edited"] ?? false,
      relatedLeaseId: map["relatedLeaseId"],
      relatedTaskId: map["relatedTaskId"],
      createdAt: DateTime.parse(map["createdAt"]),
      updatedAt: map["updatedAt"] != null ? DateTime.parse(map["updatedAt"]) : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "id": id,
      "reviewerId": reviewerId,
      "reviewerName": reviewerName,
      "reviewerPhotoUrl": reviewerPhotoUrl,
      "reviewedUserId": reviewedUserId,
      "reviewedEntityType": reviewedEntityType,
      "reviewType": reviewType,
      "rating": rating,
      "comment": comment,
      "tags": tags,
      "reviewerRole": reviewerRole,
      "isVerified": isVerified,
      "helpfulCount": helpfulCount,
      "edited": edited,
      "relatedLeaseId": relatedLeaseId,
      "relatedTaskId": relatedTaskId,
      "createdAt": createdAt.toIso8601String(),
      "updatedAt": updatedAt.toIso8601String(),
    };
  }

  UserReviewModel copyWith({
    String? id,
    String? reviewerId,
    String? reviewerName,
    String? reviewerPhotoUrl,
    String? reviewedUserId,
    String? reviewedEntityType,
    String? reviewType,
    double? rating,
    String? comment,
    List<String>? tags,
    String? reviewerRole,
    bool? isVerified,
    int? helpfulCount,
    bool? edited,
    String? relatedLeaseId,
    String? relatedTaskId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserReviewModel(
      id: id ?? this.id,
      reviewerId: reviewerId ?? this.reviewerId,
      reviewerName: reviewerName ?? this.reviewerName,
      reviewerPhotoUrl: reviewerPhotoUrl ?? this.reviewerPhotoUrl,
      reviewedUserId: reviewedUserId ?? this.reviewedUserId,
      reviewedEntityType: reviewedEntityType ?? this.reviewedEntityType,
      reviewType: reviewType ?? this.reviewType,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      tags: tags ?? this.tags,
      reviewerRole: reviewerRole ?? this.reviewerRole,
      isVerified: isVerified ?? this.isVerified,
      helpfulCount: helpfulCount ?? this.helpfulCount,
      edited: edited ?? this.edited,
      relatedLeaseId: relatedLeaseId ?? this.relatedLeaseId,
      relatedTaskId: relatedTaskId ?? this.relatedTaskId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
