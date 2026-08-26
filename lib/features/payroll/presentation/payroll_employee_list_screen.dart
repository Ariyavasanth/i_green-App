import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/responsive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../employee/providers/employee_providers.dart';
import '../../employee/domain/employee.dart';
import '../../attendance/providers/attendance_providers.dart';
import '../domain/payroll.dart';
import '../providers/payroll_providers.dart';
import '../../leave/providers/leave_providers.dart';

class PayrollEmployeeListScreen extends ConsumerStatefulWidget {
  const PayrollEmployeeListScreen({super.key});

  @override
  ConsumerState<PayrollEmployeeListScreen> createState() => _PayrollEmployeeListScreenState();
}

class _PayrollEmployeeListScreenState extends ConsumerState<PayrollEmployeeListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedMonth = ref.watch(selectedPayrollMonthProvider);
    final settingsAsync = ref.watch(payrollSettingsProvider);
    final settings = settingsAsync.value ?? const PayrollSettings();
    final employeesAsync = ref.watch(employeesProvider);
    final payrollRecordsAsync = ref.watch(payrollRecordsForMonthProvider);
    final attendanceRecordsAsync = ref.watch(allAttendanceRecordsProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Run Payroll', style: AppTextStyles.heading),
            Text(selectedMonth, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.normal)),
          ],
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < AppBreakpoints.tablet;
          final gutter = AppLayout.gutter(constraints.maxWidth);

          return employeesAsync.when(
            data: (employees) => payrollRecordsAsync.when(
              data: (records) => attendanceRecordsAsync.when(
                data: (attendanceRecords) {
                  // Filter employees by search query
                  final filteredEmployees = employees.where((emp) {
                    if (_searchQuery.isEmpty) return true;
                    final query = _searchQuery.toLowerCase();
                    final name = '${emp.firstName} ${emp.lastName}'.toLowerCase();
                    final id = 'emp${emp.id}'.toLowerCase();
                    final dept = emp.department.toLowerCase();
                    final desig = emp.designation.toLowerCase();
                    return name.contains(query) || id.contains(query) || dept.contains(query) || desig.contains(query);
                  }).toList();

                  return SingleChildScrollView(
                    padding: EdgeInsets.all(gutter),
                    child: ResponsiveContent(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSubHeader(selectedMonth, settings),
                          const SizedBox(height: 16),
                          _buildSearchBar(),
                          const SizedBox(height: 16),
                          isMobile
                              ? _buildMobileEmployeeList(
                                  context,
                                  filteredEmployees,
                                  records,
                                  selectedMonth,
                                )
                              : _buildDesktopEmployeeList(
                                  context,
                                  filteredEmployees,
                                  records,
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

  Widget _buildSubHeader(String month, PayrollSettings settings) {
    final parts = month.trim().split(' ');
    int year = DateTime.now().year;
    int monthNum = DateTime.now().month;
    if (parts.length >= 2) {
      year = int.tryParse(parts[1]) ?? year;
      final monthMap = {
        'january': 1, 'february': 2, 'march': 3, 'april': 4, 'may': 5, 'june': 6,
        'july': 7, 'august': 8, 'september': 9, 'october': 10, 'november': 11, 'december': 12
      };
      monthNum = monthMap[parts[0].toLowerCase()] ?? monthNum;
    }
    final period = settings.getPayrollPeriod(year, monthNum);

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
                'Running payroll for period: $month (${period.displayPeriodString}). Select an employee to review or calculate monthly salary.',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return SizedBox(
      height: 44,
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search Employee by Name, ID, Department, Designation...',
          prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textSecondary),
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.primary),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopEmployeeList(
    BuildContext context,
    List<Employee> employees,
    List<PayrollRecord> records,
    String selectedMonth,
  ) {
    if (employees.isEmpty) {
      return _buildEmptyState();
    }

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2.2), // Employee Name
          1: FlexColumnWidth(1.2), // Emp ID
          2: FlexColumnWidth(1.8), // Department
          3: FlexColumnWidth(1.8), // Designation
          4: FlexColumnWidth(1.4), // Status
          5: FlexColumnWidth(2.2), // Actions
        },
        children: [
          TableRow(
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            children: [
              _buildTableHeader('Employee'),
              _buildTableHeader('Employee ID'),
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
                  _buildTableCell(Text('${emp.firstName} ${emp.lastName}', style: const TextStyle(fontWeight: FontWeight.w600))),
                  _buildTableCell(Text('EMP${emp.id}', style: const TextStyle(fontWeight: FontWeight.w500))),
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
                                child: const Text('View Details', style: TextStyle(fontSize: 12)),
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
                            icon: const Icon(Icons.play_arrow_rounded, size: 14),
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
    List<Employee> employees,
    List<PayrollRecord> records,
    String selectedMonth,
  ) {
    if (employees.isEmpty) {
      return _buildEmptyState();
    }

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
          elevation: 0,
          color: Colors.white,
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
                              icon: const Icon(Icons.play_arrow_rounded, size: 14),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondary,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildTableCell(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: child,
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = Colors.grey[700]!;
    Color bgColor = Colors.grey[100]!;

    if (status == 'Paid') {
      color = const Color(0xFF9CC70A);
      bgColor = const Color(0xFF9CC70A).withValues(alpha: 0.1);
    } else if (status == 'Processed') {
      color = Colors.blue[700]!;
      bgColor = Colors.blue[50]!;
    } else if (status == 'Draft' || status == 'Pending') {
      color = Colors.amber[800]!;
      bgColor = Colors.amber[50]!;
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
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 40, horizontal: 16),
        child: Center(
          child: Text(
            'No matching employees found.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ),
      ),
    );
  }
}
