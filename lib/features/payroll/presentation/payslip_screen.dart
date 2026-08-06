import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/layout/responsive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/payroll.dart';
import '../providers/payroll_providers.dart';
import '../../leave/providers/leave_providers.dart';
import 'widgets/access_denied_view.dart';

class PayslipScreen extends ConsumerStatefulWidget {
  const PayslipScreen({required this.payrollId, super.key});
  final int payrollId;

  @override
  ConsumerState<PayslipScreen> createState() => _PayslipScreenState();
}

class _PayslipScreenState extends ConsumerState<PayslipScreen> {
  bool _downloading = false;

  String _maskBankAccount(String acctNo) {
    final clean = acctNo.trim();
    if (clean.length <= 4) return clean;
    return '${"*" * (clean.length - 4)}${clean.substring(clean.length - 4)}';
  }

  void _showMockAction(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _startDownloadFlow(BuildContext context, PayrollRecord record) async {
    setState(() {
      _downloading = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() {
      _downloading = false;
    });
    if (context.mounted) {
      _showMockAction(context, 'PDF Downloaded successfully!');
    }
  }

  void _showOverflowMenu(BuildContext context, WidgetRef ref, PayrollRecord record, bool isMobile) {
    if (isMobile) {
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.print_outlined),
                  title: const Text('Print'),
                  onTap: () {
                    Navigator.pop(context);
                    _showMockAction(context, 'Opening print layout...');
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.warning_amber_rounded, color: Colors.red),
                  title: const Text('Report an issue', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _showReportIssueDialog(context, ref, record);
                  },
                ),
              ],
            ),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final payrollAsync = ref.watch(payrollRecordByIdProvider(widget.payrollId));
    final employee = ref.watch(currentEmployeeProvider);
    final isEmployee = employee != null && employee.userType.toUpperCase() == 'EMPLOYEE';

    return payrollAsync.when(
      data: (record) {
        if (record == null) {
          return Scaffold(
            backgroundColor: AppColors.canvas,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                onPressed: () => context.pop(),
              ),
              title: const Text('Payslip Detail'),
            ),
            body: const Center(child: Text('Payroll record not found.')),
          );
        }

        if (isEmployee && record.employeeId != employee.id) {
          return const Scaffold(
            backgroundColor: AppColors.canvas,
            body: AccessDeniedView(),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < AppBreakpoints.tablet;
            final gutter = AppLayout.gutter(constraints.maxWidth);

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
                  'Payslip Detail',
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                ),
                actions: [
                  if (isMobile)
                    IconButton(
                      icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
                      onPressed: () => _showOverflowMenu(context, ref, record, true),
                    )
                  else
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
                      onSelected: (val) {
                        if (val == 'print') {
                          _showMockAction(context, 'Opening print layout...');
                        } else if (val == 'report') {
                          _showReportIssueDialog(context, ref, record);
                        }
                      },
                      color: Colors.white,
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'print',
                          child: Row(
                            children: [
                              Icon(Icons.print_outlined, size: 18),
                              SizedBox(width: 8),
                              Text('Print'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'report',
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
                              SizedBox(width: 8),
                              Text('Report an issue', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              body: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(gutter),
                  child: ResponsiveContent(
                    maxWidth: 720,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (record.isDisputed)
                          Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red[200]!),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'DISPUTE RAISED BY EMPLOYEE',
                                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        record.disputeComment,
                                        style: TextStyle(color: Colors.red[900], fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        _buildDetailCard(record, isMobile),
                        const SizedBox(height: 24),
                        _buildActionRow(context, record, isMobile),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => context.pop(),
          ),
          title: const Text('Payslip Detail'),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ResponsiveContent(
              maxWidth: 720,
              child: _buildSkeletonLoader(),
            ),
          ),
        ),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: AppColors.canvas,
        body: Center(child: Text('Error loading payslip: $err')),
      ),
    );
  }

  Widget _buildDetailCard(PayrollRecord record, bool isMobile) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    final grossSalary = record.basicPay +
        record.hra +
        record.educationAllowance +
        record.specialAllowance +
        record.travelAllowance +
        record.otherAllowance +
        record.incentive +
        record.othersEarning +
        record.cumulativeIncentive +
        record.bonus +
        record.ot;

    final deductions = record.pf +
        record.tax +
        record.esi +
        record.lop +
        record.companyLoan +
        record.salaryAdvance +
        record.othersDeduction +
        record.staffWelfareContribution +
        record.greeting;

    final netSalary = grossSalary - deductions;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                record.month,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              _buildStatusPill(record),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.divider, thickness: 0.5),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFF9CC70A).withOpacity(0.1),
                child: const Icon(Icons.person_outline, color: Color(0xFF9CC70A), size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.employeeName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: IGT-000${record.employeeId} • ${record.department} • ${record.designation}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.divider, thickness: 0.5),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: _buildLabelValue('PRESENT', '${record.presentDays}')),
              Expanded(child: _buildLabelValue('LATE', '${record.lateDays}')),
              Expanded(child: _buildLabelValue('ABSENT (LOP)', '${record.absentDays}')),
              Expanded(child: _buildLabelValue('LEAVE', '${record.leaveDays}')),
              Expanded(child: _buildLabelValue('TOTAL DAYS', '${record.presentDays + record.absentDays + record.leaveDays}')),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.divider, thickness: 0.5),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'EARNINGS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildRowItem('Basic Pay', currencyFormat.format(record.basicPay)),
                    _buildRowItem('HRA', currencyFormat.format(record.hra)),
                    if (record.educationAllowance > 0)
                      _buildRowItem('Education Allowance', currencyFormat.format(record.educationAllowance)),
                    _buildRowItem('Special Allowance', currencyFormat.format(record.specialAllowance)),
                    if (record.travelAllowance > 0)
                      _buildRowItem('Travel Allowance', currencyFormat.format(record.travelAllowance)),
                    if (record.otherAllowance > 0)
                      _buildRowItem('Other Allowance', currencyFormat.format(record.otherAllowance)),
                    if (record.incentive > 0)
                      _buildRowItem('Incentive', currencyFormat.format(record.incentive)),
                    if (record.othersEarning > 0)
                      _buildRowItem('Others', currencyFormat.format(record.othersEarning)),
                    if (record.cumulativeIncentive > 0)
                      _buildRowItem('Cumulative Incentive', currencyFormat.format(record.cumulativeIncentive)),
                    if (record.bonus > 0)
                      _buildRowItem('Bonus', currencyFormat.format(record.bonus)),
                    if (record.ot > 0)
                      _buildRowItem('OT', currencyFormat.format(record.ot)),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Container(
                height: 140,
                width: 0.5,
                color: AppColors.divider,
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DEDUCTIONS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildRowItem('PF', currencyFormat.format(record.pf)),
                    _buildRowItem('TDS (Tax)', currencyFormat.format(record.tax)),
                    if (record.esi > 0)
                      _buildRowItem('ESI', currencyFormat.format(record.esi)),
                    if (record.lop > 0)
                      _buildRowItem('LOP', currencyFormat.format(record.lop)),
                    if (record.companyLoan > 0)
                      _buildRowItem(
                        record.loanDescription.isNotEmpty ? 'Loan (${record.loanDescription})' : 'Company Loan',
                        currencyFormat.format(record.companyLoan),
                      ),
                    if (record.salaryAdvance > 0)
                      _buildRowItem(
                        record.advanceDescription.isNotEmpty ? 'Advance (${record.advanceDescription})' : 'Salary Advance',
                        currencyFormat.format(record.salaryAdvance),
                      ),
                    if (record.staffWelfareContribution > 0)
                      _buildRowItem('Staff Welfare', currencyFormat.format(record.staffWelfareContribution)),
                    if (record.greeting > 0)
                      _buildRowItem('Greeting Deduction', currencyFormat.format(record.greeting)),
                    if (record.othersDeduction > 0)
                      _buildRowItem('Others', currencyFormat.format(record.othersDeduction)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.divider, thickness: 0.5),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildLabelValue('GROSS SALARY', currencyFormat.format(grossSalary)),
                  _buildLabelValue('TOTAL DEDUCTIONS', currencyFormat.format(deductions)),
                  _buildLabelValue('NET SALARY', currencyFormat.format(netSalary), highlight: true),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'In words: ${numberToWords(netSalary)} Rupees Only',
                style: const TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.divider, thickness: 0.5),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabelValue('BANK NAME', record.bankName),
                    const SizedBox(height: 12),
                    _buildLabelValue('BANK ACCOUNT', _maskBankAccount(record.bankAcctNo)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabelValue('IFSC CODE', record.ifscCode),
                    const SizedBox(height: 12),
                    _buildLabelValue(
                      'CREDIT DATE',
                      record.paymentDate.isNotEmpty ? record.paymentDate : 'Expected by 5th of next month',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.divider, thickness: 0.5),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'This is a system generated payslip hence needs no signature.',
              style: TextStyle(
                fontSize: 10,
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabelValue(String label, String value, {bool highlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: highlight ? 16 : 13,
            fontWeight: FontWeight.bold,
            color: highlight ? const Color(0xFF9CC70A) : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildRowItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(PayrollRecord record) {
    final isPaid = record.status == 'Paid';
    final color = isPaid ? const Color(0xFF9CC70A) : Colors.amber[800]!;
    final bgColor = isPaid ? const Color(0xFF9CC70A).withOpacity(0.1) : Colors.amber[50]!;
    final label = isPaid ? 'Paid' : 'Processing';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildActionRow(BuildContext context, PayrollRecord record, bool isMobile) {
    final isPaid = record.status == 'Paid';

    final downloadBtn = ElevatedButton(
      onPressed: (!isPaid || _downloading) ? null : () => _startDownloadFlow(context, record),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF9CC70A),
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey[200],
        disabledForegroundColor: Colors.grey[400],
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
      child: Center(
        child: _downloading
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text('Preparing PDF…', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              )
            : const Text('Download PDF', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );

    final emailBtn = OutlinedButton(
      onPressed: () => _showMockAction(context, 'Sending Email to employee...'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.divider, width: 1),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: Colors.white,
      ),
      child: const Center(
        child: Text('Send Email', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          downloadBtn,
          const SizedBox(height: 8),
          emailBtn,
        ],
      );
    } else {
      return Row(
        children: [
          Expanded(child: downloadBtn),
          const SizedBox(width: 12),
          Expanded(child: emailBtn),
        ],
      );
    }
  }

  Widget _buildSkeletonLoader() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 150,
                height: 24,
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
              ),
              Container(
                width: 60,
                height: 20,
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.divider, thickness: 0.5),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 180,
                      height: 16,
                      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 240,
                      height: 12,
                      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.divider, thickness: 0.5),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              5,
              (index) => Container(
                width: 50,
                height: 36,
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.divider, thickness: 0.5),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: List.generate(
                    4,
                    (index) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 48),
              Expanded(
                child: Column(
                  children: List.generate(
                    4,
                    (index) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.divider, thickness: 0.5),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              3,
              (index) => Container(
                width: 80,
                height: 36,
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showReportIssueDialog(BuildContext context, WidgetRef ref, PayrollRecord record) {
    final commentController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Report an Issue / Query'),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please describe the query or mismatch in detail. This will flag the payslip to HR/admin for review.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'e.g. LOP days incorrect, missing bonus, bank credit issue...',
                  hintStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final comment = commentController.text.trim();
                if (comment.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a description of the issue.')),
                  );
                  return;
                }
                Navigator.pop(dialogContext);
                
                final updated = record.copyWith(
                  isDisputed: true,
                  disputeComment: comment,
                );

                try {
                  await ref.read(payrollRepositoryProvider).savePayrollRecord(updated);
                  ref.invalidate(payrollRecordByIdProvider(record.id));
                  ref.invalidate(payrollRecordsForMonthProvider);
                  ref.invalidate(employeePayrollRecordsProvider(record.employeeId));
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Dispute raised successfully. HR has been notified.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to raise dispute: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
              ),
              child: const Text('Submit Query'),
            ),
          ],
        );
      },
    );
  }

  static String numberToWords(double number) {
    if (number == 0) return 'Zero';
    final intNumber = number.toInt();
    
    final units = [
      '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
      'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
      'Seventeen', 'Eighteen', 'Nineteen'
    ];
    
    final tens = [
      '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'
    ];

    String convertLessThanOneThousand(int n) {
      if (n < 20) return units[n];
      if (n < 100) {
        return '${tens[n ~/ 10]} ${units[n % 10]}'.trim();
      }
      return '${units[n ~/ 100]} Hundred ${convertLessThanOneThousand(n % 100)}'.trim();
    }

    String result = '';
    int temp = intNumber;

    if (temp >= 10000000) {
      result += '${convertLessThanOneThousand(temp ~/ 10000000)} Crore ';
      temp %= 10000000;
    }
    if (temp >= 100000) {
      result += '${convertLessThanOneThousand(temp ~/ 100000)} Lakh ';
      temp %= 100000;
    }
    if (temp >= 1000) {
      result += '${convertLessThanOneThousand(temp ~/ 1000)} Thousand ';
      temp %= 1000;
    }
    if (temp > 0) {
      result += convertLessThanOneThousand(temp);
    }

    final words = result.trim();
    if (words.isEmpty) return 'Zero';
    return words;
  }
}
