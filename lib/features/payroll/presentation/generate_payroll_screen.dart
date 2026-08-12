import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/layout/responsive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../employee/providers/employee_providers.dart';
import '../../attendance/providers/attendance_providers.dart';
import '../domain/payroll.dart';
import '../providers/payroll_providers.dart';
import '../../leave/providers/leave_providers.dart';
import '../../loan/providers/loan_providers.dart';
import 'widgets/access_denied_view.dart';

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

  // Attendance
  int _presentDays = 27;
  int _lateDays = 0;
  int _absentDays = 0;
  int _leaveDays = 3;
  int _totalDays = 30;

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

  void _initializeValues(dynamic employee, PayrollSettings settings, String selectedMonth) {
    if (_initialized) return;
    _initialized = true;

    // Use employee standard CTC details
    final basic = employee.salaryBasic > 0 ? employee.salaryBasic : 33500.0;
    final hra = employee.salaryHra > 0 ? employee.salaryHra : 16750.0;
    final special = employee.salarySpecialAllowance > 0 ? employee.salarySpecialAllowance : 16750.0;
    final edu = employee.salaryEducationAllowance > 0 ? employee.salaryEducationAllowance : 3000.0;
    final travel = employee.salaryTravelAllowance > 0 ? employee.salaryTravelAllowance : 0.0;
    final otherAllowance = employee.salaryOtherAllowance > 0 ? employee.salaryOtherAllowance : 3000.0;

    final pf = employee.salaryPf > 0 ? employee.salaryPf : 1800.0;
    final tax = employee.salaryTax > 0 ? employee.salaryTax : 0.0;
    final esi = employee.salaryEsi > 0 ? employee.salaryEsi : 0.0;

    _basicController.text = basic.toStringAsFixed(2);
    _hraController.text = hra.toStringAsFixed(2);
    _educationController.text = edu.toStringAsFixed(2);
    _specialController.text = special.toStringAsFixed(2);
    _travelAllowanceController.text = travel.toStringAsFixed(2);
    _otherAllowanceController.text = otherAllowance.toStringAsFixed(2);

    // Initial mock values for monthly inputs matching screenshot
    _incentiveController.text = '8880.00';
    _carryForwardController.text = '-';
    _othersEarningController.text = '0.00';
    _cumulativeIncentiveController.text = '31067.00';
    _bonusController.text = '0.00';
    _otController.text = '0.00';

    _pfController.text = pf.toStringAsFixed(2);
    _taxController.text = tax.toStringAsFixed(2);
    _esiController.text = esi.toStringAsFixed(2);

    _lopController.text = '0.00';
    _companyLoanController.text = '0.00';
    _loanDescController.text = '';
    _salaryAdvanceController.text = '12200.00';
    _othersDeductionController.text = '3392.00';
    _staffWelfareController.text = '0.00';

    _recalculate();
    _loadActiveLoan(employee.id, selectedMonth);
    _loadLopDetails(employee.id, selectedMonth);
  }

  Future<void> _loadLopDetails(int employeeId, String month) async {
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

      final salaryCalc = await ref.read(leaveRepositoryProvider).calculateSalaryAndLop(
        employeeId,
        year,
        monthNum,
        workingDays: 26,
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

  Future<void> _loadActiveLoan(int employeeId, String month) async {
    try {
      final loan = await ref.read(loanRepositoryProvider).getActiveLoanForEmployee(employeeId, month);
      if (loan != null && mounted) {
        setState(() {
          _companyLoanController.text = loan.emiAmount.toStringAsFixed(2);
          _loanDescController.text = loan.loanId;
          _recalculate();
        });
      }
    } catch (_) {}
  }

  void _calculateAttendanceMetrics(dynamic attendanceRecords, String month) {
    if (attendanceRecords == null || attendanceRecords.isEmpty) return;

    final dateParts = month.split(' ');
    if (dateParts.length < 2) return;
    final monthName = dateParts[0].substring(0, 3);
    final yearStr = dateParts[1];

    int present = 0;
    int late = 0;
    int absent = 0;
    int leave = 0;

    for (final r in attendanceRecords) {
      if (r.date.contains(monthName) && r.date.contains(yearStr)) {
        final status = r.status.toLowerCase();
        if (status.contains('present') || status.contains('check')) {
          present++;
        } else if (status.contains('late')) {
          present++;
          late++;
        } else if (status.contains('absent')) {
          absent++;
        } else if (status.contains('leave') || status.contains('half')) {
          leave++;
        }
      }
    }

    if (present > 0 || absent > 0 || leave > 0) {
      setState(() {
        _presentDays = present;
        _lateDays = late;
        _absentDays = absent;
        _leaveDays = leave;
        _totalDays = present + absent + leave;
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

  Future<void> _savePayroll(dynamic employee, String month) async {
    final record = PayrollRecord(
      id: 0,
      employeeId: employee.id,
      employeeName: '${employee.firstName} ${employee.lastName}',
      month: month,
      presentDays: _presentDays,
      lateDays: _lateDays,
      absentDays: _absentDays,
      leaveDays: _leaveDays,
      
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
      status: 'Processed',
    );

    try {
      await ref.read(payrollRepositoryProvider).savePayrollRecord(record);
      ref.invalidate(payrollRecordsForMonthProvider);
      ref.invalidate(allPayrollRecordsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payroll processed successfully for ${employee.firstName}!'),
            backgroundColor: Colors.green[700],
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save payroll: $e'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final employee = ref.watch(currentEmployeeProvider);
    if (employee != null && employee.userType.toUpperCase() == 'EMPLOYEE') {
      return const AccessDeniedView();
    }

    final selectedMonth = ref.watch(selectedPayrollMonthProvider);
    final employeesAsync = ref.watch(employeesProvider);
    final settingsAsync = ref.watch(payrollSettingsProvider);

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

          // Load attendance
          final attendanceAsync = ref.watch(attendanceRecordsProvider(widget.employeeId));
          attendanceAsync.whenData((records) => _calculateAttendanceMetrics(records, selectedMonth));

          return settingsAsync.when(
            data: (settings) {
              _initializeValues(employee, settings, selectedMonth);

              return LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < AppBreakpoints.tablet;
                  final gutter = AppLayout.gutter(constraints.maxWidth);

                  if (isMobile) {
                    return _buildMobileStepFlow(context, employee, selectedMonth);
                  }

                  return _buildDesktopLayout(context, employee, selectedMonth, gutter);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error loading settings: $err')),
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
    double gutter,
  ) {
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
                    child: _buildAttendanceSummaryCard(),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildEmployeeOverviewCard(employee, selectedMonth),
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
        _buildStickyFooter(employee, selectedMonth),
      ],
    );
  }

  Widget _buildMobileStepFlow(BuildContext context, dynamic employee, String selectedMonth) {
    Widget stepWidget;
    String stepTitle;

    switch (_currentStep) {
      case 0:
        stepTitle = 'Step 1: Attendance';
        stepWidget = _buildAttendanceSummaryCard();
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
            _buildEmployeeOverviewCard(employee, selectedMonth),
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
            _buildSummaryRow('Leave Days Deduction (LOP)', _lopController.text, isDeduction: true),
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
        _buildMobileFooter(employee, selectedMonth),
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

  Widget _buildEmployeeOverviewCard(dynamic employee, String selectedMonth) {
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceSummaryCard() {
    final summaries = [
      ('Present Days', '$_presentDays Days', Icons.check_circle_outline, Colors.green),
      ('Late Days', '$_lateDays Days', Icons.watch_later_outlined, Colors.amber),
      ('Leave Days', '$_leaveDays Days', Icons.event_note_outlined, Colors.blue),
      ('Absent Days', '$_absentDays Days', Icons.cancel_outlined, Colors.red),
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
            const Text(
              'Attendance Summary',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            const Text(
              'Read-only attendance data pulled for the selected payroll period.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
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
            const Text('Monthly Inputs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            _buildInputField('Incentive', _incentiveController),
            const SizedBox(height: 12),
            _buildInputField('Carry Forward', _carryForwardController, isText: true),
            const SizedBox(height: 12),
            _buildInputField('Others Earning', _othersEarningController),
            const SizedBox(height: 12),
            _buildInputField('Cumulative Incentive', _cumulativeIncentiveController),
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
            _buildInputField('Leave Days Deduction (LOP)', _lopController),
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

  Widget _buildInputField(String label, TextEditingController controller, {bool isText = false}) {
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.divider)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.divider)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)),
          ),
        ),
      ],
    );
  }

  Widget _buildStickyFooter(dynamic employee, String selectedMonth) {
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
            ElevatedButton(
              onPressed: () => _savePayroll(employee, selectedMonth),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Save & Process Payroll', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileFooter(dynamic employee, String selectedMonth) {
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
                onPressed: () {
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
              onPressed: isLastStep
                  ? () => _savePayroll(employee, selectedMonth)
                  : () {
                      setState(() {
                        _currentStep++;
                      });
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              child: Text(isLastStep ? 'Process' : 'Next'),
            ),
          ],
        ),
      ),
    );
  }
}
