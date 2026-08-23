class LeaveMonthlyBalance {
  final int id;
  final int employeeId;
  final String leaveType;
  final int periodYear;
  final int periodMonth;
  final double allowedDays;
  final double usedPaidDays;
  final double lopDays;
  final double remainingDays;

  const LeaveMonthlyBalance({
    required this.id,
    required this.employeeId,
    required this.leaveType,
    required this.periodYear,
    required this.periodMonth,
    required this.allowedDays,
    required this.usedPaidDays,
    required this.lopDays,
    required this.remainingDays,
  });

  Map<String, dynamic> toMap() => {
        if (id != 0) 'id': id,
        'employee_id': employeeId,
        'leave_type': leaveType,
        'period_year': periodYear,
        'period_month': periodMonth,
        'allowed_days': allowedDays,
        'used_paid_days': usedPaidDays,
        'lop_days': lopDays,
        'remaining_days': remainingDays,
      };

  factory LeaveMonthlyBalance.fromMap(Map<String, dynamic> map) {
    final allowed = (map['allowed_days'] as num?)?.toDouble() ?? 0.0;
    final usedPaid = (map['used_paid_days'] as num?)?.toDouble() ?? 0.0;
    final lop = (map['lop_days'] as num?)?.toDouble() ?? 0.0;
    final remainingRaw = (map['remaining_days'] as num?)?.toDouble();
    final remaining = remainingRaw ?? (allowed - usedPaid).clamp(0.0, allowed);

    return LeaveMonthlyBalance(
      id: map['id'] as int? ?? 0,
      employeeId: map['employee_id'] as int? ?? 0,
      leaveType: map['leave_type'] as String? ?? '',
      periodYear: map['period_year'] as int? ?? DateTime.now().year,
      periodMonth: map['period_month'] as int? ?? DateTime.now().month,
      allowedDays: allowed,
      usedPaidDays: usedPaid,
      lopDays: lop,
      remainingDays: remaining,
    );
  }

  LeaveMonthlyBalance copyWith({
    int? id,
    int? employeeId,
    String? leaveType,
    int? periodYear,
    int? periodMonth,
    double? allowedDays,
    double? usedPaidDays,
    double? lopDays,
    double? remainingDays,
  }) {
    final newAllowed = allowedDays ?? this.allowedDays;
    final newUsed = usedPaidDays ?? this.usedPaidDays;
    return LeaveMonthlyBalance(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      leaveType: leaveType ?? this.leaveType,
      periodYear: periodYear ?? this.periodYear,
      periodMonth: periodMonth ?? this.periodMonth,
      allowedDays: newAllowed,
      usedPaidDays: newUsed,
      lopDays: lopDays ?? this.lopDays,
      remainingDays: remainingDays ?? (newAllowed - newUsed).clamp(0.0, newAllowed),
    );
  }
}
