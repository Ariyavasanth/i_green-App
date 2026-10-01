class LoanRepayment {
  final String repaymentId;
  final String payrollId; // e.g. "6_June_2026" or "PAY-001"
  final String month; // e.g. "September 2026"
  final double amount;
  final String paymentDate; // e.g. "2026-09-30"
  final String referenceNote;
  final String createdAt;

  const LoanRepayment({
    required this.repaymentId,
    required this.payrollId,
    required this.month,
    required this.amount,
    required this.paymentDate,
    this.referenceNote = '',
    this.createdAt = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'repayment_id': repaymentId,
      'payroll_id': payrollId,
      'month': month,
      'amount': amount,
      'payment_date': paymentDate,
      'reference_note': referenceNote,
      'created_at': createdAt,
    };
  }

  factory LoanRepayment.fromMap(Map<String, dynamic> map) {
    return LoanRepayment(
      repaymentId: map['repayment_id'] as String? ?? '',
      payrollId: map['payroll_id'] as String? ?? '',
      month: map['month'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      paymentDate: map['payment_date'] as String? ?? '',
      referenceNote: map['reference_note'] as String? ?? '',
      createdAt: map['created_at'] as String? ?? '',
    );
  }
}

class LoanEmiPauseRequest {
  final String requestId;
  final String loanId;
  final int employeeId;
  final String employeeName;
  final String month; // e.g. "October 2026"
  final String reason;
  final String status; // 'Pending', 'Approved', 'Rejected', 'Cancelled'
  final String requestedAt; // ISO8601
  final String reviewedBy;
  final String reviewedAt;
  final String adminRemarks;
  final bool isRecovered; // true once the following month recovers the deferred 2x EMI

  const LoanEmiPauseRequest({
    required this.requestId,
    required this.loanId,
    required this.employeeId,
    required this.employeeName,
    required this.month,
    required this.reason,
    this.status = 'Pending',
    required this.requestedAt,
    this.reviewedBy = '',
    this.reviewedAt = '',
    this.adminRemarks = '',
    this.isRecovered = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'request_id': requestId,
      'loan_id': loanId,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'month': month,
      'reason': reason,
      'status': status,
      'requested_at': requestedAt,
      'reviewed_by': reviewedBy,
      'reviewed_at': reviewedAt,
      'admin_remarks': adminRemarks,
      'is_recovered': isRecovered,
    };
  }

  factory LoanEmiPauseRequest.fromMap(Map<String, dynamic> map) {
    return LoanEmiPauseRequest(
      requestId: map['request_id'] as String? ?? '',
      loanId: map['loan_id'] as String? ?? '',
      employeeId: map['employee_id'] as int? ?? 0,
      employeeName: map['employee_name'] as String? ?? '',
      month: map['month'] as String? ?? '',
      reason: map['reason'] as String? ?? '',
      status: map['status'] as String? ?? 'Pending',
      requestedAt: map['requested_at'] as String? ?? '',
      reviewedBy: map['reviewed_by'] as String? ?? '',
      reviewedAt: map['reviewed_at'] as String? ?? '',
      adminRemarks: map['admin_remarks'] as String? ?? '',
      isRecovered: map['is_recovered'] as bool? ?? false,
    );
  }

  LoanEmiPauseRequest copyWith({
    String? requestId,
    String? loanId,
    int? employeeId,
    String? employeeName,
    String? month,
    String? reason,
    String? status,
    String? requestedAt,
    String? reviewedBy,
    String? reviewedAt,
    String? adminRemarks,
    bool? isRecovered,
  }) {
    return LoanEmiPauseRequest(
      requestId: requestId ?? this.requestId,
      loanId: loanId ?? this.loanId,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      month: month ?? this.month,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      requestedAt: requestedAt ?? this.requestedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      adminRemarks: adminRemarks ?? this.adminRemarks,
      isRecovered: isRecovered ?? this.isRecovered,
    );
  }
}

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
  final List<LoanRepayment> repayments;
  final List<LoanEmiPauseRequest> pauseRequests;

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
    this.repayments = const [],
    this.pauseRequests = const [],
  });

  /// Parse "Month Year" (e.g. "September 2026") into (year, monthNumber)
  static (int, int) parseMonthYear(String monthStr) {
    final now = DateTime.now();
    final parts = monthStr.trim().split(' ');
    if (parts.length < 2) return (now.year, now.month);
    final monthName = parts[0].toLowerCase();
    final year = int.tryParse(parts[1]) ?? now.year;
    const months = [
      'january', 'february', 'march', 'april', 'may', 'june',
      'july', 'august', 'september', 'october', 'november', 'december'
    ];
    final idx = months.indexOf(monthName);
    return (year, idx != -1 ? idx + 1 : now.month);
  }

  /// Monthly Principal (Principal / installments)
  double get monthlyPrincipal => installments > 0 ? loanAmount / installments : 0.0;

  /// Number of active interest days for installment (0-indexed)
  /// In 1st installment, calculates exact days from disbursementDate to the payroll cutoff date.
  int activeDaysForInstallment(int index, {int payrollStartDay = 20, int payrollEndDay = 20}) {
    if (installments <= 0 || scheduleMonths.isEmpty || index >= scheduleMonths.length) return 30;
    final (year, monthNum) = parseMonthYear(scheduleMonths[index]);
    
    // Determine cross month cycle
    final bool isCrossMonth = payrollStartDay > payrollEndDay || (payrollStartDay == payrollEndDay && payrollStartDay > 1);
    final DateTime cycleStart;
    if (isCrossMonth) {
      final prevMonthDate = DateTime(year, monthNum - 1, 1);
      cycleStart = DateTime(prevMonthDate.year, prevMonthDate.month, payrollStartDay);
    } else {
      cycleStart = DateTime(year, monthNum, payrollStartDay);
    }
    final endExclusive = DateTime(year, monthNum, payrollEndDay).add(const Duration(days: 1));
    final totalCycleDays = endExclusive.difference(cycleStart).inDays;

    if (index == 0 && disbursementDate.isNotEmpty) {
      final parsedDisb = DateTime.tryParse(disbursementDate);
      if (parsedDisb != null) {
        final disbDateOnly = DateTime(parsedDisb.year, parsedDisb.month, parsedDisb.day);
        if (disbDateOnly.isAfter(endExclusive)) {
          return 0;
        }
        final effectiveStart = disbDateOnly.isAfter(cycleStart) ? disbDateOnly : cycleStart;
        final diff = endExclusive.difference(effectiveStart).inDays;
        return diff.clamp(0, totalCycleDays);
      }
    }
    return totalCycleDays;
  }

  /// Total days in the payroll cycle for installment
  int cycleDaysForInstallment(int index, {int payrollStartDay = 20, int payrollEndDay = 20}) {
    if (installments <= 0 || scheduleMonths.isEmpty || index >= scheduleMonths.length) return 30;
    final (year, monthNum) = parseMonthYear(scheduleMonths[index]);
    
    final bool isCrossMonth = payrollStartDay > payrollEndDay || (payrollStartDay == payrollEndDay && payrollStartDay > 1);
    final DateTime cycleStart;
    if (isCrossMonth) {
      final prevMonthDate = DateTime(year, monthNum - 1, 1);
      cycleStart = DateTime(prevMonthDate.year, prevMonthDate.month, payrollStartDay);
    } else {
      cycleStart = DateTime(year, monthNum, payrollStartDay);
    }
    final endExclusive = DateTime(year, monthNum, payrollEndDay).add(const Duration(days: 1));
    return endExclusive.difference(cycleStart).inDays;
  }

  /// Calendar days in month for installment
  int daysInMonthForInstallment(int index) {
    if (installments <= 0 || scheduleMonths.isEmpty || index >= scheduleMonths.length) return 30;
    final (year, monthNum) = parseMonthYear(scheduleMonths[index]);
    return DateTime(year, monthNum + 1, 0).day;
  }

  /// Principal balance at start of given installment (0-indexed)
  double startPrincipalForInstallment(int index) {
    if (installments <= 0) return 0.0;
    final start = loanAmount - (index * monthlyPrincipal);
    return start < 0.01 ? 0.0 : start;
  }

  /// Principal balance at end of given installment (0-indexed)
  double endPrincipalForInstallment(int index) {
    if (installments <= 0) return 0.0;
    final end = loanAmount - ((index + 1) * monthlyPrincipal);
    return end < 0.01 ? 0.0 : end;
  }

  /// Interest amount for a specific installment month (0-indexed)
  /// calculated on full-month reducing balance: Starting Principal * (Rate / 100)
  double interestForInstallment(
    int index, {
    int payrollStartDay = 20,
    int payrollEndDay = 20,
  }) {
    if (interestRate <= 0 || installments <= 0) return 0.0;
    final start = startPrincipalForInstallment(index);
    if (start <= 0) return 0.0;

    return start * (interestRate / 100.0);
  }

  /// Total EMI for a specific installment month (0-indexed)
  /// = Monthly Principal + Full-Month Interest for that month
  double emiForInstallment(
    int index, {
    int payrollStartDay = 20,
    int payrollEndDay = 20,
  }) {
    return monthlyPrincipal + interestForInstallment(
      index,
      payrollStartDay: payrollStartDay,
      payrollEndDay: payrollEndDay,
    );
  }

  /// Total interest calculated across all installments (Full-Month Reducing Balance)
  double calculatedTotalInterestWithDays({
    int payrollStartDay = 20,
    int payrollEndDay = 20,
  }) {
    if (installments <= 0 || interestRate <= 0) return 0.0;
    double total = 0.0;
    for (int i = 0; i < installments; i++) {
      total += interestForInstallment(
        i,
        payrollStartDay: payrollStartDay,
        payrollEndDay: payrollEndDay,
      );
    }
    return total;
  }

  /// Total interest calculated using full-month reducing balance formula
  double get calculatedTotalInterest => calculatedTotalInterestWithDays();

  /// Total repayable amount (Principal + Total Full-Month Reducing Balance Interest)
  double calculatedTotalRepayableWithDays({
    int payrollStartDay = 20,
    int payrollEndDay = 20,
  }) {
    if (interestRate > 0) {
      return loanAmount + calculatedTotalInterestWithDays(
        payrollStartDay: payrollStartDay,
        payrollEndDay: payrollEndDay,
      );
    }
    return totalRepayableAmount > 0 ? totalRepayableAmount : loanAmount;
  }

  /// Total repayable amount getter
  double get calculatedTotalRepayable => calculatedTotalRepayableWithDays();

  /// Total amount repaid from the repayment ledger, fallback to balance difference.
  double get totalPaid {
    if (repayments.isNotEmpty) {
      return repayments.fold<double>(0.0, (total, r) => total + r.amount);
    }
    final paid = totalRepayableAmount - remainingBalance;
    return paid < 0 ? 0.0 : (paid > totalRepayableAmount ? totalRepayableAmount : paid);
  }

  /// Accurate calculated remaining balance
  double get actualRemainingBalance {
    if (repayments.isNotEmpty) {
      final balance = totalRepayableAmount - totalPaid;
      return balance < 0.01 ? 0.0 : balance;
    }
    return remainingBalance < 0.01 ? 0.0 : remainingBalance;
  }

  /// Paid installments count
  int get paidInstallments {
    if (repayments.isNotEmpty) {
      return repayments.length > installments ? installments : repayments.length;
    }
    if (emiAmount <= 0) return 0;
    final count = (totalPaid / emiAmount).round();
    return count > installments ? installments : count;
  }

  /// Remaining installments count
  int get remainingInstallments {
    final rem = installments - paidInstallments;
    return rem < 0 ? 0 : rem;
  }

  /// Generate chronological list of deduction months
  List<String> get scheduleMonths {
    if (installments <= 0 || firstDeductionMonth.isEmpty) return [];
    final parts = firstDeductionMonth.trim().split(' ');
    if (parts.length < 2) return [firstDeductionMonth];
    final monthName = parts[0];
    final year = int.tryParse(parts[1]) ?? DateTime.now().year;

    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final startIndex = months.indexOf(monthName);
    if (startIndex == -1) return [firstDeductionMonth];

    final result = <String>[];
    for (int i = 0; i < installments; i++) {
      final totalMonths = startIndex + i;
      final finalMonthIndex = totalMonths % 12;
      final finalYear = year + (totalMonths ~/ 12);
      result.add('${months[finalMonthIndex]} $finalYear');
    }
    return result;
  }

  /// Next EMI Month calculation
  String get nextEmiMonth {
    if (actualRemainingBalance <= 0 || status == 'Closed') return 'Completed';
    final months = scheduleMonths;
    if (months.isEmpty) return firstDeductionMonth;
    final paidCount = paidInstallments;
    if (paidCount < months.length) {
      return months[paidCount];
    }
    return months.last;
  }

  /// Get pause/deferral request for a specific month
  LoanEmiPauseRequest? getPauseRequestForMonth(String month) {
    final norm = month.trim().toLowerCase();
    return pauseRequests.where((r) => r.month.trim().toLowerCase() == norm).firstOrNull;
  }

  /// Check if a given month has an approved EMI pause
  bool isMonthPaused(String month) {
    final req = getPauseRequestForMonth(month);
    return req != null && req.status.trim().toLowerCase() == 'approved';
  }

  /// Get unrecovered approved pause request from an earlier month
  LoanEmiPauseRequest? getUnrecoveredDeferredRequestBefore(String currentMonth) {
    final (cYear, cMonth) = parseMonthYear(currentMonth);
    for (final req in pauseRequests) {
      if (req.status.trim().toLowerCase() == 'approved' && !req.isRecovered) {
        final (rYear, rMonth) = parseMonthYear(req.month);
        final isBefore = rYear < cYear || (rYear == cYear && rMonth < cMonth);
        if (isBefore) {
          return req;
        }
      }
    }
    return null;
  }

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
      'remaining_balance': actualRemainingBalance,
      'repayments': repayments.map((r) => r.toMap()).toList(),
      'pause_requests': pauseRequests.map((r) => r.toMap()).toList(),
    };
  }

  factory EmployeeLoan.fromMap(Map<String, dynamic> map) {
    var rawRepayments = map['repayments'];
    List<LoanRepayment> repaymentsList = [];
    if (rawRepayments is List) {
      repaymentsList = rawRepayments
          .map((r) => LoanRepayment.fromMap(Map<String, dynamic>.from(r as Map)))
          .toList();
    }

    var rawPauseRequests = map['pause_requests'];
    List<LoanEmiPauseRequest> pauseList = [];
    if (rawPauseRequests is List) {
      pauseList = rawPauseRequests
          .map((p) => LoanEmiPauseRequest.fromMap(Map<String, dynamic>.from(p as Map)))
          .toList();
    }

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
      repayments: repaymentsList,
      pauseRequests: pauseList,
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
    List<LoanRepayment>? repayments,
    List<LoanEmiPauseRequest>? pauseRequests,
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
      repayments: repayments ?? this.repayments,
      pauseRequests: pauseRequests ?? this.pauseRequests,
    );
  }
}
