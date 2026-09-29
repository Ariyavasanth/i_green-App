import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../employee/providers/employee_providers.dart';
import '../../employee/services/offer_letter_save_stub.dart'
    if (dart.library.html) '../../employee/services/offer_letter_save_web.dart'
    if (dart.library.io) '../../employee/services/offer_letter_save_io.dart';
import '../../organization/providers/organization_providers.dart';
import '../../payroll/domain/payroll.dart';
import '../../payroll/providers/payroll_providers.dart';
import '../domain/employee_loan.dart';
import '../providers/loan_providers.dart';
import '../services/loan_statement_pdf_generator.dart';
import 'widgets/approve_loan_dialog.dart';

class LoanDetailsPage extends ConsumerWidget {
  const LoanDetailsPage({required this.loanId, super.key});
  final int loanId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loanAsync = ref.watch(loanByIdProvider(loanId));
    final payrollsAsync = ref.watch(allPayrollRecordsProvider);
    final currentEmp = ref.watch(currentEmployeeProvider);

    final location = GoRouterState.of(context).uri.path;
    final isEmployeeRoute = location.startsWith('/loan/details');
    final isAdminManagementView = !isEmployeeRoute &&
        currentEmp != null &&
        (currentEmp.isSuperAdmin || currentEmp.hasPermission('Loan Management'));

    final isMobile = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Loan Details',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
      ),
      body: loanAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading loan: $err')),
        data: (loan) {
          if (loan == null) {
            return const Center(child: Text('Loan not found.'));
          }

          final statusNorm = loan.status.trim().toLowerCase();
          final isPendingOrRejected = statusNorm.startsWith('pending') || statusNorm == 'rejected';

          // In employee route (/loan/details/...) or for regular employees,
          // pending and rejected loans only show application & approval tracking status.
          if ((isEmployeeRoute || !isAdminManagementView) && isPendingOrRejected) {
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(loanByIdProvider(loanId));
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(isMobile ? 16 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildEmployeeCard(loan),
                    const SizedBox(height: 16),
                    _buildEmployeeApplicationStatusCard(loan),
                  ],
                ),
              ),
            );
          }

          // Full details view for Approved/Active/Closed loans or Admin Management view
          return payrollsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error loading payroll: $err')),
            data: (payrolls) {
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(loanByIdProvider(loanId));
                  ref.invalidate(allPayrollRecordsProvider);
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(isMobile ? 16 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildEmployeeCard(loan),
                      const SizedBox(height: 16),
                      _buildLoanSummaryCard(context, ref, loan),
                      const SizedBox(height: 16),
                      _buildRepaymentScheduleCard(context, ref, loan, payrolls),
                      if (isAdminManagementView) ...[
                        const SizedBox(height: 16),
                        _buildActionFooter(context, ref, loan),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmployeeApplicationStatusCard(EmployeeLoan loan) {
    final formatCurrency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final isRejected = loan.status.trim().toLowerCase() == 'rejected';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.assignment_outlined, color: AppColors.active, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'My Loan Application',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ],
              ),
              _buildStatusPill(loan.status),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          const SizedBox(height: 14),

          _buildRowDetail('Loan ID', loan.loanId),
          _buildRowDetail('Loan Type', loan.loanType),
          _buildRowDetail('Requested Amount', formatCurrency.format(loan.loanAmount)),
          _buildRowDetail('Application Date', loan.loanDate.isNotEmpty ? loan.loanDate : '-'),
          _buildRowDetail('Purpose', loan.purpose.isNotEmpty ? loan.purpose : '-'),
          if (loan.remarks.isNotEmpty)
            _buildRowDetail('Description', loan.remarks),
          _buildRowDetail('Requested By', loan.requestedBy),

          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          const SizedBox(height: 16),

          const Text(
            'Approval Workflow Status',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          _buildApprovalStepper(loan),

          const SizedBox(height: 20),
          if (isRejected)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.cancel_outlined, color: Colors.red, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Loan Application Rejected',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13),
                        ),
                        if (loan.remarks.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Reason: ${loan.remarks}',
                            style: TextStyle(color: Colors.red.shade900, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF64748B), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your loan summary, monthly EMI, and repayment schedule will be available once the loan is approved.',
                      style: TextStyle(color: Color(0xFF475569), fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildApprovalStepper(EmployeeLoan loan) {
    final status = loan.status.trim().toLowerCase();

    final isSubmitted = true;
    final isApproved = status == 'approved' || status == 'active' || status == 'closed';
    final isPending = status.startsWith('pending');

    final steps = [
      (
        'Submitted',
        'Application lodged',
        isSubmitted,
        true,
      ),
      (
        'Management Approval',
        isApproved
            ? 'Approved'
            : (isPending ? 'Pending Review & Approval' : 'Pending'),
        isApproved,
        isPending,
      ),
    ];

    return Column(
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: steps[i].$3
                          ? const Color(0xFF9CC70A)
                          : (steps[i].$4 ? Colors.amber.shade700 : const Color(0xFFE2E8F0)),
                    ),
                    child: Icon(
                      steps[i].$3
                          ? Icons.check
                          : (steps[i].$4 ? Icons.access_time : Icons.circle),
                      size: 14,
                      color: steps[i].$3 || steps[i].$4 ? Colors.white : const Color(0xFF94A3B8),
                    ),
                  ),
                  if (i < steps.length - 1)
                    Container(
                      width: 2,
                      height: 32,
                      color: steps[i + 1].$3
                          ? const Color(0xFF9CC70A)
                          : const Color(0xFFE2E8F0),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      steps[i].$1,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: steps[i].$3 || steps[i].$4
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      steps[i].$2,
                      style: TextStyle(
                        fontSize: 11,
                        color: steps[i].$4 ? Colors.amber.shade800 : AppColors.textSecondary,
                        fontWeight: steps[i].$4 ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildStatusPill(String status) {
    Color color = Colors.grey.shade700;
    Color bgColor = Colors.grey.shade100;
    final norm = status.trim().toLowerCase();

    if (norm == 'active') {
      color = AppColors.primary;
      bgColor = AppColors.primary.withValues(alpha: 0.12);
    } else if (norm.startsWith('pending')) {
      color = Colors.orange.shade800;
      bgColor = Colors.orange.shade50;
    } else if (norm == 'approved') {
      color = Colors.blue.shade700;
      bgColor = Colors.blue.shade50;
    } else if (norm == 'rejected') {
      color = Colors.red.shade700;
      bgColor = Colors.red.shade50;
    } else if (norm == 'closed') {
      color = Colors.grey.shade600;
      bgColor = Colors.grey.shade100;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildEmployeeCard(EmployeeLoan loan) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          const SizedBox(height: 14),
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
    final hasRepaymentDetails = loan.installments > 0 && loan.firstDeductionMonth.isNotEmpty && loan.scheduleMonths.isNotEmpty;

    if (!hasRepaymentDetails) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
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
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            const SizedBox(height: 14),
            _buildRowDetail('Loan ID', loan.loanId),
            _buildRowDetail('Loan Type', loan.loanType),
            _buildRowDetail('Requested Amount', formatCurrency.format(loan.loanAmount)),
            _buildRowDetail('Application Date', loan.loanDate.isNotEmpty ? loan.loanDate : '-'),
            _buildRowDetail('Purpose', loan.purpose.isNotEmpty ? loan.purpose : '-'),
            if (loan.remarks.isNotEmpty)
              _buildRowDetail('Description', loan.remarks),
            _buildRowDetail('Requested By', loan.requestedBy),
            _buildRowDetail('Status', loan.status, isStatus: true),
          ],
        ),
      );
    }

    final totalInterest = loan.interestRate > 0
        ? loan.calculatedTotalInterest
        : (loan.totalRepayableAmount - loan.loanAmount).clamp(0.0, double.infinity);
    final totalRepayable = loan.interestRate > 0
        ? loan.calculatedTotalRepayable
        : (loan.totalRepayableAmount > 0 ? loan.totalRepayableAmount : loan.loanAmount);
    final monthlyPrincipal = loan.monthlyPrincipal;
    final firstMonthEmi = loan.emiForInstallment(0);
    final lastMonthEmi = loan.emiForInstallment(loan.installments > 0 ? loan.installments - 1 : 0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          const SizedBox(height: 14),
          _buildRowDetail('Loan ID', loan.loanId),
          _buildRowDetail('Loan Type', loan.loanType),
          _buildRowDetail('Principal Amount', formatCurrency.format(loan.loanAmount)),
          _buildRowDetail('Interest Rate', '${loan.interestRate}% (Reducing Balance)'),
          if (loan.interestRate > 0 || totalInterest > 0) ...[
            _buildRowDetail('Total Interest Amount', formatCurrency.format(totalInterest)),
            _buildRowDetail('Monthly Principal', formatCurrency.format(monthlyPrincipal)),
            _buildRowDetail('1st Month Interest', formatCurrency.format(loan.interestForInstallment(0))),
            _buildRowDetail('1st Month EMI', formatCurrency.format(firstMonthEmi)),
            if (loan.installments > 1)
              _buildRowDetail('Last Month EMI', formatCurrency.format(lastMonthEmi)),
          ],
          _buildRowDetail('Total Repayable', formatCurrency.format(totalRepayable)),
          _buildRowDetail('Total Paid', formatCurrency.format(loan.totalPaid)),
          _buildRowDetail('Remaining Balance', formatCurrency.format(loan.actualRemainingBalance)),
          _buildRowDetail('Paid Installments', '${loan.paidInstallments} of ${loan.installments}'),
          _buildRowDetail('Remaining Installments', '${loan.remainingInstallments}'),
          _buildRowDetail('First Deduction Month', loan.firstDeductionMonth),
          _buildRowDetail('Last Deduction Month', loan.lastDeductionMonth),
          _buildRowDetail('Next EMI Month', loan.nextEmiMonth),
          _buildRowDetail('Disbursement Date', loan.disbursementDate.isNotEmpty ? loan.disbursementDate : '-'),
          _buildRowDetail('Purpose', loan.purpose.isNotEmpty ? loan.purpose : '-'),
          if (loan.remarks.isNotEmpty)
            _buildRowDetail('Description', loan.remarks),
          _buildRowDetail('Requested By', loan.requestedBy),
          _buildRowDetail('Approved By', loan.approvedBy.isNotEmpty ? loan.approvedBy : '-'),
          _buildRowDetail('Status', loan.status, isStatus: true),
        ],
      ),
    );
  }

  Widget _buildRepaymentScheduleCard(
    BuildContext context,
    WidgetRef ref,
    EmployeeLoan loan,
    List<PayrollRecord> payrolls,
  ) {
    final formatCurrency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final hasRepaymentDetails = loan.installments > 0 && loan.firstDeductionMonth.isNotEmpty && loan.scheduleMonths.isNotEmpty;
    final scheduleMonths = loan.scheduleMonths;
    final monthlyPrincipal = loan.monthlyPrincipal;

    if (!hasRepaymentDetails) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF64748B), size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Repayment details have not been configured by an administrator yet.',
                      style: TextStyle(color: Color(0xFF475569), fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_month_outlined, color: AppColors.active, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Repayment Schedule',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.download_outlined, size: 16),
                    label: const Text('Download Statement', style: TextStyle(fontSize: 12)),
                    onPressed: () => _downloadStatement(context, ref, loan, payrolls),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${loan.paidInstallments} / ${loan.installments} Paid',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 40,
              dataRowMinHeight: 44,
              columns: const [
                DataColumn(label: Text('Month', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Principal', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Interest', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Total EMI', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Paid', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Remaining', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Payroll Ref', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: List<DataRow>.generate(scheduleMonths.length, (index) {
                final month = scheduleMonths[index];
                final monthInterest = loan.interestForInstallment(index);
                final monthEmi = loan.emiForInstallment(index);
                final endingPrincipal = loan.endPrincipalForInstallment(index);

                // Check if repayment ledger has an entry for this month
                final ledgerRepayment = loan.repayments.where((r) => r.month.trim().toLowerCase() == month.trim().toLowerCase()).firstOrNull;

                // Check if payroll has a paid record
                final matchingPayroll = payrolls.where((p) =>
                    p.employeeId == loan.employeeId &&
                    p.month.trim().toLowerCase() == month.trim().toLowerCase() &&
                    p.status.toLowerCase() == 'paid' &&
                    p.companyLoan > 0).firstOrNull;

                final isPaid = ledgerRepayment != null || matchingPayroll != null || index < loan.paidInstallments;
                final paidAmount = isPaid ? (ledgerRepayment?.amount ?? monthEmi) : 0.0;

                final payrollRef = ledgerRepayment?.payrollId.isNotEmpty == true
                    ? ledgerRepayment!.payrollId
                    : (matchingPayroll != null ? matchingPayroll.month : '-');

                return DataRow(
                  cells: [
                    DataCell(Text(month, style: const TextStyle(fontWeight: FontWeight.w500))),
                    DataCell(Text(formatCurrency.format(monthlyPrincipal))),
                    DataCell(Text(
                      formatCurrency.format(monthInterest),
                      style: TextStyle(
                        color: monthInterest > 0 ? Colors.orange.shade800 : AppColors.textSecondary,
                        fontWeight: monthInterest > 0 ? FontWeight.w600 : FontWeight.normal,
                      ),
                    )),
                    DataCell(Text(
                      formatCurrency.format(monthEmi),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    )),
                    DataCell(Text(formatCurrency.format(paidAmount))),
                    DataCell(Text(formatCurrency.format(endingPrincipal))),
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
              label: const Text('Approve Loan'),
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
    await ApproveLoanDialog.show(context, loan);
  }

  Future<void> _downloadStatement(
    BuildContext context,
    WidgetRef ref,
    EmployeeLoan loan,
    List<PayrollRecord> payrolls,
  ) async {
    try {
      final employeesList = ref.read(employeesProvider).asData?.value ?? [];
      final employee = employeesList.where((e) =>
          e.id == loan.employeeId ||
          e.employeeId.trim().toUpperCase() == loan.employeeCustomId.trim().toUpperCase()
      ).firstOrNull;

      final orgList = ref.read(organizationsProvider).asData?.value ?? [];
      final org = orgList.firstOrNull;

      final pdfBytes = await LoanStatementPdfGenerator.generateStatementPdf(
        loan: loan,
        employee: employee,
        organization: org,
        payrolls: payrolls,
      );

      final cleanLoanId = loan.loanId.replaceAll(RegExp(r'[^\w\-_]'), '_');
      final cleanName = loan.employeeName.replaceAll(RegExp(r'[^\w\-_]'), '_');
      final fileName = 'Loan_Statement_${cleanLoanId}_$cleanName.pdf';

      if (context.mounted) {
        await saveAndDownloadOfferLetter(
          context: context,
          bytes: pdfBytes,
          fileName: fileName,
          docTitle: 'Loan Statement',
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download loan statement: $e'),
            backgroundColor: Colors.red[800],
          ),
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
        case 'pending supervisor':
        case 'pending hr':
        case 'pending md':
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
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

