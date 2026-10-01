import '../../attendance/domain/attendance_record.dart';
import '../../attendance/domain/monthly_attendance_result.dart';
import '../../employee/domain/employee.dart';
import '../../incentive/domain/incentive_request.dart';
import '../../leave/domain/leave_request.dart';
import '../../loan/domain/employee_loan.dart';
import '../../on_duty/domain/on_duty_assignment.dart';
import '../../permission/domain/permission_request.dart';
import '../domain/payroll.dart';
import '../domain/payroll_input_override.dart';

class PayrollCalculationService {
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      if ((value as dynamic).toDate != null) {
        return (value as dynamic).toDate() as DateTime;
      }
    } catch (_) {}
    final str = value.toString().trim();
    if (str.isEmpty) return null;
    final iso = DateTime.tryParse(str);
    if (iso != null) return iso;
    final dmyMatch = RegExp(r'^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})').firstMatch(str);
    if (dmyMatch != null) {
      final day = int.tryParse(dmyMatch.group(1)!);
      final month = int.tryParse(dmyMatch.group(2)!);
      final year = int.tryParse(dmyMatch.group(3)!);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }
    return null;
  }

  static ({int year, int monthNum}) parseMonthYear(String month) {
    final now = DateTime.now();
    int year = now.year;
    int monthNum = now.month;

    final parts = month.trim().split(' ');
    if (parts.length >= 2) {
      final yearParsed = int.tryParse(parts[1]);
      if (yearParsed != null) year = yearParsed;
      final monthMap = {
        'january': 1, 'jan': 1, 'february': 2, 'feb': 2, 'march': 3, 'mar': 3,
        'april': 4, 'apr': 4, 'may': 5, 'june': 6, 'jun': 6, 'july': 7, 'jul': 7,
        'august': 8, 'aug': 8, 'september': 9, 'sep': 9, 'october': 10, 'oct': 10,
        'november': 11, 'nov': 11, 'december': 12, 'dec': 12
      };
      final m = monthMap[parts[0].toLowerCase()];
      if (m != null) monthNum = m;
    }
    return (year: year, monthNum: monthNum);
  }

  static ({double cycleIncentive, double cumulativeTotal}) calculateIncentives({
    required Employee employee,
    required List<IncentiveRequest> requests,
    required PayrollPeriod period,
  }) {
    final normEmpName = employee.fullName.trim().toLowerCase();
    final normFirstName = employee.firstName.trim().toLowerCase();
    final normEmpCode = employee.employeeId.trim().toLowerCase().replaceAll('-', '').replaceAll(' ', '');

    final approved = requests.where((req) {
      if (req.status.trim().toLowerCase() != 'approved') return false;

      final reqName = req.employeeName.trim().toLowerCase();
      final reqCode = reqName.replaceAll('-', '').replaceAll(' ', '');

      if (req.employeeId != null && req.employeeId == employee.id) return true;
      if (normEmpName.isNotEmpty && (reqName == normEmpName || reqName.contains(normEmpName) || normEmpName.contains(reqName))) return true;
      if (normFirstName.isNotEmpty && reqName.contains(normFirstName)) return true;
      if (normEmpCode.isNotEmpty && (reqCode == normEmpCode || reqCode.contains(normEmpCode) || normEmpCode.contains(reqCode))) return true;

      return false;
    }).toList();

    double cycleIncentive = 0.0;
    double cumulativeTotal = 0.0;

    final startOnly = DateTime(period.startDate.year, period.startDate.month, period.startDate.day);
    final endOnly = DateTime(period.endDateExclusive.year, period.endDateExclusive.month, period.endDateExclusive.day);

    for (final req in approved) {
      final amt = req.approvedAmount ?? req.amount;
      final dt = _parseDateTime(req.createdAt);
      if (dt == null) {
        cycleIncentive += amt;
        cumulativeTotal += amt;
        continue;
      }
      final localDt = dt.toLocal();
      final dateOnly = DateTime(localDt.year, localDt.month, localDt.day);

      // Check if inside cycle
      final inCycle = !dateOnly.isBefore(startOnly) && dateOnly.isBefore(endOnly);
      if (inCycle) {
        cycleIncentive += amt;
      }

      // Check if up to end of cycle for cumulative
      if (dateOnly.isBefore(endOnly)) {
        cumulativeTotal += amt;
      }
    }

    return (cycleIncentive: cycleIncentive, cumulativeTotal: cumulativeTotal);
  }

  static ({double emiAmount, String loanDescription}) calculateLoanEmi({
    required EmployeeLoan? loan,
    required String month,
    required PayrollSettings settings,
  }) {
    if (loan == null) {
      return (emiAmount: 0.0, loanDescription: '');
    }

    final pStart = settings.payrollStartDay;
    final pEnd = settings.payrollEndDay;

    final monthIdx = loan.scheduleMonths.indexWhere((m) => m.trim().toLowerCase() == month.trim().toLowerCase());
    final currentMonthEmi = monthIdx != -1
        ? loan.emiForInstallment(monthIdx, payrollStartDay: pStart, payrollEndDay: pEnd)
        : (loan.interestRate > 0 ? loan.emiForInstallment(loan.paidInstallments, payrollStartDay: pStart, payrollEndDay: pEnd) : loan.emiAmount);

    final activeDays = monthIdx != -1 ? loan.activeDaysForInstallment(monthIdx, payrollStartDay: pStart, payrollEndDay: pEnd) : 30;
    final cycleDays = monthIdx != -1 ? loan.cycleDaysForInstallment(monthIdx, payrollStartDay: pStart, payrollEndDay: pEnd) : 30;

    String installmentNote = monthIdx != -1
        ? 'Installment ${monthIdx + 1} of ${loan.installments} (${loan.loanId})'
        : (loan.loanId.isNotEmpty ? 'Loan EMI (${loan.loanId})' : 'Loan EMI');

    if (monthIdx == 0 && activeDays < cycleDays && loan.interestRate > 0) {
      installmentNote += ' • Pro-rata $activeDays/$cycleDays days';
    }

    return (emiAmount: currentMonthEmi, loanDescription: installmentNote);
  }

  /// Single Source of Truth for Employee Payroll Calculation
  static PayrollRecord calculatePayrollRecord({
    required Employee employee,
    required String month,
    required PayrollSettings settings,
    required List<AttendanceRecord> attendanceRecords,
    List<LeaveRequest>? leaves,
    List<OnDutyAssignment>? onDutyAssignments,
    List<String>? holidays,
    List<PermissionRequest>? permissions,
    List<IncentiveRequest>? incentives,
    EmployeeLoan? activeLoan,
    PayrollInputOverride? overrideInput,
    double manualOthersEarning = 0.0,
    double manualBonus = 0.0,
    double manualOt = 0.0,
    String carryForward = '-',
    double manualSalaryAdvance = 0.0,
    String advanceDescription = '',
    double manualOthersDeduction = 0.0,
    double manualStaffWelfare = 0.0,
    String status = 'Processed',
  }) {
    final parsed = parseMonthYear(month);
    final period = settings.getPayrollPeriod(parsed.year, parsed.monthNum);

    // 1. Monthly Attendance Calculation
    final attendanceResult = MonthlyAttendanceCalculator.calculate(
      employee: employee,
      year: parsed.year,
      month: parsed.monthNum,
      records: attendanceRecords,
      leaves: leaves,
      onDutyAssignments: onDutyAssignments,
      holidays: holidays,
      permissions: permissions,
      startDate: period.startDate,
      endDateExclusive: period.endDateExclusive,
    );

    // 2. Standard CTC & Allowances (supports non-persistent upload overrides)
    final basic = overrideInput?.basic ?? (employee.salaryBasic as num?)?.toDouble() ?? 0.0;
    final hra = overrideInput?.hra ?? (employee.salaryHra as num?)?.toDouble() ?? 0.0;
    final edu = overrideInput?.educationAllowance ?? (employee.salaryEducationAllowance as num?)?.toDouble() ?? 0.0;
    final special = overrideInput?.specialAllowance ?? (employee.salarySpecialAllowance as num?)?.toDouble() ?? 0.0;
    final travel = overrideInput?.travelAllowance ?? (employee.salaryTravelAllowance as num?)?.toDouble() ?? 0.0;
    final otherAllow = overrideInput?.otherAllowance ?? (employee.salaryOtherAllowance as num?)?.toDouble() ?? 0.0;
    final standardGross = employee.salaryTotalCtc > 0
        ? employee.salaryTotalCtc
        : (basic + hra + edu + special + travel + otherAllow);

    // 3. Loss of Pay (LOP) & Date of Joining (DOJ) Pro-rata
    final beforeJoiningDays = attendanceResult.beforeJoiningCount;
    final totalDaysInCycle = attendanceResult.totalDaysInMonth;
    final eligibleDays = (totalDaysInCycle - beforeJoiningDays).clamp(0, totalDaysInCycle);

    final scheduledWorkingDays = settings.workingDaysInMonth > 0
        ? settings.workingDaysInMonth
        : (attendanceResult.totalWorkingDays > 0 ? attendanceResult.totalWorkingDays.toDouble() : 26.0);
    final dailyRequiredHours = settings.standardDailyWorkingHours > 0
        ? settings.standardDailyWorkingHours
        : (employee.requiredWorkingHours > 0 ? employee.requiredWorkingHours : 9.0);

    final scheduledHours = scheduledWorkingDays * dailyRequiredHours;
    final hourlyRate = scheduledHours > 0 ? (standardGross / scheduledHours) : 0.0;

    final perDaySalary = scheduledWorkingDays > 0 ? (standardGross / scheduledWorkingDays) : 0.0;
    final baseEligibleGross = beforeJoiningDays > 0
        ? (perDaySalary * eligibleDays).clamp(0.0, standardGross)
        : standardGross;

    final rawShortfall = attendanceResult.totalShortfallHours;
    final paidLeaveHours = attendanceResult.onLeaveCount * dailyRequiredHours;
    final lopHours = (rawShortfall - paidLeaveHours).clamp(0.0, 9999.0);
    final calculatedLopAmount = double.parse((lopHours * hourlyRate).toStringAsFixed(2));
    final earnedGross = (baseEligibleGross - calculatedLopAmount).clamp(0.0, standardGross);

    final earningRatio = (beforeJoiningDays > 0 && standardGross > 0)
        ? (earnedGross / standardGross)
        : 1.0;

    final effectiveBasic = beforeJoiningDays > 0 ? (basic * earningRatio) : basic;
    final effectiveHra = beforeJoiningDays > 0 ? (hra * earningRatio) : hra;
    final effectiveEdu = beforeJoiningDays > 0 ? (edu * earningRatio) : edu;
    final effectiveSpecial = beforeJoiningDays > 0 ? (special * earningRatio) : special;
    final effectiveTravel = beforeJoiningDays > 0 ? (travel * earningRatio) : travel;
    final effectiveOther = beforeJoiningDays > 0 ? (otherAllow * earningRatio) : otherAllow;

    final standardPf = overrideInput?.pf ?? (employee.salaryPf as num?)?.toDouble() ?? 0.0;
    final effectivePf = beforeJoiningDays > 0 ? (earnedGross > 0 ? (standardPf * earningRatio) : 0.0) : standardPf;
    final tax = overrideInput?.tax ?? (employee.salaryTax as num?)?.toDouble() ?? 0.0;
    final esi = overrideInput?.esi ?? (employee.salaryEsi as num?)?.toDouble() ?? 0.0;

    // 4. Incentives
    final incentiveMetrics = calculateIncentives(
      employee: employee,
      requests: incentives ?? [],
      period: period,
    );
    final effectiveIncentive = overrideInput?.incentive ?? incentiveMetrics.cycleIncentive;
    final effectiveOthersEarning = overrideInput?.othersEarning ?? manualOthersEarning;
    final effectiveBonus = overrideInput?.bonus ?? manualBonus;
    final effectiveOt = overrideInput?.ot ?? manualOt;

    // 5. Loan EMI
    final loanMetrics = calculateLoanEmi(
      loan: activeLoan,
      month: month,
      settings: settings,
    );
    final effectiveSalaryAdvance = overrideInput?.salaryAdvance ?? manualSalaryAdvance;
    final effectiveOthersDeduction = overrideInput?.othersDeduction ?? manualOthersDeduction;
    final effectiveStaffWelfare = overrideInput?.staffWelfare ?? manualStaffWelfare;

    // 6. Net Salary Formula
    final gross = effectiveBasic + effectiveHra + effectiveEdu + effectiveSpecial + effectiveTravel + effectiveOther +
        effectiveIncentive + effectiveOthersEarning + effectiveBonus + effectiveOt;
    final totalDeductions = effectivePf + tax + esi + calculatedLopAmount + loanMetrics.emiAmount +
        effectiveSalaryAdvance + effectiveOthersDeduction + effectiveStaffWelfare;
    final netSalary = (gross - totalDeductions).clamp(0.0, double.infinity);

    // 7. Assemble Payroll Record
    final panNumber = employee.panNumber.isNotEmpty ? employee.panNumber : 'ANAPG6040R';
    final pfNumber = employee.pfNumber.isNotEmpty ? employee.pfNumber : '101325736568';
    final bankName = employee.bankName.isNotEmpty ? employee.bankName : 'Axis Bank';
    final bankAcctNo = employee.bankAccountNumber.isNotEmpty ? employee.bankAccountNumber : '920010047315532';
    final branch = employee.bankBranch.isNotEmpty ? employee.bankBranch : 'Ram Nagar Madipakkam';
    final ifscCode = employee.bankIfsc.isNotEmpty ? employee.bankIfsc : 'UTIB0003876';

    var record = PayrollRecord(
      id: 0,
      employeeId: employee.id,
      employeeName: employee.fullName,
      month: month,
      presentDays: attendanceResult.presentCount,
      lateDays: attendanceResult.lateCount,
      absentDays: attendanceResult.absentCount,
      leaveDays: attendanceResult.onLeaveCount,
      weeklyOffCount: attendanceResult.weeklyOffCount,

      designation: employee.designation,
      department: employee.department,
      emailId: employee.emailAddress,
      panNumber: panNumber,
      pfNumber: pfNumber,
      esiNumber: employee.esiNumber,
      bankName: bankName,
      bankAcctNo: bankAcctNo,
      branch: branch,
      ifscCode: ifscCode,

      basicPay: double.parse(effectiveBasic.toStringAsFixed(2)),
      hra: double.parse(effectiveHra.toStringAsFixed(2)),
      educationAllowance: double.parse(effectiveEdu.toStringAsFixed(2)),
      specialAllowance: double.parse(effectiveSpecial.toStringAsFixed(2)),
      travelAllowance: double.parse(effectiveTravel.toStringAsFixed(2)),
      otherAllowance: double.parse(effectiveOther.toStringAsFixed(2)),

      incentive: double.parse(effectiveIncentive.toStringAsFixed(2)),
      carryForward: carryForward,
      othersEarning: effectiveOthersEarning,
      cumulativeIncentive: double.parse(incentiveMetrics.cumulativeTotal.toStringAsFixed(2)),
      bonus: effectiveBonus,
      ot: effectiveOt,

      pf: double.parse(effectivePf.toStringAsFixed(2)),
      tax: double.parse(tax.toStringAsFixed(2)),
      esi: double.parse(esi.toStringAsFixed(2)),

      lop: calculatedLopAmount,
      companyLoan: double.parse(loanMetrics.emiAmount.toStringAsFixed(2)),
      loanDescription: loanMetrics.loanDescription,
      salaryAdvance: effectiveSalaryAdvance,
      advanceDescription: advanceDescription,
      othersDeduction: effectiveOthersDeduction,
      staffWelfareContribution: effectiveStaffWelfare,
      greeting: 0.0,

      netSalary: double.parse(netSalary.toStringAsFixed(2)),
      status: status,
      periodStartDate: period.startDateFormatted,
      periodEndDate: period.endDateFormatted,
      processingDate: period.processingDateFormatted,
      paymentDate: period.paymentDateFormatted,
    );

    return record.copyWithAttendanceResult(attendanceResult);
  }
}
