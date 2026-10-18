import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../employee/providers/employee_providers.dart';
import '../../domain/employee_loan.dart';
import '../../providers/loan_providers.dart';

class ConfigureLoanExtensionDialog extends ConsumerStatefulWidget {
  const ConfigureLoanExtensionDialog({required this.loan, super.key});
  final EmployeeLoan loan;

  static Future<bool?> show(BuildContext context, EmployeeLoan loan) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ConfigureLoanExtensionDialog(loan: loan),
    );
  }

  @override
  ConsumerState<ConfigureLoanExtensionDialog> createState() => _ConfigureLoanExtensionDialogState();
}

class _ConfigureLoanExtensionDialogState extends ConsumerState<ConfigureLoanExtensionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _monthsController;
  late final TextEditingController _amountController;
  late final TextEditingController _percentageController;
  late final TextEditingController _interestRateController;
  late final TextEditingController _remarksController;
  late String _startMonth;
  bool _isSubmitting = false;
  bool _isSyncing = false;

  double get _outstanding => widget.loan.actualRemainingBalance;

  @override
  void initState() {
    super.initState();
    final defaultMonths = widget.loan.extensionInstallments > 0
        ? widget.loan.extensionInstallments
        : 4;
    final defaultInterest = widget.loan.extensionInterestRate;
    final totalToRecover = _outstanding + (_outstanding * (defaultInterest / 100.0));
    final defaultEmi = defaultMonths > 0 ? (totalToRecover / defaultMonths) : 0.0;
    final defaultPercent = _outstanding > 0 ? ((defaultEmi / _outstanding) * 100.0) : 25.0;

    _monthsController = TextEditingController(text: defaultMonths.toString());
    _amountController = TextEditingController(text: defaultEmi.round().toString());
    _percentageController = TextEditingController(text: defaultPercent.toStringAsFixed(1));
    _interestRateController = TextEditingController(text: defaultInterest.toStringAsFixed(1));
    _remarksController = TextEditingController(text: widget.loan.extensionRemarks);

    if (widget.loan.extensionStartMonth.isNotEmpty) {
      _startMonth = widget.loan.extensionStartMonth;
    } else {
      _startMonth = EmployeeLoan.getMonthAtOffset(widget.loan.originalLastDeductionMonth, 1);
    }
  }

  @override
  void dispose() {
    _monthsController.dispose();
    _amountController.dispose();
    _percentageController.dispose();
    _interestRateController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  void _onMonthsChanged(String val) {
    if (_isSyncing) return;
    _isSyncing = true;
    final months = int.tryParse(val.trim()) ?? 0;
    if (months > 0 && _outstanding > 0) {
      final interestRate = double.tryParse(_interestRateController.text.trim()) ?? 0.0;
      final total = _outstanding + (_outstanding * (interestRate / 100.0));
      final emi = total / months;
      final percent = (emi / _outstanding) * 100.0;

      _amountController.text = emi.round().toString();
      _percentageController.text = percent.toStringAsFixed(1);
    }
    _isSyncing = false;
    setState(() {});
  }

  void _onAmountChanged(String val) {
    if (_isSyncing) return;
    _isSyncing = true;
    final emi = double.tryParse(val.trim()) ?? 0.0;
    if (emi > 0 && _outstanding > 0) {
      final interestRate = double.tryParse(_interestRateController.text.trim()) ?? 0.0;
      final total = _outstanding + (_outstanding * (interestRate / 100.0));
      int months = (total / emi).ceil();
      if (months < 1) months = 1;
      if (months > 60) months = 60;
      final percent = (emi / _outstanding) * 100.0;

      _monthsController.text = months.toString();
      _percentageController.text = percent.toStringAsFixed(1);
    }
    _isSyncing = false;
    setState(() {});
  }

  void _onPercentageChanged(String val) {
    if (_isSyncing) return;
    _isSyncing = true;
    final percent = double.tryParse(val.trim()) ?? 0.0;
    if (percent > 0 && _outstanding > 0) {
      final emi = (_outstanding * (percent / 100.0)).clamp(1.0, double.infinity);
      final interestRate = double.tryParse(_interestRateController.text.trim()) ?? 0.0;
      final total = _outstanding + (_outstanding * (interestRate / 100.0));
      int months = (total / emi).ceil();
      if (months < 1) months = 1;
      if (months > 60) months = 60;

      _amountController.text = emi.round().toString();
      _monthsController.text = months.toString();
    }
    _isSyncing = false;
    setState(() {});
  }

  void _onInterestRateChanged(String val) {
    if (_isSyncing) return;
    _isSyncing = true;
    final interestRate = double.tryParse(val.trim()) ?? 0.0;
    final months = int.tryParse(_monthsController.text.trim()) ?? 4;
    if (months > 0 && _outstanding > 0) {
      final total = _outstanding + (_outstanding * (interestRate / 100.0));
      final emi = total / months;
      final percent = (emi / _outstanding) * 100.0;

      _amountController.text = emi.round().toString();
      _percentageController.text = percent.toStringAsFixed(1);
    }
    _isSyncing = false;
    setState(() {});
  }

  Future<void> _submitExtension() async {
    if (!_formKey.currentState!.validate()) return;

    final currentEmp = ref.read(currentEmployeeProvider);
    final hasPermission = currentEmp == null ||
        currentEmp.isSuperAdmin ||
        currentEmp.hasPermission('Loan Management') ||
        currentEmp.userType.toUpperCase() == 'ADMIN';

    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Access Denied: Only Admins with Loan Management permission can configure tenure extensions.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final extraMonths = int.tryParse(_monthsController.text.trim()) ?? 0;
    if (extraMonths <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid number of extension months (minimum 1).')),
      );
      return;
    }

    if (_outstanding <= 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loan has no outstanding balance to extend.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final approverName = currentEmp != null && currentEmp.fullName.isNotEmpty
          ? currentEmp.fullName
          : 'Admin';

      final interestRate = double.tryParse(_interestRateController.text.trim()) ?? 0.0;
      final totalInterest = _outstanding * (interestRate / 100.0);
      final totalToRecover = _outstanding + totalInterest;
      final emiPerMonth = double.tryParse(_amountController.text.trim()) ??
          double.parse((totalToRecover / extraMonths).toStringAsFixed(2));

      final updatedLoan = widget.loan.copyWith(
        extensionInstallments: extraMonths,
        extensionEmiAmount: emiPerMonth,
        extensionInterestRate: interestRate,
        extensionStartMonth: _startMonth,
        extensionApprovedBy: approverName,
        extensionApprovalDate: DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
        extensionRemarks: _remarksController.text.trim(),
      );

      await ref.read(loanRepositoryProvider).saveLoan(updatedLoan);
      ref.invalidate(loanByIdProvider(widget.loan.id));
      ref.invalidate(allLoansProvider);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Tenure extension of $extraMonths months approved for ${widget.loan.loanId}. Monthly EMI: ₹${emiPerMonth.toStringAsFixed(0)}',
            ),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save loan extension: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatCurrency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final extraMonths = int.tryParse(_monthsController.text.trim()) ?? 0;
    final emiPerMonth = double.tryParse(_amountController.text.trim()) ??
        (extraMonths > 0 ? (_outstanding / extraMonths) : 0.0);
    final recoveryPercent = double.tryParse(_percentageController.text.trim()) ??
        (_outstanding > 0 ? (emiPerMonth / _outstanding) * 100.0 : 0.0);
    final interestRate = double.tryParse(_interestRateController.text.trim()) ?? 0.0;
    final totalInterest = (_outstanding * (interestRate / 100.0)).clamp(0.0, double.infinity);
    final totalToRecover = _outstanding + totalInterest;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header ──
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.extension_rounded, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Configure Loan Extension',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            Text(
                              '${widget.loan.loanId} • ${widget.loan.employeeName}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppColors.textSecondary),
                        onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
                  const SizedBox(height: 16),

                  // ── Loan Status & Deficit Card ──
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        _buildSummaryRow('Original Loan Amount', formatCurrency.format(widget.loan.loanAmount)),
                        const SizedBox(height: 8),
                        _buildSummaryRow(
                          'Original Agreed Duration',
                          '${widget.loan.baseInstallments} Months (${widget.loan.firstDeductionMonth} – ${widget.loan.originalLastDeductionMonth})',
                        ),
                        const SizedBox(height: 8),
                        _buildSummaryRow('Total Paid So Far', formatCurrency.format(widget.loan.totalPaid)),
                        const Divider(height: 16, color: Color(0xFFCBD5E1)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Outstanding Deficit to Recover',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                            Text(
                              formatCurrency.format(_outstanding),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFC62828)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Title & Helper ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Repayment Parameters',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Month • Amount • Percentage',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Set any value — Month, Amount, or Percentage — and the others automatically calculate in real time.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 14),

                  // ── Row 1: Extension Months & Monthly EMI (Amount) ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Month Input
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.calendar_month_outlined, size: 14, color: AppColors.textSecondary),
                                SizedBox(width: 4),
                                Text(
                                  'Extension Months',
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _monthsController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              onChanged: _onMonthsChanged,
                              decoration: InputDecoration(
                                hintText: 'e.g. 4',
                                suffixText: 'Months',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Enter months';
                                final n = int.tryParse(val.trim());
                                if (n == null || n <= 0) return 'Min 1 mo';
                                if (n > 60) return 'Max 60 mo';
                                return null;
                              },
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [2, 3, 4, 5, 6, 10].map((preset) {
                                final isSelected = extraMonths == preset;
                                return InkWell(
                                  onTap: () {
                                    _monthsController.text = preset.toString();
                                    _onMonthsChanged(preset.toString());
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0)),
                                    ),
                                    child: Text(
                                      '${preset}mo',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        color: isSelected ? Colors.white : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Amount Input
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.currency_rupee, size: 14, color: AppColors.textSecondary),
                                SizedBox(width: 4),
                                Text(
                                  'Monthly Amount (EMI)',
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _amountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                              onChanged: _onAmountChanged,
                              decoration: InputDecoration(
                                prefixText: '₹ ',
                                suffixText: '/ mo',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Enter EMI';
                                final n = double.tryParse(val.trim());
                                if (n == null || n <= 0) return 'Min ₹1';
                                return null;
                              },
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [100, 200, 250, 500].map((preset) {
                                final isSelected = (emiPerMonth.round() - preset).abs() < 5;
                                return InkWell(
                                  onTap: () {
                                    _amountController.text = preset.toString();
                                    _onAmountChanged(preset.toString());
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0)),
                                    ),
                                    child: Text(
                                      '₹$preset',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        color: isSelected ? Colors.white : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Row 2: Recovery Percentage (%) & Extension Interest Rate (%) ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Recovery Percentage Input
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.percent_rounded, size: 14, color: AppColors.textSecondary),
                                SizedBox(width: 4),
                                Text(
                                  'Monthly Recovery (%)',
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _percentageController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}'))],
                              onChanged: _onPercentageChanged,
                              decoration: InputDecoration(
                                suffixText: '% / mo',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Enter %';
                                final n = double.tryParse(val.trim());
                                if (n == null || n <= 0) return 'Min 1%';
                                if (n > 100) return 'Max 100%';
                                return null;
                              },
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [10, 20, 25, 33, 50].map((preset) {
                                final isSelected = (recoveryPercent.round() - preset).abs() < 2;
                                return InkWell(
                                  onTap: () {
                                    _percentageController.text = preset.toString();
                                    _onPercentageChanged(preset.toString());
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0)),
                                    ),
                                    child: Text(
                                      '$preset%',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        color: isSelected ? Colors.white : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Extension Interest Rate Input
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.trending_up, size: 14, color: AppColors.textSecondary),
                                SizedBox(width: 4),
                                Text(
                                  'Interest Rate (%)',
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _interestRateController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}'))],
                              onChanged: _onInterestRateChanged,
                              decoration: InputDecoration(
                                hintText: '0.0',
                                suffixText: '% p.a.',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [0, 2, 5, 8].map((preset) {
                                final isSelected = (interestRate - preset).abs() < 0.1;
                                return InkWell(
                                  onTap: () {
                                    _interestRateController.text = preset.toStringAsFixed(1);
                                    _onInterestRateChanged(preset.toStringAsFixed(1));
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0)),
                                    ),
                                    child: Text(
                                      preset == 0 ? '0% Free' : '$preset%',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        color: isSelected ? Colors.white : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // ── Start Month of Extension ──
                  const Text(
                    'Extension Starts In',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_startMonth, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        const Text('(Following Month)', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // ── Calculation Preview Box ──
                  if (extraMonths > 0) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Calculated New Monthly EMI:',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                              ),
                              Text(
                                '${formatCurrency.format(emiPerMonth)} / month',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            interestRate > 0
                                ? 'Formula: (${formatCurrency.format(_outstanding)} balance + ${formatCurrency.format(totalInterest)} interest @ $interestRate%) ÷ $extraMonths months = ${formatCurrency.format(emiPerMonth)}/month'
                                : 'Formula: ${formatCurrency.format(_outstanding)} ÷ $extraMonths months = ${formatCurrency.format(emiPerMonth)}/month (${recoveryPercent.toStringAsFixed(1)}% recovery/mo)',
                            style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'The approved schedule adds $extraMonths installments from $_startMonth to ${EmployeeLoan.getMonthAtOffset(_startMonth, extraMonths - 1)}.',
                            style: TextStyle(fontSize: 11.5, color: Colors.blue.shade900, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 10),
                          const Divider(height: 1, color: Color(0xFFCBD5E1)),
                          const SizedBox(height: 8),
                          const Text(
                            'Approved Extension Repayment Schedule:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 6),
                          ...List.generate(extraMonths > 6 ? 6 : extraMonths, (i) {
                            final m = EmployeeLoan.getMonthAtOffset(_startMonth, i);
                            final isLast = i == extraMonths - 1;
                            final amt = (isLast && extraMonths > 1)
                                ? (totalToRecover - (emiPerMonth.round() * (extraMonths - 1))).clamp(0.0, totalToRecover)
                                : emiPerMonth;
                            final displayAmt = (amt > 0 ? amt : emiPerMonth);
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Month ${widget.loan.baseInstallments + i + 1} ($m)',
                                    style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                  ),
                                  Text(
                                    formatCurrency.format(displayAmt),
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                  ),
                                ],
                              ),
                            );
                          }),
                          if (extraMonths > 6)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '+ ${extraMonths - 6} more months (${formatCurrency.format(emiPerMonth)}/month)',
                                style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textSecondary),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Admin Remarks ──
                  const Text(
                    'Admin Notes / Justification (Optional)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _remarksController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'e.g. Approved 4-month extension to recover remaining balance.',
                      hintStyle: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // ── Action Buttons ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
                        child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: _isSubmitting
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check_circle_outline, size: 18),
                        label: Text(
                          _isSubmitting ? 'Saving...' : 'Approve & Activate Extension',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: _isSubmitting ? null : _submitExtension,
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

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ],
    );
  }
}
