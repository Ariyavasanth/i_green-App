class EmployeeLoan {
  final int id;
  final String loanId; // e.g. LN001
  final int employeeId;
  final String employeeName;
  final String employeeCustomId; // e.g. EMP-0001
  final String department;
  final String designation;
  final String loanType; // Personal Loan, Salary Advance, Emergency Loan, Education Loan, Medical Loan, Other
  final double loanAmount;
  final String loanDate;
  final String disbursementDate;
  final String purpose;
  final int installments; // in Months
  final double emiAmount;
  final String firstDeductionMonth; // e.g. "September 2026"
  final String lastDeductionMonth; // e.g. "August 2027"
  final double interestRate; // Optional, e.g. 5.0
  final double totalRepayableAmount;
  final String requestedBy;
  final String approvedBy;
  final String approvalDate;
  final String remarks;
  final String status; // Pending, Approved, Rejected, Active, Closed
  final double remainingBalance;

  const EmployeeLoan({
    required this.id,
    required this.loanId,
    required this.employeeId,
    required this.employeeName,
    required this.employeeCustomId,
    required this.department,
    required this.designation,
    required this.loanType,
    required this.loanAmount,
    required this.loanDate,
    required this.disbursementDate,
    required this.purpose,
    required this.installments,
    required this.emiAmount,
    required this.firstDeductionMonth,
    required this.lastDeductionMonth,
    this.interestRate = 0.0,
    required this.totalRepayableAmount,
    required this.requestedBy,
    this.approvedBy = '',
    this.approvalDate = '',
    this.remarks = '',
    required this.status,
    required this.remainingBalance,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != 0) 'id': id,
      'loan_id': loanId,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'employee_custom_id': employeeCustomId,
      'department': department,
      'designation': designation,
      'loan_type': loanType,
      'loan_amount': loanAmount,
      'loan_date': loanDate,
      'disbursement_date': disbursementDate,
      'purpose': purpose,
      'installments': installments,
      'emi_amount': emiAmount,
      'first_deduction_month': firstDeductionMonth,
      'last_deduction_month': lastDeductionMonth,
      'interest_rate': interestRate,
      'total_repayable_amount': totalRepayableAmount,
      'requested_by': requestedBy,
      'approved_by': approvedBy,
      'approval_date': approvalDate,
      'remarks': remarks,
      'status': status,
      'remaining_balance': remainingBalance,
    };
  }

  factory EmployeeLoan.fromMap(Map<String, dynamic> map) {
    return EmployeeLoan(
      id: map['id'] as int? ?? 0,
      loanId: map['loan_id'] as String? ?? '',
      employeeId: map['employee_id'] as int? ?? 0,
      employeeName: map['employee_name'] as String? ?? '',
      employeeCustomId: map['employee_custom_id'] as String? ?? '',
      department: map['department'] as String? ?? '',
      designation: map['designation'] as String? ?? '',
      loanType: map['loan_type'] as String? ?? '',
      loanAmount: (map['loan_amount'] as num?)?.toDouble() ?? 0.0,
      loanDate: map['loan_date'] as String? ?? '',
      disbursementDate: map['disbursement_date'] as String? ?? '',
      purpose: map['purpose'] as String? ?? '',
      installments: map['installments'] as int? ?? 0,
      emiAmount: (map['emi_amount'] as num?)?.toDouble() ?? 0.0,
      firstDeductionMonth: map['first_deduction_month'] as String? ?? '',
      lastDeductionMonth: map['last_deduction_month'] as String? ?? '',
      interestRate: (map['interest_rate'] as num?)?.toDouble() ?? 0.0,
      totalRepayableAmount: (map['total_repayable_amount'] as num?)?.toDouble() ?? 0.0,
      requestedBy: map['requested_by'] as String? ?? '',
      approvedBy: map['approved_by'] as String? ?? '',
      approvalDate: map['approval_date'] as String? ?? '',
      remarks: map['remarks'] as String? ?? '',
      status: map['status'] as String? ?? 'Pending',
      remainingBalance: (map['remaining_balance'] as num?)?.toDouble() ?? 0.0,
    );
  }

  EmployeeLoan copyWith({
    int? id,
    String? loanId,
    int? employeeId,
    String? employeeName,
    String? employeeCustomId,
    String? department,
    String? designation,
    String? loanType,
    double? loanAmount,
    String? loanDate,
    String? disbursementDate,
    String? purpose,
    int? installments,
    double? emiAmount,
    String? firstDeductionMonth,
    String? lastDeductionMonth,
    double? interestRate,
    double? totalRepayableAmount,
    String? requestedBy,
    String? approvedBy,
    String? approvalDate,
    String? remarks,
    String? status,
    double? remainingBalance,
  }) {
    return EmployeeLoan(
      id: id ?? this.id,
      loanId: loanId ?? this.loanId,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      employeeCustomId: employeeCustomId ?? this.employeeCustomId,
      department: department ?? this.department,
      designation: designation ?? this.designation,
      loanType: loanType ?? this.loanType,
      loanAmount: loanAmount ?? this.loanAmount,
      loanDate: loanDate ?? this.loanDate,
      disbursementDate: disbursementDate ?? this.disbursementDate,
      purpose: purpose ?? this.purpose,
      installments: installments ?? this.installments,
      emiAmount: emiAmount ?? this.emiAmount,
      firstDeductionMonth: firstDeductionMonth ?? this.firstDeductionMonth,
      lastDeductionMonth: lastDeductionMonth ?? this.lastDeductionMonth,
      interestRate: interestRate ?? this.interestRate,
      totalRepayableAmount: totalRepayableAmount ?? this.totalRepayableAmount,
      requestedBy: requestedBy ?? this.requestedBy,
      approvedBy: approvedBy ?? this.approvedBy,
      approvalDate: approvalDate ?? this.approvalDate,
      remarks: remarks ?? this.remarks,
      status: status ?? this.status,
      remainingBalance: remainingBalance ?? this.remainingBalance,
    );
  }
}
