class LossOfPayRecord {
  final int id;
  final int employeeId;
  final int leaveRequestId;
  final String date;
  final double amount;
  final String createdAt;

  const LossOfPayRecord({
    required this.id,
    required this.employeeId,
    required this.leaveRequestId,
    required this.date,
    required this.amount,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != 0) 'id': id,
        'employee_id': employeeId,
        'leave_request_id': leaveRequestId,
        'date': date,
        'amount': amount,
        'created_at': createdAt,
      };

  factory LossOfPayRecord.fromMap(Map<String, dynamic> map) => LossOfPayRecord(
        id: map['id'] as int? ?? 0,
        employeeId: map['employee_id'] as int? ?? 0,
        leaveRequestId: map['leave_request_id'] as int? ?? 0,
        date: map['date'] as String? ?? '',
        amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
        createdAt: map['created_at'] as String? ?? '',
      );
}
