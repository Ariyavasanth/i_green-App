import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../employee/providers/employee_providers.dart';
import '../../domain/employee_loan.dart';
import '../../providers/loan_providers.dart';

class RecordDirectPaymentDialog extends ConsumerStatefulWidget {
  final EmployeeLoan loan;

  const RecordDirectPaymentDialog({
    required this.loan,
    super.key,
  });

  static Future<bool?> show(BuildContext context, EmployeeLoan loan) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => RecordDirectPaymentDialog(loan: loan),
    );
  }

  @override
  ConsumerState<RecordDirectPaymentDialog> createState() => _RecordDirectPaymentDialogState();
}

class _RecordDirectPaymentDialogState extends ConsumerState<RecordDirectPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late TextEditingController _referenceController;
  late TextEditingController _receivedByController;

  late String _selectedMonth;
  late DateTime _paymentDate;
  String _selectedPaymentMode = 'Cash';
  bool _isSubmitting = false;

  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    // Default to the next unpaid month or the first deduction month
    _selectedMonth = widget.loan.nextEmiMonth != 'Completed'
        ? widget.loan.nextEmiMonth
        : (widget.loan.scheduleMonths.isNotEmpty ? widget.loan.scheduleMonths.last : 'October 2026');

    // Default amount to standard EMI or remaining balance (whichever is smaller)
    final defAmount = widget.loan.emiAmount > 0 && widget.loan.emiAmount <= widget.loan.actualRemainingBalance
        ? widget.loan.emiAmount
        : widget.loan.actualRemainingBalance;
    _amountController = TextEditingController(text: defAmount > 0 ? defAmount.toStringAsFixed(0) : '');

    _paymentDate = DateTime.now();

    final currentEmp = ref.read(currentEmployeeProvider);
    final adminName = currentEmp?.fullName.isNotEmpty == true ? currentEmp!.fullName : 'Admin';
    _receivedByController = TextEditingController(text: adminName);

    _referenceController = TextEditingController(
      text: 'Direct cash payment received by $adminName',
    );

    _amountController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _receivedByController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _paymentDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final enteredAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (enteredAmount <= 0) return;

    setState(() => _isSubmitting = true);

    try {
      final todayFormatted = DateFormat('yyyy-MM-dd').format(_paymentDate);
      final repo = ref.read(loanRepositoryProvider);

      await repo.recordDirectPayment(
        loanId: widget.loan.loanId,
        amount: enteredAmount,
        month: _selectedMonth,
        paymentDate: todayFormatted,
        paymentMode: _selectedPaymentMode,
        referenceNote: _referenceController.text.trim(),
        receivedBy: _receivedByController.text.trim(),
      );

      ref.invalidate(loanByIdProvider(widget.loan.id));
      ref.invalidate(allLoansProvider);
      ref.invalidate(employeeLoansProvider(widget.loan.employeeId));

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Direct payment of ${_currencyFormat.format(enteredAmount)} recorded successfully for ${widget.loan.loanId}.',
            ),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to record direct payment: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentBalance = widget.loan.actualRemainingBalance;
    final enteredAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final newBalance = (currentBalance - enteredAmount).clamp(0.0, widget.loan.totalRepayableAmount);
    final monthEmi = widget.loan.emiAmount;

    // Available months list: use loan schedule months or standard list
    List<String> monthsList = widget.loan.scheduleMonths;
    if (monthsList.isEmpty) {
      monthsList = [widget.loan.firstDeductionMonth.isNotEmpty ? widget.loan.firstDeductionMonth : 'October 2026'];
    }
    if (!monthsList.contains(_selectedMonth)) {
      monthsList = [_selectedMonth, ...monthsList];
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.payments_outlined,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Record Direct Payment',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Receive cash or direct payment to admin outside payroll',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // Loan & Employee Info Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.loan.employeeName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Text(
                                '${widget.loan.employeeCustomId} • ${widget.loan.department}',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              widget.loan.loanId,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildMiniStat('Loan Amount', _currencyFormat.format(widget.loan.loanAmount)),
                          _buildMiniStat('Monthly EMI', _currencyFormat.format(widget.loan.emiAmount)),
                          _buildMiniStat(
                            'Current Balance',
                            _currencyFormat.format(currentBalance),
                            color: Colors.blue.shade800,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Amount Field
                const Text(
                  'Payment Amount (₹) *',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF344054)),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.currency_rupee, size: 18),
                    hintText: 'Enter amount (e.g. 3000)',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter payment amount';
                    }
                    final val = double.tryParse(value.trim());
                    if (val == null || val <= 0) {
                      return 'Enter a valid amount greater than 0';
                    }
                    if (val > currentBalance) {
                      return 'Amount cannot exceed outstanding balance (${_currencyFormat.format(currentBalance)})';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Month & Date Row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'For Month / Cycle *',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF344054)),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedMonth,
                            isExpanded: true,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            items: monthsList.map((m) {
                              return DropdownMenuItem<String>(
                                value: m,
                                child: Text(m, style: const TextStyle(fontSize: 13)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedMonth = val);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Payment Date *',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF344054)),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: _pickDate,
                            borderRadius: BorderRadius.circular(8),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                suffixIcon: const Icon(Icons.calendar_today, size: 16),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: Text(
                                DateFormat('dd MMM yyyy').format(_paymentDate),
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Payment Mode & Received By Row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Payment Mode *',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF344054)),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedPaymentMode,
                            isExpanded: true,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'Cash', child: Text('Cash', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: 'UPI / Online', child: Text('UPI / Online', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: 'Cheque', child: Text('Cheque', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: 'Direct to Admin', child: Text('Direct to Admin', style: TextStyle(fontSize: 13))),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedPaymentMode = val;
                                  _referenceController.text = 'Direct $val payment received by ${_receivedByController.text}';
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Received By (Admin) *',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF344054)),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _receivedByController,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Reference / Notes Field
                const Text(
                  'Reference / Receipt Notes',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF344054)),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _referenceController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Enter receipt number or reference note...',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 18),

                // Real-time Impact Calculation Box
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: newBalance <= 0 ? Colors.green.shade50 : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: newBalance <= 0 ? Colors.green.shade300 : AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'New Outstanding Balance:',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                          ),
                          Text(
                            _currencyFormat.format(newBalance),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: newBalance <= 0 ? Colors.green.shade700 : AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (newBalance <= 0)
                        Row(
                          children: [
                            Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'This payment fully clears the loan! The loan will be marked as Closed.',
                                style: TextStyle(fontSize: 11, color: Colors.green.shade800, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        )
                      else if (enteredAmount >= monthEmi)
                        Row(
                          children: [
                            const Icon(Icons.check_circle_outline, size: 16, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                enteredAmount > monthEmi
                                    ? 'Covers full $_selectedMonth EMI plus ${_currencyFormat.format(enteredAmount - monthEmi)} advance towards principal. Payroll salary deduction for $_selectedMonth will be ₹0.'
                                    : 'Covers full $_selectedMonth EMI. Payroll salary deduction for $_selectedMonth will be ₹0.',
                                style: const TextStyle(fontSize: 11, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        )
                      else if (enteredAmount > 0)
                        Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Partial payment: Remaining ${_currencyFormat.format(monthEmi - enteredAmount)} will be deducted in $_selectedMonth payroll.',
                                style: TextStyle(fontSize: 11, color: Colors.blue.shade800, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check, size: 18),
                      label: Text(_isSubmitting ? 'Recording...' : 'Confirm & Record Payment'),
                      onPressed: _isSubmitting ? null : _submit,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
