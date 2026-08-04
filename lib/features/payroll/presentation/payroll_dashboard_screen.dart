import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/layout/responsive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../employee/providers/employee_providers.dart';
import '../domain/payroll.dart';
import '../providers/payroll_providers.dart';
import '../../leave/providers/leave_providers.dart';
import 'employee_payslip_list_screen.dart';

class PayrollDashboardScreen extends ConsumerWidget {
  const PayrollDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employee = ref.watch(currentEmployeeProvider);
    if (employee != null && employee.userType.toUpperCase() == 'EMPLOYEE') {
      return const EmployeePayslipListScreen();
    }

    final selectedMonth = ref.watch(selectedPayrollMonthProvider);
    final employeesAsync = ref.watch(employeesProvider);
    final payrollRecordsAsync = ref.watch(payrollRecordsForMonthProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < AppBreakpoints.tablet;
          final gutter = AppLayout.gutter(constraints.maxWidth);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(payrollRecordsForMonthProvider);
              ref.invalidate(employeesProvider);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(gutter),
              child: ResponsiveContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header row
                    _buildHeader(context, ref, selectedMonth, isMobile),
                    const SizedBox(height: 24),

                    // Metrics/Stat cards
                    payrollRecordsAsync.when(
                      data: (records) => employeesAsync.when(
                        data: (employees) => _buildMetricsGrid(
                          context,
                          records,
                          employees.length,
                          isMobile,
                        ),
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 24),

                    // Table/List header and title
                    Text(
                      'Payroll Summary - $selectedMonth',
                      style: AppTextStyles.heading,
                    ),
                    const SizedBox(height: 12),

                    // Main Table or Card List
                    payrollRecordsAsync.when(
                      data: (records) {
                        if (records.isEmpty) {
                          return _buildEmptyState(context);
                        }
                        return isMobile
                            ? _buildMobileCardList(context, records)
                            : _buildDesktopTable(context, records);
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, __) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('Error loading payroll: $err'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < AppBreakpoints.tablet;
          if (!isMobile) return const SizedBox.shrink();
          return FloatingActionButton(
            onPressed: () => context.push('/payroll/run'),
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.add, color: Colors.white),
          );
        },
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    String selectedMonth,
    bool isMobile,
  ) {
    final availableMonths = [
      'July 2026',
      'August 2026',
      'September 2026',
    ];

    final monthDropdown = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedMonth,
          icon: const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
          style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          onChanged: (val) {
            if (val != null) {
              ref.read(selectedPayrollMonthProvider.notifier).state = val;
            }
          },
          items: availableMonths
              .map((m) => DropdownMenuItem(value: m, child: Text(m)))
              .toList(),
        ),
      ),
    );

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 12,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Payroll', style: AppTextStyles.pageTitle),
            const SizedBox(height: 4),
            Text(
              'Manage and view active monthly payroll records',
              style: AppTextStyles.caption,
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            monthDropdown,
            if (!isMobile) ...[
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => context.push('/payroll/run'),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Run Payroll'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildMetricsGrid(
    BuildContext context,
    List<PayrollRecord> records,
    int totalEmployeesCount,
    bool isMobile,
  ) {
    // Computations
    final processedCount = records.where((r) => r.status != 'Pending').length;
    final pendingCount = totalEmployeesCount - processedCount;
    final totalPaid = records.fold(0.0, (sum, r) => sum + r.netSalary);
    final formattedTotalPaid = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(totalPaid);

    final cards = [
      _StatCard(
        title: 'Total Employees',
        value: totalEmployeesCount.toString(),
        icon: Icons.people_outline,
      ),
      _StatCard(
        title: 'Processed',
        value: processedCount.toString(),
        icon: Icons.check_circle_outline,
        valueColor: Colors.green[700],
      ),
      _StatCard(
        title: 'Pending',
        value: pendingCount < 0 ? '0' : pendingCount.toString(),
        icon: Icons.pending_actions_outlined,
        valueColor: Colors.orange[700],
      ),
      _StatCard(
        title: 'Total Payroll',
        value: formattedTotalPaid,
        icon: Icons.payments_outlined,
        valueColor: AppColors.primary, // Green accent color as requested
        isAccentValue: true,
      ),
    ];

    if (isMobile) {
      return SizedBox(
        height: 110,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: cards.length,
          itemBuilder: (context, index) {
            return Container(
              width: 170,
              margin: const EdgeInsets.only(right: 12),
              child: cards[index],
            );
          },
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth >= AppBreakpoints.desktop ? 4 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 2.8,
          ),
          itemCount: cards.length,
          itemBuilder: (context, index) => cards[index],
        );
      },
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
          0: FlexColumnWidth(1.2),
          1: FlexColumnWidth(2.5),
          2: FlexColumnWidth(1.5),
          3: FlexColumnWidth(1.8),
          4: FlexColumnWidth(1.8),
          5: FlexColumnWidth(2.2),
        },
        children: [
          // Header row
          TableRow(
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            children: [
              _buildTableHeader('Emp ID'),
              _buildTableHeader('Employee Name'),
              _buildTableHeader('Month'),
              _buildTableHeader('Net Salary'),
              _buildTableHeader('Status'),
              _buildTableHeader('Actions'),
            ],
          ),
          // Data rows
          for (final record in records)
            TableRow(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              children: [
                _buildTableCell(Text('EMP${record.employeeId}', style: const TextStyle(fontWeight: FontWeight.w600))),
                _buildTableCell(Text(record.employeeName, style: const TextStyle(fontWeight: FontWeight.w500))),
                _buildTableCell(Text(record.month)),
                _buildTableCell(Text(
                  NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(record.netSalary),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                )),
                _buildTableCell(_buildStatusPill(record.status, isDisputed: record.isDisputed)),
                _buildTableCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton.icon(
                        onPressed: () => context.push('/payroll/details/${record.id}'),
                        icon: const Icon(Icons.visibility_outlined, size: 14),
                        label: const Text('Details', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.active,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                      const SizedBox(width: 4),
                      TextButton.icon(
                        onPressed: () => context.push('/payroll/payslip/${record.id}'),
                        icon: const Icon(Icons.description_outlined, size: 14),
                        label: const Text('Payslip', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMobileCardList(BuildContext context, List<PayrollRecord> records) {
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
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.employeeName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: EMP${record.employeeId} • ${record.month}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Net Salary', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                            Text(
                              NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(record.netSalary),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => context.push('/payroll/details/${record.id}'),
                              icon: const Icon(Icons.visibility_outlined, size: 20),
                              color: AppColors.active,
                              tooltip: 'Details',
                            ),
                            IconButton(
                              onPressed: () => context.push('/payroll/payslip/${record.id}'),
                              icon: const Icon(Icons.description_outlined, size: 20),
                              color: AppColors.primary,
                              tooltip: 'Payslip',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: _buildStatusPill(record.status, isDisputed: record.isDisputed),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Card(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.payments_outlined,
                size: 48,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 16),
              const Text(
                'No Payroll Generated Yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Generate monthly payroll calculations for your active employees.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => context.push('/payroll/run'),
                icon: const Icon(Icons.add),
                label: const Text('Generate Payroll Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
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
      child: Align(
        alignment: Alignment.centerLeft,
        child: child,
      ),
    );
  }

  Widget _buildStatusPill(String status, {bool isDisputed = false}) {
    if (isDisputed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red[200]!),
        ),
        child: Text(
          'Disputed',
          style: TextStyle(
            color: Colors.red[700],
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    final isPaid = status == 'Paid' || status == 'Processed';
    final color = isPaid ? Colors.green[700]! : Colors.orange[700]!;
    final bgColor = isPaid ? Colors.green[50]! : Colors.orange[50]!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status == 'Paid'
            ? 'Paid'
            : (status == 'Processed' ? 'Processed' : 'Pending'),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    this.valueColor,
    this.isAccentValue = false,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color? valueColor;
  final bool isAccentValue;

  @override
  Widget build(BuildContext context) {
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
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (valueColor ?? AppColors.active).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: valueColor ?? AppColors.active,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: valueColor ?? AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
