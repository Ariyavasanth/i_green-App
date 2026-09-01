import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/layout/responsive_layout.dart';
import '../../../../core/theme/app_colors.dart';
import '../../employee/providers/employee_providers.dart';
import '../domain/payroll.dart';
import '../providers/payroll_providers.dart';

class EmployeePayslipListScreen extends ConsumerStatefulWidget {
  const EmployeePayslipListScreen({super.key});

  @override
  ConsumerState<EmployeePayslipListScreen> createState() => _EmployeePayslipListScreenState();
}

class _EmployeePayslipListScreenState extends ConsumerState<EmployeePayslipListScreen> {
  String? _selectedYear;
  String _selectedStatusFilter = 'All';

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

                            // Filter records by selected year and status
                            var filteredRecords = records
                                .where((r) => r.month.trim().endsWith(_selectedYear!))
                                .toList();

                            if (_selectedStatusFilter != 'All') {
                              filteredRecords = filteredRecords
                                  .where((r) => r.status.toLowerCase() == _selectedStatusFilter.toLowerCase())
                                  .toList();
                            }

                            // Sort newest month first
                            filteredRecords.sort((a, b) => b.id.compareTo(a.id));

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Top Header Row
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: const [
                                          Text(
                                            'My Payslips',
                                            style: TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'Your monthly salary statements',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (years.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: AppColors.divider, width: 1),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: _selectedYear,
                                            icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary, size: 20),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
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
                                const SizedBox(height: 20),

                                // Status Filter Chips: [ All ] [ Paid ] [ Processed ]
                                Wrap(
                                  spacing: 8,
                                  children: ['All', 'Paid', 'Processed'].map((status) {
                                    final isSelected = _selectedStatusFilter == status;
                                    return ChoiceChip(
                                      label: Text(status),
                                      selected: isSelected,
                                      onSelected: (selected) {
                                        if (selected) {
                                          setState(() {
                                            _selectedStatusFilter = status;
                                          });
                                        }
                                      },
                                      selectedColor: AppColors.primary,
                                      labelStyle: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: isSelected ? Colors.white : AppColors.textPrimary,
                                      ),
                                      backgroundColor: Colors.white,
                                      side: BorderSide(
                                        color: isSelected ? AppColors.primary : AppColors.divider,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 20),

                                if (filteredRecords.isEmpty)
                                  _buildEmptyState()
                                else
                                  ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: filteredRecords.length,
                                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                                    itemBuilder: (context, index) {
                                      final record = filteredRecords[index];
                                      return _buildPayslipCard(context, record);
                                    },
                                  ),
                              ],
                            );
                          },
                          loading: () => Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'My Payslips',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Your monthly salary statements',
                                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
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

  Widget _buildPayslipCard(BuildContext context, PayrollRecord record) {
    final formattedNetSalary = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(record.netSalary);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                record.month,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              _buildStatusPill(record),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Net Salary: ',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                formattedNetSalary,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => context.push('/payroll/payslip/${record.id}'),
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('View Payslip'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => context.push('/payroll/payslip/${record.id}'),
                icon: const Icon(Icons.download_outlined, size: 16),
                label: const Text('Download PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(PayrollRecord record) {
    final isPaid = record.status == 'Paid';
    final isProcessed = record.status == 'Processed';
    
    Color color;
    Color bgColor;
    String label;

    if (isPaid) {
      color = const Color(0xFF9CC70A);
      bgColor = const Color(0xFF9CC70A).withValues(alpha: 0.1);
      label = 'Paid';
    } else if (isProcessed) {
      color = Colors.blue[700]!;
      bgColor = Colors.blue[50]!;
      label = 'Processed';
    } else {
      color = Colors.amber[800]!;
      bgColor = Colors.amber[50]!;
      label = record.status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPaid) ...[
            const Icon(Icons.lock_outlined, size: 12, color: Color(0xFF9CC70A)),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 60, horizontal: 16),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.description_outlined, size: 48, color: AppColors.textSecondary),
            SizedBox(height: 12),
            Text(
              'No payslips found for the selected filter.',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 4),
            Text(
              'Your monthly payslips will appear here once payroll is processed by HR.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(3, (index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 120,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Container(
                    width: 60,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: 160,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 110,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 120,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      )),
    );
  }
}
