class UserReviewModel {
  final String id;
  final String reviewerId;
  final String reviewedUserId;
  final String
  reviewType; // tenant_to_landlord, landlord_to_tenant, tenant_to_tenant, manager_to_artisan, etc.
  final double rating; // 1.0 - 5.0
  final String comment;
  final String reviewerRole;
  final String? relatedLeaseId;
  final String? relatedTaskId;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserReviewModel({
    required this.id,
    required this.reviewerId,
    required this.reviewedUserId,
    required this.reviewType,
    required this.rating,
    required this.comment,
    this.relatedLeaseId,
    this.relatedTaskId,
    required this.createdAt,
    required this.updatedAt,
    required this.reviewerRole,
  });

  factory UserReviewModel.fromMap(Map<String, dynamic> map) {
    return UserReviewModel(
      id: map['id'],
      reviewerId: map['reviewerId'],
      reviewedUserId: map['reviewedUserId'],
      reviewType: map['reviewType'],
      rating: (map['rating'] as num).toDouble(),
      comment: map['comment'],
      relatedLeaseId: map['relatedLeaseId'],
      relatedTaskId: map['relatedTaskId'],
      reviewerRole: map['reviewerRole'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'reviewerId': reviewerId,
    'reviewedUserId': reviewedUserId,
    'reviewType': reviewType,
    'rating': rating,
    'comment': comment,
    'reviewerRole': reviewerRole,
    'relatedLeaseId': relatedLeaseId,
    'relatedTaskId': relatedTaskId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  UserReviewModel copyWith({
    String? id,
    String? reviewerId,
    String? reviewedUserId,
    String? reviewType,
    double? rating,
    String? comment,
    String? relatedLeaseId,
    String? reviewerRole,
    String? relatedTaskId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserReviewModel(
      id: id ?? this.id,
      reviewerId: reviewerId ?? this.reviewerId,
      reviewedUserId: reviewedUserId ?? this.reviewedUserId,
      reviewType: reviewType ?? this.reviewType,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      reviewerRole: reviewerRole ?? this.reviewerRole,
      relatedLeaseId: relatedLeaseId ?? this.relatedLeaseId,
      relatedTaskId: relatedTaskId ?? this.relatedTaskId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
