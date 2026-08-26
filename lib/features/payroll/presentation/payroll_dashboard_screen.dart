import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/layout/responsive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../employee/providers/employee_providers.dart';
import '../../employee/domain/employee.dart';
import '../domain/payroll.dart';
import '../providers/payroll_providers.dart';
import '../../leave/providers/leave_providers.dart';

class PayrollDashboardScreen extends ConsumerStatefulWidget {
  const PayrollDashboardScreen({super.key});

  @override
  ConsumerState<PayrollDashboardScreen> createState() => _PayrollDashboardScreenState();
}

class _PayrollDashboardScreenState extends ConsumerState<PayrollDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedMonth = ref.watch(selectedPayrollMonthProvider);
    final employeesAsync = ref.watch(employeesProvider);
    final payrollRecordsAsync = ref.watch(payrollRecordsForMonthProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
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
                    _buildHeader(context, selectedMonth, isMobile),
                    const SizedBox(height: 20),

                    // 5 Metric Summary Cards
                    payrollRecordsAsync.when(
                      data: (records) => employeesAsync.when(
                        data: (employees) => _buildMetricsGrid(
                          context,
                          records,
                          employees.length,
                          constraints.maxWidth,
                        ),
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (_, _) => const SizedBox.shrink(),
                      ),
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 24),

                    // Search & Status Filter Controls Bar
                    _buildFilterBar(isMobile),
                    const SizedBox(height: 16),

                    // Main Table or Card List
                    payrollRecordsAsync.when(
                      data: (records) => employeesAsync.when(
                        data: (employees) {
                          // Filter records based on search query and status filter
                          var filtered = records.where((r) {
                            final matchesSearch = _searchQuery.isEmpty ||
                                r.employeeName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                                r.employeeId.toString().contains(_searchQuery);

                            bool matchesStatus = true;
                            if (_statusFilter != 'All') {
                              if (_statusFilter == 'Draft') {
                                matchesStatus = r.status == 'Draft' || r.status == 'Pending';
                              } else {
                                matchesStatus = r.status.toLowerCase() == _statusFilter.toLowerCase();
                              }
                            }
                            return matchesSearch && matchesStatus;
                          }).toList();

                          if (filtered.isEmpty) {
                            return _buildEmptyState(context);
                          }
                          return isMobile
                              ? _buildMobileCardList(context, filtered, employees)
                              : _buildDesktopTable(context, filtered, employees);
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (err, _) => Text('Error loading employees: $err'),
                      ),
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, _) => Card(
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
    );
  }

  Widget _buildHeader(
    BuildContext context,
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
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedMonth,
          icon: const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
          style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
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
            const Text(
              'Manage monthly payroll',
              style: AppTextStyles.caption,
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            monthDropdown,
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () => context.push('/payroll/run'),
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
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
        ),
      ],
    );
  }

  Widget _buildMetricsGrid(
    BuildContext context,
    List<PayrollRecord> records,
    int totalEmployeesCount,
    double width,
  ) {
    // 5 Computations:
    final draftCount = records.where((r) => r.status == 'Draft' || r.status == 'Pending').length;
    final processedCount = records.where((r) => r.status == 'Processed').length;
    final paidCount = records.where((r) => r.status == 'Paid').length;
    final totalNetPayroll = records.fold(0.0, (sum, r) => sum + r.netSalary);

    final formattedTotalNet = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(totalNetPayroll);

    final cards = [
      _StatCard(
        title: 'Total Employees',
        value: totalEmployeesCount.toString(),
        icon: Icons.people_outline,
      ),
      _StatCard(
        title: 'Draft',
        value: draftCount.toString(),
        icon: Icons.edit_note_outlined,
        valueColor: Colors.amber[800],
      ),
      _StatCard(
        title: 'Processed',
        value: processedCount.toString(),
        icon: Icons.check_circle_outline,
        valueColor: Colors.blue[700],
      ),
      _StatCard(
        title: 'Paid',
        value: paidCount.toString(),
        icon: Icons.lock_outlined,
        valueColor: const Color(0xFF9CC70A),
      ),
      _StatCard(
        title: 'Total Net Payroll',
        value: formattedTotalNet,
        icon: Icons.payments_outlined,
        valueColor: AppColors.primary,
        isAccentValue: true,
      ),
    ];

    if (width < AppBreakpoints.tablet) {
      return SizedBox(
        height: 100,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: cards.length,
          itemBuilder: (context, index) {
            return Container(
              width: 155,
              margin: const EdgeInsets.only(right: 12),
              child: cards[index],
            );
          },
        ),
      );
    }

    final crossCount = width >= AppBreakpoints.desktop ? 5 : 3;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.3,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) => cards[index],
    );
  }

  Widget _buildFilterBar(bool isMobile) {
    final searchInput = SizedBox(
      width: isMobile ? double.infinity : 280,
      height: 42,
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search employee by name or ID...',
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

    final statusFilterDropdown = Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _statusFilter,
          icon: const Icon(Icons.filter_alt_outlined, size: 18, color: AppColors.textSecondary),
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          onChanged: (val) {
            if (val != null) setState(() => _statusFilter = val);
          },
          items: const [
            DropdownMenuItem(value: 'All', child: Text('Status: All')),
            DropdownMenuItem(value: 'Draft', child: Text('Status: Draft')),
            DropdownMenuItem(value: 'Processed', child: Text('Status: Processed')),
            DropdownMenuItem(value: 'Paid', child: Text('Status: Paid')),
          ],
        ),
      ),
    );

    if (isMobile) {
      return Column(
        children: [
          searchInput,
          const SizedBox(height: 10),
          Row(children: [Expanded(child: statusFilterDropdown)]),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        searchInput,
        statusFilterDropdown,
      ],
    );
  }

  Widget _buildDesktopTable(BuildContext context, List<PayrollRecord> records, List<Employee> employees) {
    final empMap = {for (var e in employees) e.id: e};

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
          0: FlexColumnWidth(2.2), // Employee
          1: FlexColumnWidth(1.2), // Employee ID
          2: FlexColumnWidth(1.6), // Department
          3: FlexColumnWidth(1.8), // Net Salary
          4: FlexColumnWidth(1.5), // Status
          5: FlexColumnWidth(2.0), // View & Payslip
        },
        children: [
          // Header row
          TableRow(
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            children: [
              _buildTableHeader('Employee'),
              _buildTableHeader('Employee ID'),
              _buildTableHeader('Department'),
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
                _buildTableCell(Text(record.employeeName, style: const TextStyle(fontWeight: FontWeight.w600))),
                _buildTableCell(Text('EMP${record.employeeId}', style: const TextStyle(fontWeight: FontWeight.w500))),
                _buildTableCell(Text(empMap[record.employeeId]?.department ?? 'General')),
                _buildTableCell(Text(
                  NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(record.netSalary),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                )),
                _buildTableCell(_buildStatusBadge(record.status)),
                _buildTableCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton.icon(
                        onPressed: () => context.push('/payroll/details/${record.id}'),
                        icon: const Icon(Icons.visibility_outlined, size: 14),
                        label: const Text('View', style: TextStyle(fontSize: 12)),
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

  Widget _buildMobileCardList(BuildContext context, List<PayrollRecord> records, List<Employee> employees) {
    final empMap = {for (var e in employees) e.id: e};

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final record = records[index];
        final dept = empMap[record.employeeId]?.department ?? 'General';

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
                      record.employeeName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'EMP${record.employeeId} • $dept',
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
                              NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(record.netSalary),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => context.push('/payroll/details/${record.id}'),
                              icon: const Icon(Icons.visibility_outlined, size: 20),
                              color: AppColors.active,
                              tooltip: 'View Details',
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
                  child: _buildStatusBadge(record.status),
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
    Color color;
    Color bgColor;

    if (status == 'Paid') {
      color = const Color(0xFF9CC70A);
      bgColor = const Color(0xFF9CC70A).withValues(alpha: 0.1);
    } else if (status == 'Processed') {
      color = Colors.blue[700]!;
      bgColor = Colors.blue[50]!;
    } else {
      color = Colors.amber[800]!;
      bgColor = Colors.amber[50]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == 'Paid') ...[
            const Icon(Icons.lock_outlined, size: 10, color: Color(0xFF9CC70A)),
            const SizedBox(width: 3),
          ],
          Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.search_off_rounded,
                size: 44,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 12),
              const Text(
                'No Payroll Records Found',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Try adjusting your search query or status filter.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAccentValue ? AppColors.primary.withValues(alpha: 0.4) : AppColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(icon, size: 16, color: valueColor ?? AppColors.textSecondary),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: isAccentValue ? 16 : 18,
                fontWeight: FontWeight.bold,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
