import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../employee/domain/employee.dart';
import '../../employee/providers/employee_providers.dart';
import '../../employee/services/offer_letter_save_stub.dart'
    if (dart.library.html) '../../employee/services/offer_letter_save_web.dart'
    if (dart.library.io) '../../employee/services/offer_letter_save_io.dart';
import '../../organization/providers/organization_providers.dart';
import '../../payroll/providers/payroll_providers.dart';
import '../domain/employee_loan.dart';
import '../providers/loan_providers.dart';
import '../services/loan_statement_pdf_generator.dart';

class LoanPage extends ConsumerStatefulWidget {
  const LoanPage({super.key});

  @override
  ConsumerState<LoanPage> createState() => _LoanPageState();
}

class _LoanPageState extends ConsumerState<LoanPage> {
  String _searchQuery = '';
  String _selectedTypeFilter = 'All';

  final List<String> _loanTypes = [
    'All',
    'Personal Loan',
    'Salary Advance',
    'Emergency Loan',
    'Education Loan',
    'Medical Loan',
    'Other'
  ];

  @override
  Widget build(BuildContext context) {
    final currentEmp = ref.watch(currentEmployeeProvider);

    if (currentEmp == null) {
      return const Scaffold(
        backgroundColor: AppColors.canvas,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final loansAsync = ref.watch(employeeLoansProvider(currentEmp.id));

    return Scaffold(
      backgroundColor: AppColors.canvas,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRequestLoanDialog(context, currentEmp),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Request Loan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 700;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(employeeLoansProvider(currentEmp.id));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Metrics Cards
                  loansAsync.when(
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (err, _) => Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('Error loading summary: $err',
                          style: TextStyle(color: Colors.red.shade700)),
                    ),
                    data: (loans) => _buildDashboardSummary(loans, isMobile),
                  ),
                  const SizedBox(height: 20),

                  // Search & Filters
                  _buildSearchAndFilters(isMobile),
                  const SizedBox(height: 16),

                  // Loans Table or Cards
                  loansAsync.when(
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (err, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text('Error loading loans: $err'),
                      ),
                    ),
                    data: (loans) {
                      final filtered = loans.where((loan) {
                        if (_searchQuery.isNotEmpty) {
                          final q = _searchQuery.toLowerCase();
                          final matchId = loan.loanId.toLowerCase().contains(q);
                          final matchType = loan.loanType.toLowerCase().contains(q);
                          if (!matchId && !matchType) return false;
                        }
                        if (_selectedTypeFilter != 'All' && loan.loanType != _selectedTypeFilter) {
                          return false;
                        }
                        return true;
                      }).toList();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              '${filtered.length} ${filtered.length == 1 ? 'Loan' : 'Loans'}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          if (filtered.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(40),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.info_outline, size: 40, color: AppColors.textSecondary),
                                  SizedBox(height: 12),
                                  Text(
                                    'No loan records found.',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'If you need financial assistance, click "Request Loan" below to apply.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                  ),
                                ],
                              ),
                            )
                          else if (isMobile)
                            _buildLoansListMobile(filtered, currentEmp)
                          else
                            _buildLoansTable(filtered, constraints.maxWidth, currentEmp),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDashboardSummary(List<EmployeeLoan> loans, bool isMobile) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    final activeLoansCount = loans.where((l) => l.status.toLowerCase() == 'active').length;
    final pendingLoansCount = loans.where((l) => l.status.toLowerCase().startsWith('pending')).length;
    final closedLoansCount = loans.where((l) => l.status.toLowerCase() == 'closed').length;

    final outstandingSum = loans
        .where((l) => l.status.toLowerCase() == 'active' || l.status.toLowerCase() == 'approved')
        .fold<double>(0, (sum, l) => sum + l.remainingBalance);

    if (isMobile) {
      return GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.65,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          _buildLoanSummaryCard(
            title: 'Outstanding',
            value: currencyFormat.format(outstandingSum),
            icon: Icons.account_balance_wallet_outlined,
            color: Colors.blue,
          ),
          _buildLoanSummaryCard(
            title: 'Active Loans',
            value: '$activeLoansCount',
            icon: Icons.check_circle_outline,
            color: AppColors.primary,
          ),
          _buildLoanSummaryCard(
            title: 'Pending',
            value: '$pendingLoansCount',
            icon: Icons.hourglass_empty,
            color: Colors.orange,
          ),
          _buildLoanSummaryCard(
            title: 'Closed Loans',
            value: '$closedLoansCount',
            icon: Icons.assignment_turned_in_outlined,
            color: Colors.grey,
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _buildLoanSummaryCard(
            title: 'Outstanding',
            value: currencyFormat.format(outstandingSum),
            icon: Icons.account_balance_wallet_outlined,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildLoanSummaryCard(
            title: 'Active Loans',
            value: '$activeLoansCount',
            icon: Icons.check_circle_outline,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildLoanSummaryCard(
            title: 'Pending',
            value: '$pendingLoansCount',
            icon: Icons.hourglass_empty,
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildLoanSummaryCard(
            title: 'Closed Loans',
            value: '$closedLoansCount',
            icon: Icons.assignment_turned_in_outlined,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildLoanSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    Color color = AppColors.textSecondary,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                icon,
                size: 20,
                color: color,
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(bool isMobile) {
    final searchField = TextField(
      onChanged: (val) => setState(() => _searchQuery = val),
      decoration: InputDecoration(
        hintText: 'Search loan ID or type...',
        hintStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );

    final typeDropdown = DropdownButtonFormField<String>(
      initialValue: _selectedTypeFilter,
      decoration: _filterDropdownDecoration('Loan Type'),
      isDense: true,
      items: _loanTypes.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(item, style: const TextStyle(fontSize: 13)),
        );
      }).toList(),
      onChanged: (val) => setState(() => _selectedTypeFilter = val ?? 'All'),
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          searchField,
          const SizedBox(height: 12),
          typeDropdown,
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          flex: 4,
          child: searchField,
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: typeDropdown,
        ),
      ],
    );
  }

  InputDecoration _filterDropdownDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }

  Widget _buildLoansListMobile(List<EmployeeLoan> loans, Employee employee) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: loans.length,
      itemBuilder: (context, index) {
        final loan = loans[index];
        final isPending = loan.status.trim().toLowerCase().startsWith('pending');
        return _EmployeeMobileLoanCard(
          loanId: loan.loanId,
          loanType: loan.loanType,
          loanAmount: currencyFormat.format(loan.loanAmount),
          emi: currencyFormat.format(loan.emiAmount),
          balance: currencyFormat.format(loan.remainingBalance),
          status: loan.status,
          onView: () => context.push('/loan/details/${loan.id}'),
          onEdit: isPending ? () => _showRequestLoanDialog(context, employee, loanToEdit: loan) : null,
          onDownload: () => _downloadStatement(loan),
        );
      },
    );
  }

  Future<void> _downloadStatement(EmployeeLoan loan) async {
    try {
      final employeesList = ref.read(employeesProvider).asData?.value ?? [];
      final employee = employeesList.where((e) =>
          e.id == loan.employeeId ||
          e.employeeId.trim().toUpperCase() == loan.employeeCustomId.trim().toUpperCase()
      ).firstOrNull;

      final payrolls = ref.read(allPayrollRecordsProvider).asData?.value ?? [];
      final orgList = ref.read(organizationsProvider).asData?.value ?? [];
      final org = orgList.firstOrNull;

      final pdfBytes = await LoanStatementPdfGenerator.generateStatementPdf(
        loan: loan,
        employee: employee,
        organization: org,
        payrolls: payrolls,
      );

      final cleanLoanId = loan.loanId.replaceAll(RegExp(r'[^\w\-_]'), '_');
      final cleanName = loan.employeeName.replaceAll(RegExp(r'[^\w\-_]'), '_');
      final fileName = 'Loan_Statement_${cleanLoanId}_$cleanName.pdf';

      if (mounted) {
        await saveAndDownloadOfferLetter(
          context: context,
          bytes: pdfBytes,
          fileName: fileName,
          docTitle: 'Loan Statement',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download loan statement: $e'),
            backgroundColor: Colors.red[800],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildLoansTable(List<EmployeeLoan> loans, double screenWidth, Employee employee) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    const minTableWidth = 900.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: screenWidth < minTableWidth ? minTableWidth : screenWidth - 48,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(Colors.grey.withValues(alpha: 0.04)),
              headingRowHeight: 46,
              dataRowMinHeight: 56,
              dataRowMaxHeight: 64,
              horizontalMargin: 16,
              columnSpacing: 18,
              headingTextStyle: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
              columns: const [
                DataColumn(label: Text('LOAN ID')),
                DataColumn(label: Text('LOAN TYPE')),
                DataColumn(label: Text('LOAN AMOUNT')),
                DataColumn(label: Text('EMI AMOUNT')),
                DataColumn(label: Text('BALANCE')),
                DataColumn(label: Text('FIRST DEDUCTION')),
                DataColumn(label: Text('STATUS')),
                DataColumn(label: Text('ACTIONS')),
              ],
              rows: loans.map((loan) {
                final isPending = loan.status.trim().toLowerCase().startsWith('pending');
                return DataRow(
                  cells: [
                    DataCell(Text(loan.loanId, style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(loan.loanType)),
                    DataCell(Text(currencyFormat.format(loan.loanAmount), style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(Text(isPending ? '-' : currencyFormat.format(loan.emiAmount))),
                    DataCell(Text(isPending ? '-' : currencyFormat.format(loan.remainingBalance), style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(Text(isPending ? '-' : loan.firstDeductionMonth)),
                    DataCell(_buildStatusBadge(loan.status)),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isPending)
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.active),
                              onPressed: () => _showRequestLoanDialog(context, employee, loanToEdit: loan),
                              tooltip: 'Edit Request',
                            ),
                          IconButton(
                            icon: const Icon(Icons.visibility_outlined, size: 20),
                            onPressed: () => context.push('/loan/details/${loan.id}'),
                            tooltip: 'View Details',
                          ),
                          IconButton(
                            icon: const Icon(Icons.download_outlined, size: 20, color: AppColors.primary),
                            onPressed: () => _downloadStatement(loan),
                            tooltip: 'Download Statement',
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = Colors.grey.shade700;
    Color bgColor = Colors.grey.shade100;
    final norm = status.trim().toLowerCase();

    if (norm == 'active') {
      color = AppColors.primary;
      bgColor = AppColors.primary.withValues(alpha: 0.12);
    } else if (norm.startsWith('pending')) {
      color = Colors.orange.shade800;
      bgColor = Colors.orange.shade50;
    } else if (norm == 'approved') {
      color = Colors.blue.shade700;
      bgColor = Colors.blue.shade50;
    } else if (norm == 'rejected') {
      color = Colors.red.shade700;
      bgColor = Colors.red.shade50;
    } else if (norm == 'closed') {
      color = Colors.grey.shade600;
      bgColor = Colors.grey.shade100;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  void _showRequestLoanDialog(BuildContext context, Employee employee, {EmployeeLoan? loanToEdit}) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _RequestLoanDialog(
          employee: employee,
          loanToEdit: loanToEdit,
        );
      },
    ).then((_) {
      ref.invalidate(employeeLoansProvider(employee.id));
      ref.invalidate(allLoansProvider);
      if (loanToEdit != null) {
        ref.invalidate(loanByIdProvider(loanToEdit.id));
      }
    });
  }
}

class _EmployeeMobileLoanCard extends StatelessWidget {
  final String loanId;
  final String loanType;
  final String loanAmount;
  final String emi;
  final String balance;
  final String status;
  final VoidCallback onView;
  final VoidCallback? onEdit;
  final VoidCallback onDownload;

  const _EmployeeMobileLoanCard({
    required this.loanId,
    required this.loanType,
    required this.loanAmount,
    required this.emi,
    required this.balance,
    required this.status,
    required this.onView,
    this.onEdit,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor = Colors.grey.shade700;
    Color statusBgColor = Colors.grey.shade100;
    final norm = status.trim().toLowerCase();

    if (norm == 'active') {
      statusColor = AppColors.primary;
      statusBgColor = AppColors.primary.withValues(alpha: 0.12);
    } else if (norm.startsWith('pending')) {
      statusColor = Colors.orange.shade800;
      statusBgColor = Colors.orange.shade50;
    } else if (norm == 'approved') {
      statusColor = Colors.blue.shade700;
      statusBgColor = Colors.blue.shade50;
    } else if (norm == 'rejected') {
      statusColor = Colors.red.shade700;
      statusBgColor = Colors.red.shade50;
    } else if (norm == 'closed') {
      statusColor = Colors.grey.shade600;
      statusBgColor = Colors.grey.shade100;
    }

    final isPending = norm.startsWith('pending');
    final isApprovedOrActive = norm == 'approved' || norm == 'active' || norm == 'closed';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loanId,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      loanType,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                color: Colors.white,
                elevation: 3,
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onEdit?.call();
                      break;
                    case 'view':
                      onView();
                      break;
                    case 'download':
                      onDownload();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  if (isPending && onEdit != null)
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.edit_outlined, size: 20),
                        title: Text('Edit loan'),
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'view',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.visibility_outlined, size: 20),
                      title: Text('View loan'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'download',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.download_outlined, size: 20),
                      title: Text('Download statement'),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          Text(
            loanAmount,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),

          if (isApprovedOrActive) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'EMI',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        emi,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Balance',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        balance,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 14),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onView,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.active,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('View details', style: TextStyle(fontWeight: FontWeight.w600)),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward,
                      size: 16,
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
}

class _RequestLoanDialog extends ConsumerStatefulWidget {
  const _RequestLoanDialog({
    required this.employee,
    this.loanToEdit,
  });
  final Employee employee;
  final EmployeeLoan? loanToEdit;

  @override
  ConsumerState<_RequestLoanDialog> createState() => _RequestLoanDialogState();
}

class _RequestLoanDialogState extends ConsumerState<_RequestLoanDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _installmentsController;
  late final TextEditingController _emiController;
  late final TextEditingController _purposeController;
  late final TextEditingController _descriptionController;
  late String _selectedLoanType;

  final List<String> _loanTypes = [
    'Personal Loan',
    'Salary Advance',
    'Emergency Loan',
    'Education Loan',
    'Medical Loan',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    final loan = widget.loanToEdit;
    _selectedLoanType = loan?.loanType ?? 'Personal Loan';
    if (!_loanTypes.contains(_selectedLoanType) && _selectedLoanType.isNotEmpty) {
      _loanTypes.add(_selectedLoanType);
    }
    _amountController = TextEditingController(
      text: loan != null
          ? (loan.loanAmount == loan.loanAmount.roundToDouble()
              ? loan.loanAmount.toInt().toString()
              : loan.loanAmount.toString())
          : '',
    );
    _purposeController = TextEditingController(
      text: loan?.purpose ?? '',
    );
    _descriptionController = TextEditingController(
      text: loan?.remarks ?? '',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _purposeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<String> _generateNewLoanId() async {
    try {
      final loans = await ref.read(loanRepositoryProvider).getAllLoans();
      int maxNum = 0;
      for (final l in loans) {
        final cleanId = l.loanId.replaceAll(RegExp(r'[^0-9]'), '');
        final numPart = int.tryParse(cleanId) ?? 0;
        if (numPart > maxNum) maxNum = numPart;
      }
      return 'LN${(maxNum + 1).toString().padLeft(3, '0')}';
    } catch (_) {
      return 'LN003';
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final isEdit = widget.loanToEdit != null;
    final now = DateTime.now();

    if (isEdit) {
      final existingLoan = widget.loanToEdit!;
      final updatedLoan = existingLoan.copyWith(
        loanType: _selectedLoanType,
        loanAmount: amount,
        purpose: _purposeController.text.trim(),
        remarks: _descriptionController.text.trim(),
      );

      try {
        await ref.read(loanRepositoryProvider).saveLoan(updatedLoan);
        ref.invalidate(allLoansProvider);
        ref.invalidate(employeeLoansProvider(widget.employee.id));
        ref.invalidate(loanByIdProvider(existingLoan.id));
        ref.invalidate(loanByIdProvider(updatedLoan.id));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Loan request updated successfully.'),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update loan request: $e'),
              backgroundColor: Colors.red[800],
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } else {
      final generatedId = await _generateNewLoanId();

      final loanRequest = EmployeeLoan(
        id: 0,
        loanId: generatedId,
        employeeId: widget.employee.id,
        employeeName: widget.employee.fullName,
        employeeCustomId: widget.employee.employeeId,
        department: widget.employee.department,
        designation: widget.employee.designation,
        loanType: _selectedLoanType,
        loanAmount: amount,
        loanDate: DateFormat('yyyy-MM-dd').format(now),
        disbursementDate: '',
        purpose: _purposeController.text.trim(),
        installments: 0,
        emiAmount: 0.0,
        firstDeductionMonth: '',
        lastDeductionMonth: '',
        interestRate: 0.0,
        totalRepayableAmount: 0.0,
        requestedBy: widget.employee.fullName,
        approvedBy: '',
        approvalDate: '',
        remarks: _descriptionController.text.trim(),
        status: 'Pending',
        remainingBalance: 0.0,
      );

      try {
        await ref.read(loanRepositoryProvider).saveLoan(loanRequest);
        ref.invalidate(allLoansProvider);
        ref.invalidate(employeeLoansProvider(widget.employee.id));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Loan request submitted successfully.'),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to submit loan request: $e'),
              backgroundColor: Colors.red[800],
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.loanToEdit != null;
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Row(
        children: [
          const Icon(Icons.rate_review_outlined, color: AppColors.active),
          const SizedBox(width: 10),
          Text(
            isEdit ? 'Edit Loan Request' : 'Request New Loan',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: _inputDecoration('Loan Type'),
                initialValue: _selectedLoanType,
                items: _loanTypes.where((t) => t != 'All').map((type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedLoanType = val!;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: _inputDecoration('Loan Amount (₹)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Amount is required';
                  final parsed = double.tryParse(val);
                  if (parsed == null || parsed <= 0) return 'Enter a valid positive number';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _purposeController,
                decoration: _inputDecoration('Purpose of Loan'),
                maxLines: 2,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Purpose is required';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: _inputDecoration('Description'),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _submitRequest,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(isEdit ? 'Save Changes' : 'Submit Request'),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
      filled: true,
      fillColor: Colors.grey.withValues(alpha: 0.02),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.divider, width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }
}
