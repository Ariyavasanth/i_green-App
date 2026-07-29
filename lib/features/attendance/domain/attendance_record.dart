class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.date,
    required this.time,
    required this.status,
    required this.verificationStatus,
    required this.similarityScore,
    this.markedAt = '',
  });

  final int id;
  final int employeeId;
  final String employeeName;
  final String date;
  final String time;
  final String status;
  final String verificationStatus;
  final double similarityScore;
  final String markedAt;

  Map<String, dynamic> toMap() => {
        if (id != 0) 'id': id,
        'employee_id': employeeId,
        'employee_name': employeeName,
        'date': date,
        'time': time,
        'status': status,
        'verification_status': verificationStatus,
        'similarity_score': similarityScore,
        'marked_at': markedAt,
      };

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) => AttendanceRecord(
        id: map['id'] as int? ?? 0,
        employeeId: map['employee_id'] as int? ?? 0,
        employeeName: map['employee_name'] as String? ?? '',
        date: map['date'] as String? ?? '',
        time: map['time'] as String? ?? '',
        status: map['status'] as String? ?? 'Present',
        verificationStatus: map['verification_status'] as String? ?? 'Verified',
        similarityScore: (map['similarity_score'] as num?)?.toDouble() ?? 0.0,
        markedAt: map['marked_at'] as String? ?? '',
      );
}
