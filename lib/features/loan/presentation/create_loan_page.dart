import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../employee/domain/employee.dart';
import '../../employee/providers/employee_providers.dart';
import '../domain/employee_loan.dart';
import '../providers/loan_providers.dart';

class CreateLoanPage extends ConsumerStatefulWidget {
  const CreateLoanPage({this.loan, super.key});
  final EmployeeLoan? loan;

  @override
  ConsumerState<CreateLoanPage> createState() => _CreateLoanPageState();
}

class _CreateLoanPageState extends ConsumerState<CreateLoanPage> {
  final _formKey = GlobalKey<FormState>();

  // Employee Information
  Employee? _selectedEmployee;
  String _employeeId = '';
  String _department = '';
  String _designation = '';

  // Loan Details
  final _loanIdController = TextEditingController();
  String _selectedLoanType = 'Personal Loan';
  final _amountController = TextEditingController();
  final _purposeController = TextEditingController();
  DateTime _loanDate = DateTime.now();
  DateTime _disbursementDate = DateTime.now();

  // Repayment Details
  final _installmentsController = TextEditingController(text: '12');
  final _emiController = TextEditingController();
  final _interestRateController = TextEditingController(text: '0');
  final _totalRepayableController = TextEditingController();
  String _firstDeductionMonth = '';
  String _lastDeductionMonth = '';

  // Approval Details
  final _requestedByController = TextEditingController();
  final _approvedByController = TextEditingController();
  DateTime? _approvalDate;
  final _remarksController = TextEditingController();
  String _status = 'Pending Supervisor';

  final List<String> _loanTypes = [
    'Personal Loan',
    'Salary Advance',
    'Emergency Loan',
    'Education Loan',
    'Medical Loan',
    'Other'
  ];

  final List<String> _statuses = ['Pending Supervisor', 'Pending HR', 'Pending MD', 'Approved', 'Rejected', 'Active', 'Closed'];
  final List<String> _monthsList = [];

  @override
  void initState() {
    super.initState();
    _generateMonthsList();

    // Setup listeners for automatic calculations
    _amountController.addListener(_calculateRepayment);
    _installmentsController.addListener(_calculateRepayment);
    _interestRateController.addListener(_calculateRepayment);

    if (widget.loan != null) {
      _loadExistingLoan(widget.loan!);
    } else {
      _loanIdController.text = 'Generating...';
      _firstDeductionMonth = _monthsList.first;
      _calculateRepayment();
      _requestedByController.text = 'Admin';
      _generateNewLoanId();
    }
  }

  void _generateMonthsList() {
    final now = DateTime.now();
    final formatter = DateFormat('MMMM yyyy');
    for (int i = -3; i < 24; i++) {
      _monthsList.add(formatter.format(DateTime(now.year, now.month + i)));
    }
  }

  Future<void> _generateNewLoanId() async {
    try {
      final loans = await ref.read(loanRepositoryProvider).getAllLoans();
      int maxNum = 0;
      for (final l in loans) {
        final cleanId = l.loanId.replaceAll(RegExp(r'[^0-9]'), '');
        final numPart = int.tryParse(cleanId) ?? 0;
        if (numPart > maxNum) maxNum = numPart;
      }
      if (mounted) {
        setState(() {
          _loanIdController.text = 'LN${(maxNum + 1).toString().padLeft(3, '0')}';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loanIdController.text = 'LN003';
        });
      }
    }
  }

  void _loadExistingLoan(EmployeeLoan loan) {
    _loanIdController.text = loan.loanId;
    _employeeId = loan.employeeCustomId;
    _department = loan.department;
    _designation = loan.designation;
    _selectedLoanType = loan.loanType;
    _amountController.text = loan.loanAmount.toString();
    _purposeController.text = loan.purpose;
    _loanDate = DateFormat('yyyy-MM-dd').parse(loan.loanDate);
    _disbursementDate = DateFormat('yyyy-MM-dd').parse(loan.disbursementDate);

    _installmentsController.text = loan.installments.toString();
    _interestRateController.text = loan.interestRate.toString();
    _emiController.text = loan.emiAmount.toString();
    _totalRepayableController.text = loan.totalRepayableAmount.toString();

    if (_monthsList.contains(loan.firstDeductionMonth)) {
      _firstDeductionMonth = loan.firstDeductionMonth;
    } else {
      _monthsList.add(loan.firstDeductionMonth);
      _firstDeductionMonth = loan.firstDeductionMonth;
    }
    _lastDeductionMonth = loan.lastDeductionMonth;

    _requestedByController.text = loan.requestedBy;
    _approvedByController.text = loan.approvedBy;
    if (loan.approvalDate.isNotEmpty) {
      _approvalDate = DateFormat('yyyy-MM-dd').parse(loan.approvalDate);
    }
    _remarksController.text = loan.remarks;
    _status = loan.status;
  }

  void _calculateRepayment() {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final installments = int.tryParse(_installmentsController.text) ?? 0;
    final rate = double.tryParse(_interestRateController.text) ?? 0.0;

    // Simple Interest: Principal + (Principal * Rate / 100 * Time in years)
    final timeInYears = installments / 12.0;
    final interest = amount * (rate / 100.0) * timeInYears;
    final total = amount + interest;

    final emi = installments > 0 ? total / installments : 0.0;

    setState(() {
      _totalRepayableController.text = total.toStringAsFixed(2);
      _emiController.text = emi.toStringAsFixed(2);
      _lastDeductionMonth = _calculateLastDeductionMonth(_firstDeductionMonth, installments);
    });
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

  Future<void> _selectDate(BuildContext context, bool isLoanDate) async {
    final initialDate = isLoanDate ? _loanDate : _disbursementDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isLoanDate) {
          _loanDate = picked;
        } else {
          _disbursementDate = picked;
        }
      });
    }
  }

  Future<void> _selectApprovalDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _approvalDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _approvalDate = picked;
      });
    }
  }

  Future<void> _saveLoan(String targetStatus) async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedEmployee == null && widget.loan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an employee.')),
      );
      return;
    }

    final empId = widget.loan?.employeeId ?? _selectedEmployee!.id;
    final empName = widget.loan?.employeeName ?? _selectedEmployee!.fullName;
    final empCustomId = widget.loan?.employeeCustomId ?? _employeeId;
    final dept = widget.loan?.department ?? _department;
    final desig = widget.loan?.designation ?? _designation;

    final employeeLoan = EmployeeLoan(
      id: widget.loan?.id ?? 0,
      loanId: _loanIdController.text,
      employeeId: empId,
      employeeName: empName,
      employeeCustomId: empCustomId,
      department: dept,
      designation: desig,
      loanType: _selectedLoanType,
      loanAmount: double.tryParse(_amountController.text) ?? 0.0,
      loanDate: DateFormat('yyyy-MM-dd').format(_loanDate),
      disbursementDate: DateFormat('yyyy-MM-dd').format(_disbursementDate),
      purpose: _purposeController.text,
      installments: int.tryParse(_installmentsController.text) ?? 0,
      emiAmount: double.tryParse(_emiController.text) ?? 0.0,
      firstDeductionMonth: _firstDeductionMonth,
      lastDeductionMonth: _lastDeductionMonth,
      interestRate: double.tryParse(_interestRateController.text) ?? 0.0,
      totalRepayableAmount: double.tryParse(_totalRepayableController.text) ?? 0.0,
      requestedBy: _requestedByController.text,
      approvedBy: _approvedByController.text,
      approvalDate: _approvalDate != null ? DateFormat('yyyy-MM-dd').format(_approvalDate!) : '',
      remarks: _remarksController.text,
      status: targetStatus,
      remainingBalance: widget.loan != null ? (targetStatus == 'Closed' ? 0.0 : widget.loan!.remainingBalance) : (double.tryParse(_totalRepayableController.text) ?? 0.0),
    );

    try {
      await ref.read(loanRepositoryProvider).saveLoan(employeeLoan);
      ref.invalidate(allLoansProvider);
      if (widget.loan != null) {
        ref.invalidate(loanByIdProvider(widget.loan!.id));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Loan ${widget.loan != null ? "updated" : "created"} with status $targetStatus.')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save loan: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(employeesProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.loan != null ? 'Edit Loan (${widget.loan!.loanId})' : 'Create Loan',
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Section 1: Employee Information
              _buildSectionCard(
                title: 'Employee Information',
                icon: Icons.person_outline,
                children: [
                  if (widget.loan == null) ...[
                    employeesAsync.when(
                      data: (list) {
                        return DropdownButtonFormField<Employee>(
                          decoration: _inputDecoration('Select Employee'),
                          initialValue: _selectedEmployee,
                          items: list.map((emp) {
                            return DropdownMenuItem<Employee>(
                              value: emp,
                              child: Text('${emp.fullName} (${emp.employeeId})'),
                            );
                          }).toList(),
                          onChanged: (emp) {
                            setState(() {
                              _selectedEmployee = emp;
                              _employeeId = emp?.employeeId ?? '';
                              _department = emp?.department ?? '';
                              _designation = emp?.designation ?? '';
                            });
                          },
                          validator: (val) => val == null ? 'Employee is required' : null,
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, _) => Text('Error loading employees: $err'),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    _buildDisabledField('Employee Name', widget.loan!.employeeName),
                    const SizedBox(height: 16),
                  ],
                  Row(
                    children: [
                      Expanded(child: _buildDisabledField('Employee ID', _employeeId)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildDisabledField('Department', _department)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildDisabledField('Designation', _designation),
                ],
              ),
              const SizedBox(height: 20),

              // Section 2: Loan Details
              _buildSectionCard(
                title: 'Loan Details',
                icon: Icons.account_balance_wallet_outlined,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _loanIdController,
                          decoration: _inputDecoration('Loan ID'),
                          readOnly: true,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
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
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _amountController,
                    decoration: _inputDecoration('Loan Amount (₹)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Amount is required';
                      if (double.tryParse(val) == null) return 'Enter a valid number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectDate(context, true),
                          child: InputDecorator(
                            decoration: _inputDecoration('Loan Date'),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(DateFormat('yyyy-MM-dd').format(_loanDate)),
                                const Icon(Icons.calendar_today, size: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectDate(context, false),
                          child: InputDecorator(
                            decoration: _inputDecoration('Disbursement Date'),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(DateFormat('yyyy-MM-dd').format(_disbursementDate)),
                                const Icon(Icons.calendar_today, size: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _purposeController,
                    decoration: _inputDecoration('Purpose'),
                    maxLines: 2,
                    validator: (val) => val == null || val.isEmpty ? 'Purpose is required' : null,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Section 3: Repayment Details
              _buildSectionCard(
                title: 'Repayment Details',
                icon: Icons.history_outlined,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _installmentsController,
                          decoration: _inputDecoration('Installments (Months)'),
                          keyboardType: TextInputType.number,
                          validator: (val) {
                            if (val == null || val.isEmpty) return 'Required';
                            if (int.tryParse(val) == null) return 'Enter integer';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _interestRateController,
                          decoration: _inputDecoration('Interest Rate (% - Optional)'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _emiController,
                          decoration: _inputDecoration('EMI Amount (₹)'),
                          readOnly: true,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _totalRepayableController,
                          decoration: _inputDecoration('Total Repayable (₹)'),
                          readOnly: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: _inputDecoration('First Deduction Month'),
                          initialValue: _firstDeductionMonth,
                          items: _monthsList.map((month) {
                            return DropdownMenuItem<String>(
                              value: month,
                              child: Text(month),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _firstDeductionMonth = val!;
                              _calculateRepayment();
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          decoration: _inputDecoration('Last Deduction Month'),
                          controller: TextEditingController(text: _lastDeductionMonth),
                          readOnly: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Section 4: Approval Details
              _buildSectionCard(
                title: 'Approval & Status',
                icon: Icons.fact_check_outlined,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _requestedByController,
                          decoration: _inputDecoration('Requested By'),
                          validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _approvedByController,
                          decoration: _inputDecoration('Approved By'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectApprovalDate(context),
                          child: InputDecorator(
                            decoration: _inputDecoration('Approval Date'),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_approvalDate != null ? DateFormat('yyyy-MM-dd').format(_approvalDate!) : 'Select Date'),
                                const Icon(Icons.calendar_today, size: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: _inputDecoration('Status'),
                          initialValue: _status,
                          items: _statuses.map((status) {
                            return DropdownMenuItem<String>(
                              value: status,
                              child: Text(status),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _status = val!;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _remarksController,
                    decoration: _inputDecoration('Remarks'),
                    maxLines: 2,
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // Action Buttons
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton(
                    onPressed: () => context.pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.divider),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => _saveLoan(widget.loan?.status ?? 'Pending Supervisor'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Save Draft'),
                  ),
                  ElevatedButton(
                    onPressed: null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.active,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Approve'),
                  ),
                  ElevatedButton(
                    onPressed: () => _saveLoan('Rejected'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Reject'),
                  ),
                  ElevatedButton(
                    onPressed: widget.loan?.status == 'Approved' ? () => _saveLoan('Active') : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Activate Loan'),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.active, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.divider, thickness: 0.5),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDisabledField(String label, String value) {
    return TextFormField(
      initialValue: value.isEmpty ? '-' : value,
      key: ValueKey(value),
      decoration: _inputDecoration(label),
      readOnly: true,
      enabled: false,
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
