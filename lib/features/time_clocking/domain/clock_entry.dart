class ClockEntry {
  final String id;
  final String employeeId;
  final String entryType; // 'WORK', 'LUNCH_BREAK', 'TEA_BREAK', 'MEETING', 'IDLE'
  final DateTime startTime;
  final DateTime? endTime;
  final String? notes;

  const ClockEntry({
    required this.id,
    required this.employeeId,
    required this.entryType,
    required this.startTime,
    this.endTime,
    this.notes,
  });

  bool get isActive => endTime == null;

  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  double get durationInHours => duration.inMinutes / 60.0;

  bool get isBreak => entryType == 'LUNCH_BREAK' || entryType == 'TEA_BREAK' || entryType == 'IDLE';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employee_id': employeeId,
      'entry_type': entryType,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'notes': notes,
    };
  }

  factory ClockEntry.fromMap(Map<String, dynamic> map) {
    return ClockEntry(
      id: map['id'] as String,
      employeeId: map['employee_id'] as String? ?? '',
      entryType: map['entry_type'] as String? ?? 'WORK',
      startTime: map['start_time'] != null
          ? DateTime.tryParse(map['start_time'] as String) ?? DateTime.now()
          : DateTime.now(),
      endTime: map['end_time'] != null ? DateTime.tryParse(map['end_time'] as String) : null,
      notes: map['notes'] as String?,
    );
  }

  ClockEntry copyWith({
    String? id,
    String? employeeId,
    String? entryType,
    DateTime? startTime,
    DateTime? endTime,
    String? notes,
  }) {
    return ClockEntry(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      entryType: entryType ?? this.entryType,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      notes: notes ?? this.notes,
    );
  }
}
