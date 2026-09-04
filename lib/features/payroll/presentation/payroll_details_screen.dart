import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/layout/responsive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../employee/domain/employee.dart';
import '../../employee/providers/employee_providers.dart';
import '../domain/payroll.dart';
import '../providers/payroll_providers.dart';

class PayrollDetailsScreen extends ConsumerStatefulWidget {
  const PayrollDetailsScreen({required this.payrollId, super.key});
  final int payrollId;

  @override
  ConsumerState<PayrollDetailsScreen> createState() => _PayrollDetailsScreenState();
}

class _GenerateStepperStep {
  final String title;
  final String date;
  final bool isCompleted;

  _GenerateStepperStep({required this.title, this.date = '', required this.isCompleted});
}

class _PayrollDetailsScreenState extends ConsumerState<PayrollDetailsScreen> {
  Future<void> _updateStatus(PayrollRecord record, String newStatus) async {
    final updated = record.copyWith(
      status: newStatus,
      paymentDate: newStatus == 'Paid'
          ? DateFormat('dd-MM-yyyy').format(DateTime.now())
          : record.paymentDate,
    );

    try {
      await ref.read(payrollRepositoryProvider).savePayrollRecord(updated);
      ref.invalidate(payrollRecordsForMonthProvider);
      ref.invalidate(payrollRecordByIdProvider(widget.payrollId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to $newStatus'),
            backgroundColor: Colors.green[700],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: $e'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
  }

  Future<void> _confirmMarkAsPaid(PayrollRecord record) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 24),
              SizedBox(width: 8),
              Text(
                'Mark Payroll as Paid?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: const Text(
            'Once this payroll is marked as Paid, it will be permanently locked and cannot be changed.',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.divider),
              ),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.check_circle_outline, size: 16),
              label: const Text('Mark as Paid'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9CC70A),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await _updateStatus(record, 'Paid');
    }
  }

  @override
  Widget build(BuildContext context) {
    final payrollAsync = ref.watch(payrollRecordByIdProvider(widget.payrollId));

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text('Payroll Details'),
      ),
      body: payrollAsync.when(
        data: (record) {
          if (record == null) {
            return const Center(child: Text('Payroll record not found.'));
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < AppBreakpoints.tablet;
              final gutter = AppLayout.gutter(constraints.maxWidth);

              return SingleChildScrollView(
                padding: EdgeInsets.all(gutter),
                child: ResponsiveContent(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Status stepper strip
                      _buildStepperStrip(record),
                      const SizedBox(height: 24),

                      // Desktop two-column or mobile single stack layout
                      isMobile
                          ? Column(
                              children: [
                                _buildEmployeeOverviewCard(record),
                                const SizedBox(height: 16),
                                _buildAttendanceCard(record),
                                const SizedBox(height: 16),
                                _buildEarningsDeductionsCard(record),
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: Column(
                                    children: [
                                      _buildEmployeeOverviewCard(record),
                                      const SizedBox(height: 16),
                                      _buildAttendanceCard(record),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  flex: 6,
                                  child: _buildEarningsDeductionsCard(record),
                                ),
                              ],
                            ),
                      
                      const SizedBox(height: 24),
                      _buildActionsRow(context, record),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading details: $err')),
      ),
    );
  }

  Widget _buildStepperStrip(PayrollRecord record) {
    final status = record.status;
    final draftCompleted = true;
    final processedCompleted = status == 'Processed' || status == 'Paid';
    final paidCompleted = status == 'Paid';

    final steps = [
      _GenerateStepperStep(
        title: 'Draft',
        date: 'Generated & Reviewable',
        isCompleted: draftCompleted,
      ),
      _GenerateStepperStep(
        title: 'Processed',
        date: processedCompleted ? 'Approved by HR' : 'Pending Approval',
        isCompleted: processedCompleted,
      ),
      _GenerateStepperStep(
        title: 'Paid 🔒',
        date: paidCompleted ? 'Paid on ${record.paymentDate}' : 'Awaiting Payment',
        isCompleted: paidCompleted,
      ),
    ];

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Row(
          children: [
            for (int i = 0; i < steps.length; i++) ...[
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: steps[i].isCompleted ? AppColors.primary : Colors.grey[300],
                      ),
                      child: Icon(
                        steps[i].isCompleted ? Icons.check : Icons.circle,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            steps[i].title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: steps[i].isCompleted ? AppColors.textPrimary : AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            steps[i].date,
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (i < steps.length - 1)
                Container(
                  width: 32,
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: steps[i + 1].isCompleted ? AppColors.primary : AppColors.divider,
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeOverviewCard(PayrollRecord record) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.active,
              child: Icon(Icons.person, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Builder(builder: (context) {
                    final currentEmp = ref.watch(currentEmployeeProvider);
                    final employees = ref.watch(employeesProvider).valueOrNull ?? [];
                    Employee? matchingEmp;
                    if (record.employeeId > 0) {
                      matchingEmp = employees.where((e) => e.id == record.employeeId).firstOrNull;
                    }
                    if (matchingEmp == null && currentEmp != null) {
                      if (currentEmp.id == record.employeeId ||
                          (record.employeeName.trim().isNotEmpty && record.employeeName.toLowerCase() == currentEmp.fullName.toLowerCase())) {
                        matchingEmp = currentEmp;
                      }
                    }
                    final displayName = matchingEmp != null && matchingEmp.fullName.isNotEmpty
                        ? matchingEmp.fullName
                        : (matchingEmp != null && matchingEmp.firstName.isNotEmpty
                            ? matchingEmp.firstName
                            : (record.employeeName.isNotEmpty
                                ? record.employeeName
                                : (currentEmp?.fullName.isNotEmpty == true ? currentEmp!.fullName : 'Employee')));

                    final displayId = matchingEmp != null && matchingEmp.employeeId.isNotEmpty
                        ? matchingEmp.employeeId
                        : (record.employeeId > 0 ? "EMP-${record.employeeId.toString().padLeft(4, '0')}" : "");

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${displayId.isNotEmpty ? "$displayId • " : ""}${record.month}${record.periodStartDate.isNotEmpty ? " (${record.periodStartDate} – ${record.periodEndDate})" : ""}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceCard(PayrollRecord record) {
    final list = [
      ('Present Days', '${record.presentDays} Days', Colors.green),
      ('Late Days', '${record.lateDays} Days', Colors.amber),
      ('Leave Days', '${record.leaveDays} Days', Colors.blue),
      ('Absent Days', '${record.absentDays} Days', Colors.red),
    ];

    return Card(
      elevation: 0,
      color: const Color(0xFFF3F4F6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Attendance & Work Days',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const Divider(height: 20),
            for (final item in list) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(item.$1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    Text(
                      item.$2,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: item.$3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEarningsDeductionsCard(PayrollRecord record) {
    final earnings = [
      ('Basic Pay', record.basicPay),
      ('HRA', record.hra),
      ('Special Allowance', record.specialAllowance),
      ('Education Allowance', record.educationAllowance),
      ('Travel Allowance', record.travelAllowance),
      ('Other Allowance', record.otherAllowance),
      ('Incentive', record.incentive),
      ('Others Earning', record.othersEarning),
      ('Cumulative Incentive', record.cumulativeIncentive),
      ('Bonus', record.bonus),
      ('OT (Overtime)', record.ot),
    ];

    final deductions = [
      ('PF Contribution', record.pf),
      ('Income Tax (TDS)', record.tax),
      ('ESI Contribution', record.esi),
      ('Leave Days Deduction (LOP)', record.lop),
      ('Company Loan', record.companyLoan),
      ('Salary Advance', record.salaryAdvance),
      ('Others Deduction', record.othersDeduction),
      ('Staff Welfare', record.staffWelfareContribution),
      ('Greeting Deduction', record.greeting),
    ];

    final totalEarnings = record.basicPay +
        record.hra +
        record.specialAllowance +
        record.educationAllowance +
        record.travelAllowance +
        record.otherAllowance +
        record.incentive +
        record.othersEarning +
        record.cumulativeIncentive +
        record.bonus +
        record.ot;

    final totalDeductions = record.pf +
        record.tax +
        record.esi +
        record.lop +
        record.companyLoan +
        record.salaryAdvance +
        record.othersDeduction +
        record.staffWelfareContribution +
        record.greeting;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Earnings
            const Text('Earnings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Divider(height: 20),
            for (final earn in earnings)
              if (earn.$2 > 0)
                _buildAmountRow(earn.$1, earn.$2),
            const Divider(height: 20),
            _buildAmountRow('Total Earnings', totalEarnings, isBold: true),

            const SizedBox(height: 24),

            // Deductions
            const Text('Deductions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Divider(height: 20),
            for (final ded in deductions)
              if (ded.$2 > 0)
                _buildAmountRow(ded.$1, ded.$2, isDeduction: true),
            const Divider(height: 20),
            _buildAmountRow('Total Deductions', totalDeductions, isBold: true, isDeduction: true),

            const Divider(height: 32, thickness: 1.5),

            // Net Salary
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Net Salary (Take Home)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(record.netSalary),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: AppColors.primary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountRow(String label, double amount, {bool isBold = false, bool isDeduction = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isBold ? 14 : 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
          Text(
            '${isDeduction ? "-" : "+"} ${NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(amount)}',
            style: TextStyle(
              fontSize: isBold ? 14 : 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: isDeduction ? Colors.red[700] : Colors.green[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsRow(BuildContext context, PayrollRecord record) {
    final status = record.status;
    final isPaid = status == 'Paid';
    final isDraft = status == 'Draft' || status == 'Pending';

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (isPaid)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFF59E0B)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.lock_outlined, size: 16, color: Color(0xFFB45309)),
                SizedBox(width: 6),
                Text(
                  'PAID 🔒 (Finalized payroll)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFB45309)),
                ),
              ],
            ),
          ),
        if (isDraft) ...[
          OutlinedButton.icon(
            onPressed: () => context.push('/payroll/generate/${record.employeeId}'),
            icon: const Icon(Icons.edit_note_outlined, size: 16),
            label: const Text('Edit / Recalculate'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.active,
              side: const BorderSide(color: AppColors.divider),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _updateStatus(record, 'Processed'),
            icon: const Icon(Icons.check_circle_outline, size: 16),
            label: const Text('Approve & Process'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
        if (status == 'Processed')
          ElevatedButton.icon(
            onPressed: () => _confirmMarkAsPaid(record),
            icon: const Icon(Icons.payment, size: 16),
            label: const Text('Mark as Paid'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9CC70A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        OutlinedButton.icon(
          onPressed: () => context.push('/payroll/payslip/${record.id}'),
          icon: const Icon(Icons.description_outlined, size: 16),
          label: const Text('View Payslip'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }
}
