class LoanRepayment {
  final String repaymentId;
  final String payrollId; // e.g. "6_June_2026", "PAY-001", or "DIRECT_PAYMENT"
  final String month; // e.g. "September 2026"
  final double amount;
  final String paymentDate; // e.g. "2026-09-30"
  final String referenceNote;
  final String createdAt;
  final String paymentType; // 'Salary Deduction' or 'Direct Payment'
  final String paymentMode; // 'Payroll', 'Cash', 'UPI', 'Bank Transfer', 'Cheque', 'Other'
  final String receivedBy; // Name of admin / authority who received direct payment

  const LoanRepayment({
    required this.repaymentId,
    required this.payrollId,
    required this.month,
    required this.amount,
    required this.paymentDate,
    this.referenceNote = '',
    this.createdAt = '',
    this.paymentType = 'Salary Deduction',
    this.paymentMode = 'Payroll',
    this.receivedBy = '',
  });

  bool get isDirectPayment =>
      paymentType.trim().toLowerCase() == 'direct payment' ||
      payrollId == 'DIRECT_PAYMENT' ||
      (paymentMode.trim().isNotEmpty && paymentMode.trim().toLowerCase() != 'payroll');

  Map<String, dynamic> toMap() {
    return {
      'repayment_id': repaymentId,
      'payroll_id': payrollId,
      'month': month,
      'amount': amount,
      'payment_date': paymentDate,
      'reference_note': referenceNote,
      'created_at': createdAt,
      'payment_type': paymentType,
      'payment_mode': paymentMode,
      'received_by': receivedBy,
    };
  }

  factory LoanRepayment.fromMap(Map<String, dynamic> map) {
    final rawPayrollId = map['payroll_id'] as String? ?? '';
    final rawPaymentType = map['payment_type'] as String?;
    final rawPaymentMode = map['payment_mode'] as String?;

    final resolvedPaymentType = rawPaymentType != null && rawPaymentType.isNotEmpty
        ? rawPaymentType
        : (rawPayrollId.isNotEmpty && rawPayrollId != 'DIRECT_PAYMENT' ? 'Salary Deduction' : 'Direct Payment');

    final resolvedPaymentMode = rawPaymentMode != null && rawPaymentMode.isNotEmpty
        ? rawPaymentMode
        : (resolvedPaymentType == 'Salary Deduction' ? 'Payroll' : 'Cash');

    return LoanRepayment(
      repaymentId: map['repayment_id'] as String? ?? '',
      payrollId: rawPayrollId,
      month: map['month'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      paymentDate: map['payment_date'] as String? ?? '',
      referenceNote: map['reference_note'] as String? ?? '',
      createdAt: map['created_at'] as String? ?? '',
      paymentType: resolvedPaymentType,
      paymentMode: resolvedPaymentMode,
      receivedBy: map['received_by'] as String? ?? '',
    );
  }

  LoanRepayment copyWith({
    String? repaymentId,
    String? payrollId,
    String? month,
    double? amount,
    String? paymentDate,
    String? referenceNote,
    String? createdAt,
    String? paymentType,
    String? paymentMode,
    String? receivedBy,
  }) {
    return LoanRepayment(
      repaymentId: repaymentId ?? this.repaymentId,
      payrollId: payrollId ?? this.payrollId,
      month: month ?? this.month,
      amount: amount ?? this.amount,
      paymentDate: paymentDate ?? this.paymentDate,
      referenceNote: referenceNote ?? this.referenceNote,
      createdAt: createdAt ?? this.createdAt,
      paymentType: paymentType ?? this.paymentType,
      paymentMode: paymentMode ?? this.paymentMode,
      receivedBy: receivedBy ?? this.receivedBy,
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
  final String requestType; // 'Pause' (full deferral) or 'Flexible' (partial deduction)
  final double? requestedAmount; // Custom amount requested to deduct (e.g. 1000.0)
  final double? approvedAmount; // Admin-approved deduction amount

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
    this.requestType = 'Pause',
    this.requestedAmount,
    this.approvedAmount,
  });

  bool get isFlexible => requestType.trim().toLowerCase() == 'flexible' || (requestedAmount != null && requestedAmount! > 0);
  bool get isFullPause => !isFlexible;

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
      'request_type': requestType,
      if (requestedAmount != null) 'requested_amount': requestedAmount,
      if (approvedAmount != null) 'approved_amount': approvedAmount,
    };
  }

  factory LoanEmiPauseRequest.fromMap(Map<String, dynamic> map) {
    final rawAmount = (map['requested_amount'] as num?)?.toDouble();
    final rawType = map['request_type'] as String?;
    final resolvedType = rawType != null && rawType.isNotEmpty
        ? rawType
        : (rawAmount != null && rawAmount > 0 ? 'Flexible' : 'Pause');

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
      requestType: resolvedType,
      requestedAmount: rawAmount,
      approvedAmount: (map['approved_amount'] as num?)?.toDouble(),
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
    String? requestType,
    double? requestedAmount,
    double? approvedAmount,
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
      requestType: requestType ?? this.requestType,
      requestedAmount: requestedAmount ?? this.requestedAmount,
      approvedAmount: approvedAmount ?? this.approvedAmount,
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
  final int originalInstallments; // Original agreed tenure
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

  // ── Admin-Controlled Extension Fields ──
  final int extensionInstallments; // Number of additional months approved by admin
  final double extensionEmiAmount; // Approved EMI per month for the extension
  final String extensionStartMonth; // First month of the extension
  final String extensionApprovedBy; // Admin who approved the extension
  final String extensionApprovalDate; // Date extension was approved
  final String extensionRemarks; // Optional notes/remarks for the extension
  final double extensionInterestRate; // Optional interest/markup % applied during extension (default 0.0)

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
    this.originalInstallments = 0,
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
    this.extensionInstallments = 0,
    this.extensionEmiAmount = 0.0,
    this.extensionStartMonth = '',
    this.extensionApprovedBy = '',
    this.extensionApprovalDate = '',
    this.extensionRemarks = '',
    this.extensionInterestRate = 0.0,
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
  /// = Monthly Principal + Full-Month Interest for that month.
  /// For admin-approved extension months, uses extensionEmiAmount with final installment rounding.
  double emiForInstallment(
    int index, {
    int payrollStartDay = 20,
    int payrollEndDay = 20,
  }) {
    if (index >= baseInstallments && extensionInstallments > 0) {
      if (extensionEmiAmount > 0) {
        // Final installment clears exact remaining balance without overcharging or leaving rounding residue
        if (index == totalTenureMonths - 1 && actualRemainingBalance > 0) {
          if (actualRemainingBalance <= extensionEmiAmount * 1.5) {
            return actualRemainingBalance;
          }
        }
        return extensionEmiAmount;
      }
    }
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

  /// Calculate month string at offset from firstDeductionMonth
  static String getMonthAtOffset(String startMonth, int offset) {
    if (startMonth.isEmpty) return '';
    final parts = startMonth.trim().split(' ');
    if (parts.length < 2) return startMonth;
    final monthName = parts[0];
    final year = int.tryParse(parts[1]) ?? DateTime.now().year;

    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final startIndex = months.indexOf(monthName);
    if (startIndex == -1) return startMonth;

    final totalMonths = startIndex + offset;
    final finalMonthIndex = totalMonths % 12;
    final finalYear = year + (totalMonths ~/ 12);
    return '${months[finalMonthIndex]} $finalYear';
  }

  /// Base installment count representing original agreed duration
  int get baseInstallments => originalInstallments > 0 ? originalInstallments : installments;

  /// Original last deduction month before any admin extension
  String get originalLastDeductionMonth {
    if (firstDeductionMonth.isEmpty || baseInstallments <= 0) return lastDeductionMonth;
    return getMonthAtOffset(firstDeductionMonth, baseInstallments - 1);
  }

  /// Whether the original agreed tenure has elapsed / finished
  bool get isOriginalTenureFinished {
    if (firstDeductionMonth.isEmpty || baseInstallments <= 0) return false;
    final distinctMonthsPaid = repayments.map((r) => r.month.trim().toLowerCase()).toSet().length;
    if (distinctMonthsPaid >= baseInstallments || repayments.length >= baseInstallments || payrollRepayments.length >= baseInstallments || paidInstallments >= baseInstallments) {
      return true;
    }
    final now = DateTime.now();
    final (lastYear, lastMonth) = parseMonthYear(originalLastDeductionMonth);
    if (now.year > lastYear || (now.year == lastYear && now.month > lastMonth)) {
      return true;
    }
    return false;
  }

  /// Whether the loan is awaiting Admin extension decision:
  /// original duration finished with pending balance, but admin hasn't configured extension yet.
  bool get isAwaitingExtensionDecision {
    if (actualRemainingBalance <= 0.01 || status == 'Closed' || status == 'Rejected' || status == 'Pending') {
      return false;
    }
    if (extensionInstallments > 0) {
      return false;
    }
    return isOriginalTenureFinished;
  }

  /// Accumulated unpaid deficit from partial deductions during original tenure
  double get accumulatedUnpaidDeficit {
    if (repayments.isEmpty) return 0.0;
    double deficit = 0.0;
    for (int i = 0; i < baseInstallments; i++) {
      final month = getMonthAtOffset(firstDeductionMonth, i);
      final monthPaid = getTotalRepaymentsForMonth(month);
      final monthEmi = emiForInstallment(i);
      if (monthPaid > 0 && monthPaid < monthEmi) {
        deficit += (monthEmi - monthPaid);
      }
    }
    return deficit > actualRemainingBalance ? actualRemainingBalance : deficit;
  }

  /// Effective total installments (strictly controlled by baseInstallments + admin-approved extension)
  int get effectiveInstallments => totalTenureMonths;

  /// Total tenure in months taking into account admin-approved extension
  int get totalTenureMonths {
    int count = baseInstallments + extensionInstallments;
    if (repayments.isNotEmpty && repayments.length > count) {
      count = repayments.length;
    }
    return count;
  }

  /// Check if total tenure has been extended beyond original duration by admin
  bool get isTenureExtended => extensionInstallments > 0;

  /// Number of extra months added to the loan by admin
  int get extendedMonthsCount => extensionInstallments;

  /// Effective last deduction month (extended if approved by admin)
  String get effectiveLastDeductionMonth {
    final months = scheduleMonths;
    if (months.isNotEmpty) return months.last;
    return lastDeductionMonth;
  }

  /// Paid installments count (accounts for accelerated payments and direct prepayments)
  int get paidInstallments {
    final total = totalTenureMonths;
    if (emiAmount <= 0) return repayments.length;
    final coveredByAmount = (totalPaid / emiAmount).floor();
    final effective = coveredByAmount > repayments.length ? coveredByAmount : repayments.length;
    return effective > total ? total : effective;
  }

  /// Direct payments recorded outside payroll
  List<LoanRepayment> get directRepayments =>
      repayments.where((r) => r.isDirectPayment).toList();

  /// Payroll deduction repayments
  List<LoanRepayment> get payrollRepayments =>
      repayments.where((r) => !r.isDirectPayment).toList();

  /// Total direct payments paid directly to admin
  double get totalDirectPaid =>
      directRepayments.fold<double>(0.0, (sum, r) => sum + r.amount);

  /// Direct payments for a specific month
  double getDirectPaymentsForMonth(String month) {
    final norm = month.trim().toLowerCase();
    return repayments
        .where((r) => r.month.trim().toLowerCase() == norm && r.isDirectPayment)
        .fold<double>(0.0, (sum, r) => sum + r.amount);
  }

  /// Total repayments for a specific month (direct + payroll)
  double getTotalRepaymentsForMonth(String month) {
    final norm = month.trim().toLowerCase();
    return repayments
        .where((r) => r.month.trim().toLowerCase() == norm)
        .fold<double>(0.0, (sum, r) => sum + r.amount);
  }

  /// Remaining installments count
  int get remainingInstallments {
    final rem = totalTenureMonths - paidInstallments;
    return rem < 0 ? 0 : rem;
  }

  /// Generate chronological list of deduction months (dynamically extended if tenure is prolonged)
  List<String> get scheduleMonths {
    final count = totalTenureMonths;
    if (count <= 0 || firstDeductionMonth.isEmpty) return [];
    final result = <String>[];
    for (int i = 0; i < count; i++) {
      result.add(getMonthAtOffset(firstDeductionMonth, i));
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

  /// Get pause/flexible request for a specific month
  LoanEmiPauseRequest? getPauseRequestForMonth(String month) {
    final norm = month.trim().toLowerCase();
    return pauseRequests.where((r) => r.month.trim().toLowerCase() == norm).firstOrNull;
  }

  /// Check if a given month has an approved full EMI pause (0 deduction)
  bool isMonthPaused(String month) {
    final req = getPauseRequestForMonth(month);
    return req != null && req.status.trim().toLowerCase() == 'approved' && req.isFullPause;
  }

  /// Get approved flexible EMI request for a specific month (partial deduction)
  LoanEmiPauseRequest? getApprovedFlexibleRequestForMonth(String month) {
    final norm = month.trim().toLowerCase();
    return pauseRequests.where((r) =>
        r.month.trim().toLowerCase() == norm &&
        r.status.trim().toLowerCase() == 'approved' &&
        r.isFlexible
    ).firstOrNull;
  }

  /// Get unrecovered approved pause request from an earlier month
  LoanEmiPauseRequest? getUnrecoveredDeferredRequestBefore(String currentMonth) {
    final (cYear, cMonth) = parseMonthYear(currentMonth);
    for (final req in pauseRequests) {
      if (req.status.trim().toLowerCase() == 'approved' && req.isFullPause && !req.isRecovered) {
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
      'original_installments': originalInstallments > 0 ? originalInstallments : installments,
      'emi_amount': emiAmount,
      'first_deduction_month': firstDeductionMonth,
      'last_deduction_month': effectiveLastDeductionMonth,
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
      'extension_installments': extensionInstallments,
      'extension_emi_amount': extensionEmiAmount,
      'extension_start_month': extensionStartMonth,
      'extension_approved_by': extensionApprovedBy,
      'extension_approval_date': extensionApprovalDate,
      'extension_remarks': extensionRemarks,
      'extension_interest_rate': extensionInterestRate,
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
      originalInstallments: map['original_installments'] as int? ?? (map['installments'] as int? ?? 0),
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
      extensionInstallments: map['extension_installments'] as int? ?? 0,
      extensionEmiAmount: (map['extension_emi_amount'] as num?)?.toDouble() ?? 0.0,
      extensionStartMonth: map['extension_start_month'] as String? ?? '',
      extensionApprovedBy: map['extension_approved_by'] as String? ?? '',
      extensionApprovalDate: map['extension_approval_date'] as String? ?? '',
      extensionRemarks: map['extension_remarks'] as String? ?? '',
      extensionInterestRate: (map['extension_interest_rate'] as num?)?.toDouble() ?? 0.0,
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
    int? originalInstallments,
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
    int? extensionInstallments,
    double? extensionEmiAmount,
    String? extensionStartMonth,
    String? extensionApprovedBy,
    String? extensionApprovalDate,
    String? extensionRemarks,
    double? extensionInterestRate,
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
      originalInstallments: originalInstallments ?? this.originalInstallments,
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
      extensionInstallments: extensionInstallments ?? this.extensionInstallments,
      extensionEmiAmount: extensionEmiAmount ?? this.extensionEmiAmount,
      extensionStartMonth: extensionStartMonth ?? this.extensionStartMonth,
      extensionApprovedBy: extensionApprovedBy ?? this.extensionApprovedBy,
      extensionApprovalDate: extensionApprovalDate ?? this.extensionApprovalDate,
      extensionRemarks: extensionRemarks ?? this.extensionRemarks,
      extensionInterestRate: extensionInterestRate ?? this.extensionInterestRate,
    );
  }
}
