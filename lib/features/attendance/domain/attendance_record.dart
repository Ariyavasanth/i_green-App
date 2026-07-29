class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.employeeId,
    required this.date,
    required this.status,
    this.markedAt = '',
  });

  final int id;
  final int employeeId;
  final String date;
  final String status;
  final String markedAt;

  Map<String, dynamic> toMap() => {
        if (id != 0) 'id': id,
        'employee_id': employeeId,
        'date': date,
        'status': status,
        'marked_at': markedAt,
      };

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) => AttendanceRecord(
        id: map['id'] as int? ?? 0,
        employeeId: map['employee_id'] as int? ?? 0,
        date: map['date'] as String? ?? '',
        status: map['status'] as String? ?? 'Present',
        markedAt: map['marked_at'] as String? ?? '',
      );
}
