import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../organization/presentation/widgets/column_selection_dialog.dart';
import '../domain/employee.dart';
import '../providers/employee_providers.dart';
import 'dialogs/employee_details_dialog.dart';
import 'dialogs/registration_links_dialog.dart';

class EmployeeManagementPage extends ConsumerStatefulWidget {
  const EmployeeManagementPage({super.key});

  @override
  ConsumerState<EmployeeManagementPage> createState() =>
      _EmployeeManagementPageState();
}

class _EmployeeManagementPageState
    extends ConsumerState<EmployeeManagementPage> {
  static const String _tableId = 'employee_management_table';

  static const List<String> _defaultAllColumns = [
    'Employee ID',
    'Employee Name',
    'Organization Name',
    'Department',
    'Designation',
    'Email Address',
    'Phone Number',
    'Employment Type',
    'Joining Date',
    'Status',
  ];

  int _currentPage = 0;
  int _rowsPerPage = 10;
  final Set<int> _selectedIds = {};

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(employeesProvider);
    final prefAsync = ref.watch(empColumnPreferenceProvider(_tableId));

    final searchQuery = ref.watch(empSearchQueryProvider);
    final orgFilter = ref.watch(empOrgFilterProvider);
    final deptFilter = ref.watch(empDeptFilterProvider);
    final statusFilter = ref.watch(empStatusFilterProvider);

    return ColoredBox(
      color: Colors.white,
      child: Column(
        children: [
          _buildToolbar(context, prefAsync),
          const Divider(height: 1),
          Expanded(
            child: employeesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text('Unable to load employees: $err'),
              ),
              data: (allEmployees) {
                // Only employees accepted in responses (or active) come into Employee Management module table
                final employees = allEmployees.where((emp) {
                  final s = emp.status.trim().toLowerCase();
                  return s == 'accepted' || s == 'active';
                }).toList();

                // Populate unique dropdown filter choices
                final orgList = ['All Organizations', ...{for (final e in employees) if (e.organizationName.isNotEmpty) e.organizationName}];
                final deptList = ['All Departments', ...{for (final e in employees) if (e.department.isNotEmpty) e.department}];
                final statusList = ['All Statuses', ...{for (final e in employees) if (e.status.isNotEmpty) e.status}];

                final filtered = employees.where((emp) {
                  final q = searchQuery.toLowerCase().trim();
                  final matchesSearch = q.isEmpty ||
                      emp.employeeId.toLowerCase().contains(q) ||
                      emp.fullName.toLowerCase().contains(q) ||
                      emp.organizationName.toLowerCase().contains(q) ||
                      emp.department.toLowerCase().contains(q) ||
                      emp.designation.toLowerCase().contains(q) ||
                      emp.emailAddress.toLowerCase().contains(q) ||
                      emp.phoneNumber.toLowerCase().contains(q);

                  final matchesOrg = orgFilter == 'All Organizations' || emp.organizationName == orgFilter;
                  final matchesDept = deptFilter == 'All Departments' || emp.department == deptFilter;
                  final matchesStatus = statusFilter == 'All Statuses' || emp.status == statusFilter;

                  return matchesSearch && matchesOrg && matchesDept && matchesStatus;
                }).toList();

                if (filtered.isEmpty) {
                  return Column(
                    children: [
                      _buildFiltersRow(orgList, deptList, statusList),
                      const Expanded(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Text(
                              'No employees found.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }

                // Determine active visible columns
                final pref = prefAsync.valueOrNull;
                List<String> visibleCols;
                if (pref != null && pref.visibleColumns.isNotEmpty) {
                  visibleCols = pref.visibleColumns;
                } else {
                  visibleCols = List.from(_defaultAllColumns);
                }

                // Pagination
                final totalItems = filtered.length;
                final totalPages = (totalItems / _rowsPerPage).ceil();
                final pageIndex = _currentPage.clamp(0, (totalPages - 1).clamp(0, 999));
                final startIndex = pageIndex * _rowsPerPage;
                final endIndex = (startIndex + _rowsPerPage).clamp(0, totalItems);
                final pageItems = filtered.sublist(startIndex, endIndex);

                return Column(
                  children: [
                    _buildFiltersRow(orgList, deptList, statusList),
                    const Divider(height: 1),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) =>
                            constraints.maxWidth < 720
                                ? _buildMobileList(pageItems)
                                : _buildDesktopTable(
                                    pageItems,
                                    visibleCols,
                                    constraints.maxWidth,
                                  ),
                      ),
                    ),
                    _buildPaginationBar(
                      totalItems: totalItems,
                      startIndex: startIndex,
                      endIndex: endIndex,
                      currentPage: pageIndex,
                      totalPages: totalPages,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(
    BuildContext context,
    AsyncValue<dynamic> prefAsync,
  ) {
    final searchController = TextEditingController(
      text: ref.read(empSearchQueryProvider),
    );
    searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: searchController.text.length),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 640;

          return Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    'Employee Management',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: isCompact ? 140 : 200,
                    height: 36,
                    child: TextField(
                      controller: searchController,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search employees...',
                        hintStyle: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        prefixIcon: const Icon(Icons.search, size: 18),
                        suffixIcon: searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  ref
                                      .read(empSearchQueryProvider.notifier)
                                      .state = '';
                                  setState(() => _currentPage = 0);
                                },
                              )
                            : null,
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide:
                              const BorderSide(color: AppColors.divider),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide:
                              const BorderSide(color: AppColors.active),
                        ),
                      ),
                      onChanged: (val) {
                        ref.read(empSearchQueryProvider.notifier).state = val;
                        setState(() => _currentPage = 0);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.file_download_outlined, size: 20),
                    tooltip: 'Export (CSV/PDF)',
                    onPressed: _exportData,
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      side: const BorderSide(color: AppColors.divider),
                    ),
                    onPressed: () => _openRegistrationLinksDialog(context),
                    icon: const Icon(Icons.rate_review_outlined, size: 18),
                    label: const Text('Response', style: TextStyle(fontSize: 13)),
                  ),
                  if (!isCompact) ...[
                    const SizedBox(width: 4),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        side: const BorderSide(color: AppColors.divider),
                      ),
                      onPressed: () => _openColumnSelectionDialog(context),
                      icon: const Icon(Icons.view_column_outlined, size: 18),
                      label: const Text('Columns', style: TextStyle(fontSize: 13)),
                    ),
                  ],
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.active,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                    onPressed: () => GoRouter.of(context).push('/employee/register/new'),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(
                      isCompact ? 'Add' : 'Add Employee',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFiltersRow(
    List<String> orgs,
    List<String> depts,
    List<String> statuses,
  ) {
    final currentOrg = ref.watch(empOrgFilterProvider);
    final currentDept = ref.watch(empDeptFilterProvider);
    final currentStatus = ref.watch(empStatusFilterProvider);

    return Container(
      color: Colors.grey.withValues(alpha: 0.05),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text(
            'Filters:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          DropdownButton<String>(
            value: orgs.contains(currentOrg) ? currentOrg : orgs.first,
            isDense: true,
            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
            items: orgs.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
            onChanged: (val) {
              if (val != null) {
                ref.read(empOrgFilterProvider.notifier).state = val;
                setState(() => _currentPage = 0);
              }
            },
          ),
          DropdownButton<String>(
            value: depts.contains(currentDept) ? currentDept : depts.first,
            isDense: true,
            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
            items: depts.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
            onChanged: (val) {
              if (val != null) {
                ref.read(empDeptFilterProvider.notifier).state = val;
                setState(() => _currentPage = 0);
              }
            },
          ),
          DropdownButton<String>(
            value: statuses.contains(currentStatus) ? currentStatus : statuses.first,
            isDense: true,
            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
            items: statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (val) {
              if (val != null) {
                ref.read(empStatusFilterProvider.notifier).state = val;
                setState(() => _currentPage = 0);
              }
            },
          ),
          if (currentOrg != 'All Organizations' ||
              currentDept != 'All Departments' ||
              currentStatus != 'All Statuses')
            TextButton(
              onPressed: () {
                ref.read(empOrgFilterProvider.notifier).state = 'All Organizations';
                ref.read(empDeptFilterProvider.notifier).state = 'All Departments';
                ref.read(empStatusFilterProvider.notifier).state = 'All Statuses';
                setState(() => _currentPage = 0);
              },
              child: const Text('Reset Filters', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  void _exportData() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Exporting Employee list to Excel / PDF...'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openRegistrationLinksDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => const RegistrationLinksDialog(),
    );
  }

  void _openColumnSelectionDialog(BuildContext context) {
    final pref = ref.read(empColumnPreferenceProvider(_tableId)).valueOrNull;

    showDialog<bool>(
      context: context,
      builder: (context) => ColumnSelectionDialog(
        tableId: _tableId,
        allColumns: _defaultAllColumns,
        currentVisibleColumns:
            pref?.visibleColumns ?? List.from(_defaultAllColumns),
        currentColumnOrder: pref?.columnOrder ?? List.from(_defaultAllColumns),
      ),
    );
  }

  void _openViewDialog(BuildContext context, Employee emp) {
    showDialog<void>(
      context: context,
      builder: (context) => EmployeeDetailsDialog(employee: emp),
    );
  }

  void _openEditDialog(BuildContext context, Employee emp) {
    GoRouter.of(context).push('/employee/register/edit', extra: emp);
  }

  Future<void> _confirmDelete(BuildContext context, Employee emp) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Text('Confirm Delete'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete employee "${emp.fullName}" (${emp.employeeId})?\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(employeeRepositoryProvider).deleteEmployee(emp.id);
      ref.invalidate(employeesProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted "${emp.fullName}"')),
      );
    }
  }


  Color _getStatusColor(String status) {
    switch (status) {
      case 'Accepted':
      case 'Active':
        return Colors.green;
      case 'Rejected':
        return Colors.redAccent;
      case 'Pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _buildDesktopTable(
    List<Employee> employees,
    List<String> visibleColumns,
    double screenWidth,
  ) {
    final minTableWidth = (visibleColumns.length * 140.0 + 440.0).clamp(800.0, 3200.0);

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: screenWidth < minTableWidth ? minTableWidth : screenWidth,
            child: SingleChildScrollView(
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  Colors.grey.withValues(alpha: 0.06),
                ),
                headingRowHeight: 44,
                dataRowMinHeight: 52,
                dataRowMaxHeight: 60,
                horizontalMargin: 16,
                columnSpacing: 18,
                showCheckboxColumn: true,
                onSelectAll: (selected) {
                  setState(() {
                    if (selected == true) {
                      _selectedIds.addAll(employees.map((e) => e.id));
                    } else {
                      _selectedIds.removeAll(employees.map((e) => e.id));
                    }
                  });
                },
                headingTextStyle: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
                columns: [
                  for (final colName in visibleColumns)
                    DataColumn(label: Text(colName.toUpperCase())),
                  const DataColumn(label: Text('ACTIONS')),
                ],
                rows: employees.map((emp) {
                  final isSelected = _selectedIds.contains(emp.id);
                  return DataRow(
                    selected: isSelected,
                    onSelectChanged: (selected) {
                      setState(() {
                        if (selected == true) {
                          _selectedIds.add(emp.id);
                        } else {
                          _selectedIds.remove(emp.id);
                        }
                      });
                    },
                    cells: [
                      for (final colName in visibleColumns)
                        DataCell(_buildCellContent(colName, emp)),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () => _openViewDialog(context, emp),
                              icon: const Icon(Icons.remove_red_eye_outlined,
                                  size: 16, color: AppColors.textPrimary),
                              label: const Text(
                                'View',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () => _openEditDialog(context, emp),
                              icon: const Icon(Icons.edit_outlined,
                                  size: 16, color: AppColors.textPrimary),
                              label: const Text(
                                'Edit',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () => _confirmDelete(context, emp),
                              icon: const Icon(Icons.delete_outline,
                                  size: 16, color: Colors.redAccent),
                              label: const Text(
                                'Delete',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.redAccent,
                                ),
                              ),
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
      ),
    );
  }

  Widget _buildCellContent(String columnName, Employee emp) {
    String value = '';
    Widget? customWidget;
    TextStyle? style;

    switch (columnName) {
      case 'Employee ID':
        value = emp.employeeId;
        style = const TextStyle(fontWeight: FontWeight.bold, color: AppColors.active);
        break;
      case 'Employee Name':
        value = emp.fullName;
        style = const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary);
        break;
      case 'Organization Name':
        value = emp.organizationName;
        break;
      case 'Department':
        value = emp.department;
        break;
      case 'Designation':
        value = emp.designation;
        break;
      case 'Email Address':
        value = emp.emailAddress;
        break;
      case 'Phone Number':
        value = emp.phoneNumber;
        break;
      case 'Employment Type':
        value = emp.employmentType;
        break;
      case 'Joining Date':
        value = emp.joiningDate;
        break;
      case 'Status':
        final statusColor = _getStatusColor(emp.status);
        customWidget = Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor, width: 0.8),
          ),
          child: Text(
            emp.status,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
        );
        break;
      default:
        value = '';
    }

    if (customWidget != null) return customWidget;

    return SizedBox(
      width: 130,
      child: Text(
        value.isEmpty ? '-' : value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: style ?? const TextStyle(fontSize: 13),
      ),
    );
  }

  Widget _buildMobileList(List<Employee> employees) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: employees.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final emp = employees[index];
        final statusColor = _getStatusColor(emp.status);

        return Card(
          elevation: 1.5,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppColors.divider, width: 0.8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
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
                            emp.fullName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.active,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.active.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              emp.employeeId,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.active,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor, width: 0.8),
                      ),
                      child: Text(
                        emp.status,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Department: ${emp.department.isEmpty ? '-' : emp.department}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                ),
                if (emp.designation.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Designation: ${emp.designation}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _openViewDialog(context, emp),
                      icon: const Icon(Icons.remove_red_eye_outlined, size: 16, color: AppColors.active),
                      label: const Text('View', style: TextStyle(fontSize: 12, color: AppColors.active)),
                    ),

                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _openEditDialog(context, emp),
                      icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.active),
                      label: const Text('Edit', style: TextStyle(fontSize: 12, color: AppColors.active)),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _confirmDelete(context, emp),
                      icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                      label: const Text('Delete', style: TextStyle(fontSize: 12, color: Colors.redAccent)),
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

  Widget _buildPaginationBar({
    required int totalItems,
    required int startIndex,
    required int endIndex,
    required int currentPage,
    required int totalPages,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 480;

        final showingText = Text(
          totalItems == 0
              ? 'Showing 0 records'
              : 'Showing ${startIndex + 1} - $endIndex of $totalItems',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        );

        final controlsRow = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Rows: ',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            DropdownButton<int>(
              value: _rowsPerPage,
              isDense: true,
              underline: const SizedBox(),
              items: [5, 10, 20, 50]
                  .map(
                    (val) => DropdownMenuItem(
                      value: val,
                      child: Text(
                        '$val',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _rowsPerPage = val;
                    _currentPage = 0;
                  });
                }
              },
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 20),
              onPressed: currentPage > 0
                  ? () => setState(() => _currentPage -= 1)
                  : null,
            ),
            Text(
              '${totalPages == 0 ? 0 : currentPage + 1} / $totalPages',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 20),
              onPressed: currentPage < totalPages - 1
                  ? () => setState(() => _currentPage += 1)
                  : null,
            ),
          ],
        );

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.divider)),
          ),
          child: isCompact
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    showingText,
                    const SizedBox(height: 4),
                    controlsRow,
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    showingText,
                    controlsRow,
                  ],
                ),
        );
      },
    );
  }
}
