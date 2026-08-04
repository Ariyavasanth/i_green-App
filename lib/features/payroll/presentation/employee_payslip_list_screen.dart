import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/layout/responsive_layout.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../employee/providers/employee_providers.dart';
import '../../leave/providers/leave_providers.dart';
import '../domain/payroll.dart';
import '../providers/payroll_providers.dart';

class EmployeePayslipListScreen extends ConsumerWidget {
  const EmployeePayslipListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeesAsync = ref.watch(employeesProvider);
    final employee = ref.watch(currentEmployeeProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: employeesAsync.when(
        data: (_) {
          if (employee == null) {
            return const Center(
              child: Text(
                'No employee account linked to this user.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }

          final recordsAsync = ref.watch(employeePayrollRecordsProvider(employee.id));

          return LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < AppBreakpoints.tablet;
              final gutter = AppLayout.gutter(constraints.maxWidth);

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(employeesProvider);
                  ref.invalidate(employeePayrollRecordsProvider(employee.id));
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(gutter),
                  child: ResponsiveContent(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(employee),
                        const SizedBox(height: 24),
                        recordsAsync.when(
                          data: (records) {
                            if (records.isEmpty) {
                              return _buildEmptyState();
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildFeaturedCard(context, records.first, isMobile),
                                const SizedBox(height: 24),
                                Text(
                                  'Payroll & Payslip History',
                                  style: AppTextStyles.heading.copyWith(fontSize: 16),
                                ),
                                const SizedBox(height: 12),
                                isMobile
                                    ? _buildMobileList(context, records)
                                    : _buildDesktopTable(context, records),
                              ],
                            );
                          },
                          loading: () => const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: CircularProgressIndicator(color: AppColors.primary),
                            ),
                          ),
                          error: (err, _) => Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text('Error loading payslips: $err'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => Center(child: Text('Error loading account: $err')),
      ),
    );
  }

  Widget _buildHeader(dynamic employee) {
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.primary.withOpacity(0.1),
          child: const Icon(Icons.badge_outlined, color: AppColors.primary, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome, ${employee.firstName} ${employee.lastName}',
                style: AppTextStyles.pageTitle.copyWith(fontSize: 20),
              ),
              const SizedBox(height: 4),
              Text(
                'Employee ID: EMP${employee.id} • ${employee.designation} • ${employee.department}',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturedCard(BuildContext context, PayrollRecord record, bool isMobile) {
    final hasDisputed = record.isDisputed;
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: hasDisputed ? Colors.red[300]! : AppColors.divider,
          width: hasDisputed ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LATEST PAYSLIP PERIOD',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      record.month,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                _buildStatusPill(record),
              ],
            ),
            const Divider(height: 32),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Net Salary Credited',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(record.netSalary),
                        style: TextStyle(
                          fontSize: isMobile ? 24 : 32,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => context.push('/payroll/payslip/${record.id}'),
                  icon: const Icon(Icons.description_outlined, size: 18),
                  label: const Text(
                    'View Details',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            if (hasDisputed) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Dispute Raised: "${record.disputeComment}"',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red[800],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopTable(BuildContext context, List<PayrollRecord> records) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(3), // Period
          1: FlexColumnWidth(3), // Net Salary
          2: FlexColumnWidth(3), // Status
          3: FlexColumnWidth(3), // Payment Date
          4: FlexColumnWidth(2.5), // Action
        },
        children: [
          TableRow(
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            children: [
              _buildTableHeader('Payroll Period'),
              _buildTableHeader('Net Salary'),
              _buildTableHeader('Status'),
              _buildTableHeader('Credit Date'),
              _buildTableHeader('Action'),
            ],
          ),
          for (final record in records)
            TableRow(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              children: [
                _buildTableCell(
                  Text(
                    record.month,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                _buildTableCell(
                  Text(
                    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(record.netSalary),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                _buildTableCell(_buildStatusPill(record)),
                _buildTableCell(
                  Text(
                    record.paymentDate.isNotEmpty ? record.paymentDate : 'Pending Credit',
                    style: TextStyle(
                      color: record.paymentDate.isNotEmpty ? AppColors.textPrimary : AppColors.textSecondary,
                      fontStyle: record.paymentDate.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                    ),
                  ),
                ),
                _buildTableCell(
                  TextButton.icon(
                    onPressed: () => context.push('/payroll/payslip/${record.id}'),
                    icon: const Icon(Icons.visibility_outlined, size: 14),
                    label: const Text('View Payslip', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.active,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMobileList(BuildContext context, List<PayrollRecord> records) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final record = records[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppColors.divider),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(record.month, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(
                        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(record.netSalary),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        record.paymentDate.isNotEmpty ? 'Credited: ${record.paymentDate}' : 'Expected: 5th of next month',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildStatusPill(record),
                    const SizedBox(height: 8),
                    IconButton(
                      onPressed: () => context.push('/payroll/payslip/${record.id}'),
                      icon: const Icon(Icons.arrow_forward_ios, size: 14),
                      color: AppColors.active,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return const Card(
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40, horizontal: 16),
          child: Column(
            children: [
              Icon(Icons.description_outlined, size: 48, color: AppColors.textSecondary),
              SizedBox(height: 16),
              Text(
                'No Payslips Available',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Your generated payslips will appear here once processed.',
                style: TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondary,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildTableCell(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Align(alignment: Alignment.centerLeft, child: child),
    );
  }

  Widget _buildStatusPill(PayrollRecord record) {
    if (record.isDisputed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red[200]!),
        ),
        child: Text(
          'Disputed',
          style: TextStyle(color: Colors.red[700], fontSize: 11, fontWeight: FontWeight.bold),
        ),
      );
    }

    final isPaid = record.status == 'Paid';
    final isProcessed = record.status == 'Processed';
    
    final color = isPaid 
        ? Colors.green[700]! 
        : (isProcessed ? Colors.blue[700]! : Colors.orange[700]!);
    final bgColor = isPaid 
        ? Colors.green[50]! 
        : (isProcessed ? Colors.blue[50]! : Colors.orange[50]!);
    final label = isPaid ? 'Paid' : (isProcessed ? 'Processing' : record.status);

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
}
