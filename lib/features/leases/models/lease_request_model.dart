enum LeaseRequestType {
  renewal,
  termination,
  transfer,
  maintenance,
  rentAdjustment,
  settlement,
  inspection,
  other,
}

extension LeaseRequestTypeX on LeaseRequestType {
  String get value => switch (this) {
    LeaseRequestType.renewal => "renewal",
    LeaseRequestType.termination => "termination",
    LeaseRequestType.transfer => "transfer",
    LeaseRequestType.maintenance => "maintenance",
    LeaseRequestType.rentAdjustment => "rent_adjustment",
    LeaseRequestType.settlement => "settlement",
    LeaseRequestType.inspection => "inspection",
    LeaseRequestType.other => "other",
  };

  static LeaseRequestType from(String value) {
    return LeaseRequestType.values.firstWhere((e) => e.value == value, orElse: () => LeaseRequestType.other);
  }
}

enum LeaseRequestStatus { pending, approved, rejected, cancelled, completed }

extension LeaseRequestStatusX on LeaseRequestStatus {
  String get value => switch (this) {
    LeaseRequestStatus.pending => "pending",
    LeaseRequestStatus.approved => "approved",
    LeaseRequestStatus.rejected => "rejected",
    LeaseRequestStatus.cancelled => "cancelled",
    LeaseRequestStatus.completed => "completed",
  };

  static LeaseRequestStatus from(String value) {
    return LeaseRequestStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => LeaseRequestStatus.pending,
    );
  }
}

enum LeaseRequestActor { tenant, landlord, manager, system }

extension LeaseRequestActorX on LeaseRequestActor {
  String get value => switch (this) {
    LeaseRequestActor.tenant => "tenant",
    LeaseRequestActor.landlord => "landlord",
    LeaseRequestActor.manager => "manager",
    LeaseRequestActor.system => "system",
  };

  static LeaseRequestActor from(String value) {
    return LeaseRequestActor.values.firstWhere(
      (e) => e.value == value,
      orElse: () => LeaseRequestActor.system,
    );
  }
}

class LeaseRequestModel {
  final String id;

  final String leaseId;

  final String propertyId;

  final String unitId;

  final String tenantId;

  final String landownerId;

  final String? managerId;

  final LeaseRequestType type;

  final LeaseRequestStatus status;

  final LeaseRequestActor initiatedBy;

  final String initiatedById;

  final String assignedToId;

  final String? title;

  final String? message;

  final String? reason;

  final Map<String, dynamic> metadata;

  final DateTime createdAt;

  final DateTime updatedAt;

  final DateTime? resolvedAt;

  const LeaseRequestModel({
    required this.id,
    required this.leaseId,
    required this.propertyId,
    required this.unitId,
    required this.tenantId,
    required this.landownerId,
    this.managerId,
    required this.type,
    required this.status,
    required this.initiatedBy,
    required this.initiatedById,
    required this.assignedToId,
    this.title,
    this.message,
    this.reason,
    this.metadata = const {},
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
  });

  LeaseRequestModel copyWith({
    String? id,
    String? leaseId,
    String? propertyId,
    String? unitId,
    String? tenantId,
    String? landownerId,
    String? managerId,
    LeaseRequestType? type,
    LeaseRequestStatus? status,
    LeaseRequestActor? initiatedBy,
    String? initiatedById,
    String? assignedToId,
    String? title,
    String? message,
    String? reason,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? resolvedAt,
  }) {
    return LeaseRequestModel(
      id: id ?? this.id,
      leaseId: leaseId ?? this.leaseId,
      propertyId: propertyId ?? this.propertyId,
      unitId: unitId ?? this.unitId,
      tenantId: tenantId ?? this.tenantId,
      landownerId: landownerId ?? this.landownerId,
      managerId: managerId ?? this.managerId,
      type: type ?? this.type,
      status: status ?? this.status,
      initiatedBy: initiatedBy ?? this.initiatedBy,
      initiatedById: initiatedById ?? this.initiatedById,
      assignedToId: assignedToId ?? this.assignedToId,
      title: title ?? this.title,
      message: message ?? this.message,
      reason: reason ?? this.reason,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }

  factory LeaseRequestModel.fromMap(Map<String, dynamic> map) {
    return LeaseRequestModel(
      id: map["id"],
      leaseId: map["leaseId"],
      propertyId: map["propertyId"],
      unitId: map["unitId"],
      tenantId: map["tenantId"],
      landownerId: map["landownerId"],
      managerId: map["managerId"],
      type: LeaseRequestTypeX.from(map["type"]),
      status: LeaseRequestStatusX.from(map["status"]),
      initiatedBy: LeaseRequestActorX.from(map["initiatedBy"]),
      initiatedById: map["initiatedById"],
      assignedToId: map["assignedToId"],
      title: map["title"],
      message: map["message"],
      reason: map["reason"],
      metadata: Map<String, dynamic>.from(map["metadata"] ?? {}),
      createdAt: DateTime.parse(map["createdAt"]),
      updatedAt: DateTime.parse(map["updatedAt"]),
      resolvedAt: map["resolvedAt"] != null ? DateTime.parse(map["resolvedAt"]) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "id": id,
      "leaseId": leaseId,
      "propertyId": propertyId,
      "unitId": unitId,
      "tenantId": tenantId,
      "landownerId": landownerId,
      "managerId": managerId,
      "type": type.value,
      "status": status.value,
      "initiatedBy": initiatedBy.value,
      "initiatedById": initiatedById,
      "assignedToId": assignedToId,
      "title": title,
      "message": message,
      "reason": reason,
      "metadata": metadata,
      "createdAt": createdAt.toIso8601String(),
      "updatedAt": updatedAt.toIso8601String(),
      "resolvedAt": resolvedAt?.toIso8601String(),
    };
  }
}
