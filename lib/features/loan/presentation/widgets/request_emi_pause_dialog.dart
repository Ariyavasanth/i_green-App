import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/employee_loan.dart';
import '../../providers/loan_providers.dart';

class RequestEmiPauseDialog extends ConsumerStatefulWidget {
  final EmployeeLoan loan;

  const RequestEmiPauseDialog({required this.loan, super.key});

  static Future<bool?> show(BuildContext context, EmployeeLoan loan) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => RequestEmiPauseDialog(loan: loan),
    );
  }

  @override
  ConsumerState<RequestEmiPauseDialog> createState() => _RequestEmiPauseDialogState();
}

class _RequestEmiPauseDialogState extends ConsumerState<RequestEmiPauseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _amountController = TextEditingController();
  late String _selectedMonth;
  late List<String> _availableMonths;
  String _requestType = 'Flexible'; // 'Flexible' or 'Pause'
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Default partial amount to 50% of regular EMI rounded
    final defaultPartial = (widget.loan.emiAmount / 2).roundToDouble();
    _amountController.text = defaultPartial > 0 ? defaultPartial.toStringAsFixed(0) : '1000';

    // Eligible months are upcoming unpaid schedule months that are not already approved or pending
    final paidCount = widget.loan.paidInstallments;
    final allMonths = widget.loan.scheduleMonths;
    final remainingMonths = paidCount < allMonths.length ? allMonths.sublist(paidCount) : allMonths;

    _availableMonths = remainingMonths.where((m) {
      final existing = widget.loan.getPauseRequestForMonth(m);
      return existing == null || existing.status.toLowerCase() == 'rejected' || existing.status.toLowerCase() == 'cancelled';
    }).toList();

    if (_availableMonths.isEmpty && remainingMonths.isNotEmpty) {
      _availableMonths = [remainingMonths.first];
    } else if (_availableMonths.isEmpty) {
      _availableMonths = [DateFormat('MMMM yyyy').format(DateTime.now())];
    }

    _selectedMonth = _availableMonths.first;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final customAmount = _requestType == 'Flexible' ? double.tryParse(_amountController.text.trim()) : 0.0;
      final request = LoanEmiPauseRequest(
        requestId: 'REQ_${DateTime.now().millisecondsSinceEpoch}',
        loanId: widget.loan.loanId,
        employeeId: widget.loan.employeeId,
        employeeName: widget.loan.employeeName,
        month: _selectedMonth,
        reason: _reasonController.text.trim(),
        status: 'Pending',
        requestedAt: DateTime.now().toIso8601String(),
        requestType: _requestType,
        requestedAmount: customAmount,
      );

      await ref.read(loanRepositoryProvider).submitEmiPauseRequest(request);

      ref.invalidate(loanByIdProvider(widget.loan.id));
      ref.invalidate(allLoansProvider);
      ref.invalidate(employeeLoansProvider(widget.loan.employeeId));
      ref.invalidate(pendingPauseRequestsProvider);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _requestType == 'Flexible'
                  ? 'Flexible EMI request (₹${customAmount?.toStringAsFixed(0)}) for $_selectedMonth submitted.'
                  : 'EMI Pause request for $_selectedMonth submitted successfully.',
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
            content: Text('Failed to submit request: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatCurrency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final regularEmi = widget.loan.emiAmount;
    final enteredAmt = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final carriedForwardAmt = (regularEmi - enteredAmt).clamp(0.0, regularEmi);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.currency_exchange, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Flexible EMI / Pause Request',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
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
                        const Text('Loan ID', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        Text(widget.loan.loanId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Regular EMI', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        Text(formatCurrency.format(widget.loan.emiAmount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Remaining Balance', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        Text(formatCurrency.format(widget.loan.actualRemainingBalance), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Request Type Tabs / Segment
              const Text('Request Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() => _requestType = 'Flexible'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _requestType == 'Flexible' ? AppColors.primary.withValues(alpha: 0.12) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _requestType == 'Flexible' ? AppColors.primary : const Color(0xFFCBD5E1),
                            width: _requestType == 'Flexible' ? 1.5 : 1.0,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.payments_outlined,
                              size: 20,
                              color: _requestType == 'Flexible' ? AppColors.primary : AppColors.textSecondary,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Flexible EMI (Partial)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _requestType == 'Flexible' ? AppColors.primary : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() => _requestType = 'Pause'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _requestType == 'Pause' ? AppColors.primary.withValues(alpha: 0.12) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _requestType == 'Pause' ? AppColors.primary : const Color(0xFFCBD5E1),
                            width: _requestType == 'Pause' ? 1.5 : 1.0,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.pause_circle_outline,
                              size: 20,
                              color: _requestType == 'Pause' ? AppColors.primary : AppColors.textSecondary,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Full Pause (Defer)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _requestType == 'Pause' ? AppColors.primary : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Month Selector
              const Text('Select Month', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedMonth,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                ),
                items: _availableMonths.map((m) {
                  return DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 14)));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedMonth = val);
                },
              ),
              const SizedBox(height: 16),

              // If Flexible, Amount Field
              if (_requestType == 'Flexible') ...[
                const Text(
                  'Affordable Deduction Amount for this Month (₹) *',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    prefixText: '₹ ',
                    hintText: 'e.g. 1000',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (val) {
                    if (_requestType != 'Flexible') return null;
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter the amount you can afford to pay';
                    }
                    final parsed = double.tryParse(val.trim());
                    if (parsed == null || parsed <= 0) {
                      return 'Amount must be greater than ₹0';
                    }
                    if (parsed >= widget.loan.emiAmount) {
                      return 'Must be less than regular EMI (${formatCurrency.format(widget.loan.emiAmount)})';
                    }
                    if (parsed > widget.loan.actualRemainingBalance) {
                      return 'Cannot exceed remaining balance (${formatCurrency.format(widget.loan.actualRemainingBalance)})';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
              ],

              // Reason
              const Text('Reason *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: _requestType == 'Flexible'
                      ? 'e.g. Facing temporary cash crunch. Requesting ₹1,000 deduction this month.'
                      : 'e.g. Unexpected medical expense this month. Please defer EMI to next month.',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a reason for your request';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Informative Notice
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade800, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _requestType == 'Flexible'
                            ? 'If approved, only ${formatCurrency.format(enteredAmt)} will be deducted in $_selectedMonth. The unpaid ${formatCurrency.format(carriedForwardAmt)} will accumulate in your remaining balance. If any balance remains when the original loan duration ends, the admin will determine the extension schedule.'
                            : 'If approved, ₹0 will be deducted in $_selectedMonth. The full EMI will carry forward to subsequent cycles or be scheduled by the admin upon tenure completion.',
                        style: TextStyle(color: Colors.blue.shade900, fontSize: 12, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Submit Request', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
