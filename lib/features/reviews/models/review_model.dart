class UserReviewModel {
  final String id;

  /// Reviewer
  final String reviewerId;
  final String reviewerName;
  final String? reviewerPhotoUrl;
  final String reviewerRole;

  /// Reviewed Entity
  final String reviewedEntityId; // NEW - Generic ID
  final String reviewedEntityType; // "user", "property", "unit", etc.

  /// Review Type
  final String reviewType; // tenant_to_landlord, etc.

  final double rating;
  final String comment;
  final List<String> tags;

  final bool isVerified;
  final int helpfulCount;
  final bool edited;

  final String? relatedLeaseId;
  final String? relatedTaskId;

  final DateTime createdAt;
  final DateTime updatedAt;

  UserReviewModel({
    required this.id,
    required this.reviewerId,
    required this.reviewerName,
    this.reviewerPhotoUrl,
    required this.reviewerRole,
    required this.reviewedEntityId,
    required this.reviewedEntityType,
    required this.reviewType,
    required this.rating,
    required this.comment,
    this.tags = const [],
    this.isVerified = true,
    this.helpfulCount = 0,
    this.edited = false,
    this.relatedLeaseId,
    this.relatedTaskId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserReviewModel.fromMap(Map<String, dynamic> map) {
    return UserReviewModel(
      id:  map['id'] ?? '',
      reviewerId: map['reviewerId'] ?? '',
      reviewerName: map['reviewerName'] ?? '',
      reviewerPhotoUrl: map['reviewerPhotoUrl'],
      reviewerRole: map['reviewerRole'] ?? '',
      reviewedEntityId: map['reviewedEntityId'] ?? '',
      reviewedEntityType: map['reviewedEntityType'] ?? 'user',
      reviewType: map['reviewType'] ?? '',
      rating: (map['rating'] as num).toDouble(),
      comment: map['comment'] ?? '',
      tags: List<String>.from(map['tags'] ?? []),
      isVerified: map['isVerified'] ?? true,
      helpfulCount: map['helpfulCount'] ?? 0,
      edited: map['edited'] ?? false,
      relatedLeaseId: map['relatedLeaseId'],
      relatedTaskId: map['relatedTaskId'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'reviewerId': reviewerId,
    'reviewerName': reviewerName,
    'reviewerPhotoUrl': reviewerPhotoUrl,
    'reviewerRole': reviewerRole,
    'reviewedEntityId': reviewedEntityId,
    'reviewedEntityType': reviewedEntityType,
    'reviewType': reviewType,
    'rating': rating,
    'comment': comment,
    'tags': tags,
    'isVerified': isVerified,
    'helpfulCount': helpfulCount,
    'edited': edited,
    'relatedLeaseId': relatedLeaseId,
    'relatedTaskId': relatedTaskId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  UserReviewModel copyWith({
    String? id,
    String? reviewerId,
    String? reviewerName,
    String? reviewerPhotoUrl,
    String? reviewerRole,
    String? reviewedEntityId,
    String? reviewedEntityType,
    String? reviewType,
    double? rating,
    String? comment,
    List<String>? tags,
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
      reviewerRole: reviewerRole ?? this.reviewerRole,
      reviewedEntityId: reviewedEntityId ?? this.reviewedEntityId,
      reviewedEntityType: reviewedEntityType ?? this.reviewedEntityType,
      reviewType: reviewType ?? this.reviewType,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      tags: tags ?? this.tags,
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
