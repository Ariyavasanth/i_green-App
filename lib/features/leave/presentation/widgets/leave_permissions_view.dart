import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../employee/domain/employee.dart';
import '../../../employee/providers/employee_providers.dart';
import '../../domain/leave_request.dart';
import '../../providers/leave_providers.dart';

class LeavePermissionsView extends ConsumerStatefulWidget {
  const LeavePermissionsView({super.key});

  @override
  ConsumerState<LeavePermissionsView> createState() => _LeavePermissionsViewState();
}

class _LeavePermissionsViewState extends ConsumerState<LeavePermissionsView> {
  String _searchQuery = '';
  String _selectedDepartment = 'All Departments';
  String _selectedDesignation = 'All Designations';
  final Set<int> _selectedEmployeeIds = {};

  bool _canEdit(Employee? currentEmp) {
    if (currentEmp == null) return false;
    if (currentEmp.isSuperAdmin) return true;
    return currentEmp.hasPermission('Leave Management');
  }

  List<Employee> _filterEmployees(List<Employee> employees) {
    return employees.where((emp) {
      if (_selectedDepartment != 'All Departments' && emp.department != _selectedDepartment) {
        return false;
      }
      if (_selectedDesignation != 'All Designations' && emp.designation != _selectedDesignation) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.trim().toLowerCase();
        final matchName = emp.fullName.toLowerCase().contains(query);
        final matchId = emp.employeeId.toLowerCase().contains(query);
        final matchDept = emp.department.toLowerCase().contains(query);
        final matchDesig = emp.designation.toLowerCase().contains(query);
        if (!matchName && !matchId && !matchDept && !matchDesig) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 850;
    final currentEmp = ref.watch(currentEmployeeProvider);
    final hasPermission = _canEdit(currentEmp);
    final employeesAsync = ref.watch(employeesProvider);
    final leaveRequests = ref.watch(allLeaveRequestsProvider).value ?? [];

    return employeesAsync.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (err, stack) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text('Error loading employees: $err', style: const TextStyle(color: Colors.red)),
        ),
      ),
      data: (allEmployees) {
        final filteredEmployees = _filterEmployees(allEmployees);

        // Calculate Stats
        final totalCount = allEmployees.length;
        final autoApprovedCount = allEmployees.where((e) => !e.requiresLeaveApproval).length;
        final approvalReqCount = allEmployees.where((e) => e.requiresLeaveApproval).length;

        // Derive options
        final deptSet = {
          'All Departments',
          ...Employee.departmentOptions,
          ...allEmployees.map((e) => e.department).where((d) => d.isNotEmpty),
        };
        final desigSet = {
          'All Designations',
          ...Employee.designationOptions,
          ...allEmployees.map((e) => e.designation).where((d) => d.isNotEmpty),
        };

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI Summary Cards
            _buildKpiBanner(totalCount, autoApprovedCount, approvalReqCount, isMobile),
            const SizedBox(height: 16),

            if (!hasPermission)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3CD),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFEEBA)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFF856404), size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Read-only view: You require Leave Management admin permission to alter employee leave policies.',
                        style: TextStyle(color: Color(0xFF856404), fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),

            // Controls Toolbar Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Row 1: Search and Filters
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final useStack = constraints.maxWidth < 700;
                      if (useStack) {
                        return Column(
                          children: [
                            _buildSearchBox(),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(child: _buildDeptDropdown(deptSet)),
                                const SizedBox(width: 10),
                                Expanded(child: _buildDesigDropdown(desigSet)),
                              ],
                            ),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(flex: 3, child: _buildSearchBox()),
                          const SizedBox(width: 12),
                          Expanded(flex: 2, child: _buildDeptDropdown(deptSet)),
                          const SizedBox(width: 12),
                          Expanded(flex: 2, child: _buildDesigDropdown(desigSet)),
                        ],
                      );
                    },
                  ),

                  // Row 2: Bulk Actions Toolbar
                  if (hasPermission) ...[
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 14),
                    _buildBulkActionsBar(filteredEmployees, isMobile),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Main Employees List View
            if (filteredEmployees.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(48),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.people_outline, size: 52, color: Colors.grey),
                    SizedBox(height: 12),
                    Text(
                      'No matching employees found.',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Try adjusting your search query or filter selection.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              )
            else if (isMobile)
              _buildMobileCardList(filteredEmployees, hasPermission, leaveRequests)
            else
              _buildDesktopTableCard(filteredEmployees, hasPermission, leaveRequests),
          ],
        );
      },
    );
  }

  Widget _buildKpiBanner(int total, int autoApproved, int approvalReq, bool isMobile) {
    final items = [
      (
        title: 'Total Employees',
        value: total.toString(),
        icon: Icons.groups,
        color: const Color(0xFF414A51),
      ),
      (
        title: 'Auto-Approved Policies',
        value: autoApproved.toString(),
        icon: Icons.verified_user,
        color: const Color(0xFF2E7D32),
      ),
      (
        title: 'Approval Required',
        value: approvalReq.toString(),
        icon: Icons.admin_panel_settings,
        color: const Color(0xFFE65100),
      ),
    ];

    if (isMobile) {
      return SizedBox(
        height: 76,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (context, index) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final item = items[index];
            return SizedBox(
              width: 210,
              child: _kpiCard(item.title, item.value, item.icon, item.color),
            );
          },
        ),
      );
    }

    return Row(
      children: items.map((item) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _kpiCard(item.title, item.value, item.icon, item.color),
          ),
        );
      }).toList()..last = Expanded(
        child: _kpiCard(items.last.title, items.last.value, items.last.icon, items.last.color),
      ),
    );
  }

  Widget _kpiCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBox() {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Search employee by name, ID, department...',
        prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
      ),
      onChanged: (val) => setState(() => _searchQuery = val),
    );
  }

  Widget _buildDeptDropdown(Set<String> deptSet) {
    return DropdownButtonFormField<String>(
      initialValue: _selectedDepartment,
      isDense: true,
      decoration: InputDecoration(
        labelText: 'Department',
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items: deptSet.map((d) {
        return DropdownMenuItem<String>(
          value: d,
          child: Text(d, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: (val) {
        if (val != null) {
          setState(() {
            _selectedDepartment = val;
            _selectedEmployeeIds.clear();
          });
        }
      },
    );
  }

  Widget _buildDesigDropdown(Set<String> desigSet) {
    return DropdownButtonFormField<String>(
      initialValue: _selectedDesignation,
      isDense: true,
      decoration: InputDecoration(
        labelText: 'Designation',
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items: desigSet.map((d) {
        return DropdownMenuItem<String>(
          value: d,
          child: Text(d, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: (val) {
        if (val != null) {
          setState(() {
            _selectedDesignation = val;
            _selectedEmployeeIds.clear();
          });
        }
      },
    );
  }

  Widget _buildBulkActionsBar(List<Employee> filteredEmployees, bool isMobile) {
    final allFilteredSelected = filteredEmployees.isNotEmpty &&
        filteredEmployees.every((e) => _selectedEmployeeIds.contains(e.id));

    final countSelected = _selectedEmployeeIds.length;

    return Wrap(
      spacing: 12,
      runSpacing: 10,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: allFilteredSelected,
              activeColor: AppColors.active,
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selectedEmployeeIds.addAll(filteredEmployees.map((e) => e.id));
                  } else {
                    _selectedEmployeeIds.clear();
                  }
                });
              },
            ),
            Text(
              'Select All (${filteredEmployees.length})',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            if (countSelected > 0) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.active.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.active.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '$countSelected selected',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ),
            ],
          ],
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _selectedEmployeeIds.isNotEmpty ? AppColors.active : Colors.grey.shade400,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 14 : 18,
              vertical: isMobile ? 10 : 12,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: _selectedEmployeeIds.isNotEmpty ? 2 : 0,
          ),
          onPressed: _selectedEmployeeIds.isEmpty
              ? null
              : () => _openBulkEditModal(context, filteredEmployees),
          icon: const Icon(Icons.admin_panel_settings, size: 18),
          label: Text(
            countSelected > 0
                ? 'Apply Bulk Policy ($countSelected)'
                : 'Apply Bulk Policy',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ],
    );
  }

  double _calculateUsedThisMonth(Employee emp, List<LeaveRequest> requests) {
    final now = DateTime.now();
    final monthStr = now.month.toString().padLeft(2, '0');
    final yearStr = now.year.toString();
    final targetSuffix = '-$monthStr-$yearStr';
    final targetPrefix = '$yearStr-$monthStr-';

    double count = 0.0;
    for (final req in requests) {
      if (req.status != 'Approved') continue;
      if (req.employeeId != emp.id && req.employeeCustomId != emp.employeeId) continue;

      if (req.approvedDates.isNotEmpty) {
        for (final date in req.approvedDates) {
          if (date.endsWith(targetSuffix) || date.startsWith(targetPrefix)) {
            count += 1.0;
          }
        }
      } else {
        if (req.fromDate.endsWith(targetSuffix) || req.fromDate.startsWith(targetPrefix)) {
          count += req.numDays;
        }
      }
    }
    return count;
  }

  Widget _buildUsedThisMonthCell(double used, double allowed, String leaveType) {
    if (leaveType != 'Manual Allocation' && leaveType != 'Once a Month') {
      return const Text('-', style: TextStyle(fontSize: 12, color: Colors.grey));
    }
    final ratio = allowed > 0 ? (used / allowed).clamp(0.0, 1.0) : 0.0;
    final color = ratio >= 1.0
        ? Colors.red.shade700
        : ratio >= 0.8
            ? Colors.orange.shade700
            : const Color(0xFF2E7D32);

    final usedStr = used == used.truncateToDouble() ? used.toInt().toString() : used.toStringAsFixed(1);
    final allowedStr = allowed == allowed.truncateToDouble() ? allowed.toInt().toString() : allowed.toStringAsFixed(1);

    return SizedBox(
      width: 130,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$usedStr / $allowedStr days used',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 5,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTableCard(List<Employee> employees, bool hasPermission, List<LeaveRequest> leaveRequests) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 1050),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              headingRowHeight: 46,
              dataRowMinHeight: 60,
              dataRowMaxHeight: 70,
              horizontalMargin: 16,
              columnSpacing: 20,
              columns: [
                if (hasPermission)
                  const DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
                const DataColumn(label: Text('Employee Name', style: TextStyle(fontWeight: FontWeight.bold))),
                const DataColumn(label: Text('Department', style: TextStyle(fontWeight: FontWeight.bold))),
                const DataColumn(label: Text('Designation', style: TextStyle(fontWeight: FontWeight.bold))),
                const DataColumn(label: Text('Leave Type Allowed', style: TextStyle(fontWeight: FontWeight.bold))),
                const DataColumn(label: Text('Allowed Days', style: TextStyle(fontWeight: FontWeight.bold))),
                const DataColumn(label: Text('Used This Month', style: TextStyle(fontWeight: FontWeight.bold))),
                const DataColumn(label: Text('Frequency', style: TextStyle(fontWeight: FontWeight.bold))),
                const DataColumn(label: Text('Requires Approval', style: TextStyle(fontWeight: FontWeight.bold))),
                if (hasPermission)
                  const DataColumn(label: Text('Save Policy', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: employees.map((emp) {
                final isSelected = _selectedEmployeeIds.contains(emp.id);
                final usedThisMonth = _calculateUsedThisMonth(emp, leaveRequests);

                if (!hasPermission) {
                  // Non-permission read-only row
                  return DataRow(
                    cells: [
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 15,
                              backgroundColor: const Color(0xFF414A51).withValues(alpha: 0.1),
                              child: Text(
                                emp.firstName.isNotEmpty ? emp.firstName[0].toUpperCase() : 'E',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF414A51)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(emp.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ),
                      DataCell(Text(emp.department.isNotEmpty ? emp.department : 'Unassigned', style: const TextStyle(fontSize: 13))),
                      DataCell(Text(emp.designation.isNotEmpty ? emp.designation : 'N/A', style: const TextStyle(fontSize: 13))),
                      DataCell(Text(emp.leaveType == 'Manual Allocation' || emp.leaveType == 'Once a Month' ? '${emp.allowedLeaves} days' : '-', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                      DataCell(_buildUsedThisMonthCell(usedThisMonth, emp.allowedLeaves, emp.leaveType)),
                      DataCell(Text(emp.leaveType == 'Manual Allocation' || emp.leaveType == 'Once a Month' ? emp.leaveAllocationFrequency : '-', style: const TextStyle(fontSize: 13))),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: emp.requiresLeaveApproval ? const Color(0xFFFFF3E0) : const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            emp.requiresLeaveApproval ? 'Yes' : 'No (Auto)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: emp.requiresLeaveApproval ? const Color(0xFFE65100) : const Color(0xFF2E7D32),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }

                // Interactive Editable Row for Permitted Admin
                return DataRow.byIndex(
                  index: emp.id,
                  selected: isSelected,
                  onSelectChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedEmployeeIds.add(emp.id);
                      } else {
                        _selectedEmployeeIds.remove(emp.id);
                      }
                    });
                  },
                  cells: [
                    DataCell(
                      Checkbox(
                        value: isSelected,
                        activeColor: AppColors.active,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedEmployeeIds.add(emp.id);
                            } else {
                              _selectedEmployeeIds.remove(emp.id);
                            }
                          });
                        },
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 15,
                            backgroundColor: const Color(0xFF414A51).withValues(alpha: 0.1),
                            child: Text(
                              emp.firstName.isNotEmpty ? emp.firstName[0].toUpperCase() : 'E',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF414A51)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(emp.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text(
                                emp.employeeId.isNotEmpty ? emp.employeeId : 'ID: ${emp.id}',
                                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    DataCell(Text(emp.department.isNotEmpty ? emp.department : 'Unassigned', style: const TextStyle(fontSize: 12))),
                    DataCell(Text(emp.designation.isNotEmpty ? emp.designation : 'N/A', style: const TextStyle(fontSize: 12))),
                    
                    // Interactive Cells
                    DataCell(_InlineLeaveTypeCell(employee: emp)),
                    DataCell(_InlineAllowedDaysCell(employee: emp)),
                    DataCell(_buildUsedThisMonthCell(usedThisMonth, emp.allowedLeaves, emp.leaveType)),
                    DataCell(_InlineFrequencyCell(employee: emp)),
                    DataCell(_InlineRequiresApprovalCell(employee: emp)),
                    DataCell(
                      _InlineSaveActionCell(
                        employee: emp,
                        onModalEditClick: () => _openSingleEditModal(context, emp),
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

  Widget _buildMobileCardList(List<Employee> employees, bool hasPermission, List<LeaveRequest> leaveRequests) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: employees.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final emp = employees[index];
        final isSelected = _selectedEmployeeIds.contains(emp.id);

        if (!hasPermission) {
          // Read-only card
          return Card(
            margin: EdgeInsets.zero,
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(emp.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text('${emp.department} • ${emp.designation}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Days: ${emp.allowedLeaves}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      Text('Type: ${emp.leaveType}', style: const TextStyle(fontSize: 12)),
                      Text('Approval: ${emp.requiresLeaveApproval ? 'Yes' : 'No'}', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          );
        }

        return _EmployeePermissionCard(
          employee: emp,
          isSelected: isSelected,
          onSelectChanged: (val) {
            setState(() {
              if (val == true) {
                _selectedEmployeeIds.add(emp.id);
              } else {
                _selectedEmployeeIds.remove(emp.id);
              }
            });
          },
          onModalEditClick: () => _openSingleEditModal(context, emp),
        );
      },
    );
  }

  void _openSingleEditModal(BuildContext context, Employee employee) {
    String leaveType = employee.leaveType.isNotEmpty ? employee.leaveType : 'As Needed';
    String frequency = employee.leaveAllocationFrequency.isNotEmpty ? employee.leaveAllocationFrequency : 'Monthly';
    bool requiresApproval = employee.requiresLeaveApproval;
    final allowedController = TextEditingController(text: employee.allowedLeaves.toString());
    final effectiveController = TextEditingController(
      text: employee.effectiveDate.isNotEmpty
          ? employee.effectiveDate
          : DateFormat('dd-MM-yyyy').format(DateTime.now()),
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: Row(
                children: [
                  const Icon(Icons.edit_note, color: AppColors.active),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Edit Policy: ${employee.fullName}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: Employee.leaveTypeOptions.contains(leaveType) ? leaveType : Employee.leaveTypeOptions.first,
                        decoration: const InputDecoration(labelText: 'Allowed Leave Type', border: OutlineInputBorder()),
                        items: Employee.leaveTypeOptions.map((opt) {
                          return DropdownMenuItem(value: opt, child: Text(opt));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setModalState(() => leaveType = val);
                        },
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: allowedController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Number of Allowed Leaves',
                          border: OutlineInputBorder(),
                          suffixText: 'days',
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: frequency,
                        decoration: const InputDecoration(labelText: 'Allocation Frequency', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'Monthly', child: Text('Monthly')),
                          DropdownMenuItem(value: 'Yearly', child: Text('Yearly')),
                          DropdownMenuItem(value: 'As Needed', child: Text('As Needed')),
                        ],
                        onChanged: (val) {
                          if (val != null) setModalState(() => frequency = val);
                        },
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: effectiveController,
                        decoration: const InputDecoration(
                          labelText: 'Effective Date (DD-MM-YYYY)',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today, size: 18),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Requires Approval', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text('If disabled, short leave requests are auto-approved.', style: TextStyle(fontSize: 12)),
                        value: requiresApproval,
                        activeThumbColor: AppColors.active,
                        onChanged: (val) {
                          setModalState(() => requiresApproval = val);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.active,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final allowedValue = double.tryParse(allowedController.text.trim()) ?? 1.0;
                    final updated = employee.copyWith(
                      leaveType: leaveType,
                      allowedLeaves: allowedValue,
                      leaveAllocationFrequency: frequency,
                      effectiveDate: effectiveController.text.trim(),
                      requiresLeaveApproval: requiresApproval,
                    );

                    try {
                      await ref.read(employeeRepositoryProvider).updateEmployee(updated);
                      ref.invalidate(employeesProvider);
                      if (ctx.mounted) Navigator.of(ctx).pop();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Leave policy updated for ${employee.fullName}'),
                            backgroundColor: const Color(0xFF2E7D32),
                          ),
                        );
                      }
                    } catch (err) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to update leave policy: $err'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openBulkEditModal(BuildContext context, List<Employee> allFiltered) {
    final selectedEmployees = allFiltered.where((e) => _selectedEmployeeIds.contains(e.id)).toList();
    if (selectedEmployees.isEmpty) return;

    String leaveType = 'As Needed';
    String frequency = 'Monthly';
    bool requiresApproval = true;
    final allowedController = TextEditingController(text: '1.0');
    final effectiveController = TextEditingController(
      text: DateFormat('dd-MM-yyyy').format(DateTime.now()),
    );

    String scopeDescription = '${selectedEmployees.length} selected employees';
    if (_selectedDepartment != 'All Departments') {
      scopeDescription = '${selectedEmployees.length} employees in "$_selectedDepartment" department';
    } else if (_selectedDesignation != 'All Designations') {
      scopeDescription = '${selectedEmployees.length} employees with "$_selectedDesignation" designation';
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: const Row(
                children: [
                  Icon(Icons.admin_panel_settings, color: AppColors.active),
                  SizedBox(width: 8),
                  Text('Bulk Leave Policy Update', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 440,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF81C784)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.people, color: Color(0xFF2E7D32), size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'This will update leave policy for $scopeDescription.',
                                style: const TextStyle(
                                  color: Color(0xFF2E7D32),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        initialValue: leaveType,
                        decoration: const InputDecoration(labelText: 'Allowed Leave Type', border: OutlineInputBorder()),
                        items: Employee.leaveTypeOptions.map((opt) {
                          return DropdownMenuItem(value: opt, child: Text(opt));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setModalState(() => leaveType = val);
                        },
                      ),
                      const SizedBox(height: 14),
                      if (leaveType == 'Manual Allocation' || leaveType == 'Once a Month') ...[
                        TextField(
                          controller: allowedController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Allowed Leave Days',
                            border: OutlineInputBorder(),
                            suffixText: 'days',
                          ),
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: frequency,
                          decoration: const InputDecoration(labelText: 'Allocation Frequency', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'Monthly', child: Text('Monthly')),
                            DropdownMenuItem(value: 'Quarterly', child: Text('Quarterly')),
                            DropdownMenuItem(value: 'Yearly', child: Text('Yearly')),
                          ],
                          onChanged: (val) {
                            if (val != null) setModalState(() => frequency = val);
                          },
                        ),
                        const SizedBox(height: 14),
                      ],
                      TextField(
                        controller: effectiveController,
                        decoration: const InputDecoration(
                          labelText: 'Effective Date (DD-MM-YYYY)',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today, size: 18),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Requires Approval', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text('If disabled, leave requests are auto-approved.', style: TextStyle(fontSize: 12)),
                        value: requiresApproval,
                        activeThumbColor: AppColors.active,
                        onChanged: (val) {
                          setModalState(() => requiresApproval = val);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.active,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final isManual = leaveType == 'Manual Allocation' || leaveType == 'Once a Month';
                    final allowedValue = isManual ? (double.tryParse(allowedController.text.trim()) ?? 0.0) : 0.0;
                    final frequencyValue = isManual ? frequency : '';
                    final empIds = selectedEmployees.map((e) => e.id).toList();

                    try {
                      await ref.read(employeeRepositoryProvider).updateBulkLeavePolicy(
                        employeeIds: empIds,
                        leaveType: leaveType,
                        allowedLeaves: allowedValue,
                        leaveAllocationFrequency: frequencyValue,
                        requiresLeaveApproval: requiresApproval,
                        effectiveDate: effectiveController.text.trim(),
                      );
                      ref.invalidate(employeesProvider);
                      setState(() {
                        _selectedEmployeeIds.clear();
                      });
                      if (ctx.mounted) Navigator.of(ctx).pop();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Leave policy updated for ${empIds.length} employees'),
                            backgroundColor: const Color(0xFF2E7D32),
                          ),
                        );
                      }
                    } catch (err) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to update bulk policy: $err'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  child: Text('Update ${selectedEmployees.length} Employees'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ── Inline Editable Component Widgets ───────────────────────────────────────

class _InlineLeaveTypeCell extends StatelessWidget {
  final Employee employee;
  const _InlineLeaveTypeCell({required this.employee});

  @override
  Widget build(BuildContext context) {
    final val = employee.leaveType.isNotEmpty ? employee.leaveType : 'As Needed';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Text(
        val,
        style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _InlineAllowedDaysCell extends ConsumerStatefulWidget {
  final Employee employee;
  const _InlineAllowedDaysCell({required this.employee});

  @override
  ConsumerState<_InlineAllowedDaysCell> createState() => _InlineAllowedDaysCellState();
}

class _InlineAllowedDaysCellState extends ConsumerState<_InlineAllowedDaysCell> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.employee.allowedLeaves.toString());
  }

  @override
  void didUpdateWidget(covariant _InlineAllowedDaysCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.employee.allowedLeaves != widget.employee.allowedLeaves) {
      _controller.text = widget.employee.allowedLeaves.toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.employee.leaveType != 'Manual Allocation' && widget.employee.leaveType != 'Once a Month') {
      return const Text('-', style: TextStyle(fontSize: 13, color: Colors.grey));
    }
    return SizedBox(
      width: 75,
      child: TextField(
        controller: _controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: AppColors.active, width: 2),
          ),
        ),
        onSubmitted: (val) {
          final numVal = double.tryParse(val.trim()) ?? widget.employee.allowedLeaves;
          _saveQuickField(ref, widget.employee.copyWith(allowedLeaves: numVal), context);
        },
      ),
    );
  }
}

class _InlineFrequencyCell extends StatelessWidget {
  final Employee employee;
  const _InlineFrequencyCell({required this.employee});

  @override
  Widget build(BuildContext context) {
    if (employee.leaveType != 'Manual Allocation' && employee.leaveType != 'Once a Month') {
      return const Text('-', style: TextStyle(fontSize: 13, color: Colors.grey));
    }
    final val = employee.leaveAllocationFrequency.isNotEmpty
        ? employee.leaveAllocationFrequency
        : 'Monthly';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Text(
        val,
        style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _InlineRequiresApprovalCell extends ConsumerStatefulWidget {
  final Employee employee;
  const _InlineRequiresApprovalCell({required this.employee});

  @override
  ConsumerState<_InlineRequiresApprovalCell> createState() => _InlineRequiresApprovalCellState();
}

class _InlineRequiresApprovalCellState extends ConsumerState<_InlineRequiresApprovalCell> {
  late bool _val;

  @override
  void initState() {
    super.initState();
    _val = widget.employee.requiresLeaveApproval;
  }

  @override
  void didUpdateWidget(covariant _InlineRequiresApprovalCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.employee.requiresLeaveApproval != widget.employee.requiresLeaveApproval) {
      _val = widget.employee.requiresLeaveApproval;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _val ? const Color(0xFFFFF3E0) : const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _val ? const Color(0xFFFFB74D) : const Color(0xFF81C784)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch.adaptive(
            value: _val,
            activeThumbColor: AppColors.active,
            onChanged: (newVal) {
              setState(() => _val = newVal);
              _saveQuickField(ref, widget.employee.copyWith(requiresLeaveApproval: newVal), context);
            },
          ),
          Text(
            _val ? 'Yes' : 'No (Auto)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: _val ? const Color(0xFFE65100) : const Color(0xFF2E7D32),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _InlineSaveActionCell extends StatefulWidget {
  final Employee employee;
  final VoidCallback onModalEditClick;

  const _InlineSaveActionCell({
    required this.employee,
    required this.onModalEditClick,
  });

  @override
  State<_InlineSaveActionCell> createState() => _InlineSaveActionCellState();
}

class _InlineSaveActionCellState extends State<_InlineSaveActionCell> {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.edit_note, color: AppColors.active, size: 22),
          tooltip: 'Full Edit Dialog',
          onPressed: widget.onModalEditClick,
        ),
      ],
    );
  }
}

// ── Mobile Responsive Card Component ───────────────────────────────────────

class _EmployeePermissionCard extends ConsumerStatefulWidget {
  final Employee employee;
  final bool isSelected;
  final ValueChanged<bool?> onSelectChanged;
  final VoidCallback onModalEditClick;

  const _EmployeePermissionCard({
    required this.employee,
    required this.isSelected,
    required this.onSelectChanged,
    required this.onModalEditClick,
  });

  @override
  ConsumerState<_EmployeePermissionCard> createState() => _EmployeePermissionCardState();
}

class _EmployeePermissionCardState extends ConsumerState<_EmployeePermissionCard> {
  late String _leaveType;
  late String _frequency;
  late bool _requiresApproval;
  late TextEditingController _allowedDaysController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initValues();
  }

  @override
  void didUpdateWidget(covariant _EmployeePermissionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.employee != widget.employee) {
      _initValues();
    }
  }

  void _initValues() {
    _leaveType = widget.employee.leaveType.isNotEmpty ? widget.employee.leaveType : 'As Needed';
    _frequency = widget.employee.leaveAllocationFrequency.isNotEmpty ? widget.employee.leaveAllocationFrequency : 'Monthly';
    _requiresApproval = widget.employee.requiresLeaveApproval;
    _allowedDaysController = TextEditingController(text: widget.employee.allowedLeaves.toString());
  }

  @override
  void dispose() {
    _allowedDaysController.dispose();
    super.dispose();
  }

  Future<void> _saveCardPolicy() async {
    setState(() => _isSaving = true);
    final isManual = _leaveType == 'Manual Allocation' || _leaveType == 'Once a Month';
    final allowedVal = isManual ? (double.tryParse(_allowedDaysController.text.trim()) ?? 0.0) : 0.0;
    final updated = widget.employee.copyWith(
      leaveType: _leaveType,
      allowedLeaves: allowedVal,
      leaveAllocationFrequency: isManual ? _frequency : '',
      requiresLeaveApproval: _requiresApproval,
    );

    try {
      await ref.read(employeeRepositoryProvider).updateEmployee(updated);
      ref.invalidate(employeesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Leave policy updated for ${widget.employee.fullName}'),
            backgroundColor: const Color(0xFF2E7D32),
          ),
        );
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update leave policy: $err'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final opts = Employee.leaveTypeOptions;
    final currentLeaveType = opts.contains(_leaveType) ? _leaveType : opts.first;
    const freqOpts = ['Monthly', 'Yearly', 'As Needed'];
    final currentFreq = freqOpts.contains(_frequency) ? _frequency : freqOpts.first;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: widget.isSelected ? AppColors.active : const Color(0xFFE2E8F0),
          width: widget.isSelected ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Checkbox, Avatar, Name & Dialog Button
            Row(
              children: [
                Checkbox(
                  value: widget.isSelected,
                  activeColor: AppColors.active,
                  onChanged: widget.onSelectChanged,
                ),
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF414A51).withValues(alpha: 0.1),
                  child: Text(
                    widget.employee.firstName.isNotEmpty ? widget.employee.firstName[0].toUpperCase() : 'E',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF414A51)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.employee.fullName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${widget.employee.department} • ${widget.employee.designation}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_note, color: AppColors.active),
                  tooltip: 'Full Edit Dialog',
                  onPressed: widget.onModalEditClick,
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Inline Mobile Controls
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Allowed Leave Type', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      const SizedBox(height: 2),
                      DropdownButtonFormField<String>(
                        initialValue: currentLeaveType,
                        isDense: true,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        items: opts.map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 11)))).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _leaveType = val);
                        },
                      ),
                    ],
                  ),
                ),
                if (currentLeaveType == 'Manual Allocation' || currentLeaveType == 'Once a Month') ...[
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 80,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Allowed Days', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        const SizedBox(height: 2),
                        TextField(
                          controller: _allowedDaysController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                if (currentLeaveType == 'Manual Allocation' || currentLeaveType == 'Once a Month') ...[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Allocation Frequency', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        const SizedBox(height: 2),
                        DropdownButtonFormField<String>(
                          initialValue: currentFreq,
                          isDense: true,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          items: freqOpts.map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 11)))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _frequency = val);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Requires Approval', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Row(
                      children: [
                        Switch.adaptive(
                          value: _requiresApproval,
                          activeThumbColor: AppColors.active,
                          onChanged: (val) => setState(() => _requiresApproval = val),
                        ),
                        Text(
                          _requiresApproval ? 'Yes' : 'No',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _requiresApproval ? const Color(0xFFE65100) : const Color(0xFF2E7D32),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Card Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.active,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _isSaving ? null : _saveCardPolicy,
                icon: _isSaving
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save, size: 16),
                label: const Text('Save Policy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Global Helper to save an inline quick field change
Future<void> _saveQuickField(WidgetRef ref, Employee updated, BuildContext context) async {
  try {
    await ref.read(employeeRepositoryProvider).updateEmployee(updated);
    ref.invalidate(employeesProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Leave policy updated for ${updated.fullName}'),
          backgroundColor: const Color(0xFF2E7D32),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  } catch (err) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save changes: $err'), backgroundColor: Colors.red),
      );
    }
  }
}
