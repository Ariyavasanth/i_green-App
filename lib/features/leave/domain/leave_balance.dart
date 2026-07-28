class LeaveBalance {
  final int id;
  final int employeeId;
  final String leaveType;
  final double allowedLeaves;
  final double usedLeaves;
  final double availableLeaves;
  final String effectiveDate;
  final String allocationFrequency;

  const LeaveBalance({
    required this.id,
    required this.employeeId,
    required this.leaveType,
    required this.allowedLeaves,
    required this.usedLeaves,
    required this.availableLeaves,
    required this.effectiveDate,
    required this.allocationFrequency,
  });

  Map<String, dynamic> toMap() => {
        if (id != 0) 'id': id,
        'employee_id': employeeId,
        'leave_type': leaveType,
        'allowed_leaves': allowedLeaves,
        'used_leaves': usedLeaves,
        'available_leaves': availableLeaves,
        'effective_date': effectiveDate,
        'allocation_frequency': allocationFrequency,
      };

  factory LeaveBalance.fromMap(Map<String, dynamic> map) => LeaveBalance(
        id: map['id'] as int? ?? 0,
        employeeId: map['employee_id'] as int? ?? 0,
        leaveType: map['leave_type'] as String? ?? '',
        allowedLeaves: (map['allowed_leaves'] as num?)?.toDouble() ?? 0.0,
        usedLeaves: (map['used_leaves'] as num?)?.toDouble() ?? 0.0,
        availableLeaves: (map['available_leaves'] as num?)?.toDouble() ?? 0.0,
        effectiveDate: map['effective_date'] as String? ?? '',
        allocationFrequency: map['allocation_frequency'] as String? ?? 'Monthly',
      );

  LeaveBalance copyWith({
    int? id,
    int? employeeId,
    String? leaveType,
    double? allowedLeaves,
    double? usedLeaves,
    double? availableLeaves,
    String? effectiveDate,
    String? allocationFrequency,
  }) =>
      LeaveBalance(
        id: id ?? this.id,
        employeeId: employeeId ?? this.employeeId,
        leaveType: leaveType ?? this.leaveType,
        allowedLeaves: allowedLeaves ?? this.allowedLeaves,
        usedLeaves: usedLeaves ?? this.usedLeaves,
        availableLeaves: availableLeaves ?? this.availableLeaves,
        effectiveDate: effectiveDate ?? this.effectiveDate,
        allocationFrequency: allocationFrequency ?? this.allocationFrequency,
      );
}
