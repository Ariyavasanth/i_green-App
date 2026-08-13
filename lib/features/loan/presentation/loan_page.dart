import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../employee/domain/employee.dart';
import '../../leave/providers/leave_providers.dart';
import '../domain/employee_loan.dart';
import '../providers/loan_providers.dart';

class LoanPage extends ConsumerStatefulWidget {
  const LoanPage({super.key});

  @override
  ConsumerState<LoanPage> createState() => _LoanPageState();
}

class _LoanPageState extends ConsumerState<LoanPage> {
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(employeeLoansProvider(currentEmp.id));
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
                      Icon(Icons.account_balance_outlined, size: 24, color: AppColors.active),
                      SizedBox(width: 8),
                      Text(
                        'My Loans',
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
                    label: const Text('Request Loan'),
                    onPressed: () => _showRequestLoanDialog(context, currentEmp),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Metrics Cards
              loansAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Text('Error loading summary: $err'),
                data: (loans) => _buildDashboardSummary(loans, isMobile),
              ),
              const SizedBox(height: 20),

              // Loans Table or Cards
              loansAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error loading loans: $err')),
                data: (loans) {
                  if (loans.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.info_outline, size: 40, color: AppColors.textSecondary),
                          const SizedBox(height: 12),
                          const Text(
                            'No loan records found.',
                            style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'If you need financial assistance, click "Request Loan" above to apply.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  }

                  if (isMobile) {
                    return _buildLoansListMobile(loans);
                  }

                  return _buildLoansTable(loans, screenWidth);
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
    final pendingLoansCount = loans.where((l) => l.status.startsWith('Pending')).length;
    final closedLoansCount = loans.where((l) => l.status == 'Closed').length;

    final outstandingSum = loans
        .where((l) => l.status == 'Active' || l.status == 'Approved')
        .fold<double>(0, (sum, l) => sum + l.remainingBalance);

    final metrics = [
      _MetricItem('Outstanding Balance', currencyFormat.format(outstandingSum), Icons.payments_outlined, Colors.blue),
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

  Widget _buildLoansTable(List<EmployeeLoan> loans, double screenWidth) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    const minTableWidth = 900.0;

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
                return DataRow(
                  cells: [
                    DataCell(Text(loan.loanId, style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(loan.loanType)),
                    DataCell(Text(currencyFormat.format(loan.loanAmount))),
                    DataCell(Text(currencyFormat.format(loan.emiAmount))),
                    DataCell(Text(currencyFormat.format(loan.remainingBalance))),
                    DataCell(Text(loan.firstDeductionMonth)),
                    DataCell(_buildStatusBadge(loan.status)),
                    DataCell(
                      IconButton(
                        icon: const Icon(Icons.visibility_outlined, size: 20),
                        onPressed: () => context.push('/loan/details/${loan.id}'),
                        tooltip: 'View Details',
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

  Widget _buildLoansListMobile(List<EmployeeLoan> loans) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: loans.length,
      itemBuilder: (context, index) {
        final loan = loans[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: AppColors.divider, width: 0.5),
          ),
          child: InkWell(
            onTap: () => context.push('/loan/details/${loan.id}'),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        loan.loanId,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      _buildStatusBadge(loan.status),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: AppColors.divider),
                  const SizedBox(height: 12),
                  _buildMobileRow('Loan Type', loan.loanType),
                  _buildMobileRow('Amount', currencyFormat.format(loan.loanAmount)),
                  _buildMobileRow('EMI', currencyFormat.format(loan.emiAmount)),
                  _buildMobileRow('Balance', currencyFormat.format(loan.remainingBalance)),
                  _buildMobileRow('First Deduction', loan.firstDeductionMonth),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        ],
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

  void _showRequestLoanDialog(BuildContext context, Employee employee) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _RequestLoanDialog(employee: employee);
      },
    ).then((_) {
      ref.invalidate(employeeLoansProvider(employee.id));
    });
  }
}

class _RequestLoanDialog extends ConsumerStatefulWidget {
  const _RequestLoanDialog({required this.employee});
  final Employee employee;

  @override
  ConsumerState<_RequestLoanDialog> createState() => _RequestLoanDialogState();
}

class _RequestLoanDialogState extends ConsumerState<_RequestLoanDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _installmentsController = TextEditingController(text: '12');
  final _emiController = TextEditingController();
  final _purposeController = TextEditingController();
  String _selectedLoanType = 'Personal Loan';

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
    _amountController.addListener(_calculateEmi);
    _installmentsController.addListener(_calculateEmi);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _installmentsController.dispose();
    _emiController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  void _calculateEmi() {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final installments = int.tryParse(_installmentsController.text) ?? 0;
    if (installments > 0) {
      final emi = amount / installments;
      setState(() {
        _emiController.text = emi.toStringAsFixed(2);
      });
    } else {
      setState(() {
        _emiController.text = '';
      });
    }
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

  String _calculateLastDeductionMonth(String startMonth, int installments) {
    if (installments <= 0) return startMonth;
    final parts = startMonth.split(' ');
    if (parts.length < 2) return startMonth;
    final monthName = parts[0];
    final year = int.tryParse(parts[1]) ?? DateTime.now().year;

    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final startIndex = months.indexOf(monthName);
    if (startIndex == -1) return startMonth;

    final totalMonths = startIndex + installments - 1;
    final finalMonthIndex = totalMonths % 12;
    final finalYear = year + (totalMonths ~/ 12);

    return '${months[finalMonthIndex]} $finalYear';
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final installments = int.tryParse(_installmentsController.text) ?? 12;
    final emi = double.tryParse(_emiController.text) ?? (amount / installments);

    final now = DateTime.now();
    final nextMonthDate = DateTime(now.year, now.month + 1);
    final firstDeductionMonth = DateFormat('MMMM yyyy').format(nextMonthDate);
    final lastDeductionMonth = _calculateLastDeductionMonth(firstDeductionMonth, installments);

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
      disbursementDate: DateFormat('yyyy-MM-dd').format(now),
      purpose: _purposeController.text,
      installments: installments,
      emiAmount: emi,
      firstDeductionMonth: firstDeductionMonth,
      lastDeductionMonth: lastDeductionMonth,
      interestRate: 0.0,
      totalRepayableAmount: amount,
      requestedBy: widget.employee.fullName,
      approvedBy: '',
      approvalDate: '',
      remarks: '',
      status: 'Pending Supervisor',
      remainingBalance: amount,
    );

    try {
      await ref.read(loanRepositoryProvider).saveLoan(loanRequest);
      ref.invalidate(allLoansProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Loan request submitted successfully.'),
            backgroundColor: AppColors.primary,
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
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.rate_review_outlined, color: AppColors.active),
          SizedBox(width: 10),
          Text('Request New Loan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                items: _loanTypes.map((type) {
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
                maxLines: 3,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Purpose is required';
                  return null;
                },
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          child: const Text('Submit Request'),
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

class _MetricItem {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  _MetricItem(this.title, this.value, this.icon, this.color);
}
