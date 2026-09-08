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

  bool get isBreak {
    final lower = entryType.toLowerCase();
    return lower.contains('break') || lower.contains('lunch') || lower.contains('tea') || lower == 'idle';
  }

  String get formattedDuration {
    final dur = duration;
    final hours = dur.inHours;
    final mins = dur.inMinutes.remainder(60);
    if (hours > 0 && mins > 0) {
      return '$hours hr $mins min';
    } else if (hours > 0) {
      return '$hours hr${hours > 1 ? 's' : ''}';
    } else {
      return '$mins min';
    }
  }

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
      id: (map['id'] ?? '').toString(),
      employeeId: (map['employee_id'] ?? '').toString(),
      entryType: (map['entry_type'] ?? 'WORK').toString(),
      startTime: _parseDateTime(map['start_time']),
      endTime: map['end_time'] != null ? _parseDateTime(map['end_time']) : null,
      notes: map['notes']?.toString(),
    );
  }

  static DateTime _parseDateTime(dynamic val) {
    if (val == null) return DateTime.now();
    if (val is DateTime) return val;
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    final str = val.toString().trim();
    return DateTime.tryParse(str) ?? DateTime.now();
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
