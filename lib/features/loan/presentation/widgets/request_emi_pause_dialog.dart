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
  late String _selectedMonth;
  late List<String> _availableMonths;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final request = LoanEmiPauseRequest(
        requestId: 'PAUSE_${DateTime.now().millisecondsSinceEpoch}',
        loanId: widget.loan.loanId,
        employeeId: widget.loan.employeeId,
        employeeName: widget.loan.employeeName,
        month: _selectedMonth,
        reason: _reasonController.text.trim(),
        status: 'Pending',
        requestedAt: DateTime.now().toIso8601String(),
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
            content: Text('EMI Pause request for $_selectedMonth submitted successfully.'),
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
            child: const Icon(Icons.pause_circle_outline, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Request EMI Pause / Skip',
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
                        const Text('Monthly EMI', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        Text(formatCurrency.format(widget.loan.emiAmount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Balance', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        Text(formatCurrency.format(widget.loan.actualRemainingBalance), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Month Selector
              const Text('Select Month to Skip', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedMonth,
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

              // Reason
              const Text('Reason for Deferral *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'e.g. Unexpected medical expense this month. Please defer EMI to next month.',
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
                    return 'Please enter a reason for pausing your EMI';
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
                        'If approved, ₹0 will be deducted in $_selectedMonth. The deferred EMI will be automatically recovered in the following month\'s payroll (2× EMI).',
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
