import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/layout/responsive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../employee/domain/employee.dart';
import '../../employee/providers/employee_providers.dart';
import '../../organization/domain/department.dart';
import '../../organization/domain/organization.dart';
import '../../organization/providers/organization_providers.dart';
import '../domain/payroll.dart';
import '../providers/payroll_providers.dart';

class PayrollEmployeeListScreen extends ConsumerStatefulWidget {
  const PayrollEmployeeListScreen({super.key});

  @override
  ConsumerState<PayrollEmployeeListScreen> createState() => _PayrollEmployeeListScreenState();
}

class _PayrollEmployeeListScreenState extends ConsumerState<PayrollEmployeeListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Filter Selection State
  Organization? _selectedOrganization;
  String? _selectedDepartment;
  String? _selectedMonth;

  // Submitted Filter State (used to display results)
  bool _hasSubmitted = false;
  Organization? _submittedOrganization;
  String? _submittedDepartment;
  String? _submittedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = ref.read(selectedPayrollMonthProvider);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> _getAvailableMonths() {
    final now = DateTime.now();
    final formatter = DateFormat('MMMM yyyy');
    final months = <String>[];
    for (int i = -12; i <= 3; i++) {
      final date = DateTime(now.year, now.month + i);
      months.add(formatter.format(date));
    }
    final currentSelected = ref.read(selectedPayrollMonthProvider);
    if (!months.contains(currentSelected)) {
      months.add(currentSelected);
    }
    return months;
  }

  void _handleSubmit() {
    if (_selectedOrganization == null ||
        _selectedDepartment == null ||
        _selectedDepartment!.trim().isEmpty ||
        _selectedMonth == null ||
        _selectedMonth!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select organisation, department, and month first.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Sync global selected month provider
    ref.read(selectedPayrollMonthProvider.notifier).state = _selectedMonth!;

    setState(() {
      _hasSubmitted = true;
      _submittedOrganization = _selectedOrganization;
      _submittedDepartment = _selectedDepartment;
      _submittedMonth = _selectedMonth;
    });
  }

  @override
  Widget build(BuildContext context) {
    final String activeMonth = _submittedMonth ?? _selectedMonth ?? ref.watch(selectedPayrollMonthProvider);
    final settingsAsync = ref.watch(payrollSettingsProvider);
    final settings = settingsAsync.value ?? const PayrollSettings();
    final employeesAsync = ref.watch(employeesProvider);
    final payrollRecordsAsync = ref.watch(payrollRecordsForMonthProvider);
    final orgsAsync = ref.watch(organizationsProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Run Payroll',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < AppBreakpoints.tablet;
          final gutter = AppLayout.gutter(constraints.maxWidth);

          return SingleChildScrollView(
            padding: EdgeInsets.all(gutter),
            child: ResponsiveContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Organisation -> Department -> Month Filter Section
                  _buildFilterControlCard(context, orgsAsync, isMobile),
                  const SizedBox(height: 16),

                  // 2. If not submitted, show initial prompt
                  if (!_hasSubmitted) ...[
                    _buildInitialPromptCard(),
                  ] else ...[
                    // 3. If submitted, show payroll period header & employee list
                    _buildSubHeader(activeMonth, settings),
                    const SizedBox(height: 16),
                    _buildSearchBar(),
                    const SizedBox(height: 16),

                    employeesAsync.when(
                      data: (employees) => payrollRecordsAsync.when(
                        data: (records) {
                          // Strict filter: organizationId = selected organisation AND department = selected department
                          final matchingEmployees = employees.where((emp) {
                            final submittedOrg = _submittedOrganization!;
                            final orgId = emp.organizationId.trim();

                            final matchesOrg = (orgId.isNotEmpty &&
                                    (orgId == submittedOrg.canonicalId ||
                                        orgId == submittedOrg.id.toString() ||
                                        orgId == submittedOrg.docId)) ||
                                (orgId.isEmpty &&
                                    emp.organizationName.trim().toLowerCase() ==
                                        submittedOrg.name.trim().toLowerCase());

                            final matchesDept = emp.department.trim().toLowerCase() ==
                                _submittedDepartment!.trim().toLowerCase();

                            return matchesOrg && matchesDept;
                          }).toList();

                          // Search query within the matching employees
                          final filteredEmployees = matchingEmployees.where((emp) {
                            if (_searchQuery.isEmpty) return true;
                            final query = _searchQuery.toLowerCase();
                            final name = '${emp.firstName} ${emp.lastName}'.toLowerCase();
                            final id = 'emp${emp.id}'.toLowerCase();
                            final desig = emp.designation.toLowerCase();
                            return name.contains(query) || id.contains(query) || desig.contains(query);
                          }).toList();

                          if (filteredEmployees.isEmpty) {
                            return _buildEmptyState();
                          }

                          return isMobile
                              ? _buildMobileEmployeeList(
                                  context,
                                  filteredEmployees,
                                  records,
                                  activeMonth,
                                )
                              : _buildDesktopEmployeeList(
                                  context,
                                  filteredEmployees,
                                  records,
                                  activeMonth,
                                );
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (err, _) => Center(child: Text('Error loading payroll records: $err')),
                      ),
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, _) => Center(child: Text('Error loading employees: $err')),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterControlCard(
    BuildContext context,
    AsyncValue<List<Organization>> orgsAsync,
    bool isMobile,
  ) {
    final availableMonths = _getAvailableMonths();
    final String currentMonth = _selectedMonth ?? ref.watch(selectedPayrollMonthProvider);

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: orgsAsync.when(
          data: (organizations) {
            final activeOrgs = organizations.where((o) => o.isActive).toList();

            // Department options for selected organization
            List<String> departmentNames = [];
            if (_selectedOrganization != null) {
              final deptsAsync = ref.watch(filteredDepartmentsProvider(
                DepartmentFilter(organizationId: _selectedOrganization!.canonicalId),
              ));
              final rawDepts = deptsAsync.valueOrNull ?? [];

              // Also fallback to all departments in case they are mapped by organizationName or numerical ID
              final allDepts = ref.watch(departmentsProvider).valueOrNull ?? [];
              final combined = <Department>[...rawDepts];
              for (final d in allDepts) {
                final matchOrg = d.organizationId == _selectedOrganization!.canonicalId ||
                    d.organizationId == _selectedOrganization!.id.toString() ||
                    d.organizationName.trim().toLowerCase() == _selectedOrganization!.name.trim().toLowerCase();
                if (matchOrg && !combined.any((c) => c.departmentName.trim().toLowerCase() == d.departmentName.trim().toLowerCase())) {
                  combined.add(d);
                }
              }

              departmentNames = combined
                  .map((d) => d.departmentName.trim())
                  .where((name) => name.isNotEmpty)
                  .toSet()
                  .toList();
              departmentNames.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
            }

            final isDepartmentEnabled = _selectedOrganization != null && departmentNames.isNotEmpty;

            if (isMobile) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildOrgDropdown(activeOrgs),
                  const SizedBox(height: 14),
                  _buildDeptDropdown(departmentNames, isDepartmentEnabled),
                  const SizedBox(height: 14),
                  _buildMonthDropdown(availableMonths, currentMonth),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: _handleSubmit,
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('Submit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  flex: 3,
                  child: _buildOrgDropdown(activeOrgs),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 3,
                  child: _buildDeptDropdown(departmentNames, isDepartmentEnabled),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 3,
                  child: _buildMonthDropdown(availableMonths, currentMonth),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: _handleSubmit,
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('Submit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error loading organizations: $err')),
        ),
      ),
    );
  }

  Widget _buildOrgDropdown(List<Organization> organizations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Organisation',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.divider),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<Organization>(
              isExpanded: true,
              value: _selectedOrganization != null &&
                      organizations.any((o) => o.canonicalId == _selectedOrganization!.canonicalId || o.id == _selectedOrganization!.id)
                  ? organizations.firstWhere((o) => o.canonicalId == _selectedOrganization!.canonicalId || o.id == _selectedOrganization!.id)
                  : null,
              hint: const Text('Select Organisation', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary, size: 20),
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
              onChanged: (Organization? newOrg) {
                setState(() {
                  _selectedOrganization = newOrg;
                  _selectedDepartment = null; // Clear previously selected department
                });
              },
              items: organizations.map((org) {
                return DropdownMenuItem<Organization>(
                  value: org,
                  child: Text(org.name, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeptDropdown(List<String> departmentNames, bool isEnabled) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Department',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isEnabled ? Colors.white : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.divider),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: isEnabled && _selectedDepartment != null && departmentNames.contains(_selectedDepartment)
                  ? _selectedDepartment
                  : null,
              hint: Text(
                _selectedOrganization == null
                    ? 'Select Organisation first'
                    : (departmentNames.isEmpty ? 'No departments found' : 'Select Department'),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: isEnabled ? AppColors.textSecondary : Colors.grey[400],
                size: 20,
              ),
              style: TextStyle(
                fontSize: 13,
                color: isEnabled ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              onChanged: isEnabled
                  ? (String? newDept) {
                      setState(() {
                        _selectedDepartment = newDept;
                      });
                    }
                  : null,
              items: isEnabled
                  ? departmentNames.map((dept) {
                      return DropdownMenuItem<String>(
                        value: dept,
                        child: Text(dept, overflow: TextOverflow.ellipsis),
                      );
                    }).toList()
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthDropdown(List<String> availableMonths, String currentMonth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Month',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.divider),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: availableMonths.contains(_selectedMonth ?? currentMonth)
                  ? (_selectedMonth ?? currentMonth)
                  : (availableMonths.isNotEmpty ? availableMonths.first : null),
              hint: const Text('Select Month', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary, size: 20),
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
              onChanged: (String? newMonth) {
                if (newMonth != null) {
                  setState(() {
                    _selectedMonth = newMonth;
                  });
                }
              },
              items: availableMonths.map((m) {
                return DropdownMenuItem<String>(
                  value: m,
                  child: Text(m, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInitialPromptCard() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.filter_alt_outlined, size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select Filters to Run Payroll',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose an Organisation, Department, and Month above, then click Submit to load eligible employees.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubHeader(String month, PayrollSettings settings) {
    final parts = month.trim().split(' ');
    int year = DateTime.now().year;
    int monthNum = DateTime.now().month;
    if (parts.length >= 2) {
      year = int.tryParse(parts[1]) ?? year;
      final monthMap = {
        'january': 1, 'february': 2, 'march': 3, 'april': 4, 'may': 5, 'june': 6,
        'july': 7, 'august': 8, 'september': 9, 'october': 10, 'november': 11, 'december': 12
      };
      monthNum = monthMap[parts[0].toLowerCase()] ?? monthNum;
    }
    final period = settings.getPayrollPeriod(year, monthNum);

    final orgName = _submittedOrganization?.name ?? '';
    final deptName = _submittedDepartment ?? '';

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.active, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Running payroll for $orgName • $deptName • $month (${period.displayPeriodString}). Select an employee to review or calculate monthly salary.',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return SizedBox(
      height: 44,
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search Employee by Name, ID, Designation...',
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
  }

  Widget _buildDesktopEmployeeList(
    BuildContext context,
    List<Employee> employees,
    List<PayrollRecord> records,
    String selectedMonth,
  ) {
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
          0: FlexColumnWidth(2.2), // Employee Name
          1: FlexColumnWidth(1.2), // Emp ID
          2: FlexColumnWidth(1.8), // Department
          3: FlexColumnWidth(1.8), // Designation
          4: FlexColumnWidth(1.4), // Status
          5: FlexColumnWidth(2.2), // Actions
        },
        children: [
          TableRow(
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            children: [
              _buildTableHeader('Employee'),
              _buildTableHeader('Employee ID'),
              _buildTableHeader('Department'),
              _buildTableHeader('Designation'),
              _buildTableHeader('Status'),
              _buildTableHeader('Actions'),
            ],
          ),
          for (final emp in employees) ...[
            () {
              final payrollRecord = records.firstWhere(
                (r) => r.employeeId == emp.id,
                orElse: () => PayrollRecord(
                  id: 0,
                  employeeId: emp.id,
                  employeeName: '${emp.firstName} ${emp.lastName}',
                  month: selectedMonth,
                  presentDays: 0,
                  lateDays: 0,
                  absentDays: 0,
                  leaveDays: 0,
                  basicPay: 0,
                  hra: 0,
                  specialAllowance: 0,
                  educationAllowance: 0,
                  pf: 0,
                  tax: 0,
                  netSalary: 0,
                  status: 'Not Generated',
                ),
              );

              final isGenerated = payrollRecord.id != 0;

              return TableRow(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                children: [
                  _buildTableCell(Text('${emp.firstName} ${emp.lastName}', style: const TextStyle(fontWeight: FontWeight.w600))),
                  _buildTableCell(Text('EMP${emp.id}', style: const TextStyle(fontWeight: FontWeight.w500))),
                  _buildTableCell(Text(emp.department)),
                  _buildTableCell(Text(emp.designation)),
                  _buildTableCell(_buildStatusBadge(payrollRecord.status)),
                  _buildTableCell(
                    isGenerated
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ElevatedButton(
                                onPressed: () => context.push('/payroll/details/${payrollRecord.id}'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.active,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                child: const Text('View Details', style: TextStyle(fontSize: 12)),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: () => context.push('/payroll/payslip/${payrollRecord.id}'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: const BorderSide(color: AppColors.primary),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                child: const Text('Payslip', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          )
                        : ElevatedButton.icon(
                            onPressed: () => context.push('/payroll/generate/${emp.id}'),
                            icon: const Icon(Icons.play_arrow_rounded, size: 14),
                            label: const Text('Generate', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                  ),
                ],
              );
            }()
          ]
        ],
      ),
    );
  }

  Widget _buildMobileEmployeeList(
    BuildContext context,
    List<Employee> employees,
    List<PayrollRecord> records,
    String selectedMonth,
  ) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: employees.length,
      itemBuilder: (context, index) {
        final emp = employees[index];
        final payrollRecord = records.firstWhere(
          (r) => r.employeeId == emp.id,
          orElse: () => PayrollRecord(
            id: 0,
            employeeId: emp.id,
            employeeName: '${emp.firstName} ${emp.lastName}',
            month: selectedMonth,
            presentDays: 0,
            lateDays: 0,
            absentDays: 0,
            leaveDays: 0,
            basicPay: 0,
            hra: 0,
            specialAllowance: 0,
            educationAllowance: 0,
            pf: 0,
            tax: 0,
            netSalary: 0,
            status: 'Not Generated',
          ),
        );

        final isGenerated = payrollRecord.id != 0;

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
                      '${emp.firstName} ${emp.lastName}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'EMP${emp.id} • ${emp.department} • ${emp.designation}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                    const SizedBox(height: 14),
                    isGenerated
                        ? Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => context.push('/payroll/details/${payrollRecord.id}'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.active,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  child: const Text('View Details', style: TextStyle(fontSize: 12)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => context.push('/payroll/payslip/${payrollRecord.id}'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    side: const BorderSide(color: AppColors.primary),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  child: const Text('Payslip', style: TextStyle(fontSize: 12)),
                                ),
                              ),
                            ],
                          )
                        : SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => context.push('/payroll/generate/${emp.id}'),
                              icon: const Icon(Icons.play_arrow_rounded, size: 14),
                              label: const Text('Generate Payroll'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                            ),
                          ),
                  ],
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: _buildStatusBadge(payrollRecord.status),
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
    Color color = Colors.grey[700]!;
    Color bgColor = Colors.grey[100]!;

    if (status == 'Paid') {
      color = const Color(0xFF9CC70A);
      bgColor = const Color(0xFF9CC70A).withValues(alpha: 0.1);
    } else if (status == 'Processed') {
      color = Colors.blue[700]!;
      bgColor = Colors.blue[50]!;
    } else if (status == 'Draft' || status == 'Pending') {
      color = Colors.amber[800]!;
      bgColor = Colors.amber[50]!;
    } else if (status == 'Not Generated') {
      color = Colors.blueGrey[700]!;
      bgColor = Colors.blueGrey[50]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 40, horizontal: 16),
        child: Center(
          child: Text(
            'No matching employees found for the selected organization and department.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ),
      ),
    );
  }
}
