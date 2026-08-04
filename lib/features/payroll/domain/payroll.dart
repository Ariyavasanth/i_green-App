class PayrollRecord {
  final int id;
  final int employeeId;
  final String employeeName;
  final String month;
  
  // Attendance metrics
  final int presentDays;
  final int lateDays;
  final int absentDays;
  final int leaveDays;

  // Employee details at generation time
  final String designation;
  final String department;
  final String emailId;
  final String panNumber;
  final String pfNumber;
  final String esiNumber;
  
  // Bank Details
  final String bankName;
  final String bankAcctNo;
  final String branch;
  final String ifscCode;

  // Standard Earnings
  final double basicPay;
  final double hra;
  final double educationAllowance;
  final double specialAllowance;
  
  // Additional Earnings
  final double incentive;
  final String carryForward; // e.g. "-"
  final double othersEarning;
  final double cumulativeIncentive;
  
  // Statutory Deductions
  final double pf;
  final double tax; // TDS
  final double esi;
  
  // Other Deductions
  final double lop;
  final double companyLoan;
  final double salaryAdvance;
  final double othersDeduction;
  final double staffWelfareContribution;
  
  // Net salary
  final double netSalary;
  
  // Metadata & Payment info
  final String status; // 'Pending', 'Processed', 'Paid'
  final String paymentDate;
  final String paymentMethod; // 'Bank Transfer', 'Cash', 'Cheque'

  // Additional fields for employee self-service and loan tracing
  final String loanDescription;
  final String advanceDescription;
  final bool isDisputed;
  final String disputeComment;

  const PayrollRecord({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.month,
    required this.presentDays,
    required this.lateDays,
    required this.absentDays,
    required this.leaveDays,
    this.designation = '',
    this.department = '',
    this.emailId = '',
    this.panNumber = '',
    this.pfNumber = '',
    this.esiNumber = '',
    this.bankName = '',
    this.bankAcctNo = '',
    this.branch = '',
    this.ifscCode = '',
    required this.basicPay,
    required this.hra,
    required this.educationAllowance,
    required this.specialAllowance,
    this.incentive = 0.0,
    this.carryForward = '-',
    this.othersEarning = 0.0,
    this.cumulativeIncentive = 0.0,
    required this.pf,
    required this.tax,
    this.esi = 0.0,
    this.lop = 0.0,
    this.companyLoan = 0.0,
    this.salaryAdvance = 0.0,
    this.othersDeduction = 0.0,
    this.staffWelfareContribution = 0.0,
    required this.netSalary,
    required this.status,
    this.paymentDate = '',
    this.paymentMethod = 'Bank Transfer',
    this.loanDescription = '',
    this.advanceDescription = '',
    this.isDisputed = false,
    this.disputeComment = '',
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != 0) 'id': id,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'month': month,
      'present_days': presentDays,
      'late_days': lateDays,
      'absent_days': absentDays,
      'leave_days': leaveDays,
      'designation': designation,
      'department': department,
      'email_id': emailId,
      'pan_number': panNumber,
      'pf_number': pfNumber,
      'esi_number': esiNumber,
      'bank_name': bankName,
      'bank_acct_no': bankAcctNo,
      'branch': branch,
      'ifsc_code': ifscCode,
      'basic_pay': basicPay,
      'hra': hra,
      'education_allowance': educationAllowance,
      'special_allowance': specialAllowance,
      'incentive': incentive,
      'carry_forward': carryForward,
      'others_earning': othersEarning,
      'cumulative_incentive': cumulativeIncentive,
      'pf': pf,
      'tax': tax,
      'esi': esi,
      'lop': lop,
      'company_loan': companyLoan,
      'salary_advance': salaryAdvance,
      'others_deduction': othersDeduction,
      'staff_welfare_contribution': staffWelfareContribution,
      'net_salary': netSalary,
      'status': status,
      'payment_date': paymentDate,
      'payment_method': paymentMethod,
      'loan_description': loanDescription,
      'advance_description': advanceDescription,
      'is_disputed': isDisputed ? 1 : 0,
      'dispute_comment': disputeComment,
    };
  }

  factory PayrollRecord.fromMap(Map<String, dynamic> map) {
    return PayrollRecord(
      id: map['id'] as int? ?? 0,
      employeeId: map['employee_id'] as int? ?? 0,
      employeeName: map['employee_name'] as String? ?? '',
      month: map['month'] as String? ?? '',
      presentDays: map['present_days'] as int? ?? 0,
      lateDays: map['late_days'] as int? ?? 0,
      absentDays: map['absent_days'] as int? ?? 0,
      leaveDays: map['leave_days'] as int? ?? 0,
      designation: map['designation'] as String? ?? '',
      department: map['department'] as String? ?? '',
      emailId: map['email_id'] as String? ?? '',
      panNumber: map['pan_number'] as String? ?? '',
      pfNumber: map['pf_number'] as String? ?? '',
      esiNumber: map['esi_number'] as String? ?? '',
      bankName: map['bank_name'] as String? ?? '',
      bankAcctNo: map['bank_acct_no'] as String? ?? '',
      branch: map['branch'] as String? ?? '',
      ifscCode: map['ifsc_code'] as String? ?? '',
      basicPay: (map['basic_pay'] as num?)?.toDouble() ?? 0.0,
      hra: (map['hra'] as num?)?.toDouble() ?? 0.0,
      educationAllowance: (map['education_allowance'] as num?)?.toDouble() ?? 0.0,
      specialAllowance: (map['special_allowance'] as num?)?.toDouble() ?? 0.0,
      incentive: (map['incentive'] as num?)?.toDouble() ?? 0.0,
      carryForward: map['carry_forward'] as String? ?? '-',
      othersEarning: (map['others_earning'] as num?)?.toDouble() ?? 0.0,
      cumulativeIncentive: (map['cumulative_incentive'] as num?)?.toDouble() ?? 0.0,
      pf: (map['pf'] as num?)?.toDouble() ?? 0.0,
      tax: (map['tax'] as num?)?.toDouble() ?? 0.0,
      esi: (map['esi'] as num?)?.toDouble() ?? 0.0,
      lop: (map['lop'] as num?)?.toDouble() ?? 0.0,
      companyLoan: (map['company_loan'] as num?)?.toDouble() ?? 0.0,
      salaryAdvance: (map['salary_advance'] as num?)?.toDouble() ?? 0.0,
      othersDeduction: (map['others_deduction'] as num?)?.toDouble() ?? 0.0,
      staffWelfareContribution: (map['staff_welfare_contribution'] as num?)?.toDouble() ?? 0.0,
      netSalary: (map['net_salary'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] as String? ?? 'Pending',
      paymentDate: map['payment_date'] as String? ?? '',
      paymentMethod: map['payment_method'] as String? ?? 'Bank Transfer',
      loanDescription: map['loan_description'] as String? ?? '',
      advanceDescription: map['advance_description'] as String? ?? '',
      isDisputed: (map['is_disputed'] as int? ?? 0) == 1 || (map['is_disputed'] as bool? ?? false),
      disputeComment: map['dispute_comment'] as String? ?? '',
    );
  }

  PayrollRecord copyWith({
    int? id,
    int? employeeId,
    String? employeeName,
    String? month,
    int? presentDays,
    int? lateDays,
    int? absentDays,
    int? leaveDays,
    String? designation,
    String? department,
    String? emailId,
    String? panNumber,
    String? pfNumber,
    String? esiNumber,
    String? bankName,
    String? bankAcctNo,
    String? branch,
    String? ifscCode,
    double? basicPay,
    double? hra,
    double? educationAllowance,
    double? specialAllowance,
    double? incentive,
    String? carryForward,
    double? othersEarning,
    double? cumulativeIncentive,
    double? pf,
    double? tax,
    double? esi,
    double? lop,
    double? companyLoan,
    double? salaryAdvance,
    double? othersDeduction,
    double? staffWelfareContribution,
    double? netSalary,
    String? status,
    String? paymentDate,
    String? paymentMethod,
    String? loanDescription,
    String? advanceDescription,
    bool? isDisputed,
    String? disputeComment,
  }) {
    return PayrollRecord(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      month: month ?? this.month,
      presentDays: presentDays ?? this.presentDays,
      lateDays: lateDays ?? this.lateDays,
      absentDays: absentDays ?? this.absentDays,
      leaveDays: leaveDays ?? this.leaveDays,
      designation: designation ?? this.designation,
      department: department ?? this.department,
      emailId: emailId ?? this.emailId,
      panNumber: panNumber ?? this.panNumber,
      pfNumber: pfNumber ?? this.pfNumber,
      esiNumber: esiNumber ?? this.esiNumber,
      bankName: bankName ?? this.bankName,
      bankAcctNo: bankAcctNo ?? this.bankAcctNo,
      branch: branch ?? this.branch,
      ifscCode: ifscCode ?? this.ifscCode,
      basicPay: basicPay ?? this.basicPay,
      hra: hra ?? this.hra,
      educationAllowance: educationAllowance ?? this.educationAllowance,
      specialAllowance: specialAllowance ?? this.specialAllowance,
      incentive: incentive ?? this.incentive,
      carryForward: carryForward ?? this.carryForward,
      othersEarning: othersEarning ?? this.othersEarning,
      cumulativeIncentive: cumulativeIncentive ?? this.cumulativeIncentive,
      pf: pf ?? this.pf,
      tax: tax ?? this.tax,
      esi: esi ?? this.esi,
      lop: lop ?? this.lop,
      companyLoan: companyLoan ?? this.companyLoan,
      salaryAdvance: salaryAdvance ?? this.salaryAdvance,
      othersDeduction: othersDeduction ?? this.othersDeduction,
      staffWelfareContribution: staffWelfareContribution ?? this.staffWelfareContribution,
      netSalary: netSalary ?? this.netSalary,
      status: status ?? this.status,
      paymentDate: paymentDate ?? this.paymentDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      loanDescription: loanDescription ?? this.loanDescription,
      advanceDescription: advanceDescription ?? this.advanceDescription,
      isDisputed: isDisputed ?? this.isDisputed,
      disputeComment: disputeComment ?? this.disputeComment,
    );
  }
}

class PayrollSettings {
  final int id;
  // Attendance Rules
  final double penaltyPerLateDay;
  final int allowedLateDays;
  final double workingDaysInMonth;
  // Statutory percentages
  final double pfPercentage;
  final double taxPercentage;
  final double professionalTaxPercentage;
  // Payment dates
  final int payrollCutoffDay;
  final int paymentDay;

  const PayrollSettings({
    this.id = 1,
    this.penaltyPerLateDay = 0.5,
    this.allowedLateDays = 3,
    this.workingDaysInMonth = 30.0,
    this.pfPercentage = 12.0,
    this.taxPercentage = 10.0,
    this.professionalTaxPercentage = 2.0,
    this.payrollCutoffDay = 20,
    this.paymentDay = 5,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'penalty_per_late_day': penaltyPerLateDay,
      'allowed_late_days': allowedLateDays,
      'working_days_in_month': workingDaysInMonth,
      'pf_percentage': pfPercentage,
      'tax_percentage': taxPercentage,
      'professional_tax_percentage': professionalTaxPercentage,
      'payroll_cutoff_day': payrollCutoffDay,
      'payment_day': paymentDay,
    };
  }

  factory PayrollSettings.fromMap(Map<String, dynamic> map) {
    return PayrollSettings(
      id: map['id'] as int? ?? 1,
      penaltyPerLateDay: (map['penalty_per_late_day'] as num?)?.toDouble() ?? 0.5,
      allowedLateDays: map['allowed_late_days'] as int? ?? 3,
      workingDaysInMonth: (map['working_days_in_month'] as num?)?.toDouble() ?? 30.0,
      pfPercentage: (map['pf_percentage'] as num?)?.toDouble() ?? 12.0,
      taxPercentage: (map['tax_percentage'] as num?)?.toDouble() ?? 10.0,
      professionalTaxPercentage: (map['professional_tax_percentage'] as num?)?.toDouble() ?? 2.0,
      payrollCutoffDay: map['payroll_cutoff_day'] as int? ?? 20,
      paymentDay: map['payment_day'] as int? ?? 5,
    );
  }

  PayrollSettings copyWith({
    int? id,
    double? penaltyPerLateDay,
    int? allowedLateDays,
    double? workingDaysInMonth,
    double? pfPercentage,
    double? taxPercentage,
    double? professionalTaxPercentage,
    int? payrollCutoffDay,
    int? paymentDay,
  }) {
    return PayrollSettings(
      id: id ?? this.id,
      penaltyPerLateDay: penaltyPerLateDay ?? this.penaltyPerLateDay,
      allowedLateDays: allowedLateDays ?? this.allowedLateDays,
      workingDaysInMonth: workingDaysInMonth ?? this.workingDaysInMonth,
      pfPercentage: pfPercentage ?? this.pfPercentage,
      taxPercentage: taxPercentage ?? this.taxPercentage,
      professionalTaxPercentage: professionalTaxPercentage ?? this.professionalTaxPercentage,
      payrollCutoffDay: payrollCutoffDay ?? this.payrollCutoffDay,
      paymentDay: paymentDay ?? this.paymentDay,
    );
  }
}
