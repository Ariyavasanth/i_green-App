class IncentivePayoutLedger {
  final String id;
  final int employeeId;
  final String employeeName;
  final String earnedCycle;
  final double totalEarnedAmount;
  final double immediateAmount;
  final double deferredAmount;
  final String status; // 'Pending' or 'Released'
  final String? releaseCycle;
  final double? releasedAmount;
  final String createdAt;
  final String? releasedAt;
  final int? payrollRecordId;

  const IncentivePayoutLedger({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.earnedCycle,
    required this.totalEarnedAmount,
    required this.immediateAmount,
    required this.deferredAmount,
    this.status = 'Pending',
    this.releaseCycle,
    this.releasedAmount,
    required this.createdAt,
    this.releasedAt,
    this.payrollRecordId,
  });

  bool get isPending => status.toLowerCase() == 'pending';
  bool get isReleased => status.toLowerCase() == 'released';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'earned_cycle': earnedCycle,
      'total_earned_amount': totalEarnedAmount,
      'immediate_amount': immediateAmount,
      'deferred_amount': deferredAmount,
      'status': status,
      'release_cycle': releaseCycle,
      'released_amount': releasedAmount,
      'created_at': createdAt,
      'released_at': releasedAt,
      if (payrollRecordId != null) 'payroll_record_id': payrollRecordId,
    };
  }

  factory IncentivePayoutLedger.fromMap(Map<String, dynamic> map, [String? docId]) {
    return IncentivePayoutLedger(
      id: (map['id'] as String?) ?? docId ?? '',
      employeeId: (map['employee_id'] as num?)?.toInt() ?? 0,
      employeeName: map['employee_name'] as String? ?? '',
      earnedCycle: map['earned_cycle'] as String? ?? '',
      totalEarnedAmount: (map['total_earned_amount'] as num?)?.toDouble() ?? 0.0,
      immediateAmount: (map['immediate_amount'] as num?)?.toDouble() ?? 0.0,
      deferredAmount: (map['deferred_amount'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] as String? ?? 'Pending',
      releaseCycle: map['release_cycle'] as String?,
      releasedAmount: (map['released_amount'] as num?)?.toDouble(),
      createdAt: map['created_at'] as String? ?? DateTime.now().toIso8601String(),
      releasedAt: map['released_at'] as String?,
      payrollRecordId: (map['payroll_record_id'] as num?)?.toInt(),
    );
  }

  IncentivePayoutLedger copyWith({
    String? id,
    int? employeeId,
    String? employeeName,
    String? earnedCycle,
    double? totalEarnedAmount,
    double? immediateAmount,
    double? deferredAmount,
    String? status,
    String? releaseCycle,
    double? releasedAmount,
    String? createdAt,
    String? releasedAt,
    int? payrollRecordId,
  }) {
    return IncentivePayoutLedger(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      earnedCycle: earnedCycle ?? this.earnedCycle,
      totalEarnedAmount: totalEarnedAmount ?? this.totalEarnedAmount,
      immediateAmount: immediateAmount ?? this.immediateAmount,
      deferredAmount: deferredAmount ?? this.deferredAmount,
      status: status ?? this.status,
      releaseCycle: releaseCycle ?? this.releaseCycle,
      releasedAmount: releasedAmount ?? this.releasedAmount,
      createdAt: createdAt ?? this.createdAt,
      releasedAt: releasedAt ?? this.releasedAt,
      payrollRecordId: payrollRecordId ?? this.payrollRecordId,
    );
  }
}
