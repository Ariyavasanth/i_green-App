import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../employee/providers/employee_providers.dart';
import '../domain/employee_loan.dart';
import '../providers/loan_providers.dart';

class LoanManagementPage extends ConsumerStatefulWidget {
  const LoanManagementPage({super.key});

  @override
  ConsumerState<LoanManagementPage> createState() => _LoanManagementPageState();
}

class _LoanManagementPageState extends ConsumerState<LoanManagementPage> {
  String _searchQuery = '';
  String _selectedDeptFilter = 'All';
  String _selectedTypeFilter = 'All';
  String _selectedStatusFilter = 'All';

  final List<String> _departments = [
    'All',
    'Administration',
    'Human Resources',
    'Information Technology',
    'Admin Support',
    'Management',
    'Finance',
    'Project',
    'Execution',
    'Business Development',
    'Production Unit',
    'Production Support',
    'Labour',
    'Others'
  ];

  final List<String> _loanTypes = [
    'All',
    'Personal Loan',
    'Salary Advance',
    'Emergency Loan',
    'Education Loan',
    'Medical Loan',
    'Other'
  ];

  final List<String> _statuses = [
    'All',
    'Active',
    'Pending Supervisor',
    'Pending HR',
    'Pending MD',
    'Approved',
    'Rejected',
    'Closed'
  ];

  @override
  Widget build(BuildContext context) {
    final loansAsync = ref.watch(allLoansProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 700;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(allLoansProvider);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Page Header
                  _buildPageHeader(isMobile),
                  const SizedBox(height: 20),

                  // Summary Cards
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

                  // Search & Filter Controls
                  _buildSearchAndFilters(isMobile),
                  const SizedBox(height: 16),

                  // Loan List / Table
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
                        // Unified Search Filter
                        if (_searchQuery.isNotEmpty) {
                          final q = _searchQuery.toLowerCase();
                          final matchName = loan.employeeName.toLowerCase().contains(q);
                          final matchEmpId = loan.employeeCustomId.toLowerCase().contains(q);
                          final matchLoanId = loan.loanId.toLowerCase().contains(q);
                          if (!matchName && !matchEmpId && !matchLoanId) {
                            return false;
                          }
                        }
                        // Department filter
                        if (_selectedDeptFilter != 'All' && loan.department != _selectedDeptFilter) {
                          return false;
                        }
                        // Loan Type filter
                        if (_selectedTypeFilter != 'All' && loan.loanType != _selectedTypeFilter) {
                          return false;
                        }
                        // Status filter
                        if (_selectedStatusFilter != 'All') {
                          if (_selectedStatusFilter == 'Active' && loan.status.toLowerCase() != 'active') {
                            return false;
                          } else if (_selectedStatusFilter == 'Closed' && loan.status.toLowerCase() != 'closed') {
                            return false;
                          } else if (loan.status != _selectedStatusFilter) {
                            return false;
                          }
                        }
                        return true;
                      }).toList();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Counter
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
                                  Icon(Icons.search_off_outlined, size: 40, color: AppColors.textSecondary),
                                  SizedBox(height: 12),
                                  Text(
                                    'No loan records match your criteria.',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (isMobile)
                            _buildMobileLoanList(filtered)
                          else
                            _buildLoansTable(filtered, constraints.maxWidth),
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

  Widget _buildPageHeader(bool isMobile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.account_balance, size: 24, color: AppColors.active),
                  SizedBox(width: 8),
                  Text(
                    'Loan Management',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Manage and track employee loans and repayments',
                style: TextStyle(
                  fontSize: isMobile ? 12 : 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 14 : 18,
              vertical: isMobile ? 10 : 12,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.add, size: 18),
          label: Text(
            'Create Loan',
            style: TextStyle(
              fontSize: isMobile ? 13 : 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          onPressed: () => context.push('/loan-management/create'),
        ),
      ],
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
        hintText: 'Search employee, ID or loan ID',
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

    final statusDropdown = DropdownButtonFormField<String>(
      initialValue: _selectedStatusFilter,
      decoration: _filterDropdownDecoration('Status'),
      isDense: true,
      items: _statuses.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(item, style: const TextStyle(fontSize: 13)),
        );
      }).toList(),
      onChanged: (val) => setState(() => _selectedStatusFilter = val ?? 'All'),
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

    final deptDropdown = DropdownButtonFormField<String>(
      initialValue: _selectedDeptFilter,
      decoration: _filterDropdownDecoration('Department'),
      isDense: true,
      items: _departments.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(item, style: const TextStyle(fontSize: 13)),
        );
      }).toList(),
      onChanged: (val) => setState(() => _selectedDeptFilter = val ?? 'All'),
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          searchField,
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: statusDropdown),
              const SizedBox(width: 10),
              Expanded(child: typeDropdown),
            ],
          ),
          const SizedBox(height: 10),
          deptDropdown,
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
          child: statusDropdown,
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: typeDropdown,
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: deptDropdown,
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

  Widget _buildMobileLoanList(List<EmployeeLoan> loans) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: loans.length,
      itemBuilder: (context, index) {
        final loan = loans[index];
        return MobileLoanCard(
          employeeName: loan.employeeName,
          employeeId: loan.employeeCustomId.isNotEmpty ? loan.employeeCustomId : loan.loanId,
          loanType: loan.loanType,
          loanAmount: currencyFormat.format(loan.loanAmount),
          emi: currencyFormat.format(loan.emiAmount),
          balance: currencyFormat.format(loan.remainingBalance),
          status: loan.status,
          onView: () => context.push('/loan-management/details/${loan.id}'),
          onHistory: () => _showEmployeeLoanHistory(loan),
          onEdit: () => context.push('/loan-management/create', extra: loan),
          onDownload: () => _showSnackBar('Statement downloaded for loan ${loan.loanId}.'),
          onApprove: (loan.status == 'Pending' || loan.status.startsWith('Pending '))
              ? () => _handleAction('approve', loan)
              : null,
          onReject: (loan.status == 'Pending' || loan.status.startsWith('Pending '))
              ? () => _handleAction('reject', loan)
              : null,
          onActivate: loan.status == 'Approved'
              ? () => _handleAction('activate', loan)
              : null,
          onClose: loan.status == 'Active'
              ? () => _handleAction('close', loan)
              : null,
        );
      },
    );
  }

  Widget _buildLoansTable(List<EmployeeLoan> loans, double screenWidth) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    const minTableWidth = 980.0;

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
                DataColumn(label: Text('EMPLOYEE')),
                DataColumn(label: Text('LOAN ID')),
                DataColumn(label: Text('LOAN TYPE')),
                DataColumn(label: Text('LOAN AMOUNT')),
                DataColumn(label: Text('EMI')),
                DataColumn(label: Text('BALANCE')),
                DataColumn(label: Text('STATUS')),
                DataColumn(label: Text('ACTIONS')),
              ],
              rows: loans.map((loan) {
                return DataRow(
                  cells: [
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(loan.employeeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(loan.employeeCustomId, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                        ],
                      ),
                    ),
                    DataCell(Text(loan.loanId, style: const TextStyle(fontWeight: FontWeight.w500))),
                    DataCell(Text(loan.loanType)),
                    DataCell(Text(currencyFormat.format(loan.loanAmount), style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(Text(currencyFormat.format(loan.emiAmount))),
                    DataCell(Text(currencyFormat.format(loan.remainingBalance), style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(_buildStatusBadge(loan.status)),
                    DataCell(_buildActionsCell(loan)),
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

  Widget _buildActionsCell(EmployeeLoan loan) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz, size: 20),
      color: Colors.white,
      elevation: 3,
      onSelected: (val) => _handleAction(val, loan),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'view',
          child: Row(children: [Icon(Icons.visibility_outlined, size: 16), SizedBox(width: 8), Text('View loan')]),
        ),
        const PopupMenuItem(
          value: 'history',
          child: Row(children: [Icon(Icons.history_outlined, size: 16), SizedBox(width: 8), Text('Loan history')]),
        ),
        const PopupMenuItem(
          value: 'edit',
          child: Row(children: [Icon(Icons.edit_outlined, size: 16), SizedBox(width: 8), Text('Edit loan')]),
        ),
        if (loan.status == 'Pending' || loan.status.startsWith('Pending ')) ...[
          const PopupMenuItem(
            value: 'approve',
            child: Row(children: [Icon(Icons.check_circle_outline, size: 16, color: Colors.blue), SizedBox(width: 8), Text('Approve', style: TextStyle(color: Colors.blue))]),
          ),
          const PopupMenuItem(
            value: 'reject',
            child: Row(children: [Icon(Icons.cancel_outlined, size: 16, color: Colors.red), SizedBox(width: 8), Text('Reject', style: TextStyle(color: Colors.red))]),
          ),
        ],
        if (loan.status == 'Approved')
          const PopupMenuItem(
            value: 'activate',
            child: Row(children: [Icon(Icons.play_circle_outline, size: 16, color: Colors.green), SizedBox(width: 8), Text('Activate Loan', style: TextStyle(color: Colors.green))]),
          ),
        if (loan.status == 'Active')
          const PopupMenuItem(
            value: 'close',
            child: Row(children: [Icon(Icons.lock_outline, size: 16, color: Colors.grey), SizedBox(width: 8), Text('Close Loan', style: TextStyle(color: Colors.grey))]),
          ),
        const PopupMenuItem(
          value: 'download',
          child: Row(children: [Icon(Icons.download_outlined, size: 16), SizedBox(width: 8), Text('Download statement')]),
        ),
      ],
    );
  }

  Future<void> _handleAction(String action, EmployeeLoan loan) async {
    final repository = ref.read(loanRepositoryProvider);

    try {
      switch (action) {
        case 'view':
          context.push('/loan-management/details/${loan.id}');
          break;
        case 'history':
          await _showEmployeeLoanHistory(loan);
          break;
        case 'edit':
          context.push('/loan-management/create', extra: loan);
          break;
        case 'approve':
          final currentEmployee = ref.read(currentEmployeeProvider);
          if (currentEmployee == null) throw StateError('Current employee not found.');
          final nextStatus = await repository.approveLoan(
            id: loan.id,
            approverName: currentEmployee.fullName,
            approverRole: currentEmployee.userType,
          );
          ref.invalidate(allLoansProvider);
          _showSnackBar(nextStatus == 'Approved'
              ? 'Loan ${loan.loanId} approved.'
              : 'Loan ${loan.loanId} sent to ${nextStatus.replaceFirst('Pending ', '')}.');
          break;
        case 'reject':
          await repository.changeLoanStatus(loan.id, 'Rejected');
          ref.invalidate(allLoansProvider);
          _showSnackBar('Loan ${loan.loanId} rejected.');
          break;
        case 'activate':
          await repository.changeLoanStatus(loan.id, 'Active');
          ref.invalidate(allLoansProvider);
          _showSnackBar('Loan ${loan.loanId} activated successfully.');
          break;
        case 'close':
          await repository.updateLoanBalance(loan.loanId, loan.remainingBalance);
          ref.invalidate(allLoansProvider);
          _showSnackBar('Loan ${loan.loanId} marked as Closed.');
          break;
        case 'download':
          _showSnackBar('Statement downloaded for loan ${loan.loanId}.');
          break;
      }
    } catch (e) {
      _showSnackBar('Failed to perform action: $e', isError: true);
    }
  }

  Future<void> _showEmployeeLoanHistory(EmployeeLoan selectedLoan) async {
    final history = await ref
        .read(loanRepositoryProvider)
        .getLoansForEmployee(selectedLoan.employeeId);
    if (!mounted) return;

    final currencyFormat = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '\u20B9',
      decimalDigits: 0,
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        title: Row(
          children: [
            const Icon(Icons.history_outlined, color: AppColors.active),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${selectedLoan.employeeName} - Loan History',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    selectedLoan.employeeCustomId,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.of(dialogContext).pop(),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        content: SizedBox(
          width: 760,
          height: MediaQuery.sizeOf(dialogContext).height * 0.6,
          child: history.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: Text('No loan history found.')),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: history.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final loan = history[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 6),
                      leading: CircleAvatar(
                        backgroundColor: AppColors.active.withValues(alpha: 0.1),
                        child: const Icon(
                          Icons.account_balance_wallet_outlined,
                          color: AppColors.active,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        '${loan.loanId}  •  ${loan.loanType}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        '${loan.loanDate.isEmpty ? 'Date not available' : loan.loanDate}  •  EMI ${currencyFormat.format(loan.emiAmount)}  •  Balance ${currencyFormat.format(loan.remainingBalance)}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildStatusBadge(loan.status),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'View loan details',
                            icon: const Icon(Icons.chevron_right),
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                              context.push('/loan-management/details/${loan.id}');
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red[800] : AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class MobileLoanCard extends StatelessWidget {
  final String employeeName;
  final String employeeId;
  final String loanType;
  final String loanAmount;
  final String emi;
  final String balance;
  final String status;
  final VoidCallback onView;
  final VoidCallback onHistory;
  final VoidCallback onEdit;
  final VoidCallback onDownload;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onActivate;
  final VoidCallback? onClose;

  const MobileLoanCard({
    super.key,
    required this.employeeName,
    required this.employeeId,
    required this.loanType,
    required this.loanAmount,
    required this.emi,
    required this.balance,
    required this.status,
    required this.onView,
    required this.onHistory,
    required this.onEdit,
    required this.onDownload,
    this.onApprove,
    this.onReject,
    this.onActivate,
    this.onClose,
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
          // Employee Header & Action Menu
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employeeName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      employeeId,
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
                    case 'view':
                      onView();
                      break;
                    case 'history':
                      onHistory();
                      break;
                    case 'edit':
                      onEdit();
                      break;
                    case 'download':
                      onDownload();
                      break;
                    case 'approve':
                      onApprove?.call();
                      break;
                    case 'reject':
                      onReject?.call();
                      break;
                    case 'activate':
                      onActivate?.call();
                      break;
                    case 'close':
                      onClose?.call();
                      break;
                  }
                },
                itemBuilder: (context) => [
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
                    value: 'history',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.history, size: 20),
                      title: Text('Loan history'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.edit_outlined, size: 20),
                      title: Text('Edit loan'),
                    ),
                  ),
                  if (onApprove != null)
                    const PopupMenuItem(
                      value: 'approve',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.check_circle_outline, color: Colors.blue, size: 20),
                        title: Text('Approve', style: TextStyle(color: Colors.blue)),
                      ),
                    ),
                  if (onReject != null)
                    const PopupMenuItem(
                      value: 'reject',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.cancel_outlined, color: Colors.red, size: 20),
                        title: Text('Reject', style: TextStyle(color: Colors.red)),
                      ),
                    ),
                  if (onActivate != null)
                    const PopupMenuItem(
                      value: 'activate',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.play_circle_outline, color: Colors.green, size: 20),
                        title: Text('Activate Loan', style: TextStyle(color: Colors.green)),
                      ),
                    ),
                  if (onClose != null)
                    const PopupMenuItem(
                      value: 'close',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.lock_outline, color: Colors.grey, size: 20),
                        title: Text('Close Loan', style: TextStyle(color: Colors.grey)),
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

          // Loan type
          Text(
            loanType,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),

          // Amount
          Text(
            loanAmount,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          const SizedBox(height: 14),

          // EMI / Balance
          Row(
            children: [
              Expanded(
                child: _LoanInfo(
                  label: 'EMI',
                  value: emi,
                ),
              ),
              Expanded(
                child: _LoanInfo(
                  label: 'Balance',
                  value: balance,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Status & View Details
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
                    Text('View loan details', style: TextStyle(fontWeight: FontWeight.w600)),
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

class _LoanInfo extends StatelessWidget {
  final String label;
  final String value;

  const _LoanInfo({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
