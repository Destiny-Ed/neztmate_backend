class Availability {
  final String id;
  final String artisanId;
  final DateTime startTime;
  final DateTime endTime;
  final bool recurring; // true = repeats weekly/monthly
  final String? recurrenceRule; // e.g. "every Monday", "monthly on 15th" (simple string or RRULE format)
  final String? notes; // e.g. "Available only evenings"
  final DateTime createdAt;
  final DateTime? updatedAt;

  Availability({
    required this.id,
    required this.artisanId,
    required this.startTime,
    required this.endTime,
    this.recurring = false,
    this.recurrenceRule,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  factory Availability.fromMap(Map<String, dynamic> map, String id) {
    return Availability(
      id: id,
      artisanId: map['artisanId'] as String,
      startTime: DateTime.parse(map['startTime'] as String),
      endTime: DateTime.parse(map['endTime'] as String),
      recurring: map['recurring'] as bool? ?? false,
      recurrenceRule: map['recurrenceRule'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt'] as String) : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'artisanId': artisanId,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'recurring': recurring,
    'recurrenceRule': recurrenceRule,
    'notes': notes,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  Availability copyWith({
    String? id,
    String? artisanId,
    DateTime? startTime,
    DateTime? endTime,
    bool? recurring,
    String? recurrenceRule,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Availability(
      id: id ?? this.id,
      artisanId: artisanId ?? this.artisanId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      recurring: recurring ?? this.recurring,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
