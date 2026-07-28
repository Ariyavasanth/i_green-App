class LeaveRequest {
  const LeaveRequest({
    required this.id,
    required this.employeeId,
    required this.date,
    required this.reason,
    required this.status,
    required this.createdAt,
  });

  final int id;
  final int employeeId;
  final String date;
  final String reason;
  final String status; // Pending, Approved, Rejected
  final String createdAt;

  Map<String, dynamic> toMap() {
    return {
      if (id != 0) 'id': id,
      'employee_id': employeeId,
      'date': date,
      'reason': reason,
      'status': status,
      'created_at': createdAt,
    };
  }

  factory LeaveRequest.fromMap(Map<String, dynamic> map) {
    return LeaveRequest(
      id: map['id'] as int? ?? 0,
      employeeId: map['employee_id'] as int? ?? 0,
      date: map['date'] as String? ?? '',
      reason: map['reason'] as String? ?? '',
      status: map['status'] as String? ?? 'Pending',
      createdAt: map['created_at'] as String? ?? '',
    );
  }

  LeaveRequest copyWith({
    int? id,
    int? employeeId,
    String? date,
    String? reason,
    String? status,
    String? createdAt,
  }) {
    return LeaveRequest(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      date: date ?? this.date,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
