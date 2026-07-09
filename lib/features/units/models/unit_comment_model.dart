class UnitCommentModel {
  final String id;
  final String unitId;
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final String comment;
  final DateTime createdAt;
  final DateTime? updatedAt;

  UnitCommentModel({
    required this.id,
    required this.unitId,
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    required this.comment,
    required this.createdAt,
    this.updatedAt,
  });

  factory UnitCommentModel.fromMap(Map<String, dynamic> map) {
    return UnitCommentModel(
      id: map['id'],
      unitId: map['unitId'] as String,
      userId: map['userId'] as String,
      userName: map['userName'] as String,
      userPhotoUrl: map['userPhotoUrl'] as String?,
      comment: map['comment'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt'] as String) : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'unitId': unitId,
    'userId': userId,
    'userName': userName,
    'userPhotoUrl': userPhotoUrl,
    'comment': comment,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  UnitCommentModel copyWith({
    String? id,
    String? unitId,
    String? userId,
    String? userName,
    String? userPhotoUrl,
    String? comment,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UnitCommentModel(
      id: id ?? this.id,
      unitId: unitId ?? this.unitId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userPhotoUrl: userPhotoUrl ?? this.userPhotoUrl,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
