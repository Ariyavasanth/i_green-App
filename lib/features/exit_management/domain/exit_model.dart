import 'dart:convert';

class ExitRequest {
  final int? id;
  final String employeeId;
  final String employeeName;
  final String department;
  final String designation;
  final String appliedDate;
  final String reason;
  final String noticeStartDate;
  final String noticeEndDate;
  final int daysCompleted;
  final int totalNoticeDays;
  final String lastWorkingDay;
  final String status; // Pending, Approved, Rejected, In Notice, Clearance, Settlement, Completed
  final bool policyAccepted;
  final String? employeeSignature;
  final int leaveTakenCount;
  final String managerApprovalStatus; // Pending, Approved, Rejected
  final String hrApprovalStatus; // Pending, Approved, Rejected
  final String createdAt;

  const ExitRequest({
    this.id,
    required this.employeeId,
    required this.employeeName,
    required this.department,
    required this.designation,
    required this.appliedDate,
    required this.reason,
    required this.noticeStartDate,
    required this.noticeEndDate,
    this.daysCompleted = 0,
    this.totalNoticeDays = 60,
    required this.lastWorkingDay,
    this.status = 'Pending',
    this.policyAccepted = true,
    this.employeeSignature,
    this.leaveTakenCount = 0,
    this.managerApprovalStatus = 'Pending',
    this.hrApprovalStatus = 'Pending',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'department': department,
      'designation': designation,
      'applied_date': appliedDate,
      'reason': reason,
      'notice_start_date': noticeStartDate,
      'notice_end_date': noticeEndDate,
      'days_completed': daysCompleted,
      'total_notice_days': totalNoticeDays,
      'last_working_day': lastWorkingDay,
      'status': status,
      'policy_accepted': policyAccepted ? 1 : 0,
      'employee_signature': employeeSignature ?? '',
      'leave_taken_count': leaveTakenCount,
      'manager_approval_status': managerApprovalStatus,
      'hr_approval_status': hrApprovalStatus,
      'created_at': createdAt,
    };
  }

  factory ExitRequest.fromMap(Map<String, dynamic> map) {
    return ExitRequest(
      id: map['id'] as int?,
      employeeId: map['employee_id'] as String? ?? '',
      employeeName: map['employee_name'] as String? ?? '',
      department: map['department'] as String? ?? '',
      designation: map['designation'] as String? ?? '',
      appliedDate: map['applied_date'] as String? ?? '',
      reason: map['reason'] as String? ?? '',
      noticeStartDate: map['notice_start_date'] as String? ?? '',
      noticeEndDate: map['notice_end_date'] as String? ?? '',
      daysCompleted: (map['days_completed'] as num?)?.toInt() ?? 0,
      totalNoticeDays: (map['total_notice_days'] as num?)?.toInt() ?? 60,
      lastWorkingDay: map['last_working_day'] as String? ?? '',
      status: map['status'] as String? ?? 'Pending',
      policyAccepted: (map['policy_accepted'] as int?) == 1,
      employeeSignature: map['employee_signature'] as String?,
      leaveTakenCount: (map['leave_taken_count'] as num?)?.toInt() ?? 0,
      managerApprovalStatus: map['manager_approval_status'] as String? ?? 'Pending',
      hrApprovalStatus: map['hr_approval_status'] as String? ?? 'Pending',
      createdAt: map['created_at'] as String? ?? '',
    );
  }

  ExitRequest copyWith({
    int? id,
    String? employeeId,
    String? employeeName,
    String? department,
    String? designation,
    String? appliedDate,
    String? reason,
    String? noticeStartDate,
    String? noticeEndDate,
    int? daysCompleted,
    int? totalNoticeDays,
    String? lastWorkingDay,
    String? status,
    bool? policyAccepted,
    String? employeeSignature,
    int? leaveTakenCount,
    String? managerApprovalStatus,
    String? hrApprovalStatus,
    String? createdAt,
  }) {
    return ExitRequest(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      department: department ?? this.department,
      designation: designation ?? this.designation,
      appliedDate: appliedDate ?? this.appliedDate,
      noticeStartDate: noticeStartDate ?? this.noticeStartDate,
      noticeEndDate: noticeEndDate ?? this.noticeEndDate,
      daysCompleted: daysCompleted ?? this.daysCompleted,
      totalNoticeDays: totalNoticeDays ?? this.totalNoticeDays,
      lastWorkingDay: lastWorkingDay ?? this.lastWorkingDay,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      policyAccepted: policyAccepted ?? this.policyAccepted,
      employeeSignature: employeeSignature ?? this.employeeSignature,
      leaveTakenCount: leaveTakenCount ?? this.leaveTakenCount,
      managerApprovalStatus: managerApprovalStatus ?? this.managerApprovalStatus,
      hrApprovalStatus: hrApprovalStatus ?? this.hrApprovalStatus,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class DepartmentClearance {
  final int? id;
  final int exitRequestId;
  final String department; // IT, HR, Admin, Accounts, Manager
  final String status; // Pending, Approved, Rejected
  final Map<String, bool> checklist;
  final String comments;
  final String updatedAt;

  const DepartmentClearance({
    this.id,
    required this.exitRequestId,
    required this.department,
    this.status = 'Pending',
    required this.checklist,
    this.comments = '',
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'exit_request_id': exitRequestId,
      'department': department,
      'status': status,
      'checklist_json': jsonEncode(checklist),
      'comments': comments,
      'updated_at': updatedAt,
    };
  }

  factory DepartmentClearance.fromMap(Map<String, dynamic> map) {
    Map<String, bool> parsedChecklist = {};
    if (map['checklist_json'] != null && (map['checklist_json'] as String).isNotEmpty) {
      try {
        final decoded = jsonDecode(map['checklist_json'] as String) as Map<String, dynamic>;
        parsedChecklist = decoded.map((key, value) => MapEntry(key, value == true));
      } catch (_) {}
    }

    return DepartmentClearance(
      id: map['id'] as int?,
      exitRequestId: (map['exit_request_id'] as num).toInt(),
      department: map['department'] as String? ?? '',
      status: map['status'] as String? ?? 'Pending',
      checklist: parsedChecklist,
      comments: map['comments'] as String? ?? '',
      updatedAt: map['updated_at'] as String? ?? '',
    );
  }

  DepartmentClearance copyWith({
    int? id,
    int? exitRequestId,
    String? department,
    String? status,
    Map<String, bool>? checklist,
    String? comments,
    String? updatedAt,
  }) {
    return DepartmentClearance(
      id: id ?? this.id,
      exitRequestId: exitRequestId ?? this.exitRequestId,
      department: department ?? this.department,
      status: status ?? this.status,
      checklist: checklist ?? this.checklist,
      comments: comments ?? this.comments,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ExitInterview {
  final int? id;
  final int exitRequestId;
  final String reasonCategory;
  final String feedback;
  final bool recommendCompany;
  final String submittedAt;

  const ExitInterview({
    this.id,
    required this.exitRequestId,
    required this.reasonCategory,
    required this.feedback,
    required this.recommendCompany,
    required this.submittedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'exit_request_id': exitRequestId,
      'reason_category': reasonCategory,
      'feedback': feedback,
      'recommend_company': recommendCompany ? 1 : 0,
      'submitted_at': submittedAt,
    };
  }

  factory ExitInterview.fromMap(Map<String, dynamic> map) {
    return ExitInterview(
      id: map['id'] as int?,
      exitRequestId: (map['exit_request_id'] as num).toInt(),
      reasonCategory: map['reason_category'] as String? ?? 'Other',
      feedback: map['feedback'] as String? ?? '',
      recommendCompany: (map['recommend_company'] as int?) == 1,
      submittedAt: map['submitted_at'] as String? ?? '',
    );
  }
}

class ExitSettlement {
  final int? id;
  final int exitRequestId;
  final double grossSalary;
  final double noticePay;
  final double insuranceDeduction;
  final double uniformDeduction;
  final double shoesDeduction;
  final double idCardDeduction;
  final double loanDeduction;
  final double noticeShortfallDeduction;
  final double otherDeductions;
  final double totalDeductions;
  final double netSettlement;
  final String status; // Pending, Processed, Paid
  final String? payoutDate;
  final String notes;

  const ExitSettlement({
    this.id,
    required this.exitRequestId,
    this.grossSalary = 0.0,
    this.noticePay = 0.0,
    this.insuranceDeduction = 0.0,
    this.uniformDeduction = 0.0,
    this.shoesDeduction = 0.0,
    this.idCardDeduction = 0.0,
    this.loanDeduction = 0.0,
    this.noticeShortfallDeduction = 0.0,
    this.otherDeductions = 0.0,
    this.totalDeductions = 0.0,
    this.netSettlement = 0.0,
    this.status = 'Pending',
    this.payoutDate,
    this.notes = 'Salary processed after 45 working days',
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'exit_request_id': exitRequestId,
      'gross_salary': grossSalary,
      'notice_pay': noticePay,
      'insurance_deduction': insuranceDeduction,
      'uniform_deduction': uniformDeduction,
      'shoes_deduction': shoesDeduction,
      'id_card_deduction': idCardDeduction,
      'loan_deduction': loanDeduction,
      'notice_shortfall_deduction': noticeShortfallDeduction,
      'other_deductions': otherDeductions,
      'total_deductions': totalDeductions,
      'net_settlement': netSettlement,
      'status': status,
      'payout_date': payoutDate ?? '',
      'notes': notes,
    };
  }

  factory ExitSettlement.fromMap(Map<String, dynamic> map) {
    return ExitSettlement(
      id: map['id'] as int?,
      exitRequestId: (map['exit_request_id'] as num).toInt(),
      grossSalary: (map['gross_salary'] as num?)?.toDouble() ?? 0.0,
      noticePay: (map['notice_pay'] as num?)?.toDouble() ?? 0.0,
      insuranceDeduction: (map['insurance_deduction'] as num?)?.toDouble() ?? 0.0,
      uniformDeduction: (map['uniform_deduction'] as num?)?.toDouble() ?? 0.0,
      shoesDeduction: (map['shoes_deduction'] as num?)?.toDouble() ?? 0.0,
      idCardDeduction: (map['id_card_deduction'] as num?)?.toDouble() ?? 0.0,
      loanDeduction: (map['loan_deduction'] as num?)?.toDouble() ?? 0.0,
      noticeShortfallDeduction: (map['notice_shortfall_deduction'] as num?)?.toDouble() ?? 0.0,
      otherDeductions: (map['other_deductions'] as num?)?.toDouble() ?? 0.0,
      totalDeductions: (map['total_deductions'] as num?)?.toDouble() ?? 0.0,
      netSettlement: (map['net_settlement'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] as String? ?? 'Pending',
      payoutDate: map['payout_date'] as String?,
      notes: map['notes'] as String? ?? 'Salary processed after 45 working days',
    );
  }
}
