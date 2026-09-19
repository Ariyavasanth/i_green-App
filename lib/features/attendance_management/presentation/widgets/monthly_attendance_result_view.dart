import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../attendance/domain/attendance_record.dart';
import '../../../attendance/domain/monthly_attendance_result.dart';
import '../../../employee/domain/employee.dart';
import '../../../leave/domain/leave_request.dart';
import '../../../on_duty/domain/on_duty_assignment.dart';

class MonthlyAttendanceResultView extends StatefulWidget {
  const MonthlyAttendanceResultView({
    super.key,
    required this.focusedMonth,
    this.onMonthChanged,
    required this.employees,
    this.selectedEmployeeId,
    this.onEmployeeChanged,
    required this.records,
    this.leaves,
    this.onDutyAssignments,
    this.holidays,
    this.isMobile = false,
    this.onRowTap,
  });

  final DateTime focusedMonth;
  final ValueChanged<DateTime>? onMonthChanged;
  final List<Employee> employees;
  final int? selectedEmployeeId;
  final ValueChanged<int?>? onEmployeeChanged;
  final List<AttendanceRecord> records;
  final List<LeaveRequest>? leaves;
  final List<OnDutyAssignment>? onDutyAssignments;
  final List<String>? holidays;
  final bool isMobile;
  final void Function(DailyAttendanceResult dailyResult, Employee employee)? onRowTap;

  @override
  State<MonthlyAttendanceResultView> createState() => _MonthlyAttendanceResultViewState();
}

class _MonthlyAttendanceResultViewState extends State<MonthlyAttendanceResultView> {
  late DateTime _currentMonth;
  int? _localSelectedEmployeeId;
  String _selectedDepartment = 'All Departments';
  String _selectedDesignation = 'All Designations';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentMonth = widget.focusedMonth;
    _localSelectedEmployeeId = widget.selectedEmployeeId;
  }

  @override
  void didUpdateWidget(covariant MonthlyAttendanceResultView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusedMonth != widget.focusedMonth) {
      _currentMonth = widget.focusedMonth;
    }
    if (oldWidget.selectedEmployeeId != widget.selectedEmployeeId) {
      _localSelectedEmployeeId = widget.selectedEmployeeId;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Employee> _getFilteredEmployees() {
    return widget.employees.where((emp) {
      if (_selectedDepartment != 'All Departments' &&
          emp.department.trim().toLowerCase() != _selectedDepartment.trim().toLowerCase()) {
        return false;
      }
      if (_selectedDesignation != 'All Designations' &&
          emp.designation.trim().toLowerCase() != _selectedDesignation.trim().toLowerCase()) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesName = emp.fullName.toLowerCase().contains(q);
        final matchesCode = emp.employeeId.toLowerCase().contains(q);
        if (!matchesName && !matchesCode) return false;
      }
      return true;
    }).toList();
  }

  Employee? _getSelectedEmployee(List<Employee> filtered) {
    if (filtered.isEmpty) {
      return null;
    }
    if (_localSelectedEmployeeId != null) {
      for (final e in filtered) {
        if (e.id == _localSelectedEmployeeId) return e;
      }
    }
    return filtered.first;
  }

  void _changeMonth(DateTime newMonth) {
    setState(() => _currentMonth = newMonth);
    widget.onMonthChanged?.call(newMonth);
  }

  void _selectEmployee(int? empId) {
    setState(() => _localSelectedEmployeeId = empId);
    widget.onEmployeeChanged?.call(empId);
  }

  @override
  Widget build(BuildContext context) {
    final filteredEmployees = _getFilteredEmployees();
    final activeEmployee = _getSelectedEmployee(filteredEmployees);

    final MonthlyAttendanceResult monthlyResult = activeEmployee != null
        ? MonthlyAttendanceCalculator.calculate(
            employee: activeEmployee,
            year: _currentMonth.year,
            month: _currentMonth.month,
            records: widget.records,
            leaves: widget.leaves,
            onDutyAssignments: widget.onDutyAssignments,
            holidays: widget.holidays,
            referenceDate: DateTime.now(),
          )
        : MonthlyAttendanceResult.empty(
            year: _currentMonth.year,
            month: _currentMonth.month,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Controls & Filter Toolbar
        _buildFilterToolbar(context, filteredEmployees, activeEmployee),
        const SizedBox(height: 16),

        if (activeEmployee != null) ...[
          // 2. Employee Profile Info Card
          _buildEmployeeHeaderCard(activeEmployee),
          const SizedBox(height: 16),

          // 3. 8 Status Summary KPI Cards
          _buildStatusKpiGrid(monthlyResult, widget.isMobile),
          const SizedBox(height: 16),

          // 4. Hours Summary Banner Card
          _buildHoursSummaryCard(monthlyResult, widget.isMobile),
          const SizedBox(height: 16),

          // 5. Daily Breakdown Table / Cards
          _buildDailyBreakdownSection(monthlyResult, activeEmployee, widget.isMobile),
        ] else ...[
          _buildNoEmployeeSelectedView(),
        ],
      ],
    );
  }

  // --- 1. Filter Toolbar ---

  Widget _buildFilterToolbar(
    BuildContext context,
    List<Employee> filteredEmployees,
    Employee? activeEmployee,
  ) {
    final departmentOptions = ['All Departments', ...Employee.departmentOptions];
    final designationOptions = ['All Designations', ...Employee.designationOptions];
    final monthText = DateFormat(widget.isMobile ? 'MMM yyyy' : 'MMMM yyyy').format(_currentMonth);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(widget.isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
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
          // Row 1: Month / Year Picker + Employee Search Bar
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              // Month / Year Navigation & Picker Button
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 18, color: Color(0xFF475569)),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: const EdgeInsets.all(4),
                      tooltip: 'Previous Month',
                      onPressed: () {
                        _changeMonth(DateTime(_currentMonth.year, _currentMonth.month - 1, 1));
                      },
                    ),
                    InkWell(
                      onTap: () => _openMonthYearPicker(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_month_outlined, size: 15, color: Color(0xFF9CC70A)),
                            const SizedBox(width: 4),
                            Text(
                              monthText,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(Icons.keyboard_arrow_down, size: 15, color: Color(0xFF64748B)),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 18, color: Color(0xFF475569)),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: const EdgeInsets.all(4),
                      tooltip: 'Next Month',
                      onPressed: () {
                        _changeMonth(DateTime(_currentMonth.year, _currentMonth.month + 1, 1));
                      },
                    ),
                  ],
                ),
              ),

              // Search Box for Quick Employee Filter
              SizedBox(
                width: widget.isMobile ? double.infinity : 260,
                height: 38,
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Search employee...',
                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF9CC70A)),
                    ),
                  ),
                  onChanged: (val) {
                    setState(() => _searchQuery = val.trim());
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Row 2: Employee Dropdown + Department Filter + Designation Filter + Reset Button
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Employee Dropdown
              SizedBox(
                width: widget.isMobile ? double.infinity : 240,
                child: _buildEmployeeDropdown(filteredEmployees, activeEmployee),
              ),

              // Department Dropdown
              SizedBox(
                width: widget.isMobile ? double.infinity : 180,
                child: _buildGenericFilterDropdown<String>(
                  key: const ValueKey('department_dropdown'),
                  label: 'Department',
                  value: _selectedDepartment == 'All Departments' ? null : _selectedDepartment,
                  items: departmentOptions,
                  itemLabel: (item) => item,
                  onChanged: (val) {
                    setState(() {
                      _selectedDepartment = val ?? 'All Departments';
                    });
                  },
                ),
              ),

              // Designation Dropdown
              SizedBox(
                width: widget.isMobile ? double.infinity : 180,
                child: _buildGenericFilterDropdown<String>(
                  key: const ValueKey('designation_dropdown'),
                  label: 'Designation',
                  value: _selectedDesignation == 'All Designations' ? null : _selectedDesignation,
                  items: designationOptions,
                  itemLabel: (item) => item,
                  onChanged: (val) {
                    setState(() {
                      _selectedDesignation = val ?? 'All Designations';
                    });
                  },
                ),
              ),

              // Reset Filter Button
              if (_selectedDepartment != 'All Departments' ||
                  _selectedDesignation != 'All Designations' ||
                  _searchQuery.isNotEmpty)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Reset Filters', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _selectedDepartment = 'All Departments';
                      _selectedDesignation = 'All Designations';
                      _searchQuery = '';
                    });
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeDropdown(List<Employee> employees, Employee? activeEmployee) {
    return InkWell(
      onTap: () => _openEmployeeSelectionDialog(context, employees),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Row(
          children: [
            const Icon(Icons.person_outline, size: 18, color: Color(0xFF9CC70A)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                activeEmployee != null
                    ? '${activeEmployee.fullName} (${activeEmployee.employeeId})'
                    : 'Select Employee',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: activeEmployee != null ? FontWeight.bold : FontWeight.normal,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 18, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }

  Widget _buildGenericFilterDropdown<T>({
    Key? key,
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T item) itemLabel,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      key: key,
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          hint: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          icon: const Icon(Icons.arrow_drop_down, size: 18, color: Color(0xFF64748B)),
          items: items.map((item) {
            final isPlaceholder = itemLabel(item).startsWith('All ');
            return DropdownMenuItem<T>(
              value: isPlaceholder ? null : item,
              child: Text(
                itemLabel(item),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isPlaceholder ? FontWeight.normal : FontWeight.w600,
                  color: const Color(0xFF0F172A),
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // --- 2. Employee Profile Header Card ---

  Widget _buildEmployeeHeaderCard(Employee emp) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFF9CC70A).withValues(alpha: 0.15),
            child: Text(
              emp.firstName.isNotEmpty ? emp.firstName[0].toUpperCase() : 'E',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF414A51),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Name & Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        emp.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Text(
                        emp.employeeId.isNotEmpty ? emp.employeeId : 'ID: ${emp.id}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    if (emp.department.isNotEmpty)
                      _buildMiniInfoBadge(Icons.business_outlined, emp.department),
                    if (emp.designation.isNotEmpty)
                      _buildMiniInfoBadge(Icons.badge_outlined, emp.designation),
                    _buildMiniInfoBadge(
                      Icons.schedule_outlined,
                      'Req: ${emp.requiredWorkingHours > 0 ? emp.requiredWorkingHours : 9.0} hrs/day',
                    ),
                    if (emp.weeklyOffDay.isNotEmpty)
                      _buildMiniInfoBadge(Icons.weekend_outlined, 'Off: ${emp.weeklyOffDay}'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniInfoBadge(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: const Color(0xFF64748B)),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  // --- 3. 8 Status Summary KPI Cards ---

  Widget _buildStatusKpiGrid(MonthlyAttendanceResult result, bool isMobile) {
    final kpis = [
      _SummaryKpiItem(
        label: 'Present',
        code: 'P',
        count: result.presentCount,
        bgColor: const Color(0xFFDCFCE7),
        textColor: const Color(0xFF16A34A),
        icon: Icons.check_circle_outline,
      ),
      _SummaryKpiItem(
        label: 'Late',
        code: 'L',
        count: result.lateCount,
        bgColor: const Color(0xFFFFEDD5),
        textColor: const Color(0xFFEA580C),
        icon: Icons.access_time,
      ),
      _SummaryKpiItem(
        label: 'Absent',
        code: 'A',
        count: result.absentCount,
        bgColor: const Color(0xFFFEE2E2),
        textColor: const Color(0xFFDC2626),
        icon: Icons.cancel_outlined,
      ),
      _SummaryKpiItem(
        label: 'On Leave',
        code: 'OL',
        count: result.onLeaveCount,
        bgColor: const Color(0xFFFEF9C3),
        textColor: const Color(0xFFCA8A04),
        icon: Icons.work_off_outlined,
      ),
      _SummaryKpiItem(
        label: 'Weekly Off',
        code: 'WO',
        count: result.weeklyOffCount,
        bgColor: const Color(0xFFF1F5F9),
        textColor: const Color(0xFF64748B),
        icon: Icons.weekend_outlined,
      ),
      _SummaryKpiItem(
        label: 'Holiday',
        code: 'H',
        count: result.holidayCount,
        bgColor: const Color(0xFFF3E8FF),
        textColor: const Color(0xFF7C3AED),
        icon: Icons.celebration_outlined,
      ),
      _SummaryKpiItem(
        label: 'Missing Check-Out',
        code: 'MC',
        count: result.missingCheckoutCount,
        bgColor: const Color(0xFFF3E8FF),
        textColor: const Color(0xFF9333EA),
        icon: Icons.warning_amber_rounded,
      ),
      _SummaryKpiItem(
        label: 'Insufficient Hours',
        code: 'IH',
        count: result.insufficientHoursCount,
        bgColor: const Color(0xFFFFEDD5),
        textColor: const Color(0xFFD97706),
        icon: Icons.timer_off_outlined,
      ),
    ];

    if (isMobile) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.8,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: kpis.length,
        itemBuilder: (context, index) => _buildSingleKpiCard(kpis[index]),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900 ? 4 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: crossAxisCount == 4 ? 2.4 : 2.0,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: kpis.length,
          itemBuilder: (context, index) => _buildSingleKpiCard(kpis[index]),
        );
      },
    );
  }

  Widget _buildSingleKpiCard(_SummaryKpiItem kpi) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: kpi.bgColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kpi.textColor.withValues(alpha: 0.2)),
            ),
            child: Icon(kpi.icon, color: kpi.textColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${kpi.count}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: kpi.bgColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        kpi.code,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: kpi.textColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  kpi.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 4. Hours Summary Banner Card ---

  Widget _buildHoursSummaryCard(MonthlyAttendanceResult result, bool isMobile) {
    final hasShortfall = result.totalShortfallHours > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 18, color: Color(0xFF414A51)),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Monthly Hours Summary',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${result.totalWorkingDays} Working Days',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),

          // Hours Metrics Row / Wrap
          if (isMobile) ...[
            _buildHourMetricTile(
              title: 'Total Required Hours',
              value: result.formattedRequiredHours,
              subtext: '${result.totalRequiredHours} hrs required',
              icon: Icons.calendar_today_outlined,
              iconColor: const Color(0xFF2563EB),
              bgColor: const Color(0xFFEFF6FF),
            ),
            const SizedBox(height: 10),
            _buildHourMetricTile(
              title: 'Total Working Hours',
              value: result.formattedWorkingHours,
              subtext: '${result.totalWorkingHours} hrs logged',
              icon: Icons.schedule_outlined,
              iconColor: const Color(0xFF16A34A),
              bgColor: const Color(0xFFF0FDF4),
            ),
            const SizedBox(height: 10),
            _buildHourMetricTile(
              title: 'Total Shortfall',
              value: result.formattedShortfallHours,
              subtext: hasShortfall ? '${result.totalShortfallHours} hrs deficit' : 'Target Achieved',
              icon: Icons.trending_down_outlined,
              iconColor: hasShortfall ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
              bgColor: hasShortfall ? const Color(0xFFFEE2E2) : const Color(0xFFF0FDF4),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: _buildHourMetricTile(
                    title: 'Total Required Hours',
                    value: result.formattedRequiredHours,
                    subtext: '${result.totalRequiredHours} hrs required',
                    icon: Icons.calendar_today_outlined,
                    iconColor: const Color(0xFF2563EB),
                    bgColor: const Color(0xFFEFF6FF),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildHourMetricTile(
                    title: 'Total Working Hours',
                    value: result.formattedWorkingHours,
                    subtext: '${result.totalWorkingHours} hrs logged',
                    icon: Icons.schedule_outlined,
                    iconColor: const Color(0xFF16A34A),
                    bgColor: const Color(0xFFF0FDF4),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildHourMetricTile(
                    title: 'Total Shortfall',
                    value: result.formattedShortfallHours,
                    subtext: hasShortfall ? '${result.totalShortfallHours} hrs deficit' : 'Target Achieved',
                    icon: Icons.trending_down_outlined,
                    iconColor: hasShortfall ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                    bgColor: hasShortfall ? const Color(0xFFFEE2E2) : const Color(0xFFF0FDF4),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHourMetricTile({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtext,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 5. Daily Breakdown Section ---

  Widget _buildDailyBreakdownSection(
    MonthlyAttendanceResult result,
    Employee employee,
    bool isMobile,
  ) {
    final monthName = DateFormat('MMMM yyyy').format(_currentMonth);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF9CC70A).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.table_chart_outlined, size: 16, color: Color(0xFF9CC70A)),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Daily Attendance — $monthName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: isMobile ? 12 : 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${result.dailyResults.length} Days',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          if (isMobile)
            _buildDailyMobileCards(result.dailyResults, employee)
          else
            _buildDailyDesktopTable(result.dailyResults, employee),
        ],
      ),
    );
  }

  Widget _buildDailyDesktopTable(List<DailyAttendanceResult> dailyResults, Employee employee) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
        columnSpacing: 18,
        horizontalMargin: 16,
        columns: const [
          DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          DataColumn(label: Text('Day', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          DataColumn(label: Text('Check-in', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          DataColumn(label: Text('Check-out', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          DataColumn(label: Text('Working Hours', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          DataColumn(label: Text('Required Hours', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          DataColumn(label: Text('Shortfall', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
        ],
        rows: dailyResults.map((day) {
          final dayName = DateFormat('EEEE').format(day.date);
          final statusInfo = day.statusInfo;
          final statusLabel = day.statusLabel;

          final statusBg = statusInfo?.bgColor ?? const Color(0xFFF1F5F9);
          final statusText = statusInfo?.textColor ?? const Color(0xFF64748B);

          final checkInStr = day.record?.effectiveCheckInTime.isNotEmpty == true
              ? day.record!.formattedCheckInTime
              : '--:--';
          final checkOutStr = day.record?.checkOutTime.isNotEmpty == true
              ? day.record!.formattedCheckOutTime
              : '--:--';

          final workingHrsStr = day.workingHours > 0
              ? AttendanceRecord.formatHours(day.workingHours)
              : (day.isWorkingDay ? '0hr' : '-');
          final reqHrsStr = day.isWorkingDay
              ? AttendanceRecord.formatHours(day.requiredHours)
              : '-';
          final shortfallStr = day.isWorkingDay
              ? (day.shortfallHours > 0 ? AttendanceRecord.formatHours(day.shortfallHours) : '0hr')
              : '-';

          final hasDayShortfall = day.isWorkingDay && day.shortfallHours > 0;

          return DataRow(
            onSelectChanged: widget.onRowTap != null
                ? (_) => widget.onRowTap!(day, employee)
                : null,
            cells: [
              DataCell(
                Text(
                  day.dateStr,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)),
                ),
              ),
              DataCell(
                Text(
                  dayName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: day.date.weekday == DateTime.sunday ? const Color(0xFFEF4444) : const Color(0xFF475569),
                  ),
                ),
              ),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusText.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    statusInfo != null ? '${statusInfo.code} - $statusLabel' : statusLabel,
                    style: TextStyle(fontSize: 11, color: statusText, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              DataCell(Text(checkInStr, style: const TextStyle(fontSize: 12))),
              DataCell(Text(checkOutStr, style: const TextStyle(fontSize: 12))),
              DataCell(
                Text(
                  workingHrsStr,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: day.workingHours > 0 ? FontWeight.bold : FontWeight.normal,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
              DataCell(Text(reqHrsStr, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: hasDayShortfall
                        ? const Color(0xFFFEE2E2)
                        : (day.isWorkingDay ? const Color(0xFFF0FDF4) : Colors.transparent),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    shortfallStr,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: hasDayShortfall ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                    ),
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDailyMobileCards(List<DailyAttendanceResult> dailyResults, Employee employee) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: dailyResults.length,
      separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
      itemBuilder: (context, index) {
        final day = dailyResults[index];
        final dayName = DateFormat('EEEE').format(day.date);
        final statusInfo = day.statusInfo;
        final statusLabel = day.statusLabel;
        final statusBg = statusInfo?.bgColor ?? const Color(0xFFF1F5F9);
        final statusText = statusInfo?.textColor ?? const Color(0xFF64748B);

        final checkInStr = day.record?.effectiveCheckInTime.isNotEmpty == true
            ? day.record!.formattedCheckInTime
            : '--:--';
        final checkOutStr = day.record?.checkOutTime.isNotEmpty == true
            ? day.record!.formattedCheckOutTime
            : '--:--';

        final workingHrsStr = day.workingHours > 0
            ? AttendanceRecord.formatHours(day.workingHours)
            : (day.isWorkingDay ? '0hr' : '-');
        final reqHrsStr = day.isWorkingDay
            ? AttendanceRecord.formatHours(day.requiredHours)
            : '-';
        final shortfallStr = day.isWorkingDay
            ? (day.shortfallHours > 0 ? AttendanceRecord.formatHours(day.shortfallHours) : '0hr')
            : '-';

        final hasDayShortfall = day.isWorkingDay && day.shortfallHours > 0;

        return InkWell(
          onTap: widget.onRowTap != null ? () => widget.onRowTap!(day, employee) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top: Date & Day on left, Status Chip on right
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            day.dateStr,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            dayName,
                            style: TextStyle(
                              fontSize: 11,
                              color: day.date.weekday == DateTime.sunday ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: statusText.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        statusInfo != null ? '${statusInfo.code} - $statusLabel' : statusLabel,
                        style: TextStyle(fontSize: 10, color: statusText, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Middle: In & Out Time
                Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.login, size: 13, color: Color(0xFF16A34A)),
                        const SizedBox(width: 4),
                        Text('In: $checkInStr', style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.logout, size: 13, color: Color(0xFFDC2626)),
                        const SizedBox(width: 4),
                        Text('Out: $checkOutStr', style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Bottom: Hours & Shortfall
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Work: $workingHrsStr  |  Req: $reqHrsStr',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (day.isWorkingDay)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: hasDayShortfall ? const Color(0xFFFEE2E2) : const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Shortfall: $shortfallStr',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: hasDayShortfall ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- No Employee Selected View ---

  Widget _buildNoEmployeeSelectedView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Center(
        child: Column(
          children: [
            Icon(Icons.person_search_outlined, size: 48, color: Color(0xFF94A3B8)),
            SizedBox(height: 12),
            Text(
              'No Employee Selected',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
            ),
            SizedBox(height: 4),
            Text(
              'Select an employee from the dropdown or clear filters to view monthly results.',
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }

  // --- Dialogs ---

  void _openMonthYearPicker(BuildContext context) {
    int tempYear = _currentMonth.year;
    int tempMonth = _currentMonth.month;

    final months = [
      'Jan', 'Feb', 'Mar', 'Apr',
      'May', 'Jun', 'Jul', 'Aug',
      'Sep', 'Oct', 'Nov', 'Dec',
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                width: 320,
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: () => setDialogState(() => tempYear--),
                        ),
                        Text(
                          '$tempYear',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: () => setDialogState(() => tempYear++),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 1.8,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: 12,
                      itemBuilder: (context, index) {
                        final isSelected = (index + 1) == tempMonth;
                        return InkWell(
                          onTap: () => setDialogState(() => tempMonth = index + 1),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF9CC70A) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF9CC70A) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Text(
                              months[index],
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : const Color(0xFF334155),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF9CC70A),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            _changeMonth(DateTime(tempYear, tempMonth, 1));
                            Navigator.pop(ctx);
                          },
                          child: const Text('Select', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openEmployeeSelectionDialog(BuildContext context, List<Employee> employees) {
    showDialog(
      context: context,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final filtered = employees.where((emp) {
              if (query.isEmpty) return true;
              final q = query.toLowerCase();
              return emp.fullName.toLowerCase().contains(q) || emp.employeeId.toLowerCase().contains(q);
            }).toList();

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                width: 380,
                height: 480,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Select Employee',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      autofocus: true,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search by name or code...',
                        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                      ),
                      onChanged: (val) => setDialogState(() => query = val.trim()),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text(
                                'No employees found',
                                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                              ),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                              itemBuilder: (context, index) {
                                final emp = filtered[index];
                                final isSelected = emp.id == _localSelectedEmployeeId;
                                return ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: isSelected
                                        ? const Color(0xFF9CC70A)
                                        : const Color(0xFF9CC70A).withValues(alpha: 0.15),
                                    child: Text(
                                      emp.firstName.isNotEmpty ? emp.firstName[0].toUpperCase() : 'E',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected ? Colors.white : const Color(0xFF414A51),
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    emp.fullName,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                      color: isSelected ? const Color(0xFF9CC70A) : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${emp.employeeId} • ${emp.department} • ${emp.designation}',
                                    style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                  ),
                                  trailing: isSelected
                                      ? const Icon(Icons.check_circle, size: 18, color: Color(0xFF9CC70A))
                                      : null,
                                  onTap: () {
                                    _selectEmployee(emp.id);
                                    Navigator.pop(ctx);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SummaryKpiItem {
  const _SummaryKpiItem({
    required this.label,
    required this.code,
    required this.count,
    required this.bgColor,
    required this.textColor,
    required this.icon,
  });

  final String label;
  final String code;
  final int count;
  final Color bgColor;
  final Color textColor;
  final IconData icon;
}
