import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../employee/providers/employee_providers.dart';
import '../../domain/employee_loan.dart';
import '../../providers/loan_providers.dart';

class ReviewEmiPauseDialog extends ConsumerStatefulWidget {
  final EmployeeLoan loan;
  final LoanEmiPauseRequest request;

  const ReviewEmiPauseDialog({
    required this.loan,
    required this.request,
    super.key,
  });

  static Future<bool?> show(
    BuildContext context, {
    required EmployeeLoan loan,
    required LoanEmiPauseRequest request,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ReviewEmiPauseDialog(loan: loan, request: request),
    );
  }

  @override
  ConsumerState<ReviewEmiPauseDialog> createState() => _ReviewEmiPauseDialogState();
}

class _ReviewEmiPauseDialogState extends ConsumerState<ReviewEmiPauseDialog> {
  final _remarksController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _processReview(String newStatus) async {
    setState(() => _isProcessing = true);

    try {
      final currentEmp = ref.read(currentEmployeeProvider);
      final reviewerName = currentEmp?.fullName ?? 'Administrator';

      await ref.read(loanRepositoryProvider).reviewEmiPauseRequest(
        loanId: widget.loan.loanId,
        requestId: widget.request.requestId,
        status: newStatus,
        reviewedBy: reviewerName,
        adminRemarks: _remarksController.text.trim(),
      );

      ref.invalidate(loanByIdProvider(widget.loan.id));
      ref.invalidate(allLoansProvider);
      ref.invalidate(employeeLoansProvider(widget.loan.employeeId));
      ref.invalidate(pendingPauseRequestsProvider);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('EMI Pause request for ${widget.request.month} $newStatus.'),
            backgroundColor: newStatus == 'Approved' ? AppColors.primary : Colors.red.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update request: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
              color: Colors.amber.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.rule_folder_outlined, color: Colors.amber.shade800, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Review EMI Pause Request',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
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
                  _buildDetailRow('Employee', '${widget.loan.employeeName} (${widget.loan.employeeCustomId})'),
                  const SizedBox(height: 6),
                  _buildDetailRow('Loan ID', widget.loan.loanId),
                  const SizedBox(height: 6),
                  _buildDetailRow('Month to Pause', widget.request.month, highlight: true),
                  const SizedBox(height: 6),
                  _buildDetailRow('Reason', widget.request.reason),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Admin Remarks (Optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            TextField(
              controller: _remarksController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Enter approval note or rejection reason...',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
              ),
            ),
            const SizedBox(height: 14),
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
                      'Approving this request will skip EMI deduction (₹0) for ${widget.request.month}. The salary deduction will recover 2× EMI in the subsequent payroll cycle.',
                      style: TextStyle(color: Colors.blue.shade900, fontSize: 12, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
        ),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red.shade700,
            side: BorderSide(color: Colors.red.shade300),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _isProcessing ? null : () => _processReview('Rejected'),
          child: const Text('Reject Request', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _isProcessing ? null : () => _processReview('Approved'),
          child: _isProcessing
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Approve Pause', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool highlight = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: highlight ? FontWeight.bold : FontWeight.w600,
              color: highlight ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
