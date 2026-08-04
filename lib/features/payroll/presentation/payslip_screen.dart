import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/responsive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/payroll.dart';
import '../providers/payroll_providers.dart';
import '../../leave/providers/leave_providers.dart';
import 'widgets/access_denied_view.dart';

class PayslipScreen extends ConsumerWidget {
  const PayslipScreen({required this.payrollId, super.key});
  final int payrollId;

  String _maskBankAccount(String acctNo) {
    final clean = acctNo.trim();
    if (clean.length <= 4) return clean;
    return '${"*" * (clean.length - 4)}${clean.substring(clean.length - 4)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payrollAsync = ref.watch(payrollRecordByIdProvider(payrollId));
    final employee = ref.watch(currentEmployeeProvider);
    final isEmployee = employee != null && employee.userType.toUpperCase() == 'EMPLOYEE';

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text('Payslip Document View'),
      ),
      body: payrollAsync.when(
        data: (record) {
          if (record == null) {
            return const Center(child: Text('Payroll record not found.'));
          }

          // Security check: Employee can only see their own record!
          if (isEmployee && record.employeeId != employee.id) {
            return const AccessDeniedView();
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < AppBreakpoints.tablet;
              final gutter = AppLayout.gutter(constraints.maxWidth);

              return Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(gutter),
                      child: ResponsiveContent(
                        maxWidth: 960, // Wide document page view
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (record.isDisputed)
                              Container(
                                padding: const EdgeInsets.all(16),
                                margin: const EdgeInsets.only(bottom: 20),
                                decoration: BoxDecoration(
                                  color: Colors.red[50],
                                  borderRadius: BorderRadius.circular(8),
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
                            _buildDocumentPreview(record),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _buildActionBar(context, ref, record, isMobile, isEmployee),
                ],
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => Center(child: Text('Error loading payslip: $err')),
      ),
    );
  }

  Widget _buildDocumentPreview(PayrollRecord record) {
    // Computations based on screenshot logic:
    // Standard salary sum
    final stdBasic = record.basicPay;
    final stdHra = record.hra;
    final stdEdu = record.educationAllowance > 0 ? record.educationAllowance : 3000.0;
    final stdSpecial = record.specialAllowance;
    final standardSalary = stdBasic + stdHra + stdEdu + stdSpecial;

    // Gross Salary sum: Earning Components + incentives + others + cumulative incentive
    final grossSalary = record.basicPay +
        record.hra +
        record.educationAllowance +
        record.specialAllowance +
        record.incentive +
        record.othersEarning +
        record.cumulativeIncentive;

    // Deductions sum
    final deductions = record.pf +
        record.tax +
        record.esi +
        record.lop +
        record.companyLoan +
        record.salaryAdvance +
        record.othersDeduction +
        record.staffWelfareContribution;

    final netSalary = grossSalary - deductions;

    return Card(
      elevation: 4,
      color: Colors.white,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Company Header
            _buildCompanyHeader(),
            const SizedBox(height: 16),

            // 2. Employee Details Table
            _buildEmployeeDetailsTable(record),
            const SizedBox(height: 16),

            // 3. Salary Details Grid (6 Columns Table)
            _buildSalaryDetailsGrid(record, standardSalary, grossSalary, deductions, netSalary),
            const SizedBox(height: 16),

            // 4. Footer System Disclaimer
            const Center(
              child: Text(
                'This Is A System Generated Payslip Hence Needs No Signature',
                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Logo & Name
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Custom drawn green logo mimic
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF9CC70A),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Center(
                child: Text(
                  'iG',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Igreen',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF9CC70A),
                  ),
                ),
                Text(
                  'Tec Engineering India Pvt Ltd',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                Text(
                  'Innovation In Engineering',
                  style: TextStyle(fontSize: 9, fontStyle: FontStyle.italic, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
        // Email & TAN Details
        const Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'EMAIL : SUPPORT@IGREENTEC.IN',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            SizedBox(height: 4),
            Text(
              'TAN No: CHEI09733D',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmployeeDetailsTable(PayrollRecord record) {
    return Table(
      border: TableBorder.all(color: Colors.grey[300]!),
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(3),
        2: FlexColumnWidth(2),
        3: FlexColumnWidth(3),
      },
      children: [
        // Row 1 - Header Row
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFFF9FAFB)),
          children: [
            _buildGridHeaderCell('PAYSLIP PERIOD'),
            _buildGridHeaderCell(''),
            _buildGridHeaderCell('STATUTORY DETAILS'),
            _buildGridHeaderCell(''),
          ],
        ),
        // Row 2 - Month Year / PAN
        TableRow(
          children: [
            _buildGridLabelCell('Payroll Period (Month/Year)'),
            _buildGridValueCell(record.month),
            _buildGridLabelCell('PAN Number'),
            _buildGridValueCell(record.panNumber.isNotEmpty ? record.panNumber : '-'),
          ],
        ),
        // Row 3 - Header Employee Details / PF
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFFF9FAFB)),
          children: [
            _buildGridHeaderCell('EMPLOYEE DETAILS'),
            _buildGridHeaderCell(''),
            _buildGridValueCell(''), // statutory empty Col 3
            _buildGridValueCell(''), // statutory empty Col 4
          ],
        ),
        // Row 4 - Employee No / PF Number
        TableRow(
          children: [
            _buildGridLabelCell('Employee no'),
            _buildGridValueCell('IGT - 000${record.employeeId}'),
            _buildGridLabelCell('PF'),
            _buildGridValueCell(record.pfNumber.isNotEmpty ? record.pfNumber : '-'),
          ],
        ),
        // Row 5 - Employee Name / BANK DETAILS header
        TableRow(
          children: [
            _buildGridLabelCell('Employee Name'),
            _buildGridValueCell(record.employeeName, isBold: true),
            _buildGridHeaderCell('BANK DETAILS'),
            _buildGridHeaderCell(''),
          ],
        ),
        // Row 6 - Designation / Bank Name
        TableRow(
          children: [
            _buildGridLabelCell('Designation'),
            _buildGridValueCell(record.designation),
            _buildGridLabelCell('Bank Name'),
            _buildGridValueCell(record.bankName),
          ],
        ),
        // Row 7 - Department / Account
        TableRow(
          children: [
            _buildGridLabelCell('Department'),
            _buildGridValueCell(record.department),
            _buildGridLabelCell('Bank Acct no'),
            _buildGridValueCell(_maskBankAccount(record.bankAcctNo)),
          ],
        ),
        // Row 8 - Email / Branch
        TableRow(
          children: [
            _buildGridLabelCell('Email ID'),
            _buildGridValueCell(record.emailId),
            _buildGridLabelCell('Branch'),
            _buildGridValueCell(record.branch),
          ],
        ),
        // Row 9 - Working Days Present / IFSC Code
        TableRow(
          children: [
            _buildGridLabelCell('Days Present'),
            _buildGridValueCell('${record.presentDays}'),
            _buildGridLabelCell('IFSC/Swift Code'),
            _buildGridValueCell(record.ifscCode),
          ],
        ),
        // Row 10 - Total Working Days / Payment Credit Date
        TableRow(
          children: [
            _buildGridLabelCell('Total Working Days'),
            _buildGridValueCell('${record.presentDays + record.absentDays + record.leaveDays}'),
            _buildGridLabelCell('Payment Credit Date'),
            _buildGridValueCell(record.paymentDate.isNotEmpty ? record.paymentDate : 'Expected by 5th of next month'),
          ],
        ),
        // Row 11 - Loss of Pay (LOP) Days / Payment Method
        TableRow(
          children: [
            _buildGridLabelCell('LOP (Loss of Pay) Days'),
            _buildGridValueCell('${record.absentDays}'),
            _buildGridLabelCell('Payment Method'),
            _buildGridValueCell(record.paymentMethod),
          ],
        ),
      ],
    );
  }

  Widget _buildSalaryDetailsGrid(
    PayrollRecord record,
    double standardSalary,
    double grossSalary,
    double totalDeductions,
    double netSalary,
  ) {
    // Render standard component placeholders as shown in the screenshot
    final stdBasic = record.basicPay;
    final stdHra = record.hra;
    final stdEdu = record.educationAllowance > 0 ? record.educationAllowance : 3000.0;
    final stdSpecial = record.specialAllowance;

    return Table(
      border: TableBorder.all(color: Colors.grey[300]!),
      columnWidths: const {
        0: FlexColumnWidth(2.5), // Monthly Salary Component label
        1: FlexColumnWidth(1.2), // Standard Component INR
        2: FlexColumnWidth(2.5), // Earning label
        3: FlexColumnWidth(1.2), // Earning INR
        4: FlexColumnWidth(2.5), // Deductions label
        5: FlexColumnWidth(1.2), // Deductions INR
      },
      children: [
        // Main headers
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFFF3F4F6)),
          children: [
            _buildGridHeaderCell('Monthly Salary'),
            _buildGridHeaderCell('INR', alignRight: true),
            _buildGridHeaderCell('Earning'),
            _buildGridHeaderCell('INR', alignRight: true),
            _buildGridHeaderCell('Deductions'),
            _buildGridHeaderCell('INR', alignRight: true),
          ],
        ),
        // Standard Components labels row
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFFF9FAFB)),
          children: [
            _buildGridHeaderCell('Standard Components'),
            _buildGridHeaderCell(''),
            _buildGridHeaderCell('Standard Components'),
            _buildGridHeaderCell(''),
            _buildGridHeaderCell('Statutory'),
            _buildGridHeaderCell(''),
          ],
        ),
        // Row 1: Basic
        TableRow(
          children: [
            _buildGridLabelCell('Basic'),
            _buildGridValueCell(stdBasic.toStringAsFixed(2), alignRight: true),
            _buildGridLabelCell('Basic'),
            _buildGridValueCell(record.basicPay.toStringAsFixed(0), alignRight: true),
            _buildGridLabelCell('PF'),
            _buildGridValueCell(record.pf.toStringAsFixed(0), alignRight: true),
          ],
        ),
        // Row 2: HRA
        TableRow(
          children: [
            _buildGridLabelCell('HRA'),
            _buildGridValueCell(stdHra.toStringAsFixed(2), alignRight: true),
            _buildGridLabelCell('HRA'),
            _buildGridValueCell(record.hra.toStringAsFixed(0), alignRight: true),
            _buildGridLabelCell('TDS'),
            _buildGridValueCell(record.tax.toStringAsFixed(0), alignRight: true),
          ],
        ),
        // Row 3: Educational
        TableRow(
          children: [
            _buildGridLabelCell('Educational Allowance'),
            _buildGridValueCell(stdEdu.toStringAsFixed(0), alignRight: true),
            _buildGridLabelCell('Educational Allowance'),
            _buildGridValueCell(record.educationAllowance.toStringAsFixed(0), alignRight: true),
            _buildGridLabelCell('ESI'),
            _buildGridValueCell(record.esi.toStringAsFixed(0), alignRight: true),
          ],
        ),
        // Row 4: Special / Deductions Other Header
        TableRow(
          children: [
            _buildGridLabelCell('Special Allowance'),
            _buildGridValueCell(stdSpecial.toStringAsFixed(0), alignRight: true),
            _buildGridLabelCell('Special Allowance'),
            _buildGridValueCell(record.specialAllowance.toStringAsFixed(0), alignRight: true),
            _buildGridHeaderCell('Other'), // Deduction other header
            _buildGridHeaderCell(''),
          ],
        ),
        // Row 5: LOP
        TableRow(
          children: [
            _buildGridValueCell(''),
            _buildGridValueCell(''),
            _buildGridValueCell(''),
            _buildGridValueCell(''),
            _buildGridLabelCell('LOP'),
            _buildGridValueCell(record.lop.toStringAsFixed(0), alignRight: true),
          ],
        ),
        // Row 6: Company loan
        TableRow(
          children: [
            _buildGridValueCell(''),
            _buildGridValueCell(''),
            _buildGridValueCell(''),
            _buildGridValueCell(''),
            _buildGridLabelCell(record.loanDescription.isNotEmpty ? 'Company loan (${record.loanDescription})' : 'Company loan'),
            _buildGridValueCell(record.companyLoan.toStringAsFixed(0), alignRight: true),
          ],
        ),
        // Row 7: Salary Advance
        TableRow(
          children: [
            _buildGridValueCell(''),
            _buildGridValueCell(''),
            _buildGridValueCell(''),
            _buildGridValueCell(''),
            _buildGridLabelCell(record.advanceDescription.isNotEmpty ? 'Salary Advance (${record.advanceDescription})' : 'Salary Advance'),
            _buildGridValueCell(record.salaryAdvance.toStringAsFixed(0), alignRight: true),
          ],
        ),
        // Row 8: Additional Components header / Others Ded
        TableRow(
          children: [
            _buildGridValueCell(''),
            _buildGridValueCell(''),
            _buildGridHeaderCell('Additional Components'),
            _buildGridHeaderCell(''),
            _buildGridLabelCell('Others'),
            _buildGridValueCell(record.othersDeduction.toStringAsFixed(0), alignRight: true),
          ],
        ),
        // Row 9: Incentive / Staff welfare
        TableRow(
          children: [
            _buildGridValueCell(''),
            _buildGridValueCell(''),
            _buildGridLabelCell('Incentive'),
            _buildGridValueCell(record.incentive.toStringAsFixed(0), alignRight: true),
            _buildGridLabelCell('Staff welfare contribution'),
            _buildGridValueCell(record.staffWelfareContribution.toStringAsFixed(0), alignRight: true),
          ],
        ),
        // Row 10: Carry forward
        TableRow(
          children: [
            _buildGridValueCell(''),
            _buildGridValueCell(''),
            _buildGridLabelCell('Carry forward'),
            _buildGridValueCell(record.carryForward, alignRight: true),
            _buildGridValueCell(''),
            _buildGridValueCell(''),
          ],
        ),
        // Row 11: Others Earning
        TableRow(
          children: [
            _buildGridValueCell(''),
            _buildGridValueCell(''),
            _buildGridLabelCell('Others'),
            _buildGridValueCell(record.othersEarning.toStringAsFixed(0), alignRight: true),
            _buildGridValueCell(''),
            _buildGridValueCell(''),
          ],
        ),
        // Row 12: Cumulative Incentive
        TableRow(
          children: [
            _buildGridValueCell(''),
            _buildGridValueCell(''),
            _buildGridLabelCell('Cumulative Incentive'),
            _buildGridValueCell(record.cumulativeIncentive.toStringAsFixed(0), alignRight: true),
            _buildGridValueCell(''),
            _buildGridValueCell(''),
          ],
        ),
        // Totals Footer Row
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFFF3F4F6)),
          children: [
            _buildGridHeaderCell('Standard Salary'),
            _buildGridValueCell(standardSalary.toStringAsFixed(0), alignRight: true, isBold: true),
            _buildGridHeaderCell('Gross Salary'),
            _buildGridValueCell(grossSalary.toStringAsFixed(0), alignRight: true, isBold: true),
            _buildGridHeaderCell('Deduction'),
            _buildGridValueCell(totalDeductions.toStringAsFixed(0), alignRight: true, isBold: true),
          ],
        ),
        // Net Salary Row
        TableRow(
          children: [
            _buildGridValueCell(
              'In words: ${numberToWords(netSalary)} only',
              isBold: true,
              isItalic: true,
              spanAcross: true,
            ),
            _buildGridValueCell(''), // empty due to span
            _buildGridValueCell(''), // empty due to span
            _buildGridValueCell(''), // empty due to span
            _buildGridHeaderCell('Net Salary'),
            _buildGridValueCell(netSalary.toStringAsFixed(0), alignRight: true, isBold: true),
          ],
        ),
      ],
    );
  }

  Widget _buildGridHeaderCell(String text, {bool alignRight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Text(
        text,
        textAlign: alignRight ? TextAlign.right : TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black87),
      ),
    );
  }

  Widget _buildGridLabelCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black87),
      ),
    );
  }

  Widget _buildGridValueCell(
    String text, {
    bool alignRight = false,
    bool isBold = false,
    bool isItalic = false,
    bool spanAcross = false,
  }) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Text(
        text,
        textAlign: alignRight ? TextAlign.right : (spanAcross ? TextAlign.left : TextAlign.left),
        style: TextStyle(
          fontSize: 10,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildActionBar(BuildContext context, WidgetRef ref, PayrollRecord record, bool isMobile, bool isEmployee) {
    final actions = isEmployee
        ? [
            (Icons.download_outlined, 'Download', () => _showMockAction(context, 'Downloading PDF...')),
            (Icons.print_outlined, 'Print', () => _showMockAction(context, 'Opening print layout...')),
            (Icons.warning_amber_rounded, 'Report Issue', () => _showReportIssueDialog(context, ref, record)),
          ]
        : [
            (Icons.download_outlined, 'Download', () => _showMockAction(context, 'Downloading PDF...')),
            (Icons.mail_outline, 'Send Email', () => _showMockAction(context, 'Sending Email to employee...')),
            (Icons.print_outlined, 'Print', () => _showMockAction(context, 'Opening print layout...')),
          ];

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: isMobile
            ? Row(
                children: actions
                    .map(
                      (a) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: OutlinedButton.icon(
                            onPressed: a.$3,
                            icon: Icon(a.$1, size: 16),
                            label: Text(a.$2, style: const TextStyle(fontSize: 10)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: a.$2 == 'Report Issue' ? Colors.red[700] : AppColors.primary,
                              side: BorderSide(color: a.$2 == 'Report Issue' ? Colors.red[300]! : AppColors.primary),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: actions
                    .map(
                      (a) => Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: ElevatedButton.icon(
                          onPressed: a.$3,
                          icon: Icon(a.$1, size: 16),
                          label: Text(a.$2),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: a.$2 == 'Report Issue'
                                ? Colors.red[700]
                                : (a.$2 == 'Download' ? AppColors.primary : AppColors.active),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
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

  void _showMockAction(BuildContext context, String message) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Processing Request'),
          content: Row(
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(width: 16),
              Expanded(child: Text(message)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Action executed successfully!')),
                );
              },
              child: const Text('Complete'),
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

    // Capitalize properly
    final words = result.trim();
    if (words.isEmpty) return 'Zero';
    return words;
  }
}
