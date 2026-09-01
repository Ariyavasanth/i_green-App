import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../employee/providers/employee_providers.dart';
import '../../payroll/domain/payroll.dart';
import '../../payroll/providers/payroll_providers.dart';
import '../domain/employee_loan.dart';
import '../providers/loan_providers.dart';

class LoanDetailsPage extends ConsumerWidget {
  const LoanDetailsPage({required this.loanId, super.key});
  final int loanId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loanAsync = ref.watch(loanByIdProvider(loanId));
    final payrollsAsync = ref.watch(allPayrollRecordsProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: loanAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading loan: $err')),
        data: (loan) {
          if (loan == null) {
            return const Center(child: Text('Loan not found.'));
          }

          return payrollsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error loading payroll: $err')),
            data: (payrolls) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildEmployeeCard(loan),
                    const SizedBox(height: 20),
                    _buildLoanSummaryCard(context, ref, loan),
                    const SizedBox(height: 20),
                    _buildRepaymentScheduleCard(loan, payrolls),
                    const SizedBox(height: 20),
                    _buildActionFooter(context, ref, loan),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmployeeCard(EmployeeLoan loan) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.person_outline, color: AppColors.active, size: 20),
              SizedBox(width: 8),
              Text(
                'Employee Information',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.divider, thickness: 0.5),
          const SizedBox(height: 16),
          _buildRowDetail('Employee Name', loan.employeeName),
          _buildRowDetail('Employee ID', loan.employeeCustomId),
          _buildRowDetail('Department', loan.department),
          _buildRowDetail('Designation', loan.designation),
        ],
      ),
    );
  }

  Widget _buildLoanSummaryCard(BuildContext context, WidgetRef ref, EmployeeLoan loan) {
    final formatCurrency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_balance_outlined, color: AppColors.active, size: 20),
              SizedBox(width: 8),
              Text(
                'Loan Summary',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.divider, thickness: 0.5),
          const SizedBox(height: 16),
          _buildRowDetail('Loan ID', loan.loanId),
          _buildRowDetail('Loan Type', loan.loanType),
          _buildRowDetail('Principal Amount', formatCurrency.format(loan.loanAmount)),
          _buildRowDetail('Interest Rate', '${loan.interestRate}%'),
          _buildRowDetail('Total Repayable', formatCurrency.format(loan.totalRepayableAmount)),
          _buildRowDetail('Monthly EMI', formatCurrency.format(loan.emiAmount)),
          _buildRowDetail('Total Paid', formatCurrency.format(loan.totalPaid)),
          _buildRowDetail('Remaining Balance', formatCurrency.format(loan.actualRemainingBalance)),
          _buildRowDetail('Paid Installments', '${loan.paidInstallments} of ${loan.installments}'),
          _buildRowDetail('Remaining Installments', '${loan.remainingInstallments}'),
          _buildRowDetail('First Deduction Month', loan.firstDeductionMonth),
          _buildRowDetail('Last Deduction Month', loan.lastDeductionMonth),
          _buildRowDetail('Next EMI Month', loan.nextEmiMonth),
          _buildRowDetail('Disbursement Date', loan.disbursementDate.isNotEmpty ? loan.disbursementDate : '-'),
          _buildRowDetail('Purpose', loan.purpose.isNotEmpty ? loan.purpose : '-'),
          _buildRowDetail('Requested By', loan.requestedBy),
          _buildRowDetail('Approved By', loan.approvedBy.isNotEmpty ? loan.approvedBy : '-'),
          _buildRowDetail('Status', loan.status, isStatus: true),
        ],
      ),
    );
  }

  Widget _buildRepaymentScheduleCard(EmployeeLoan loan, List<PayrollRecord> payrolls) {
    final formatCurrency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final scheduleMonths = loan.scheduleMonths;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.calendar_month_outlined, color: AppColors.active, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Repayment Schedule',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ],
              ),
              Text(
                '${loan.paidInstallments} / ${loan.installments} Paid',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.divider, thickness: 0.5),
          const SizedBox(height: 12),
          if (scheduleMonths.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('No deduction schedule defined.')),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 40,
                dataRowMinHeight: 44,
                columns: const [
                  DataColumn(label: Text('Month', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('EMI', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Paid', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Remaining', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Payroll Ref', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: List<DataRow>.generate(scheduleMonths.length, (index) {
                  final month = scheduleMonths[index];

                  // Check if repayment ledger has an entry for this month
                  final ledgerRepayment = loan.repayments.where((r) => r.month.trim().toLowerCase() == month.trim().toLowerCase()).firstOrNull;

                  // Check if payroll has a paid record
                  final matchingPayroll = payrolls.where((p) =>
                      p.employeeId == loan.employeeId &&
                      p.month.trim().toLowerCase() == month.trim().toLowerCase() &&
                      p.status.toLowerCase() == 'paid' &&
                      p.companyLoan > 0).firstOrNull;

                  final isPaid = ledgerRepayment != null || matchingPayroll != null || index < loan.paidInstallments;
                  final paidAmount = isPaid ? (ledgerRepayment?.amount ?? loan.emiAmount) : 0.0;

                  // Calculate remaining balance at this step in the timeline
                  final runningPaid = (index + 1) * loan.emiAmount;
                  final expectedRemaining = isPaid
                      ? ((loan.totalRepayableAmount - runningPaid).clamp(0.0, loan.totalRepayableAmount))
                      : ((loan.totalRepayableAmount - (index * loan.emiAmount)).clamp(0.0, loan.totalRepayableAmount));

                  final payrollRef = ledgerRepayment?.payrollId.isNotEmpty == true
                      ? ledgerRepayment!.payrollId
                      : (matchingPayroll != null ? matchingPayroll.month : '-');

                  return DataRow(
                    cells: [
                      DataCell(Text(month, style: const TextStyle(fontWeight: FontWeight.w500))),
                      DataCell(Text(formatCurrency.format(loan.emiAmount))),
                      DataCell(Text(formatCurrency.format(paidAmount))),
                      DataCell(Text(formatCurrency.format(expectedRemaining))),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPaid ? Icons.check_circle : (loan.status == 'Active' && index == loan.paidInstallments ? Icons.schedule : Icons.circle_outlined),
                              size: 14,
                              color: isPaid ? AppColors.primary : (loan.status == 'Active' && index == loan.paidInstallments ? Colors.orange : Colors.grey),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isPaid ? 'Paid' : (loan.status == 'Active' && index == loan.paidInstallments ? 'Upcoming' : 'Scheduled'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isPaid ? AppColors.primary : (loan.status == 'Active' && index == loan.paidInstallments ? Colors.orange : Colors.grey),
                              ),
                            ),
                          ],
                        ),
                      ),
                      DataCell(Text(payrollRef, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                    ],
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionFooter(BuildContext context, WidgetRef ref, EmployeeLoan loan) {
    final isPending = loan.status == 'Pending' || loan.status.startsWith('Pending ');
    final isApproved = loan.status == 'Approved';
    final isActive = loan.status == 'Active';

    if (!isPending && !isApproved && !isActive) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 12,
        runSpacing: 12,
        children: [
          if (isPending) ...[
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
              icon: const Icon(Icons.cancel_outlined, size: 16),
              label: const Text('Reject Loan'),
              onPressed: () => _confirmReject(context, ref, loan),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.check_circle_outline, size: 16),
              label: Text('Approve (${loan.status})'),
              onPressed: () => _approveLoan(context, ref, loan),
            ),
          ],
          if (isApproved)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.send_outlined, size: 16),
              label: const Text('Disburse / Activate Loan'),
              onPressed: () => _disburseLoan(context, ref, loan),
            ),
          if (isActive)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey[700],
              ),
              icon: const Icon(Icons.lock_outline, size: 16),
              label: const Text('Mark as Closed'),
              onPressed: () => _closeLoan(context, ref, loan),
            ),
        ],
      ),
    );
  }

  Future<void> _approveLoan(BuildContext context, WidgetRef ref, EmployeeLoan loan) async {
    try {
      final currentEmp = ref.read(currentEmployeeProvider);
      final approverName = currentEmp?.fullName ?? 'Admin';
      final approverRole = currentEmp?.userType ?? 'Admin';

      final nextStatus = await ref.read(loanRepositoryProvider).approveLoan(
        id: loan.id,
        approverName: approverName,
        approverRole: approverRole,
      );

      ref.invalidate(loanByIdProvider(loan.id));
      ref.invalidate(allLoansProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Loan updated to $nextStatus.'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to approve loan: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _disburseLoan(BuildContext context, WidgetRef ref, EmployeeLoan loan) async {
    try {
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await ref.read(loanRepositoryProvider).disburseLoan(loan.id, todayStr);
      ref.invalidate(loanByIdProvider(loan.id));
      ref.invalidate(allLoansProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Loan disbursed and is now Active.'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to disburse loan: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirmReject(BuildContext context, WidgetRef ref, EmployeeLoan loan) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dContext) => AlertDialog(
        title: const Text('Reject Loan Request'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Reason for rejection',
            hintText: 'Enter reason...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dContext, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(loanRepositoryProvider).rejectLoan(loan.id, reasonController.text);
      ref.invalidate(loanByIdProvider(loan.id));
      ref.invalidate(allLoansProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Loan rejected.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _closeLoan(BuildContext context, WidgetRef ref, EmployeeLoan loan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dContext) => AlertDialog(
        title: const Text('Close Loan'),
        content: const Text('Are you sure you want to close this loan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dContext, true),
            child: const Text('Confirm Close'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(loanRepositoryProvider).changeLoanStatus(loan.id, 'Closed');
      ref.invalidate(loanByIdProvider(loan.id));
      ref.invalidate(allLoansProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Loan marked as Closed.')),
        );
      }
    }
  }

  Widget _buildRowDetail(String label, String value, {bool isStatus = false}) {
    Color statusColor = AppColors.textPrimary;
    if (isStatus) {
      final norm = value.trim().toLowerCase();
      switch (norm) {
        case 'active':
        case 'approved':
          statusColor = AppColors.primary;
          break;
        case 'pending':
          statusColor = Colors.orange;
          break;
        case 'rejected':
          statusColor = Colors.redAccent;
          break;
        case 'closed':
          statusColor = Colors.grey;
          break;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }
}
