import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../organization/presentation/widgets/column_selection_dialog.dart';
import '../domain/employee.dart';
import '../providers/employee_providers.dart';
import 'dialogs/employee_details_dialog.dart';
import 'dialogs/registration_links_dialog.dart';
import 'widgets/admin_list_toolbar.dart';

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
  late final TextEditingController _mobileSearchController = TextEditingController();

  @override
  void dispose() {
    _mobileSearchController.dispose();
    super.dispose();
  }

  String _getInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'EM';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(employeesProvider);
    final prefAsync = ref.watch(empColumnPreferenceProvider(_tableId));

    final searchQuery = ref.watch(empSearchQueryProvider);
    final orgFilter = ref.watch(empOrgFilterProvider);
    final deptFilter = ref.watch(empDeptFilterProvider);
    final desigFilter = ref.watch(empDesigFilterProvider);
    final statusFilter = ref.watch(empStatusFilterProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 720;

        return ColoredBox(
          color: Colors.white,
          child: employeesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Text('Unable to load employees: $err'),
            ),
            data: (allEmployees) {
              // Only active employees (imported and configured) come into Employee Management module table
              final employees = allEmployees.where((emp) {
                final s = emp.status.trim().toLowerCase();
                return s == 'active' || s == 'converted' || s == 'submitted';
              }).toList();

              // Populate unique dropdown filter choices
              final deptList = ['All Departments', ...{...Employee.departmentOptions, for (final e in employees) if (e.department.isNotEmpty) e.department}];
              final desigList = ['All Designations', ...{...Employee.designationOptions, for (final e in employees) if (e.designation.isNotEmpty) e.designation}];
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
                final matchesDesig = desigFilter == 'All Designations' || emp.designation == desigFilter;
                final matchesStatus = statusFilter == 'All Statuses' || emp.status == statusFilter;

                return matchesSearch && matchesOrg && matchesDept && matchesDesig && matchesStatus;
              }).toList();

              if (isMobile) {
                final totalItems = filtered.length;
                final totalPages = (totalItems / _rowsPerPage).ceil();
                final pageIndex = _currentPage.clamp(0, (totalPages - 1).clamp(0, 999));
                final startIndex = pageIndex * _rowsPerPage;
                final endIndex = (startIndex + _rowsPerPage).clamp(0, totalItems);
                final pageItems = filtered.sublist(startIndex, endIndex);

                return Column(
                  children: [
                    _buildMobileSearch(context, searchQuery),
                    _buildMobileFilterChips(context, deptList, desigList, statusList),
                    const Divider(height: 1),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
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
                            )
                          : _buildMobileList(pageItems),
                    ),
                    _buildPaginationBar(
                      totalItems: totalItems,
                      startIndex: startIndex,
                      endIndex: endIndex,
                      currentPage: pageIndex,
                      totalPages: totalPages,
                    ),
                    _buildStickyAddEmployeeButton(context),
                  ],
                );
              }

              // Desktop View Layout
              if (filtered.isEmpty) {
                return Column(
                  children: [
                    _buildToolbar(context, prefAsync),
                    const Divider(height: 1),
                    _buildFiltersRow(deptList, desigList, statusList),
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

              // Determine active visible columns for desktop
              final pref = prefAsync.valueOrNull;
              List<String> visibleCols;
              if (pref != null && pref.visibleColumns.isNotEmpty) {
                visibleCols = pref.visibleColumns;
              } else {
                visibleCols = List.from(_defaultAllColumns);
              }

              // Pagination for desktop
              final totalItems = filtered.length;
              final totalPages = (totalItems / _rowsPerPage).ceil();
              final pageIndex = _currentPage.clamp(0, (totalPages - 1).clamp(0, 999));
              final startIndex = pageIndex * _rowsPerPage;
              final endIndex = (startIndex + _rowsPerPage).clamp(0, totalItems);
              final pageItems = filtered.sublist(startIndex, endIndex);

              return Column(
                children: [
                  _buildToolbar(context, prefAsync),
                  const Divider(height: 1),
                  _buildFiltersRow(deptList, desigList, statusList),
                  const Divider(height: 1),
                  Expanded(
                    child: _buildDesktopTable(
                      pageItems,
                      visibleCols,
                      constraints.maxWidth,
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
        );
      },
    );
  }

  Widget _buildToolbar(
    BuildContext context,
    AsyncValue<dynamic> prefAsync,
  ) {
    final searchQuery = ref.watch(empSearchQueryProvider);

    return AdminListToolbar(
      title: 'Employee Management',
      searchHint: 'Search employees...',
      searchQuery: searchQuery,
      onSearchChanged: (val) {
        ref.read(empSearchQueryProvider.notifier).state = val;
        setState(() => _currentPage = 0);
      },
      onSearchCleared: () {
        ref.read(empSearchQueryProvider.notifier).state = '';
        setState(() => _currentPage = 0);
      },
      primaryActionLabel: 'Add Employee',
      primaryActionIcon: Icons.add,
      onPrimaryAction: () => GoRouter.of(context).push('/employee/register/new'),
      secondaryActions: [
        AdminToolbarAction(
          label: 'Export',
          icon: Icons.file_download_outlined,
          tooltip: 'Export (CSV/PDF)',
          onPressed: _exportData,
        ),
        AdminToolbarAction(
          label: 'Response',
          icon: Icons.rate_review_outlined,
          tooltip: 'Response',
          onPressed: () => _openRegistrationLinksDialog(context),
        ),
        AdminToolbarAction(
          label: 'Columns',
          icon: Icons.view_column_outlined,
          tooltip: 'Columns',
          onPressed: () => _openColumnSelectionDialog(context),
        ),
      ],
    );
  }

  Widget _buildFiltersRow(
    List<String> depts,
    List<String> desigs,
    List<String> statuses,
  ) {
    final currentOrg = ref.watch(empOrgFilterProvider);
    final currentDept = ref.watch(empDeptFilterProvider);
    final currentDesig = ref.watch(empDesigFilterProvider);
    final currentStatus = ref.watch(empStatusFilterProvider);

    return Container(
      width: double.infinity,
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
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.divider),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
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
            ),
          ),
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.divider),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: desigs.contains(currentDesig) ? currentDesig : desigs.first,
                isDense: true,
                style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                items: desigs.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                onChanged: (val) {
                  if (val != null) {
                    ref.read(empDesigFilterProvider.notifier).state = val;
                    setState(() => _currentPage = 0);
                  }
                },
              ),
            ),
          ),
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.divider),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
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
            ),
          ),
          if (currentOrg != 'All Organizations' ||
              currentDept != 'All Departments' ||
              currentDesig != 'All Designations' ||
              currentStatus != 'All Statuses')
            TextButton(
              onPressed: () {
                ref.read(empOrgFilterProvider.notifier).state = 'All Organizations';
                ref.read(empDeptFilterProvider.notifier).state = 'All Departments';
                ref.read(empDesigFilterProvider.notifier).state = 'All Designations';
                ref.read(empStatusFilterProvider.notifier).state = 'All Statuses';
                setState(() => _currentPage = 0);
              },
              child: const Text('Reset Filters', style: TextStyle(fontSize: 12, color: AppColors.active)),
            ),
        ],
      ),
    );
  }

  Future<void> _exportData() async {
    final employees = ref.read(employeesProvider).valueOrNull ?? const [];
    if (employees.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No employee records available to export.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('Employee ID,Employee Name,Department,Designation,Email Address,Phone Number,Employment Type,Status');
    for (final emp in employees) {
      buffer.writeln(
        '"${emp.employeeId}","${emp.fullName.replaceAll('"', '""')}","${emp.department.replaceAll('"', '""')}","${emp.designation.replaceAll('"', '""')}","${emp.emailAddress}","${emp.phoneNumber}","${emp.employmentType}","${emp.status}"',
      );
    }

    final String csvContent = buffer.toString();
    final Uri url = Uri.parse('data:text/csv;charset=utf-8,${Uri.encodeComponent(csvContent)}');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully exported ${employees.length} employee records!'),
              backgroundColor: AppColors.active,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export error: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _openRegistrationLinksDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => const RegistrationLinksDialog(),
    );
  }

  Future<void> _openColumnSelectionDialog(BuildContext context) async {
    final pref = ref.read(empColumnPreferenceProvider(_tableId)).valueOrNull;

    final updated = await showDialog<bool>(
      context: context,
      builder: (context) => ColumnSelectionDialog(
        tableId: _tableId,
        allColumns: _defaultAllColumns,
        currentVisibleColumns:
            pref?.visibleColumns ?? List.from(_defaultAllColumns),
        currentColumnOrder: pref?.columnOrder ?? List.from(_defaultAllColumns),
      ),
    );

    if (updated == true) {
      ref.invalidate(empColumnPreferenceProvider(_tableId));
    }
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
    final normalized = status.trim().toLowerCase();
    switch (normalized) {
      case 'accepted':
      case 'active':
        return Colors.green;
      case 'rejected':
        return Colors.redAccent;
      case 'pending':
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

  Widget _buildMobileSearch(BuildContext context, String searchQuery) {
    if (_mobileSearchController.text != searchQuery) {
      _mobileSearchController.text = searchQuery;
      _mobileSearchController.selection = TextSelection.fromPosition(
        TextPosition(offset: searchQuery.length),
      );
    }

    return Container(
      height: 48,
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: TextField(
        controller: _mobileSearchController,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search employees...',
          hintStyle: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    ref.read(empSearchQueryProvider.notifier).state = '';
                    setState(() => _currentPage = 0);
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          filled: true,
          fillColor: Colors.grey.withValues(alpha: 0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.active),
          ),
        ),
        onChanged: (val) {
          ref.read(empSearchQueryProvider.notifier).state = val;
          setState(() => _currentPage = 0);
        },
      ),
    );
  }

  Widget _buildMobileFilterChips(
    BuildContext context,
    List<String> depts,
    List<String> desigs,
    List<String> statuses,
  ) {
    final currentOrg = ref.watch(empOrgFilterProvider);
    final currentDept = ref.watch(empDeptFilterProvider);
    final currentDesig = ref.watch(empDesigFilterProvider);
    final currentStatus = ref.watch(empStatusFilterProvider);

    int activeCount = 0;
    if (currentOrg != 'All Organizations') activeCount++;
    if (currentDept != 'All Departments') activeCount++;
    if (currentDesig != 'All Designations') activeCount++;
    if (currentStatus != 'All Statuses') activeCount++;

    return Container(
      height: 42,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            InkWell(
              onTap: () => _openFilterBottomSheet(context, depts, desigs, statuses),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: activeCount > 0
                      ? AppColors.active.withValues(alpha: 0.12)
                      : Colors.grey.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: activeCount > 0 ? AppColors.active : AppColors.divider,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.tune,
                      size: 16,
                      color: activeCount > 0 ? AppColors.active : AppColors.textPrimary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Filters${activeCount > 0 ? " • $activeCount active" : ""}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: activeCount > 0 ? AppColors.active : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

            if (currentOrg != 'All Organizations')
              _buildActiveChip(
                label: currentOrg,
                onClear: () {
                  ref.read(empOrgFilterProvider.notifier).state = 'All Organizations';
                  setState(() => _currentPage = 0);
                },
              ),
            if (currentDept != 'All Departments')
              _buildActiveChip(
                label: currentDept,
                onClear: () {
                  ref.read(empDeptFilterProvider.notifier).state = 'All Departments';
                  setState(() => _currentPage = 0);
                },
              ),
            if (currentDesig != 'All Designations')
              _buildActiveChip(
                label: currentDesig,
                onClear: () {
                  ref.read(empDesigFilterProvider.notifier).state = 'All Designations';
                  setState(() => _currentPage = 0);
                },
              ),
            if (currentStatus != 'All Statuses')
              _buildActiveChip(
                label: currentStatus,
                onClear: () {
                  ref.read(empStatusFilterProvider.notifier).state = 'All Statuses';
                  setState(() => _currentPage = 0);
                },
              ),

            if (activeCount == 0)
              ...statuses.where((s) => s != 'All Statuses').map((status) {
                final isSelected = currentStatus == status;
                return Container(
                  margin: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () {
                      ref.read(empStatusFilterProvider.notifier).state =
                          isSelected ? 'All Statuses' : status;
                      setState(() => _currentPage = 0);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.active.withValues(alpha: 0.12)
                            : Colors.grey.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AppColors.active : AppColors.divider,
                        ),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? AppColors.active : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveChip({
    required String label,
    required VoidCallback onClear,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.active.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.active, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.active,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onClear,
            child: const Icon(
              Icons.close,
              size: 14,
              color: AppColors.active,
            ),
          ),
        ],
      ),
    );
  }

  void _openFilterBottomSheet(
    BuildContext context,
    List<String> depts,
    List<String> desigs,
    List<String> statuses,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final currentDept = ref.watch(empDeptFilterProvider);
            final currentDesig = ref.watch(empDesigFilterProvider);
            final currentStatus = ref.watch(empStatusFilterProvider);

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter Employees',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildBottomSheetDropdown(
                    label: 'Department',
                    value: currentDept,
                    items: depts,
                    onChanged: (val) {
                      ref.read(empDeptFilterProvider.notifier).state = val;
                      setState(() => _currentPage = 0);
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildBottomSheetDropdown(
                    label: 'Designation',
                    value: currentDesig,
                    items: desigs,
                    onChanged: (val) {
                      ref.read(empDesigFilterProvider.notifier).state = val;
                      setState(() => _currentPage = 0);
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildBottomSheetDropdown(
                    label: 'Status',
                    value: currentStatus,
                    items: statuses,
                    onChanged: (val) {
                      ref.read(empStatusFilterProvider.notifier).state = val;
                      setState(() => _currentPage = 0);
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            ref.read(empOrgFilterProvider.notifier).state = 'All Organizations';
                            ref.read(empDeptFilterProvider.notifier).state = 'All Departments';
                            ref.read(empDesigFilterProvider.notifier).state = 'All Designations';
                            ref.read(empStatusFilterProvider.notifier).state = 'All Statuses';
                            setState(() => _currentPage = 0);
                          },
                          child: const Text('Reset All'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.active,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBottomSheetDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.divider),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : items.first,
              isExpanded: true,
              items: items
                  .map((i) => DropdownMenuItem(value: i, child: Text(i, style: const TextStyle(fontSize: 14))))
                  .toList(),
              onChanged: (val) {
                if (val != null) onChanged(val);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactEmployeeCard(BuildContext context, Employee emp) {
    final statusColor = _getStatusColor(emp.status);
    final initials = _getInitials(emp.fullName);

    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.divider, width: 0.8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Initials Avatar
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.active.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.active,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Employee Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    emp.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'ID: ${emp.employeeId}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.active,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (emp.department.isNotEmpty) emp.department,
                      if (emp.designation.isNotEmpty) emp.designation,
                    ].join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Email: ${emp.emailAddress.isEmpty ? '-' : emp.emailAddress} • Phone: ${emp.phoneNumber.isEmpty ? '-' : emp.phoneNumber}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Status Badge (equal size/height to View Button) + View Button + ⋮ Menu
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor, width: 1),
                  ),
                  child: Text(
                    emp.status,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  height: 32,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      side: const BorderSide(color: AppColors.divider),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    onPressed: () => _openViewDialog(context, emp),
                    child: const Text(
                      'View',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20, color: AppColors.textSecondary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Edit', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(fontSize: 13, color: Colors.redAccent)),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'edit') {
                      _openEditDialog(context, emp);
                    } else if (value == 'delete') {
                      _confirmDelete(context, emp);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileList(List<Employee> pageItems) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      itemCount: pageItems.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _buildCompactEmployeeCard(context, pageItems[index]),
    );
  }

  Widget _buildStickyAddEmployeeButton(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        10 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: AppColors.divider)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 44,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.active,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () => GoRouter.of(context).push('/employee/register/new'),
          icon: const Icon(Icons.add, size: 20),
          label: const Text(
            'Add Employee',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
      ),
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
