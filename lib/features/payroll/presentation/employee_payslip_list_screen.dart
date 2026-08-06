import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/layout/responsive_layout.dart';
import '../../../../core/theme/app_colors.dart';
import '../../employee/providers/employee_providers.dart';
import '../../leave/providers/leave_providers.dart';
import '../domain/payroll.dart';
import '../providers/payroll_providers.dart';

class EmployeePayslipListScreen extends ConsumerStatefulWidget {
  const EmployeePayslipListScreen({super.key});

  @override
  ConsumerState<EmployeePayslipListScreen> createState() => _EmployeePayslipListScreenState();
}

class _EmployeePayslipListScreenState extends ConsumerState<EmployeePayslipListScreen> {
  String? _selectedYear;

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(employeesProvider);
    final employee = ref.watch(currentEmployeeProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
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
                        recordsAsync.when(
                          data: (records) {
                            // Extract unique years from month strings (e.g. "June 2026" -> "2026")
                            final years = records
                                .map((r) => r.month.trim().split(' ').last)
                                .where((y) => y.length == 4 && int.tryParse(y) != null)
                                .toSet()
                                .toList();
                            years.sort((a, b) => b.compareTo(a)); // Descending order

                            // Default selected year if not set or no longer valid
                            if (_selectedYear == null || !years.contains(_selectedYear)) {
                              if (years.isNotEmpty) {
                                _selectedYear = years.first;
                              } else {
                                _selectedYear = DateTime.now().year.toString();
                              }
                            }

                            final filteredRecords = records
                                .where((r) => r.month.trim().endsWith(_selectedYear!))
                                .toList();

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'My payslips',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    if (years.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: AppColors.divider, width: 0.5),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: _selectedYear,
                                            icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary, size: 18),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                            ),
                                            dropdownColor: Colors.white,
                                            items: years.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                                            onChanged: (val) {
                                              if (val != null) {
                                                setState(() {
                                                  _selectedYear = val;
                                                });
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                if (filteredRecords.isEmpty)
                                  _buildEmptyState()
                                else
                                  ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: filteredRecords.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                                    itemBuilder: (context, index) {
                                      final record = filteredRecords[index];
                                      return _buildCompactPayslipCard(context, record);
                                    },
                                  ),
                              ],
                            );
                          },
                          loading: () => Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'My payslips',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Container(
                                    width: 80,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.divider, width: 0.5),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              _buildSkeletonLoader(),
                            ],
                          ),
                          error: (err, _) => Card(
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: AppColors.divider, width: 0.5),
                            ),
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
        loading: () => const Scaffold(
          backgroundColor: AppColors.canvas,
          body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
        ),
        error: (err, _) => Scaffold(
          backgroundColor: AppColors.canvas,
          body: Center(child: Text('Error loading account: $err')),
        ),
      ),
    );
  }

  Widget _buildCompactPayslipCard(BuildContext context, PayrollRecord record) {
    return GestureDetector(
      onTap: () => context.push('/payroll/payslip/${record.id}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider, width: 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.month,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(record.netSalary),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            _buildStatusPill(record),
          ],
        ),
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

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 80, horizontal: 16),
      child: Center(
        child: Text(
          'Your payslips will appear here once payroll is processed.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(4, (index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider, width: 0.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 120,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 70,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
              Container(
                width: 70,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
          ),
        ),
      )),
    );
  }
}
