import '../../employee/domain/employee.dart';
import '../../organization/domain/organization.dart';
import 'payroll.dart';

/// Single unified row representation for payroll exports and reports.
class PayrollReportRow {
  // A. Employee Information
  final String employeeId;
  final String employeeName;
  final String organization;
  final String department;
  final String payrollMonth;

  // B. Attendance (Always computed from actual attendance data)
  final int presentDays;
  final int lateDays;
  final double lopHours;
  final int leaveDays;
  final int absentDays;
  final int weeklyOff;
  final int workingDays;

  // C. Earnings
  final double basic;
  final double hra;
  final double educationAllowance;
  final double specialAllowance;
  final double travelAllowance;
  final double otherAllowance;
  final double incentive;
  final double othersEarning;
  final double bonus;
  final double ot;

  // D. Deductions
  final double pf;
  final double tax; // TDS
  final double esi;
  final double salaryAdvance;
  final double othersDeduction;
  final double staffWelfare;
  final double lopDeduction;
  final double companyLoan;

  // E. Final Totals
  final double grossSalary;
  final double totalDeductions;
  final double netSalary;

  // Status
  final String status;

  const PayrollReportRow({
    required this.employeeId,
    required this.employeeName,
    required this.organization,
    required this.department,
    required this.payrollMonth,
    required this.presentDays,
    required this.lateDays,
    required this.lopHours,
    required this.leaveDays,
    required this.absentDays,
    required this.weeklyOff,
    required this.workingDays,
    required this.basic,
    required this.hra,
    required this.educationAllowance,
    required this.specialAllowance,
    required this.travelAllowance,
    required this.otherAllowance,
    required this.incentive,
    required this.othersEarning,
    required this.bonus,
    required this.ot,
    required this.pf,
    required this.tax,
    required this.esi,
    required this.salaryAdvance,
    required this.othersDeduction,
    required this.staffWelfare,
    required this.lopDeduction,
    required this.companyLoan,
    required this.grossSalary,
    required this.totalDeductions,
    required this.netSalary,
    required this.status,
  });

  /// Factory creating a report row from Employee master and calculated PayrollRecord
  factory PayrollReportRow.fromEmployeeAndRecord({
    required Employee employee,
    required PayrollRecord? record,
    required String organizationName,
    required String departmentName,
    required String month,
  }) {
    final empIdStr = employee.employeeId.isNotEmpty
        ? employee.employeeId
        : (employee.id > 0 ? 'EMP${employee.id}' : '-');
    final empNameStr = record?.employeeName.isNotEmpty == true
        ? record!.employeeName
        : employee.fullName;

    if (record != null) {
      final totalGross = record.basicPay +
          record.hra +
          record.educationAllowance +
          record.specialAllowance +
          record.travelAllowance +
          record.otherAllowance +
          record.incentive +
          record.othersEarning +
          record.cumulativeIncentive +
          record.bonus +
          record.ot;

      final totalDed = record.pf +
          record.tax +
          record.esi +
          record.lop +
          record.companyLoan +
          record.salaryAdvance +
          record.othersDeduction +
          record.staffWelfareContribution +
          record.greeting;

      final dailyReqHours = employee.requiredWorkingHours > 0 ? employee.requiredWorkingHours : 9.0;
      final paidLeaveHours = record.leaveDays * dailyReqHours;
      final finalLopHours = record.lop > 0
          ? (record.totalShortfallHours - paidLeaveHours).clamp(0.0, 9999.0)
          : 0.0;

      return PayrollReportRow(
        employeeId: empIdStr,
        employeeName: empNameStr,
        organization: organizationName,
        department: record.department.isNotEmpty
            ? record.department
            : (employee.department.isNotEmpty ? employee.department : departmentName),
        payrollMonth: month,
        presentDays: record.presentDays,
        lateDays: record.lateDays,
        lopHours: double.parse(finalLopHours.toStringAsFixed(1)),
        leaveDays: record.leaveDays,
        absentDays: record.absentDays,
        weeklyOff: record.weeklyOffCount,
        workingDays: record.totalWorkingDays > 0 ? record.totalWorkingDays : 26,
        basic: record.basicPay,
        hra: record.hra,
        educationAllowance: record.educationAllowance,
        specialAllowance: record.specialAllowance,
        travelAllowance: record.travelAllowance,
        otherAllowance: record.otherAllowance,
        incentive: record.incentive,
        othersEarning: record.othersEarning,
        bonus: record.bonus,
        ot: record.ot,
        pf: record.pf,
        tax: record.tax,
        esi: record.esi,
        salaryAdvance: record.salaryAdvance,
        othersDeduction: record.othersDeduction,
        staffWelfare: record.staffWelfareContribution,
        lopDeduction: record.lop,
        companyLoan: record.companyLoan,
        grossSalary: double.parse(totalGross.toStringAsFixed(2)),
        totalDeductions: double.parse(totalDed.toStringAsFixed(2)),
        netSalary: record.netSalary,
        status: record.status,
      );
    }

    // If payroll not yet generated, display employee's master salary baseline
    final basic = (employee.salaryBasic as num?)?.toDouble() ?? 0.0;
    final hra = (employee.salaryHra as num?)?.toDouble() ?? 0.0;
    final edu = (employee.salaryEducationAllowance as num?)?.toDouble() ?? 0.0;
    final special = (employee.salarySpecialAllowance as num?)?.toDouble() ?? 0.0;
    final travel = (employee.salaryTravelAllowance as num?)?.toDouble() ?? 0.0;
    final otherAllow = (employee.salaryOtherAllowance as num?)?.toDouble() ?? 0.0;
    final gross = basic + hra + edu + special + travel + otherAllow;
    final pf = (employee.salaryPf as num?)?.toDouble() ?? 0.0;
    final tax = (employee.salaryTax as num?)?.toDouble() ?? 0.0;
    final esi = (employee.salaryEsi as num?)?.toDouble() ?? 0.0;
    final totalDed = pf + tax + esi;
    final net = (gross - totalDed).clamp(0.0, double.infinity);

    return PayrollReportRow(
      employeeId: empIdStr,
      employeeName: empNameStr,
      organization: organizationName,
      department: departmentName,
      payrollMonth: month,
      presentDays: 0,
      lateDays: 0,
      lopHours: 0.0,
      leaveDays: 0,
      absentDays: 0,
      weeklyOff: 0,
      workingDays: 26,
      basic: basic,
      hra: hra,
      educationAllowance: edu,
      specialAllowance: special,
      travelAllowance: travel,
      otherAllowance: otherAllow,
      incentive: 0.0,
      othersEarning: 0.0,
      bonus: 0.0,
      ot: 0.0,
      pf: pf,
      tax: tax,
      esi: esi,
      salaryAdvance: 0.0,
      othersDeduction: 0.0,
      staffWelfare: 0.0,
      lopDeduction: 0.0,
      companyLoan: 0.0,
      grossSalary: double.parse(gross.toStringAsFixed(2)),
      totalDeductions: double.parse(totalDed.toStringAsFixed(2)),
      netSalary: double.parse(net.toStringAsFixed(2)),
      status: 'Not Generated',
    );
  }
}

/// Unified Payroll Report Dataset encompassing all rows and summary metadata.
class PayrollReportDataset {
  final String organizationName;
  final String departmentName;
  final String payrollMonth;
  final List<PayrollReportRow> rows;

  const PayrollReportDataset({
    required this.organizationName,
    required this.departmentName,
    required this.payrollMonth,
    required this.rows,
  });

  int get totalEmployees => rows.length;

  double get grandTotalGross =>
      rows.fold(0.0, (sum, r) => sum + r.grossSalary);

  double get grandTotalDeductions =>
      rows.fold(0.0, (sum, r) => sum + r.totalDeductions);

  double get grandTotalNet =>
      rows.fold(0.0, (sum, r) => sum + r.netSalary);

  /// Builds a unified dataset from filtered employees and records
  factory PayrollReportDataset.build({
    required Organization organization,
    required String department,
    required String month,
    required List<Employee> employees,
    required List<PayrollRecord> records,
  }) {
    final rows = <PayrollReportRow>[];
    for (final emp in employees) {
      final record = records.where((r) => r.employeeId == emp.id).firstOrNull;
      rows.add(PayrollReportRow.fromEmployeeAndRecord(
        employee: emp,
        record: record,
        organizationName: organization.name,
        departmentName: department,
        month: month,
      ));
    }

    return PayrollReportDataset(
      organizationName: organization.name,
      departmentName: department,
      payrollMonth: month,
      rows: rows,
    );
  }

  static const List<String> columnHeaders = [
    // Employee Info
    'Employee ID',
    'Employee Name',
    'Organisation',
    'Department',
    'Payroll Month',
    // Attendance
    'Present Days',
    'Late Days',
    'LOP Hours',
    'Leave Days',
    'Absent Days',
    'Weekly Off',
    'Working Days',
    // Earnings
    'Basic',
    'HRA',
    'Education Allowance',
    'Special Allowance',
    'Travel Allowance',
    'Other Allowance',
    'Incentive',
    'Others Earning',
    'Bonus',
    'OT',
    // Deductions
    'PF',
    'TDS',
    'ESI',
    'Salary Advance',
    'Others Deduction',
    'Staff Welfare',
    'LOP Deduction',
    'Company Loan',
    // Final Totals
    'Gross Salary',
    'Total Deductions',
    'Net Salary',
    'Status',
  ];

  List<dynamic> rowToCells(PayrollReportRow row) {
    return [
      row.employeeId,
      row.employeeName,
      row.organization,
      row.department,
      row.payrollMonth,
      row.presentDays,
      row.lateDays,
      row.lopHours.toStringAsFixed(1),
      row.leaveDays,
      row.absentDays,
      row.weeklyOff,
      row.workingDays,
      row.basic.toStringAsFixed(2),
      row.hra.toStringAsFixed(2),
      row.educationAllowance.toStringAsFixed(2),
      row.specialAllowance.toStringAsFixed(2),
      row.travelAllowance.toStringAsFixed(2),
      row.otherAllowance.toStringAsFixed(2),
      row.incentive.toStringAsFixed(2),
      row.othersEarning.toStringAsFixed(2),
      row.bonus.toStringAsFixed(2),
      row.ot.toStringAsFixed(2),
      row.pf.toStringAsFixed(2),
      row.tax.toStringAsFixed(2),
      row.esi.toStringAsFixed(2),
      row.salaryAdvance.toStringAsFixed(2),
      row.othersDeduction.toStringAsFixed(2),
      row.staffWelfare.toStringAsFixed(2),
      row.lopDeduction.toStringAsFixed(2),
      row.companyLoan.toStringAsFixed(2),
      row.grossSalary.toStringAsFixed(2),
      row.totalDeductions.toStringAsFixed(2),
      row.netSalary.toStringAsFixed(2),
      row.status,
    ];
  }
}
