import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Loan Details',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
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
                    _buildLoanSummaryCard(loan, payrolls),
                    const SizedBox(height: 20),
                    _buildEmiHistoryCard(loan, payrolls),
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

  Widget _buildLoanSummaryCard(EmployeeLoan loan, List<dynamic> payrolls) {
    final formatCurrency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final paidAmount = loan.totalRepayableAmount - loan.remainingBalance;

    // Determine Next EMI Month
    final installmentsList = _generateInstallments(loan);
    int paidCount = loan.emiAmount > 0 ? (paidAmount / loan.emiAmount).round() : 0;
    String nextEmiMonth = 'None';
    if (loan.remainingBalance > 0 && installmentsList.isNotEmpty) {
      if (paidCount < installmentsList.length) {
        nextEmiMonth = installmentsList[paidCount];
      } else {
        nextEmiMonth = installmentsList.last;
      }
    }

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
          _buildRowDetail('Loan Amount', formatCurrency.format(loan.loanAmount)),
          _buildRowDetail('Interest Rate', '${loan.interestRate}%'),
          _buildRowDetail('Total Repayable', formatCurrency.format(loan.totalRepayableAmount)),
          _buildRowDetail('Paid Amount', formatCurrency.format(paidAmount)),
          _buildRowDetail('Remaining Balance', formatCurrency.format(loan.remainingBalance)),
          _buildRowDetail('Monthly EMI', formatCurrency.format(loan.emiAmount)),
          _buildRowDetail('Next EMI Month', nextEmiMonth),
          _buildRowDetail('Purpose', loan.purpose),
          _buildRowDetail('Requested By', loan.requestedBy),
          _buildRowDetail('Approved By', loan.approvedBy.isNotEmpty ? loan.approvedBy : '-'),
          _buildRowDetail('Status', loan.status, isStatus: true),
        ],
      ),
    );
  }

  Widget _buildEmiHistoryCard(EmployeeLoan loan, List<dynamic> payrolls) {
    final formatCurrency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final installmentsList = _generateInstallments(loan);
    final paidAmount = loan.totalRepayableAmount - loan.remainingBalance;
    int calculatedPaidCount = loan.emiAmount > 0 ? (paidAmount / loan.emiAmount).round() : 0;

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
              Icon(Icons.history_outlined, color: AppColors.active, size: 20),
              SizedBox(width: 8),
              Text(
                'EMI History',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.divider, thickness: 0.5),
          const SizedBox(height: 12),
          if (installmentsList.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('No installments defined for this loan.')),
            )
          else
            Table(
              columnWidths: const {
                0: FlexColumnWidth(4),
                1: FlexColumnWidth(3),
                2: FlexColumnWidth(3),
              },
              children: [
                const TableRow(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
                  ),
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Month', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('EMI', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                    ),
                  ],
                ),
                for (int i = 0; i < installmentsList.length; i++) ...[
                  (() {
                    final month = installmentsList[i];
                    // A month is paid if:
                    // 1. We have a payroll record for this employee and month where company_loan is matching EMI and description matches
                    // 2. OR, if the index of this installment is less than calculatedPaidCount (for historical seeded data)
                    final isPayrollPaid = payrolls.any((p) =>
                        p.employeeId == loan.employeeId &&
                        p.month.trim().toLowerCase() == month.trim().toLowerCase() &&
                        p.companyLoan > 0 &&
                        p.loanDescription.trim() == loan.loanId);

                    final isPaid = isPayrollPaid || (i < calculatedPaidCount);

                    return TableRow(
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(month, style: const TextStyle(fontWeight: FontWeight.w500)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(formatCurrency.format(loan.emiAmount)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              Icon(
                                isPaid ? Icons.check_circle : Icons.pending_actions,
                                size: 16,
                                color: isPaid ? AppColors.primary : Colors.orange,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isPaid ? 'Paid' : 'Pending',
                                style: TextStyle(
                                  color: isPaid ? AppColors.primary : Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }())
                ]
              ],
            ),
        ],
      ),
    );
  }

  List<String> _generateInstallments(EmployeeLoan loan) {
    if (loan.installments <= 0 || loan.firstDeductionMonth.isEmpty) return [];
    final list = <String>[];
    final parts = loan.firstDeductionMonth.split(' ');
    if (parts.length < 2) return [loan.firstDeductionMonth];
    final monthName = parts[0];
    final year = int.tryParse(parts[1]) ?? DateTime.now().year;

    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final startIndex = months.indexOf(monthName);
    if (startIndex == -1) return [loan.firstDeductionMonth];

    for (int i = 0; i < loan.installments; i++) {
      final totalMonths = startIndex + i;
      final mIndex = totalMonths % 12;
      final yOffset = totalMonths ~/ 12;
      list.add('${months[mIndex]} ${year + yOffset}');
    }
    return list;
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
