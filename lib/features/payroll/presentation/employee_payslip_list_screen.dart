import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/layout/responsive_layout.dart';
import '../../../../core/theme/app_colors.dart';
import '../../employee/domain/employee.dart';
import '../../employee/providers/employee_providers.dart';
import '../../employee/services/offer_letter_save_stub.dart'
    if (dart.library.html) '../../employee/services/offer_letter_save_web.dart'
    if (dart.library.io) '../../employee/services/offer_letter_save_io.dart';
import '../../organization/domain/organization.dart';
import '../../organization/providers/organization_providers.dart';
import '../domain/payroll.dart';
import '../providers/payroll_providers.dart';
import '../services/payslip_pdf_generator.dart';

class EmployeePayslipListScreen extends ConsumerStatefulWidget {
  const EmployeePayslipListScreen({super.key});

  @override
  ConsumerState<EmployeePayslipListScreen> createState() => _EmployeePayslipListScreenState();
}

class _EmployeePayslipListScreenState extends ConsumerState<EmployeePayslipListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int? _downloadingPayrollId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleDownloadPdf(PayrollRecord record, Employee employee) async {
    if (_downloadingPayrollId != null) return;
    setState(() {
      _downloadingPayrollId = record.id;
    });

    try {
      final organizations = ref.read(organizationsProvider).valueOrNull ?? [];
      Organization? resolvedOrg = organizations.where((o) =>
          o.docId == employee.organizationId ||
          o.canonicalId == employee.organizationId ||
          o.name.trim().toLowerCase() == employee.organizationName.trim().toLowerCase()).firstOrNull;

      if (resolvedOrg == null && organizations.isNotEmpty) {
        if (employee.organizationName.toLowerCase().contains('technolog') ||
            employee.employeeId.toUpperCase().startsWith('EMP')) {
          resolvedOrg = organizations.where((o) => o.name.toLowerCase().contains('technolog')).firstOrNull;
        } else if (employee.organizationName.toLowerCase().contains('engineering') ||
            employee.employeeId.toUpperCase().startsWith('IGT')) {
          resolvedOrg = organizations.where((o) => o.name.toLowerCase().contains('engineering')).firstOrNull;
        }
        resolvedOrg ??= organizations.firstOrNull;
      }

      final pdfBytes = await PayslipPdfGenerator.generatePayslipPdf(
        record: record,
        employee: employee,
        organization: resolvedOrg,
      ).timeout(const Duration(seconds: 8));

      final cleanEmpId = (employee.employeeId.isNotEmpty ? employee.employeeId : 'EMP_${record.employeeId}')
          .replaceAll(RegExp(r'[^\w\-_]'), '_');
      final cleanMonth = record.month.replaceAll(RegExp(r'[^\w\-_]'), '_');
      final fileName = 'Payslip_${cleanEmpId}_$cleanMonth.pdf';

      if (mounted) {
        await saveAndDownloadOfferLetter(
          context: context,
          bytes: pdfBytes,
          fileName: fileName,
          docTitle: 'Payslip',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download payslip: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _downloadingPayrollId = null;
        });
      }
    }
  }

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
                            // Only PAID payslips should appear in My Payslips
                            final paidRecords = records
                                .where((r) => r.status.trim().toLowerCase() == 'paid')
                                .toList();

                            // Filter records by search query (matching month name, e.g. "September 2026", "2026", "Sep")
                            final query = _searchQuery.trim().toLowerCase();
                            final filteredRecords = paidRecords.where((r) {
                              if (query.isEmpty) return true;
                              return r.month.toLowerCase().contains(query);
                            }).toList();

                            // Sort newest month/id first
                            filteredRecords.sort((a, b) => b.id.compareTo(a.id));

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildSearchBar(),
                                const SizedBox(height: 16),
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
                                      return _buildPayslipCard(context, record, employee);
                                    },
                                  ),
                              ],
                            );
                          },
                          loading: () => Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildSearchBar(),
                              const SizedBox(height: 16),
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

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) {
          setState(() {
            _searchQuery = val;
          });
        },
        decoration: InputDecoration(
          hintText: 'Search payslip by month or year...',
          hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF414A51), size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildPayslipCard(BuildContext context, PayrollRecord record, Employee employee) {
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
                onPressed: _downloadingPayrollId == record.id
                    ? null
                    : () => _handleDownloadPdf(record, employee),
                icon: _downloadingPayrollId == record.id
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.download_outlined, size: 16),
                label: Text(_downloadingPayrollId == record.id ? 'Downloading...' : 'Download PDF'),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 16),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.description_outlined, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty ? 'No matching payslips found.' : 'No payslips found.',
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try searching with a different month or year.'
                  : 'Your monthly payslips will appear here once marked as paid by HR.',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
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
