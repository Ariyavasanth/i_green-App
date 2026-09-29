import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../employee/domain/employee.dart';
import '../../../employee/providers/employee_providers.dart';
import '../../../payroll/providers/payroll_providers.dart';
import '../../domain/employee_loan.dart';
import '../../providers/loan_providers.dart';

class ApproveLoanDialog extends ConsumerStatefulWidget {
  final EmployeeLoan loan;

  const ApproveLoanDialog({
    required this.loan,
    super.key,
  });

  static Future<bool?> show(BuildContext context, EmployeeLoan loan) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ApproveLoanDialog(loan: loan),
    );
  }

  @override
  ConsumerState<ApproveLoanDialog> createState() => _ApproveLoanDialogState();
}

class _ApproveLoanDialogState extends ConsumerState<ApproveLoanDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _installmentsController;
  late TextEditingController _remarksController;
  late String _firstDeductionMonth;
  final List<String> _monthsList = [];

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _installmentsController = TextEditingController(
      text: widget.loan.installments > 0 ? widget.loan.installments.toString() : '12',
    );
    _remarksController = TextEditingController();

    _generateMonthsList();
    _firstDeductionMonth = widget.loan.firstDeductionMonth.isNotEmpty &&
            _monthsList.contains(widget.loan.firstDeductionMonth)
        ? widget.loan.firstDeductionMonth
        : (_monthsList.isNotEmpty ? _monthsList.first : '');
  }

  void _generateMonthsList() {
    final now = DateTime.now();
    final formatter = DateFormat('MMMM yyyy');
    for (int i = 0; i < 24; i++) {
      _monthsList.add(formatter.format(DateTime(now.year, now.month + i)));
    }
  }

  @override
  void dispose() {
    _installmentsController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  String _calculateLastDeductionMonth(String startMonth, int installments) {
    if (installments <= 0 || startMonth.isEmpty) return startMonth;
    final parts = startMonth.split(' ');
    if (parts.length < 2) return startMonth;
    final monthName = parts[0];
    final year = int.tryParse(parts[1]) ?? DateTime.now().year;

    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final startIndex = months.indexOf(monthName);
    if (startIndex == -1) return startMonth;

    final totalMonths = startIndex + installments - 1;
    final finalMonthIndex = totalMonths % 12;
    final finalYear = year + (totalMonths ~/ 12);

    return '${months[finalMonthIndex]} $finalYear';
  }

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(employeesProvider);
    final settingsAsync = ref.watch(payrollSettingsProvider);
    final settings = settingsAsync.asData?.value;
    final pStart = settings?.payrollStartDay ?? 20;
    final pEnd = settings?.payrollEndDay ?? 20;

    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    final employeesList = employeesAsync.asData?.value ?? [];
    final employee = employeesList.where((e) =>
        e.id == widget.loan.employeeId ||
        e.employeeId.trim().toUpperCase() == widget.loan.employeeCustomId.trim().toUpperCase() ||
        e.fullName.trim().toLowerCase() == widget.loan.employeeName.trim().toLowerCase()
    ).firstOrNull;

    final monthlySalary = employee != null
        ? (employee.salaryTotalCtc > 0
            ? employee.salaryTotalCtc
            : (employee.salaryBasic + employee.salaryHra + employee.salaryAllowances))
        : 0.0;

    final installments = int.tryParse(_installmentsController.text) ?? widget.loan.installments;
    final lastDeductionMonth = _calculateLastDeductionMonth(_firstDeductionMonth, installments);

    final previewLoan = widget.loan.copyWith(
      installments: installments,
      firstDeductionMonth: _firstDeductionMonth,
      lastDeductionMonth: lastDeductionMonth,
    );

    final rate = previewLoan.interestRate;
    final totalInterest = previewLoan.calculatedTotalInterestWithDays(payrollStartDay: pStart, payrollEndDay: pEnd);
    final monthlyPrincipal = previewLoan.monthlyPrincipal;
    final firstMonthInterest = previewLoan.interestForInstallment(0, payrollStartDay: pStart, payrollEndDay: pEnd);
    final monthlyEmi = previewLoan.emiForInstallment(0, payrollStartDay: pStart, payrollEndDay: pEnd);
    final activeDays = previewLoan.activeDaysForInstallment(0, payrollStartDay: pStart, payrollEndDay: pEnd);
    final cycleDays = previewLoan.cycleDaysForInstallment(0, payrollStartDay: pStart, payrollEndDay: pEnd);
    final emiPercent = monthlySalary > 0 ? (monthlyEmi / monthlySalary) * 100 : 0.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.verified_user_outlined, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Approve Loan (${widget.loan.loanId})',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Review salary, configure EMIs, and confirm approval',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20, color: AppColors.textSecondary),
                        onPressed: _isSubmitting ? null : () => Navigator.pop(context, false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: AppColors.divider),
                  const SizedBox(height: 16),

                  // Employee & Salary Summary Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.loan.employeeName,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${widget.loan.employeeCustomId} • ${widget.loan.department} (${widget.loan.designation})',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFBFDBFE)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'MONTHLY SALARY',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1D4ED8),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    monthlySalary > 0 ? currencyFormat.format(monthlySalary) : '₹0',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E3A8A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Loan Amount & Requested Information
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoTile(
                          label: 'Loan Amount',
                          value: currencyFormat.format(widget.loan.loanAmount),
                          icon: Icons.account_balance_wallet_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInfoTile(
                          label: 'Loan Type',
                          value: widget.loan.loanType,
                          icon: Icons.category_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // EMI Configuration Section
                  const Text(
                    'Configure Repayment / EMIs',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _installmentsController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Number of EMIs (Months)',
                            labelStyle: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Required';
                            final parsed = int.tryParse(val.trim());
                            if (parsed == null || parsed <= 0) return 'Must be >= 1';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _firstDeductionMonth,
                          isDense: true,
                          decoration: InputDecoration(
                            labelText: 'First Deduction Month',
                            labelStyle: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                            ),
                          ),
                          items: _monthsList.map((m) {
                            return DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 12)));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _firstDeductionMonth = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Calculated EMI Breakdown Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Calculated Monthly EMI:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF166534),
                              ),
                            ),
                            Text(
                              currencyFormat.format(monthlyEmi),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF15803D),
                              ),
                            ),
                          ],
                        ),
                        if (rate > 0 || totalInterest > 0) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                activeDays < cycleDays
                                    ? 'Principal: ${currencyFormat.format(monthlyPrincipal)} + 1st Month Int: ${currencyFormat.format(firstMonthInterest)} ($activeDays/$cycleDays days)'
                                    : 'Principal: ${currencyFormat.format(monthlyPrincipal)} + 1st Month Int: ${currencyFormat.format(firstMonthInterest)}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF166534)),
                              ),
                              Text(
                                'Total Interest: ${currencyFormat.format(totalInterest)}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF166534)),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Schedule: $_firstDeductionMonth to $lastDeductionMonth',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF166534)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isSubmitting ? null : () => Navigator.pop(context, false),
                        child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check_circle_outline, size: 18),
                        label: Text(_isSubmitting ? 'Approving...' : 'Confirm Approval'),
                        onPressed: _isSubmitting ? null : _submitApproval,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                Text(
                  value,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitApproval() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final currentEmp = ref.read(currentEmployeeProvider);
      final approverName = currentEmp?.fullName ?? 'Admin';
      final approverRole = currentEmp?.userType ?? 'Admin';

      final settings = ref.read(payrollSettingsProvider).asData?.value;
      final pStart = settings?.payrollStartDay ?? 20;
      final pEnd = settings?.payrollEndDay ?? 20;

      final installments = int.tryParse(_installmentsController.text.trim()) ?? widget.loan.installments;
      final lastDeductionMonth = _calculateLastDeductionMonth(_firstDeductionMonth, installments);

      final previewLoan = widget.loan.copyWith(
        installments: installments,
        firstDeductionMonth: _firstDeductionMonth,
        lastDeductionMonth: lastDeductionMonth,
      );

      final totalRepayable = previewLoan.calculatedTotalRepayableWithDays(payrollStartDay: pStart, payrollEndDay: pEnd);
      final emiAmount = previewLoan.emiForInstallment(0, payrollStartDay: pStart, payrollEndDay: pEnd);

      final nextStatus = await ref.read(loanRepositoryProvider).approveLoan(
        id: widget.loan.id,
        approverName: approverName,
        approverRole: approverRole,
        installments: installments,
        emiAmount: emiAmount,
        totalRepayableAmount: totalRepayable,
        firstDeductionMonth: _firstDeductionMonth,
        lastDeductionMonth: lastDeductionMonth,
      );

      ref.invalidate(allLoansProvider);
      ref.invalidate(loanByIdProvider(widget.loan.id));
      ref.invalidate(employeeLoansProvider(widget.loan.employeeId));

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Loan ${widget.loan.loanId} updated to $nextStatus.'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve loan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
