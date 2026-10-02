import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/layout/responsive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../employee/domain/employee.dart';
import '../../employee/providers/employee_providers.dart';
import '../../attendance/providers/attendance_providers.dart';
import '../../attendance/domain/attendance_record.dart';
import '../../attendance/domain/monthly_attendance_result.dart';
import '../domain/payroll.dart';
import '../domain/payroll_input_override.dart';
import '../providers/payroll_providers.dart';
import '../services/payroll_calculation_service.dart';
import '../../leave/domain/leave_request.dart';
import '../../leave/providers/leave_providers.dart';
import '../../loan/providers/loan_providers.dart';
import '../../on_duty/domain/on_duty_assignment.dart';
import '../../on_duty/providers/on_duty_providers.dart';
import '../../permission/domain/permission_request.dart';
import '../../permission/providers/permission_providers.dart';
import '../../incentive/providers/incentive_providers.dart';
import '../../incentive/domain/incentive_request.dart';
import '../../incentive/domain/incentive_payout_ledger.dart';
import '../../incentive/domain/incentive_settings.dart';

class GeneratePayrollScreen extends ConsumerStatefulWidget {
  const GeneratePayrollScreen({required this.employeeId, super.key});
  final int employeeId;

  @override
  ConsumerState<GeneratePayrollScreen> createState() => _GeneratePayrollScreenState();
}

class _GeneratePayrollScreenState extends ConsumerState<GeneratePayrollScreen> {
  int _currentStep = 0;

  // Earnings standard
  final _basicController = TextEditingController();
  final _hraController = TextEditingController();
  final _educationController = TextEditingController();
  final _specialController = TextEditingController();
  final _travelAllowanceController = TextEditingController();
  final _otherAllowanceController = TextEditingController();
  
  // Monthly Inputs (formerly Additional Components)
  final _incentiveController = TextEditingController();
  final _carryForwardController = TextEditingController();
  final _othersEarningController = TextEditingController();
  final _cumulativeIncentiveController = TextEditingController();
  final _bonusController = TextEditingController();
  final _otController = TextEditingController();

  // Deductions statutory
  final _pfController = TextEditingController();
  final _taxController = TextEditingController();
  final _esiController = TextEditingController();
  
  // Deductions other
  final _lopController = TextEditingController();
  final _companyLoanController = TextEditingController();
  final _salaryAdvanceController = TextEditingController();
  final _othersDeductionController = TextEditingController();
  final _staffWelfareController = TextEditingController();
  final _loanDescController = TextEditingController();
  final _advanceDescController = TextEditingController();

  double _netSalary = 0.0;
  bool _initialized = false;
  bool _isSavingDraft = false;
  bool _isSavingProcessed = false;

  // Attendance
  int _presentDays = 27;
  int _lateDays = 0;
  int _absentDays = 0;
  int _leaveDays = 3;
  int _weeklyOffDays = 0;
  int _totalDays = 30;
  double _lopHours = 0.0;
  double _hourlyRate = 0.0;
  double _scheduledHours = 0.0;
  MonthlyAttendanceResult? _attendanceResult;
  IncentiveCalculationResult? _incentiveResult;
  double? _lastCalculatedIncentive;
  double? _lastCalculatedCumulativeIncentive;


  @override
  void initState() {
    super.initState();
    // Recalculation listeners
    _basicController.addListener(_recalculate);
    _hraController.addListener(_recalculate);
    _educationController.addListener(_recalculate);
    _specialController.addListener(_recalculate);
    _travelAllowanceController.addListener(_recalculate);
    _otherAllowanceController.addListener(_recalculate);
    
    _incentiveController.addListener(_recalculate);
    _carryForwardController.addListener(_recalculate);
    _othersEarningController.addListener(_recalculate);
    _cumulativeIncentiveController.addListener(_recalculate);
    _bonusController.addListener(_recalculate);
    _otController.addListener(_recalculate);

    _pfController.addListener(_recalculate);
    _taxController.addListener(_recalculate);
    _esiController.addListener(_recalculate);

    _lopController.addListener(_recalculate);
    _companyLoanController.addListener(_recalculate);
    _salaryAdvanceController.addListener(_recalculate);
    _othersDeductionController.addListener(_recalculate);
    _staffWelfareController.addListener(_recalculate);
  }

  @override
  void dispose() {
    _basicController.dispose();
    _hraController.dispose();
    _educationController.dispose();
    _specialController.dispose();
    _travelAllowanceController.dispose();
    _otherAllowanceController.dispose();
    
    _incentiveController.dispose();
    _carryForwardController.dispose();
    _othersEarningController.dispose();
    _cumulativeIncentiveController.dispose();
    _bonusController.dispose();
    _otController.dispose();

    _pfController.dispose();
    _taxController.dispose();
    _esiController.dispose();

    _lopController.dispose();
    _companyLoanController.dispose();
    _salaryAdvanceController.dispose();
    _othersDeductionController.dispose();
    _staffWelfareController.dispose();
    _loanDescController.dispose();
    _advanceDescController.dispose();
    super.dispose();
  }

  void _initializeValues(
    dynamic employee,
    PayrollSettings settings,
    String selectedMonth, {
    PayrollInputOverride? overrideInput,
  }) {
    if (_initialized) return;
    _initialized = true;
    _totalDays = settings.workingDaysInMonth.toInt();

    // Use employee standard CTC details, overridden by uploaded input if available
    final basic = overrideInput?.basic ?? (employee.salaryBasic as num?)?.toDouble() ?? 0.0;
    final hra = overrideInput?.hra ?? (employee.salaryHra as num?)?.toDouble() ?? 0.0;
    final special = overrideInput?.specialAllowance ?? (employee.salarySpecialAllowance as num?)?.toDouble() ?? 0.0;
    final edu = overrideInput?.educationAllowance ?? (employee.salaryEducationAllowance as num?)?.toDouble() ?? 0.0;
    final travel = overrideInput?.travelAllowance ?? (employee.salaryTravelAllowance as num?)?.toDouble() ?? 0.0;
    final otherAllowance = overrideInput?.otherAllowance ?? (employee.salaryOtherAllowance as num?)?.toDouble() ?? 0.0;

    final pf = overrideInput?.pf ?? (employee.salaryPf as num?)?.toDouble() ?? 0.0;
    final tax = overrideInput?.tax ?? (employee.salaryTax as num?)?.toDouble() ?? 0.0;
    final esi = overrideInput?.esi ?? (employee.salaryEsi as num?)?.toDouble() ?? 0.0;

    _basicController.text = basic.toStringAsFixed(2);
    _hraController.text = hra.toStringAsFixed(2);
    _educationController.text = edu.toStringAsFixed(2);
    _specialController.text = special.toStringAsFixed(2);
    _travelAllowanceController.text = travel.toStringAsFixed(2);
    _otherAllowanceController.text = otherAllowance.toStringAsFixed(2);

    // Initial values for dynamic monthly inputs
    if (overrideInput?.incentive != null) {
      _incentiveController.text = overrideInput!.incentive!.toStringAsFixed(2);
    } else if (_incentiveController.text.isEmpty) {
      _incentiveController.text = '0.00';
    }

    if (_carryForwardController.text.isEmpty) _carryForwardController.text = '-';

    if (overrideInput?.othersEarning != null) {
      _othersEarningController.text = overrideInput!.othersEarning!.toStringAsFixed(2);
    } else if (_othersEarningController.text.isEmpty) {
      _othersEarningController.text = '0.00';
    }

    if (_cumulativeIncentiveController.text.isEmpty) _cumulativeIncentiveController.text = '0.00';

    if (overrideInput?.bonus != null) {
      _bonusController.text = overrideInput!.bonus!.toStringAsFixed(2);
    } else if (_bonusController.text.isEmpty) {
      _bonusController.text = '0.00';
    }

    if (overrideInput?.ot != null) {
      _otController.text = overrideInput!.ot!.toStringAsFixed(2);
    } else if (_otController.text.isEmpty) {
      _otController.text = '0.00';
    }

    _pfController.text = pf.toStringAsFixed(2);
    _taxController.text = tax.toStringAsFixed(2);
    _esiController.text = esi.toStringAsFixed(2);

    _lopController.text = '0.00';
    _companyLoanController.text = '0.00';
    _loanDescController.text = '';
    _salaryAdvanceController.text = overrideInput?.salaryAdvance?.toStringAsFixed(2) ?? '0.00';
    _othersDeductionController.text = overrideInput?.othersDeduction?.toStringAsFixed(2) ?? '0.00';
    _staffWelfareController.text = overrideInput?.staffWelfare?.toStringAsFixed(2) ?? '0.00';

    _recalculate();
    _loadActiveLoan(employee.id, selectedMonth, settings);
    _loadLopDetails(employee.id, selectedMonth, settings);
  }

  DateTime? _parseDateTime(dynamic value) {
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

  void _calculateIncentiveMetrics(
    Employee employee,
    List<IncentiveRequest> requests,
    String month,
    PayrollSettings settings, {
    IncentiveSettings incentiveSettings = const IncentiveSettings(),
    List<IncentivePayoutLedger>? ledgers,
    double? overrideIncentive,
  }) {
    final parsed = PayrollCalculationService.parseMonthYear(month);
    final period = settings.getPayrollPeriod(parsed.year, parsed.monthNum);

    final result = PayrollCalculationService.calculateIncentives(
      employee: employee,
      requests: requests,
      period: period,
      cycleMonth: month,
      incentiveSettings: incentiveSettings,
      ledgers: ledgers,
      overrideEarnedIncentive: overrideIncentive,
    );

    _incentiveResult = result;
    final effectiveIncentive = result.totalPayableIncentive;
    final currentIncentiveVal = double.tryParse(_incentiveController.text) ?? -1.0;
    final currentCumVal = double.tryParse(_cumulativeIncentiveController.text) ?? -1.0;

    if (currentIncentiveVal != effectiveIncentive || currentCumVal != result.cumulativeTotal) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _incentiveController.text = effectiveIncentive.toStringAsFixed(2);
            _cumulativeIncentiveController.text = result.cumulativeTotal.toStringAsFixed(2);
            if (result.currentDeferredIncentive > 0) {
              _carryForwardController.text = '₹${result.currentDeferredIncentive.toStringAsFixed(2)} (Deferred)';
            } else if (_carryForwardController.text.isEmpty) {
              _carryForwardController.text = '-';
            }
            _recalculate();
          });
        }
      });
    }
  }


  Future<void> _loadLopDetails(int employeeId, String month, PayrollSettings settings) async {
    try {
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

      final period = settings.getPayrollPeriod(year, monthNum);

      final salaryCalc = await ref.read(leaveRepositoryProvider).calculateSalaryAndLop(
        employeeId,
        year,
        monthNum,
        workingDays: settings.workingDaysInMonth.toInt(),
        settings: settings,
        startDate: period.startDate,
        endDateExclusive: period.endDateExclusive,
      );

      if (mounted) {
        setState(() {
          _lopController.text = salaryCalc.lopDeductionAmount.toStringAsFixed(2);
          if (salaryCalc.totalApprovedLeaveDays > 0) {
            _leaveDays = salaryCalc.totalApprovedLeaveDays.toInt();
          }
          _recalculate();
        });
      }
    } catch (_) {}
  }

  Future<void> _loadActiveLoan(int employeeId, String month, PayrollSettings settings) async {
    try {
      final loan = await ref.read(loanRepositoryProvider).getActiveLoanForEmployee(employeeId, month);
      if (loan != null && mounted) {
        final loanMetrics = PayrollCalculationService.calculateLoanEmi(
          loan: loan,
          month: month,
          settings: settings,
        );

        setState(() {
          _companyLoanController.text = loanMetrics.emiAmount.toStringAsFixed(2);
          _loanDescController.text = loanMetrics.loanDescription;
          _recalculate();
        });
      }
    } catch (_) {}
  }

  void _calculateAttendanceMetrics(
    Employee employee,
    dynamic attendanceRecords,
    String month,
    PayrollSettings settings, {
    List<LeaveRequest>? leaves,
    List<OnDutyAssignment>? onDutyAssignments,
    List<String>? holidays,
    List<PermissionRequest>? permissions,
  }) {
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

    final period = settings.getPayrollPeriod(year, monthNum);

    List<AttendanceRecord> records = [];
    if (attendanceRecords is List<AttendanceRecord>) {
      records = attendanceRecords;
    } else if (attendanceRecords is List) {
      for (final r in attendanceRecords) {
        if (r is AttendanceRecord) records.add(r);
      }
    }

    final result = MonthlyAttendanceCalculator.calculate(
      employee: employee,
      year: year,
      month: monthNum,
      records: records,
      leaves: leaves,
      onDutyAssignments: onDutyAssignments,
      holidays: holidays,
      permissions: permissions,
      startDate: period.startDate,
      endDateExclusive: period.endDateExclusive,
    );

    if (_attendanceResult != result) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final beforeJoiningDays = result.beforeJoiningCount;
          final totalDaysInCycle = result.totalDaysInMonth;
          final eligibleDays = (totalDaysInCycle - beforeJoiningDays).clamp(0, totalDaysInCycle);

          final basic = (employee.salaryBasic as num?)?.toDouble() ?? 0.0;
          final hra = (employee.salaryHra as num?)?.toDouble() ?? 0.0;
          final edu = (employee.salaryEducationAllowance as num?)?.toDouble() ?? 0.0;
          final special = (employee.salarySpecialAllowance as num?)?.toDouble() ?? 0.0;
          final travel = (employee.salaryTravelAllowance as num?)?.toDouble() ?? 0.0;
          final otherAllow = (employee.salaryOtherAllowance as num?)?.toDouble() ?? 0.0;
          final standardGross = employee.salaryTotalCtc > 0
              ? employee.salaryTotalCtc
              : (basic + hra + edu + special + travel + otherAllow);

          final scheduledWorkingDays = settings.workingDaysInMonth > 0
              ? settings.workingDaysInMonth
              : (result.totalWorkingDays > 0 ? result.totalWorkingDays.toDouble() : 26.0);
          final dailyRequiredHours = settings.standardDailyWorkingHours > 0
              ? settings.standardDailyWorkingHours
              : (employee.requiredWorkingHours > 0 ? employee.requiredWorkingHours : 9.0);

          final scheduledHours = scheduledWorkingDays * dailyRequiredHours;
          final hourlyRate = scheduledHours > 0 ? (standardGross / scheduledHours) : 0.0;

          // Pro-rata base gross for eligible days post-DOJ
          final perDaySalary = scheduledWorkingDays > 0 ? (standardGross / scheduledWorkingDays) : 0.0;
          final baseEligibleGross = beforeJoiningDays > 0
              ? (perDaySalary * eligibleDays).clamp(0.0, standardGross)
              : standardGross;

          final rawShortfall = result.totalShortfallHours;
          final paidLeaveHours = result.onLeaveCount * dailyRequiredHours;
          final lopHours = (rawShortfall - paidLeaveHours).clamp(0.0, 9999.0);
          final calculatedLopAmount = double.parse((lopHours * hourlyRate).toStringAsFixed(2));
          final earnedGross = (baseEligibleGross - calculatedLopAmount).clamp(0.0, standardGross);

          // If employee joined mid-month or has 0 earned days, pro-rate standard earnings and PF
          final earningRatio = (beforeJoiningDays > 0 && standardGross > 0)
              ? (earnedGross / standardGross)
              : 1.0;

          final proRatedBasic = basic * earningRatio;
          final proRatedHra = hra * earningRatio;
          final proRatedEdu = edu * earningRatio;
          final proRatedSpecial = special * earningRatio;
          final proRatedTravel = travel * earningRatio;
          final proRatedOther = otherAllow * earningRatio;

          final standardPf = (employee.salaryPf as num?)?.toDouble() ?? 0.0;
          final proRatedPf = earnedGross > 0 ? (standardPf * earningRatio) : 0.0;

          setState(() {
            _attendanceResult = result;
            _presentDays = result.presentCount;
            _lateDays = result.lateCount;
            _absentDays = result.absentCount;
            _leaveDays = result.onLeaveCount;
            _weeklyOffDays = result.weeklyOffCount;
            _totalDays = result.totalWorkingDays;
            _lopHours = lopHours;
            _hourlyRate = hourlyRate;
            _scheduledHours = scheduledHours;

            if (beforeJoiningDays > 0) {
              _basicController.text = proRatedBasic.toStringAsFixed(2);
              _hraController.text = proRatedHra.toStringAsFixed(2);
              _educationController.text = proRatedEdu.toStringAsFixed(2);
              _specialController.text = proRatedSpecial.toStringAsFixed(2);
              _travelAllowanceController.text = proRatedTravel.toStringAsFixed(2);
              _otherAllowanceController.text = proRatedOther.toStringAsFixed(2);
              _pfController.text = proRatedPf.toStringAsFixed(2);
              _lopController.text = calculatedLopAmount.toStringAsFixed(2);
            } else {
              _lopController.text = calculatedLopAmount.toStringAsFixed(2);
            }

            _recalculate();
          });
        }
      });
    }
  }

  void _recalculate() {
    final basic = double.tryParse(_basicController.text) ?? 0.0;
    final hra = double.tryParse(_hraController.text) ?? 0.0;
    final edu = double.tryParse(_educationController.text) ?? 0.0;
    final special = double.tryParse(_specialController.text) ?? 0.0;
    final travel = double.tryParse(_travelAllowanceController.text) ?? 0.0;
    final otherAllow = double.tryParse(_otherAllowanceController.text) ?? 0.0;
    
    final incentive = double.tryParse(_incentiveController.text) ?? 0.0;
    final otherEarn = double.tryParse(_othersEarningController.text) ?? 0.0;
    final bonus = double.tryParse(_bonusController.text) ?? 0.0;
    final ot = double.tryParse(_otController.text) ?? 0.0;

    final pf = double.tryParse(_pfController.text) ?? 0.0;
    final tax = double.tryParse(_taxController.text) ?? 0.0;
    final esi = double.tryParse(_esiController.text) ?? 0.0;

    final lop = double.tryParse(_lopController.text) ?? 0.0;
    final loan = double.tryParse(_companyLoanController.text) ?? 0.0;
    final advance = double.tryParse(_salaryAdvanceController.text) ?? 0.0;
    final otherDed = double.tryParse(_othersDeductionController.text) ?? 0.0;
    final welfare = double.tryParse(_staffWelfareController.text) ?? 0.0;

    final gross = basic + hra + edu + special + travel + otherAllow + incentive + otherEarn + bonus + ot;
    final deductions = pf + tax + esi + lop + loan + advance + otherDed + welfare;

    setState(() {
      _netSalary = gross - deductions;
      if (_netSalary < 0) _netSalary = 0;
    });
  }

  Future<void> _savePayroll(dynamic employee, String month, PayrollSettings settings, {String saveStatus = 'Processed'}) async {
    if (_isSavingDraft || _isSavingProcessed) return;

    setState(() {
      if (saveStatus == 'Draft') {
        _isSavingDraft = true;
      } else {
        _isSavingProcessed = true;
      }
    });

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

    final period = settings.getPayrollPeriod(year, monthNum);

    var record = PayrollRecord(
      id: 0,
      employeeId: employee.id,
      employeeName: employee.fullName,
      month: month,
      presentDays: _presentDays,
      lateDays: _lateDays,
      absentDays: _absentDays,
      leaveDays: _leaveDays,
      weeklyOffCount: _weeklyOffDays,
      
      designation: employee.designation,
      department: employee.department,
      emailId: employee.emailAddress,
      panNumber: employee.panNumber.isNotEmpty ? employee.panNumber : 'ANAPG6040R',
      pfNumber: employee.pfNumber.isNotEmpty ? employee.pfNumber : '101325736568',
      esiNumber: employee.esiNumber,
      bankName: employee.bankName.isNotEmpty ? employee.bankName : 'Axis Bank',
      bankAcctNo: employee.bankAccountNumber.isNotEmpty ? employee.bankAccountNumber : '920010047315532',
      branch: employee.bankBranch.isNotEmpty ? employee.bankBranch : 'Ram Nagar Madipakkam',
      ifscCode: employee.bankIfsc.isNotEmpty ? employee.bankIfsc : 'UTIB0003876',

      basicPay: double.tryParse(_basicController.text) ?? 0.0,
      hra: double.tryParse(_hraController.text) ?? 0.0,
      educationAllowance: double.tryParse(_educationController.text) ?? 0.0,
      specialAllowance: double.tryParse(_specialController.text) ?? 0.0,
      travelAllowance: double.tryParse(_travelAllowanceController.text) ?? 0.0,
      otherAllowance: double.tryParse(_otherAllowanceController.text) ?? 0.0,
      
      incentive: double.tryParse(_incentiveController.text) ?? 0.0,
      carryForward: _carryForwardController.text.isNotEmpty ? _carryForwardController.text : '-',
      othersEarning: double.tryParse(_othersEarningController.text) ?? 0.0,
      cumulativeIncentive: double.tryParse(_cumulativeIncentiveController.text) ?? 0.0,
      bonus: double.tryParse(_bonusController.text) ?? 0.0,
      ot: double.tryParse(_otController.text) ?? 0.0,
      
      pf: double.tryParse(_pfController.text) ?? 0.0,
      tax: double.tryParse(_taxController.text) ?? 0.0,
      esi: double.tryParse(_esiController.text) ?? 0.0,
      
      lop: double.tryParse(_lopController.text) ?? 0.0,
      companyLoan: double.tryParse(_companyLoanController.text) ?? 0.0,
      loanDescription: _loanDescController.text,
      salaryAdvance: double.tryParse(_salaryAdvanceController.text) ?? 0.0,
      advanceDescription: _advanceDescController.text,
      othersDeduction: double.tryParse(_othersDeductionController.text) ?? 0.0,
      staffWelfareContribution: double.tryParse(_staffWelfareController.text) ?? 0.0,
      greeting: 0.0,
      
      netSalary: _netSalary,
      status: saveStatus,
      periodStartDate: period.startDateFormatted,
      periodEndDate: period.endDateFormatted,
      processingDate: period.processingDateFormatted,
      paymentDate: period.paymentDateFormatted,
    );

    if (_attendanceResult != null) {
      record = record.copyWithAttendanceResult(_attendanceResult!);
    }

    try {
      await ref.read(payrollRepositoryProvider).savePayrollRecord(record);

      // Save / Update 3-Table Incentive Payout Ledger
      if (_incentiveResult != null) {
        if (_incentiveResult!.totalEarnedIncentive > 0) {
          final ledger = IncentivePayoutLedger(
            id: 'ledger_${employee.id}_${month.replaceAll(' ', '_')}',
            employeeId: employee.id,
            employeeName: employee.fullName,
            earnedCycle: month,
            totalEarnedAmount: _incentiveResult!.totalEarnedIncentive,
            immediateAmount: _incentiveResult!.immediateIncentive,
            deferredAmount: _incentiveResult!.currentDeferredIncentive,
            status: 'Pending', // Current cycle 50% deferred ALWAYS stays Pending
            createdAt: DateTime.now().toIso8601String(),
          );
          await ref.read(incentiveRepositoryProvider).savePayoutLedger(ledger);
        }

        // If this is a release cycle and there are eligible pending ledgers from previous cycles, mark them as Released
        if (saveStatus == 'Processed' && _incentiveResult!.eligibleLedgersToRelease.isNotEmpty) {
          final pendingIds = _incentiveResult!.eligibleLedgersToRelease
              .where((l) => l.isPending)
              .map((l) => l.id)
              .toList();
          if (pendingIds.isNotEmpty) {
            await ref.read(incentiveRepositoryProvider).markPayoutLedgersReleased(
              ledgerIds: pendingIds,
              releaseCycle: month,
              releasedAt: DateTime.now(),
            );
          }
        }
      }

      ref.invalidate(payrollRecordsForMonthProvider);
      ref.invalidate(allPayrollRecordsProvider);
      ref.invalidate(employeePayoutLedgersProvider(employee.id));
      ref.invalidate(allPayoutLedgersProvider);

      if (mounted) {
        final actionText = saveStatus == 'Draft' ? 'saved as Draft' : 'processed successfully';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payroll $actionText for ${employee.fullName}!'),
            backgroundColor: Colors.green[700],
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Action blocked: $e'),
            backgroundColor: Colors.red[700],
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingDraft = false;
          _isSavingProcessed = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedMonth = ref.watch(selectedPayrollMonthProvider);
    final employeesAsync = ref.watch(employeesProvider);
    final settingsAsync = ref.watch(payrollSettingsProvider);
    final incentiveSettingsAsync = ref.watch(incentiveSettingsProvider);
    final ledgersAsync = ref.watch(employeePayoutLedgersProvider(widget.employeeId));

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text('Generate Payroll'),
      ),
      body: employeesAsync.when(
        data: (employees) {
          final matching = employees.where((e) => e.id == widget.employeeId).toList();
          if (matching.isEmpty) {
            return const Center(child: Text('Employee not found.'));
          }
          final employee = matching.first;
          final attendanceAsync = ref.watch(attendanceRecordsProvider(widget.employeeId));
          final leavesAsync = ref.watch(leaveRequestsProvider(widget.employeeId));
          final onDutyAsync = ref.watch(employeeOnDutyAssignmentsProvider((employeeId: widget.employeeId, date: null)));
          final holidaysAsync = ref.watch(holidaysProvider);
          final permissionsAsync = ref.watch(allPermissionRequestsProvider(const AllPermissionRequestsFilter()));
          final incentivesAsync = ref.watch(allIncentiveRequestsProvider);

          final overridesMap = ref.watch(payrollInputOverridesProvider);
          final overrideInput = overridesMap[widget.employeeId.toString()] ??
              overridesMap[employee.employeeId.trim().toLowerCase()];

          return settingsAsync.when(
            data: (settings) {
              if (attendanceAsync.isLoading || leavesAsync.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              _initializeValues(employee, settings, selectedMonth, overrideInput: overrideInput);
              final records = attendanceAsync.value ?? [];
              final leaves = leavesAsync.value;
              final onDuty = onDutyAsync.value;
              final holidays = holidaysAsync.value ?? [];
              final permissions = permissionsAsync.value ?? [];
              _calculateAttendanceMetrics(
                employee,
                records,
                selectedMonth,
                settings,
                leaves: leaves,
                onDutyAssignments: onDuty,
                holidays: holidays,
                permissions: permissions,
              );
              _calculateIncentiveMetrics(
                employee,
                incentivesAsync.value ?? [],
                selectedMonth,
                settings,
                incentiveSettings: incentiveSettingsAsync.value ?? const IncentiveSettings(),
                ledgers: ledgersAsync.value ?? [],
                overrideIncentive: overrideInput?.incentive,
              );

              return LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < AppBreakpoints.tablet;
                  final gutter = AppLayout.gutter(constraints.maxWidth);

                  if (isMobile) {
                    return _buildMobileStepFlow(context, employee, selectedMonth, settings, overrideInput: overrideInput);
                  }

                  return _buildDesktopLayout(context, employee, selectedMonth, settings, gutter, overrideInput: overrideInput);
                },
              );
            },

            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.orange),
                    const SizedBox(height: 16),
                    const Text(
                      'Unable to connect to server',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Check your internet connection and try again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () => ref.invalidate(payrollSettingsProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading employee: $err')),
      ),
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    dynamic employee,
    String selectedMonth,
    PayrollSettings settings,
    double gutter, {
    PayrollInputOverride? overrideInput,
  }) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(gutter),
            child: ResponsiveContent(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: _buildAttendanceSummaryCard(settings, selectedMonth),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildEmployeeOverviewCard(employee, selectedMonth, overrideInput: overrideInput),
                        const SizedBox(height: 16),
                        _buildEarningsCard(),
                        const SizedBox(height: 16),
                        _buildDeductionsCard(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        _buildStickyFooter(employee, selectedMonth, settings),
      ],
    );
  }

  Widget _buildMobileStepFlow(
    BuildContext context,
    dynamic employee,
    String selectedMonth,
    PayrollSettings settings, {
    PayrollInputOverride? overrideInput,
  }) {
    Widget stepWidget;
    String stepTitle;

    switch (_currentStep) {
      case 0:
        stepTitle = 'Step 1: Attendance';
        stepWidget = _buildAttendanceSummaryCard(settings, selectedMonth);
        break;
      case 1:
        stepTitle = 'Step 2: Earnings';
        stepWidget = _buildEarningsCard();
        break;
      case 2:
        stepTitle = 'Step 3: Deductions';
        stepWidget = _buildDeductionsCard();
        break;
      case 3:
      default:
        stepTitle = 'Step 4: Review';
        stepWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildEmployeeOverviewCard(employee, selectedMonth, overrideInput: overrideInput),
            const SizedBox(height: 12),
            _buildSummaryRow('Basic Pay', _basicController.text),
            _buildSummaryRow('HRA', _hraController.text),
            _buildSummaryRow('Educational Allowance', _educationController.text),
            _buildSummaryRow('Special Allowance', _specialController.text),
            _buildSummaryRow('Travel Allowance', _travelAllowanceController.text),
            _buildSummaryRow('Other Allowance', _otherAllowanceController.text),
            _buildSummaryRow('Incentive', _incentiveController.text),
            _buildSummaryRow('Others Earning', _othersEarningController.text),
            _buildSummaryRow('Bonus', _bonusController.text),
            _buildSummaryRow('OT', _otController.text),
            const Divider(height: 16),
            _buildSummaryRow('PF Contribution', _pfController.text, isDeduction: true),
            _buildSummaryRow('Income Tax (TDS)', _taxController.text, isDeduction: true),
            _buildSummaryRow('ESI Contribution', _esiController.text, isDeduction: true),
            _buildSummaryRow('Hourly Loss of Pay (LOP)', _lopController.text, isDeduction: true),
            _buildSummaryRow('Company Loan', _companyLoanController.text, isDeduction: true),
            _buildSummaryRow('Salary Advance', _salaryAdvanceController.text, isDeduction: true),
            _buildSummaryRow('Others Deduction', _othersDeductionController.text, isDeduction: true),
            _buildSummaryRow('Staff Welfare', _staffWelfareController.text, isDeduction: true),
          ],
        );
        break;
    }

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(stepTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text('Step ${_currentStep + 1} of 4', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: stepWidget,
          ),
        ),
        _buildMobileFooter(employee, selectedMonth, settings),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String valueStr, {bool isDeduction = false}) {
    final value = double.tryParse(valueStr) ?? 0.0;
    if (value == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Text(
            '${isDeduction ? "-" : "+"} ${NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(value)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDeduction ? Colors.red[700] : Colors.green[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeOverviewCard(dynamic employee, String selectedMonth, {PayrollInputOverride? overrideInput}) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.active,
              child: Icon(Icons.person, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${employee.firstName} ${employee.lastName}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'EMP${employee.id} • ${employee.designation} • $selectedMonth',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                  if (overrideInput != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline_rounded, size: 13, color: Color(0xFF16A34A)),
                          SizedBox(width: 4),
                          Text(
                            'Excel Upload Overrides Applied',
                            style: TextStyle(fontSize: 11, color: Color(0xFF15803D), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceSummaryCard(PayrollSettings settings, String selectedMonth) {
    final now = DateTime.now();
    int year = now.year;
    int monthNum = now.month;

    final parts = selectedMonth.trim().split(' ');
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

    final period = settings.getPayrollPeriod(year, monthNum);

    final lopHoursStr = _lopHours > 0
        ? '${_lopHours.toStringAsFixed(1)} Hrs'
        : (_attendanceResult != null && _attendanceResult!.totalShortfallHours > 0
            ? '${_attendanceResult!.totalShortfallHours.toStringAsFixed(1)} Hrs'
            : '0.0 Hrs');

    final otHours = _attendanceResult?.totalOvertimeHours ?? 0.0;
    final otHoursStr = '${otHours.toStringAsFixed(1)} Hrs';

    final summaries = [
      ('Present Days', '$_presentDays Days', Icons.check_circle_outline, Colors.green),
      ('Late Days', '$_lateDays Days', Icons.watch_later_outlined, Colors.amber),
      ('Overtime (OT)', otHoursStr, Icons.more_time_rounded, const Color(0xFF9CC70A)),
      ('LOP Hours', lopHoursStr, Icons.timer_outlined, Colors.deepOrange),
      ('Leave Days', '$_leaveDays Days', Icons.event_note_outlined, Colors.blue),
      ('Absent Days', '$_absentDays Days', Icons.cancel_outlined, Colors.red),
      ('Weekly Off', '$_weeklyOffDays Days', Icons.weekend_outlined, const Color(0xFF64748B)),
      ('Working Days', '$_totalDays Days', Icons.calendar_month_outlined, AppColors.active),
    ];

    return Card(
      elevation: 0,
      color: const Color(0xFFF3F4F6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Attendance Summary',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'HR Proc: ${period.processingDateFormatted}',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Period: ${period.displayPeriodString}',
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const Divider(height: 24),
            for (var i = 0; i < summaries.length; i++) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(summaries[i].$3, color: summaries[i].$4, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        summaries[i].$1,
                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                      ),
                    ),
                    Text(
                      summaries[i].$2,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (i < summaries.length - 1) const Divider(height: 8, color: Color(0xFFE5E7EB)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEarningsCard() {
    String? incentiveHelper;
    if (_incentiveResult != null) {
      if (_incentiveResult!.releasedDeferredIncentive > 0) {
        incentiveHelper = 'Immediate (50%): ₹${_incentiveResult!.immediateIncentive.toStringAsFixed(2)} + Released: ₹${_incentiveResult!.releasedDeferredIncentive.toStringAsFixed(2)} = ₹${_incentiveResult!.totalPayableIncentive.toStringAsFixed(2)} payable (Total Earned: ₹${_incentiveResult!.totalEarnedIncentive.toStringAsFixed(2)})';
      } else if (_incentiveResult!.totalEarnedIncentive > 0) {
        incentiveHelper = 'Immediate (50%): ₹${_incentiveResult!.immediateIncentive.toStringAsFixed(2)} payable | Deferred (50%): ₹${_incentiveResult!.currentDeferredIncentive.toStringAsFixed(2)} (Total Earned: ₹${_incentiveResult!.totalEarnedIncentive.toStringAsFixed(2)})';
      }
    }

    String? carryForwardHelper;
    if (_incentiveResult != null && _incentiveResult!.currentDeferredIncentive > 0) {
      carryForwardHelper = 'Current cycle deferred: ₹${_incentiveResult!.currentDeferredIncentive.toStringAsFixed(2)} (Total pending balance: ₹${_incentiveResult!.totalPendingDeferredBalance.toStringAsFixed(2)})';
    }

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Earnings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            _buildInputField('Basic Salary', _basicController),
            const SizedBox(height: 12),
            _buildInputField('HRA (House Rent Allowance)', _hraController),
            const SizedBox(height: 12),
            _buildInputField('Educational Allowance', _educationController),
            const SizedBox(height: 12),
            _buildInputField('Special Allowance', _specialController),
            const SizedBox(height: 12),
            _buildInputField('Travel Allowance', _travelAllowanceController),
            const SizedBox(height: 12),
            _buildInputField('Other Allowance', _otherAllowanceController),
            const Divider(height: 24),
            const Text('Monthly Inputs & Incentives', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            _buildInputField('Incentive (Payable)', _incentiveController, helperText: incentiveHelper),
            const SizedBox(height: 12),
            _buildInputField('Carry Forward (Deferred 50%)', _carryForwardController, isText: true, helperText: carryForwardHelper),
            const SizedBox(height: 12),
            _buildInputField('Others Earning', _othersEarningController),
            const SizedBox(height: 12),
            _buildInputField('Cumulative Incentive (Informational)', _cumulativeIncentiveController, helperText: 'Informational accrued reference – not added to net salary'),
            const SizedBox(height: 12),
            _buildInputField('Bonus', _bonusController),
            const SizedBox(height: 12),
            _buildInputField('OT (Overtime)', _otController),
          ],
        ),
      ),
    );
  }


  Widget _buildDeductionsCard() {
    final lopHelper = _lopHours > 0
        ? '${_lopHours.toStringAsFixed(1)} Hours × ₹${_hourlyRate.toStringAsFixed(2)}/hr'
        : '0.0 Hours LOP (₹${_hourlyRate.toStringAsFixed(2)}/hr)';

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Deductions - Statutory', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            _buildInputField('PF (Provident Fund)', _pfController),
            const SizedBox(height: 12),
            _buildInputField('TDS (Income Tax)', _taxController),
            const SizedBox(height: 12),
            _buildInputField('ESI Contribution', _esiController),
            const Divider(height: 24),
            const Text('Deductions - Other', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            _buildInputField('Hourly Loss of Pay (LOP)', _lopController, helperText: lopHelper),
            const SizedBox(height: 12),
            _buildInputField('Company Loan Recovery', _companyLoanController),
            const SizedBox(height: 8),
            _buildInputField('Loan Details Note (e.g. Installment 4 of 12)', _loanDescController, isText: true),
            const SizedBox(height: 12),
            _buildInputField('Salary Advance Recovery', _salaryAdvanceController),
            const SizedBox(height: 8),
            _buildInputField('Salary Advance Details Note', _advanceDescController, isText: true),
            const SizedBox(height: 12),
            _buildInputField('Others Deduction', _othersDeductionController),
            const SizedBox(height: 12),
            _buildInputField('Staff Welfare Contribution', _staffWelfareController),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, {bool isText = false, String? helperText}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: isText ? TextInputType.text : const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: isText ? null : [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            prefixText: isText ? null : '₹ ',
            prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            helperText: helperText,
            helperStyle: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w500),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.divider)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.divider)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)),
          ),
        ),
      ],
    );
  }

  Widget _buildStickyFooter(dynamic employee, String selectedMonth, PayrollSettings settings) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('NET SALARY (TAKE HOME)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(
                  NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(_netSalary),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ],
            ),
            const Spacer(),
            OutlinedButton(
              onPressed: (_isSavingDraft || _isSavingProcessed)
                  ? null
                  : () => _savePayroll(employee, selectedMonth, settings, saveStatus: 'Draft'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.active,
                side: const BorderSide(color: AppColors.divider),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isSavingDraft
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.active,
                      ),
                    )
                  : const Text('Save as Draft', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: (_isSavingDraft || _isSavingProcessed)
                  ? null
                  : () => _savePayroll(employee, selectedMonth, settings, saveStatus: 'Processed'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isSavingProcessed
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save & Process Payroll', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileFooter(dynamic employee, String selectedMonth, PayrollSettings settings) {
    final isLastStep = _currentStep == 3;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('NET SALARY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                Text(
                  NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(_netSalary),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ],
            ),
            const Spacer(),
            if (_currentStep > 0) ...[
              OutlinedButton(
                onPressed: (_isSavingDraft || _isSavingProcessed)
                    ? null
                    : () {
                        setState(() {
                          _currentStep--;
                        });
                      },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.active,
                  side: const BorderSide(color: AppColors.divider),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text('Back'),
              ),
              const SizedBox(width: 8),
            ],
            ElevatedButton(
              onPressed: (_isSavingDraft || _isSavingProcessed)
                  ? null
                  : (isLastStep
                      ? () => _savePayroll(employee, selectedMonth, settings)
                      : () {
                          setState(() {
                            _currentStep++;
                          });
                        }),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              child: (_isSavingDraft || _isSavingProcessed)
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(isLastStep ? 'Process' : 'Next'),
            ),
          ],
        ),
      ),
    );
  }
}
