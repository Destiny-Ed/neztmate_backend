class TaskModel {
  final String id;
  final String requestId; // links to maintenance request
  final String? artisanId;
  final String? managerId; // who assigned
  final String description;
  final List<String>? beforePhotos;
  final List<String>? afterPhotos;
  final String? workSummary;
  final double? totalCost;
  final String status; // 'Pending', 'Assigned', 'InProgress', 'Completed', 'Approved', 'Rejected'
  final DateTime? scheduledTime;
  final DateTime? completedTime;
  final DateTime createdAt;

  TaskModel({
    required this.id,
    required this.requestId,
    this.artisanId,
    this.managerId,
    required this.description,
    this.beforePhotos,
    this.afterPhotos,
    this.workSummary,
    this.totalCost,
    this.status = 'Pending',
    this.scheduledTime,
    this.completedTime,
    required this.createdAt,
  });

  factory TaskModel.fromMap(Map<String, dynamic> map, String id) {
    return TaskModel(
      id: id,
      requestId: map['requestId'] as String,
      artisanId: map['artisanId'] as String?,
      managerId: map['managerId'] as String?,
      description: map['description'] as String,
      beforePhotos: (map['beforePhotos'] as List<dynamic>?)?.cast<String>(),
      afterPhotos: (map['afterPhotos'] as List<dynamic>?)?.cast<String>(),
      workSummary: map['workSummary'] as String?,
      totalCost: (map['totalCost'] as num?)?.toDouble(),
      status: map['status'] as String? ?? 'Pending',
      scheduledTime: map['scheduledTime'] != null ? DateTime.parse(map['scheduledTime'] as String) : null,
      completedTime: map['completedTime'] != null ? DateTime.parse(map['completedTime'] as String) : null,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
    'requestId': requestId,
    'artisanId': artisanId,
    'managerId': managerId,
    'description': description,
    'beforePhotos': beforePhotos,
    'afterPhotos': afterPhotos,
    'workSummary': workSummary,
    'totalCost': totalCost,
    'status': status,
    'scheduledTime': scheduledTime?.toIso8601String(),
    'completedTime': completedTime?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };

  TaskModel copyWith({
    String? id,
    String? requestId,
    String? artisanId,
    String? managerId,
    String? description,
    List<String>? beforePhotos,
    List<String>? afterPhotos,
    String? workSummary,
    double? totalCost,
    String? status,
    DateTime? scheduledTime,
    DateTime? completedTime,
    DateTime? createdAt,
  }) {
    return TaskModel(
      id: id ?? this.id,
      requestId: requestId ?? this.requestId,
      artisanId: artisanId ?? this.artisanId,
      managerId: managerId ?? this.managerId,
      description: description ?? this.description,
      beforePhotos: beforePhotos ?? this.beforePhotos,
      afterPhotos: afterPhotos ?? this.afterPhotos,
      workSummary: workSummary ?? this.workSummary,
      totalCost: totalCost ?? this.totalCost,
      status: status ?? this.status,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      completedTime: completedTime ?? this.completedTime,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
