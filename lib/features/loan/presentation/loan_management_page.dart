import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/employee_loan.dart';
import '../providers/loan_providers.dart';

class LoanTabMode {
  static const list = 0;
  static const dashboard = 1;
}

class LoanManagementPage extends ConsumerStatefulWidget {
  const LoanManagementPage({super.key});

  @override
  ConsumerState<LoanManagementPage> createState() => _LoanManagementPageState();
}

class _LoanManagementPageState extends ConsumerState<LoanManagementPage> {
  // Filters state
  String _employeeNameFilter = '';
  String _employeeIdFilter = '';
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

  final List<String> _statuses = ['All', 'Pending', 'Approved', 'Rejected', 'Active', 'Closed'];

  @override
  Widget build(BuildContext context) {
    final loansAsync = ref.watch(allLoansProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(allLoansProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.account_balance, size: 24, color: AppColors.active),
                      SizedBox(width: 8),
                      Text(
                        'Employee Loan Management',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Create Loan'),
                    onPressed: () => context.push('/loan-management/create'),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Dashboard / Metrics cards
              loansAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Text('Error calculating summary: $err'),
                data: (loans) => _buildDashboardSummary(loans, isMobile),
              ),
              const SizedBox(height: 20),

              // Filters Card
              _buildFiltersCard(),
              const SizedBox(height: 20),

              // Table Card
              loansAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error loading loans: $err')),
                data: (loans) {
                  final filtered = loans.where((loan) {
                    // Employee Name filter
                    if (_employeeNameFilter.isNotEmpty &&
                        !loan.employeeName.toLowerCase().contains(_employeeNameFilter.toLowerCase())) {
                      return false;
                    }
                    // Employee ID filter
                    if (_employeeIdFilter.isNotEmpty &&
                        !loan.employeeCustomId.toLowerCase().contains(_employeeIdFilter.toLowerCase())) {
                      return false;
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
                    if (_selectedStatusFilter != 'All' && loan.status != _selectedStatusFilter) {
                      return false;
                    }
                    return true;
                  }).toList();

                  if (filtered.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: const Center(
                        child: Text(
                          'No loan records match the filters.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    );
                  }

                  return _buildLoansTable(filtered, screenWidth);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardSummary(List<EmployeeLoan> loans, bool isMobile) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    final activeLoansCount = loans.where((l) => l.status == 'Active').length;
    final pendingLoansCount = loans.where((l) => l.status == 'Pending').length;
    final closedLoansCount = loans.where((l) => l.status == 'Closed').length;

    final outstandingSum = loans
        .where((l) => l.status == 'Active' || l.status == 'Approved')
        .fold<double>(0, (sum, l) => sum + l.remainingBalance);

    final metrics = [
      _MetricItem('Outstanding Amount', currencyFormat.format(outstandingSum), Icons.payments_outlined, Colors.blue),
      _MetricItem('Active Loans', '$activeLoansCount', Icons.check_circle_outline, AppColors.primary),
      _MetricItem('Pending Approval', '$pendingLoansCount', Icons.hourglass_empty, Colors.orange),
      _MetricItem('Closed Loans', '$closedLoansCount', Icons.assignment_turned_in_outlined, Colors.grey),
    ];

    if (isMobile) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.4,
        ),
        itemCount: metrics.length,
        itemBuilder: (context, index) => _buildMetricCard(metrics[index]),
      );
    }

    return Row(
      children: metrics.map((m) => Expanded(child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: _buildMetricCard(m),
      ))).toList(),
    );
  }

  Widget _buildMetricCard(_MetricItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(width: 4),
              Icon(item.icon, color: item.color, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              item.value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Filter Label
          const Text('Filters:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary)),
          
          // Search Employee Name
          SizedBox(
            width: 180,
            height: 38,
            child: TextField(
              decoration: _filterInputDecoration('Employee Name'),
              style: const TextStyle(fontSize: 12),
              onChanged: (val) => setState(() => _employeeNameFilter = val),
            ),
          ),

          // Search Employee ID
          SizedBox(
            width: 130,
            height: 38,
            child: TextField(
              decoration: _filterInputDecoration('Employee ID'),
              style: const TextStyle(fontSize: 12),
              onChanged: (val) => setState(() => _employeeIdFilter = val),
            ),
          ),

          // Department Dropdown
          _buildFilterDropdown(
            label: 'Dept',
            value: _selectedDeptFilter,
            items: _departments,
            onChanged: (val) => setState(() => _selectedDeptFilter = val!),
          ),

          // Loan Type Dropdown
          _buildFilterDropdown(
            label: 'Type',
            value: _selectedTypeFilter,
            items: _loanTypes,
            onChanged: (val) => setState(() => _selectedTypeFilter = val!),
          ),

          // Status Dropdown
          _buildFilterDropdown(
            label: 'Status',
            value: _selectedStatusFilter,
            items: _statuses,
            onChanged: (val) => setState(() => _selectedStatusFilter = val!),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
          hint: Text(label),
          items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildLoansTable(List<EmployeeLoan> loans, double screenWidth) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final minTableWidth = 1000.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: screenWidth < minTableWidth ? minTableWidth : screenWidth,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(Colors.grey.withValues(alpha: 0.04)),
              headingRowHeight: 44,
              dataRowMinHeight: 52,
              dataRowMaxHeight: 60,
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
                    DataCell(Text(loan.loanId)),
                    DataCell(Text(loan.loanType)),
                    DataCell(Text(currencyFormat.format(loan.loanAmount))),
                    DataCell(Text(currencyFormat.format(loan.emiAmount))),
                    DataCell(Text(currencyFormat.format(loan.remainingBalance))),
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
    Color color = Colors.grey;
    Color bgColor = Colors.grey.withValues(alpha: 0.1);
    final norm = status.trim().toLowerCase();

    switch (norm) {
      case 'active':
        color = AppColors.primary;
        bgColor = AppColors.primary.withValues(alpha: 0.1);
        break;
      case 'pending':
        color = Colors.orange;
        bgColor = Colors.orange.withValues(alpha: 0.1);
        break;
      case 'approved':
        color = Colors.blue;
        bgColor = Colors.blue.withValues(alpha: 0.1);
        break;
      case 'rejected':
        color = Colors.redAccent;
        bgColor = Colors.redAccent.withValues(alpha: 0.1);
        break;
      case 'closed':
        color = Colors.grey;
        bgColor = Colors.grey.withValues(alpha: 0.1);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
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
          child: Row(children: [Icon(Icons.visibility_outlined, size: 16), SizedBox(width: 8), Text('View')]),
        ),
        const PopupMenuItem(
          value: 'edit',
          child: Row(children: [Icon(Icons.edit_outlined, size: 16), SizedBox(width: 8), Text('Edit')]),
        ),
        if (loan.status == 'Pending') ...[
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
          child: Row(children: [Icon(Icons.download_outlined, size: 16), SizedBox(width: 8), Text('Download Statement')]),
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
        case 'edit':
          context.push('/loan-management/create', extra: loan);
          break;
        case 'approve':
          await repository.changeLoanStatus(loan.id, 'Approved');
          ref.invalidate(allLoansProvider);
          _showSnackBar('Loan ${loan.loanId} approved.');
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

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red[800] : AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  InputDecoration _filterInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
      filled: true,
      fillColor: Colors.grey.withValues(alpha: 0.02),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.divider, width: 0.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.divider, width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.0),
      ),
    );
  }
}

class _MetricItem {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  _MetricItem(this.title, this.value, this.icon, this.color);
}
