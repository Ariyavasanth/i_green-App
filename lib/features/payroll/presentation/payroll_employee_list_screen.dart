import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/responsive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../employee/providers/employee_providers.dart';
import '../../attendance/providers/attendance_providers.dart';
import '../domain/payroll.dart';
import '../providers/payroll_providers.dart';

class PayrollEmployeeListScreen extends ConsumerWidget {
  const PayrollEmployeeListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.watch(selectedPayrollMonthProvider);
    final employeesAsync = ref.watch(employeesProvider);
    final payrollRecordsAsync = ref.watch(payrollRecordsForMonthProvider);
    final attendanceRecordsAsync = ref.watch(allAttendanceRecordsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text('Run Payroll', style: AppTextStyles.heading),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < AppBreakpoints.tablet;
          final gutter = AppLayout.gutter(constraints.maxWidth);

          return employeesAsync.when(
            data: (employees) => payrollRecordsAsync.when(
              data: (records) => attendanceRecordsAsync.when(
                data: (attendanceRecords) {
                  return SingleChildScrollView(
                    padding: EdgeInsets.all(gutter),
                    child: ResponsiveContent(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSubHeader(selectedMonth),
                          const SizedBox(height: 20),
                          isMobile
                              ? _buildMobileEmployeeList(
                                  context,
                                  employees,
                                  records,
                                  attendanceRecords,
                                  selectedMonth,
                                )
                              : _buildDesktopEmployeeList(
                                  context,
                                  employees,
                                  records,
                                  attendanceRecords,
                                  selectedMonth,
                                ),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error loading attendance: $err')),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error loading payroll: $err')),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error loading employees: $err')),
          );
        },
      ),
    );
  }

  Widget _buildSubHeader(String month) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.active, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Running payroll checks for month: $month. Select an employee to generate or review payroll calculations.',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopEmployeeList(
    BuildContext context,
    dynamic employees,
    List<PayrollRecord> records,
    dynamic attendanceRecords,
    String selectedMonth,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(1.2),
          1: FlexColumnWidth(2.5),
          2: FlexColumnWidth(2.0),
          3: FlexColumnWidth(2.0),
          4: FlexColumnWidth(1.5),
          5: FlexColumnWidth(2.0),
        },
        children: [
          TableRow(
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            children: [
              _buildTableHeader('Emp ID'),
              _buildTableHeader('Employee Name'),
              _buildTableHeader('Department'),
              _buildTableHeader('Designation'),
              _buildTableHeader('Status'),
              _buildTableHeader('Actions'),
            ],
          ),
          for (final emp in employees) ...[
            () {
              final payrollRecord = records.firstWhere(
                (r) => r.employeeId == emp.id,
                orElse: () => PayrollRecord(
                  id: 0,
                  employeeId: emp.id,
                  employeeName: '${emp.firstName} ${emp.lastName}',
                  month: selectedMonth,
                  presentDays: 0,
                  lateDays: 0,
                  absentDays: 0,
                  leaveDays: 0,
                  basicPay: 0,
                  hra: 0,
                  specialAllowance: 0,
                  educationAllowance: 0,
                  pf: 0,
                  tax: 0,
                  netSalary: 0,
                  status: 'Not Generated',
                ),
              );

              final isGenerated = payrollRecord.id != 0;

              return TableRow(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                children: [
                  _buildTableCell(Text('EMP${emp.id}', style: const TextStyle(fontWeight: FontWeight.w600))),
                  _buildTableCell(Text('${emp.firstName} ${emp.lastName}', style: const TextStyle(fontWeight: FontWeight.w500))),
                  _buildTableCell(Text(emp.department)),
                  _buildTableCell(Text(emp.designation)),
                  _buildTableCell(_buildStatusBadge(payrollRecord.status)),
                  _buildTableCell(
                    isGenerated
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ElevatedButton(
                                onPressed: () => context.push('/payroll/details/${payrollRecord.id}'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.active,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                child: const Text('View', style: TextStyle(fontSize: 12)),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: () => context.push('/payroll/payslip/${payrollRecord.id}'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: const BorderSide(color: AppColors.primary),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                child: const Text('Payslip', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          )
                        : ElevatedButton.icon(
                            onPressed: () => context.push('/payroll/generate/${emp.id}'),
                            icon: const Icon(Icons.add, size: 14),
                            label: const Text('Generate', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                  ),
                ],
              );
            }()
          ]
        ],
      ),
    );
  }

  Widget _buildMobileEmployeeList(
    BuildContext context,
    dynamic employees,
    List<PayrollRecord> records,
    dynamic attendanceRecords,
    String selectedMonth,
  ) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: employees.length,
      itemBuilder: (context, index) {
        final emp = employees[index];
        final payrollRecord = records.firstWhere(
          (r) => r.employeeId == emp.id,
          orElse: () => PayrollRecord(
            id: 0,
            employeeId: emp.id,
            employeeName: '${emp.firstName} ${emp.lastName}',
            month: selectedMonth,
            presentDays: 0,
            lateDays: 0,
            absentDays: 0,
            leaveDays: 0,
            basicPay: 0,
            hra: 0,
            specialAllowance: 0,
            educationAllowance: 0,
            pf: 0,
            tax: 0,
            netSalary: 0,
            status: 'Not Generated',
          ),
        );

        final isGenerated = payrollRecord.id != 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppColors.divider),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${emp.firstName} ${emp.lastName}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'EMP${emp.id} • ${emp.department} • ${emp.designation}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                    const SizedBox(height: 14),
                    isGenerated
                        ? Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => context.push('/payroll/details/${payrollRecord.id}'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.active,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  child: const Text('View Details', style: TextStyle(fontSize: 12)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => context.push('/payroll/payslip/${payrollRecord.id}'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    side: const BorderSide(color: AppColors.primary),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  child: const Text('Payslip', style: TextStyle(fontSize: 12)),
                                ),
                              ),
                            ],
                          )
                        : SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => context.push('/payroll/generate/${emp.id}'),
                              icon: const Icon(Icons.add, size: 14),
                              label: const Text('Generate Payroll'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                            ),
                          ),
                  ],
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: _buildStatusBadge(payrollRecord.status),
                ),
              ],
            ),
          ),
        );
      },
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
      child: Align(
        alignment: Alignment.centerLeft,
        child: child,
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = Colors.grey[700]!;
    Color bgColor = Colors.grey[100]!;

    if (status == 'Paid' || status == 'Processed') {
      color = Colors.green[700]!;
      bgColor = Colors.green[50]!;
    } else if (status == 'Pending') {
      color = Colors.orange[700]!;
      bgColor = Colors.orange[50]!;
    } else if (status == 'Not Generated') {
      color = Colors.blueGrey[700]!;
      bgColor = Colors.blueGrey[50]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
